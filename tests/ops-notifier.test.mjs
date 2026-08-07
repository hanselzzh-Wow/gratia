import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

// 走 worker 的 scheduled 入口而不是直接 import 模块：构建把服务端打成
// 单个 dist/server/index.js，没有单独的 ops-notifier.js 可以引；而且这样
// 测到的是真实链路——真 SQL、真表结构、真的 Cron 处理函数。

class D1Statement {
  constructor(database, sql, values = []) {
    this.database = database; this.sql = sql; this.values = values;
  }
  bind(...values) { return new D1Statement(this.database, this.sql, values); }
  async run() {
    const r = this.database.prepare(this.sql).run(...this.values);
    return { success: true, results: [], meta: { changes: Number(r.changes ?? 0) } };
  }
  async all() {
    return { success: true, results: this.database.prepare(this.sql).all(...this.values), meta: {} };
  }
  async first() { return this.database.prepare(this.sql).get(...this.values) ?? null; }
}
class TestD1 {
  constructor() { this.database = new DatabaseSync(":memory:"); }
  prepare(sql) { return new D1Statement(this.database, sql); }
  async batch(statements) { return Promise.all(statements.map((s) => s.run())); }
  async exec(sql) { this.database.exec(sql); return { count: 0, duration: 0 }; }
}

async function setup(extraEnv = {}) {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("ops-test", `${process.pid}-${Date.now()}-${Math.random()}`);
  const { default: worker } = await import(workerUrl.href);
  const database = new TestD1();
  const env = {
    DB: database,
    ADMIN_API_KEY: "test-admin-pin",
    PUBLIC_APP_ORIGIN: "https://ops.example.com",
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
    ...extraEnv,
  };
  const pending = [];
  const ctx = { waitUntil(p) { pending.push(p); }, passThroughOnException() {} };
  const request = (path, init = {}) =>
    worker.fetch(new Request(`http://localhost${path}`, init), env, ctx);
  // 跑一次真实发布，既建好全部表结构，也留下一条 pending_review 的心愿
  const publish = async (message) => {
    const response = await request("/api/wishes", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        requesterName: "小白", contact: "wx-001", city: "杭州", landmark: "西湖断桥",
        occasion: "生日祝福", message, deliveryType: "spoken_video",
        deadlineText: "本周六前", rewardFen: 500, contactConsent: true,
      }),
    });
    assert.equal(response.status, 201, `发布心愿失败：${await response.clone().text()}`);
    return response;
  };
  /** 触发一次 Cron，并等待 waitUntil 里的异步工作完成 */
  const runCron = async () => {
    await worker.scheduled({ scheduledTime: Date.now(), cron: "*/15 * * * *" }, env, ctx);
    await Promise.all(pending.splice(0));
  };
  return { worker, env, ctx, request, publish, runCron };
}

function mailStub(status = 200) {
  const calls = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    if (String(url).includes("api.resend.com")) {
      calls.push({ body: JSON.parse(init.body), headers: init.headers });
      return new Response(JSON.stringify({ id: "mail-1" }), { status });
    }
    return original(url, init);
  };
  return { calls, restore() { globalThis.fetch = original; } };
}

const MAIL_ENV = { RESEND_API_KEY: "re_test", OPS_NOTIFY_EMAIL: "ops@example.com" };

test("没有待审内容时不发信", async () => {
  const { request, runCron } = await setup(MAIL_ENV);
  await request("/api/health");            // 建表，但不产生待审内容
  const mail = mailStub();
  try {
    await runCron();
    assert.equal(mail.calls.length, 0, "队列为空不该发信");
  } finally { mail.restore(); }
});

test("有待审心愿时发一封，写明数量与运营台地址", async () => {
  const { publish, runCron } = await setup(MAIL_ENV);
  await publish("请替我在断桥上说一声生日快乐。");
  const mail = mailStub();
  try {
    await runCron();
    assert.equal(mail.calls.length, 1);
    const { body, headers } = mail.calls[0];
    assert.equal(headers.authorization, "Bearer re_test");
    assert.deepEqual(body.to, ["ops@example.com"]);
    assert.match(body.subject, /1 项待审/);
    assert.match(body.text, /心愿正文 1 条/);
    assert.match(body.text, /https:\/\/ops\.example\.com\/ops\//);
    assert.doesNotMatch(body.text, /断桥/, "提醒邮件不该带出用户正文");
  } finally { mail.restore(); }
});

// 这条是这个功能最要紧的：Cron 每 15 分钟跑一次，不去重就会为同一批
// 内容反复发信，提醒多了等于没有提醒。
test("待审内容没变化时不重复发信", async () => {
  const { publish, runCron } = await setup(MAIL_ENV);
  await publish("请替我在断桥上说一声生日快乐。");
  const mail = mailStub();
  try {
    await runCron();
    await runCron();
    await runCron();
    assert.equal(mail.calls.length, 1, "同一批内容只该提醒一次");
  } finally { mail.restore(); }
});

test("又来了新的待审内容时会再发", async () => {
  const { publish, runCron } = await setup(MAIL_ENV);
  await publish("请替我在断桥上说一声生日快乐。");
  const mail = mailStub();
  try {
    await runCron();
    await publish("也请替我看看那棵老桂花树。");
    await runCron();
    assert.equal(mail.calls.length, 2);
    assert.match(mail.calls[1].body.subject, /2 项待审/);
  } finally { mail.restore(); }
});

test("没配密钥时静默跳过，不发信也不抛错", async () => {
  const { publish, runCron } = await setup();     // 不给 RESEND_API_KEY
  await publish("请替我在断桥上说一声生日快乐。");
  const mail = mailStub();
  try {
    await runCron();
    assert.equal(mail.calls.length, 0);
  } finally { mail.restore(); }
});

test("邮件服务报错时不抛出，且该批内容下次仍会被提醒", async () => {
  const { publish, runCron } = await setup(MAIL_ENV);
  await publish("请替我在断桥上说一声生日快乐。");
  const failing = mailStub(422);
  try {
    await runCron();
    assert.equal(failing.calls.length, 1);
  } finally { failing.restore(); }

  const ok = mailStub(200);
  try {
    await runCron();
    assert.equal(ok.calls.length, 1, "上次发失败的内容，这次仍应尝试");
  } finally { ok.restore(); }
});

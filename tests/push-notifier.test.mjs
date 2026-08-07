import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

// 走 worker 的真实端点，而不是直接 import 模块：构建把服务端打成单个
// dist/server/index.js。这样测到的是真链路——真 SQL、真表结构、真触发点。

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

/** 一把可用的 P-256 私钥，用来验证 APNs 的 JWT 真的签得出来。 */
async function testPrivateKeyPem() {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", pair.privateKey);
  const body = Buffer.from(pkcs8).toString("base64").match(/.{1,64}/g).join("\n");
  return `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----`;
}

async function setup(extraEnv = {}) {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("push-test", `${process.pid}-${Date.now()}-${Math.random()}`);
  const { default: worker } = await import(workerUrl.href);
  const database = new TestD1();
  const env = {
    DB: database,
    ADMIN_API_KEY: "test-admin-pin",
    APPLE_BUNDLE_ID: "com.hanselzzh.gratia",
    APPLE_TEAM_ID: "TEAMID1234",
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
    ...extraEnv,
  };
  const pending = [];
  const ctx = { waitUntil(p) { pending.push(p); }, passThroughOnException() {} };
  const request = (path, init = {}) =>
    worker.fetch(new Request(`http://localhost${path}`, init), env, ctx);
  const settle = async () => { await Promise.all(pending.splice(0)); };
  return { worker, env, request, settle, database };
}

/** 拦截发往 APNs 的请求，其余照常。 */
function apnsStub(status = 200, reason) {
  const calls = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const href = String(url);
    if (href.includes("push.apple.com")) {
      calls.push({ url: href, headers: init.headers, body: JSON.parse(init.body) });
      return new Response(reason ? JSON.stringify({ reason }) : "{}", { status });
    }
    if (href.includes("api.weixin.qq.com")) {
      return Response.json({ openid: `openid-${new URL(href).searchParams.get("js_code")}` });
    }
    return original(url, init);
  };
  return { calls, restore() { globalThis.fetch = original; } };
}

const h = (token) => ({ "content-type": "application/json", authorization: `Bearer ${token}` });

async function signIn(request, code) {
  const response = await request("/api/auth/wechat", {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ code }),
  });
  return (await response.json()).token;
}

test("没配 APNs 密钥时静默跳过，不发任何请求", async () => {
  const { request, settle } = await setup({ WECHAT_MINI_PROGRAM_APP_ID: "id", WECHAT_MINI_PROGRAM_APP_SECRET: "s" });
  const apns = apnsStub();
  try {
    const token = await signIn(request, "no-key-user");
    const registered = await request("/api/account/device-token", {
      method: "POST", headers: h(token),
      body: JSON.stringify({ token: "device-aaa", environment: "production" }),
    });
    assert.equal(registered.status, 201);
    await settle();
    assert.equal(apns.calls.length, 0, "没有密钥就不该往 APNs 发任何东西");
  } finally { apns.restore(); }
});

test("注册设备令牌：同一 token 重复上报不会产生第二条", async () => {
  const pem = await testPrivateKeyPem();
  const { request, database } = await setup({
    WECHAT_MINI_PROGRAM_APP_ID: "id", WECHAT_MINI_PROGRAM_APP_SECRET: "s",
    APNS_KEY_ID: "KEYID12345", APNS_PRIVATE_KEY: pem,
  });
  const apns = apnsStub();
  try {
    const token = await signIn(request, "device-user");
    for (const env of ["sandbox", "production"]) {
      await request("/api/account/device-token", {
        method: "POST", headers: h(token),
        body: JSON.stringify({ token: "device-same", environment: env }),
      });
    }
    const rows = database.database.prepare("SELECT token, environment FROM device_tokens").all();
    assert.equal(rows.length, 1, "同一台设备只该有一条记录");
    assert.equal(rows[0].environment, "production", "重复上报应更新为最新的环境");
  } finally { apns.restore(); }
});

test("缺少令牌时返回 400", async () => {
  const { request } = await setup({ WECHAT_MINI_PROGRAM_APP_ID: "id", WECHAT_MINI_PROGRAM_APP_SECRET: "s" });
  const apns = apnsStub();
  try {
    const token = await signIn(request, "bad-token-user");
    const response = await request("/api/account/device-token", {
      method: "POST", headers: h(token), body: JSON.stringify({}),
    });
    assert.equal(response.status, 400);
  } finally { apns.restore(); }
});

test("退出登录注销令牌后不再收到推送", async () => {
  const pem = await testPrivateKeyPem();
  const { request, database } = await setup({
    WECHAT_MINI_PROGRAM_APP_ID: "id", WECHAT_MINI_PROGRAM_APP_SECRET: "s",
    APNS_KEY_ID: "KEYID12345", APNS_PRIVATE_KEY: pem,
  });
  const apns = apnsStub();
  try {
    const token = await signIn(request, "signout-user");
    await request("/api/account/device-token", {
      method: "POST", headers: h(token), body: JSON.stringify({ token: "device-bye" }),
    });
    assert.equal(database.database.prepare("SELECT COUNT(*) AS n FROM device_tokens").get().n, 1);

    const removed = await request("/api/account/device-token", { method: "DELETE", headers: h(token) });
    assert.equal(removed.status, 200);
    assert.equal(
      database.database.prepare("SELECT COUNT(*) AS n FROM device_tokens").get().n, 0,
      "不注销的话，通知会继续推到一台已经换人的设备上",
    );
  } finally { apns.restore(); }
});

test("收到私聊消息时推给对方，且不推给自己", async () => {
  const pem = await testPrivateKeyPem();
  const { request, settle } = await setup({
    WECHAT_MINI_PROGRAM_APP_ID: "id", WECHAT_MINI_PROGRAM_APP_SECRET: "s",
    APNS_KEY_ID: "KEYID12345", APNS_PRIVATE_KEY: pem,
  });
  const apns = apnsStub();
  try {
    const ownerToken = await signIn(request, "push-owner");
    const helperToken = await signIn(request, "push-helper");

    const created = await (await request("/api/account/wishes", {
      method: "POST", headers: h(ownerToken),
      body: JSON.stringify({
        requesterName: "小白", contact: "wx", city: "上海", landmark: "外滩",
        occasion: "生日祝福", message: "请替我对着江面说一句生日快乐。",
        deliveryType: "spoken_video", deadlineText: "本周六前", rewardFen: 500, contactConsent: true,
      }),
    })).json();
    const wishId = created.wish.id;
    await request(`/api/admin/wishes/${wishId}`, {
      method: "PATCH", headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });
    const responded = await (await request(`/api/account/wishes/${wishId}/responses`, {
      method: "POST", headers: h(helperToken),
      body: JSON.stringify({ responderName: "阿哲", contact: "wx2", note: "我住附近", contentLicenseAgreed: true }),
    })).json();
    const responseId = responded.response.id;

    // 双方都注册设备
    await request("/api/account/device-token", {
      method: "POST", headers: h(ownerToken), body: JSON.stringify({ token: "device-owner" }),
    });
    await request("/api/account/device-token", {
      method: "POST", headers: h(helperToken), body: JSON.stringify({ token: "device-helper" }),
    });
    await settle();
    apns.calls.length = 0;

    // 帮助者发消息 → 只推给发布者
    await request(`/api/account/conversations/${responseId}/messages`, {
      method: "POST", headers: h(helperToken), body: JSON.stringify({ body: "我八点半到外滩" }),
    });
    await settle();

    assert.equal(apns.calls.length, 1, "一条消息只该推一次");
    const call = apns.calls[0];
    assert.ok(call.url.endsWith("/3/device/device-owner"), "该推给发布者，不是发消息的人自己");
    assert.equal(call.headers["apns-topic"], "com.hanselzzh.gratia");
    assert.match(String(call.headers.authorization), /^bearer /);
    assert.equal(call.body.aps.alert.title, "收到一条新消息");
    assert.match(call.body.aps.alert.body, /八点半/);
    assert.equal(call.body.aps["thread-id"], responseId, "同一会话的通知要能折叠成一组");
  } finally { apns.restore(); }
});

test("APNs 报 410 时删除失效令牌，不再反复重试", async () => {
  const pem = await testPrivateKeyPem();
  const { request, settle, database } = await setup({
    WECHAT_MINI_PROGRAM_APP_ID: "id", WECHAT_MINI_PROGRAM_APP_SECRET: "s",
    APNS_KEY_ID: "KEYID12345", APNS_PRIVATE_KEY: pem,
  });
  const apns = apnsStub(410);
  try {
    const ownerToken = await signIn(request, "gone-owner");
    const helperToken = await signIn(request, "gone-helper");
    const created = await (await request("/api/account/wishes", {
      method: "POST", headers: h(ownerToken),
      body: JSON.stringify({
        requesterName: "小白", contact: "wx", city: "上海", landmark: "外滩",
        occasion: "生日祝福", message: "请替我对着江面说一句生日快乐。",
        deliveryType: "spoken_video", deadlineText: "本周六前", rewardFen: 500, contactConsent: true,
      }),
    })).json();
    const wishId = created.wish.id;
    await request(`/api/admin/wishes/${wishId}`, {
      method: "PATCH", headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });
    const responded = await (await request(`/api/account/wishes/${wishId}/responses`, {
      method: "POST", headers: h(helperToken),
      body: JSON.stringify({ responderName: "阿哲", contact: "wx2", note: "我住附近", contentLicenseAgreed: true }),
    })).json();
    await request("/api/account/device-token", {
      method: "POST", headers: h(ownerToken), body: JSON.stringify({ token: "device-gone" }),
    });
    await settle();

    await request(`/api/account/conversations/${responded.response.id}/messages`, {
      method: "POST", headers: h(helperToken), body: JSON.stringify({ body: "在吗" }),
    });
    await settle();

    assert.equal(
      database.database.prepare("SELECT COUNT(*) AS n FROM device_tokens WHERE token = 'device-gone'").get().n,
      0,
      "410 表示这台设备卸载了或令牌换了，不删的话每次推送都白跑一次",
    );
  } finally { apns.restore(); }
});

test("心愿审核通过与未通过都会通知发布者", async () => {
  const pem = await testPrivateKeyPem();
  const { request, settle } = await setup({
    WECHAT_MINI_PROGRAM_APP_ID: "id", WECHAT_MINI_PROGRAM_APP_SECRET: "s",
    APNS_KEY_ID: "KEYID12345", APNS_PRIVATE_KEY: pem,
  });
  const apns = apnsStub();
  try {
    const ownerToken = await signIn(request, "review-owner");
    await request("/api/account/device-token", {
      method: "POST", headers: h(ownerToken), body: JSON.stringify({ token: "device-review" }),
    });

    const make = async (message) =>
      (await (await request("/api/account/wishes", {
        method: "POST", headers: h(ownerToken),
        body: JSON.stringify({
          requesterName: "小白", contact: "wx", city: "上海", landmark: "外滩",
          occasion: "生日祝福", message, deliveryType: "spoken_video",
          deadlineText: "本周六前", rewardFen: 500, contactConsent: true,
        }),
      })).json()).wish.id;

    const approvedId = await make("请替我对着江面说一句生日快乐。");
    await settle(); apns.calls.length = 0;
    await request(`/api/admin/wishes/${approvedId}`, {
      method: "PATCH", headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });
    await settle();
    assert.equal(apns.calls.length, 1);
    assert.equal(apns.calls[0].body.aps.alert.title, "心愿已通过审核");

    const rejectedId = await make("这条会被退回，测试用的正文内容。");
    await settle(); apns.calls.length = 0;
    await request(`/api/admin/wishes/${rejectedId}`, {
      method: "PATCH", headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "reject", note: "含违规词" }),
    });
    await settle();
    assert.equal(apns.calls.length, 1, "没通过更要通知——否则发布者会一直以为还在排队");
    assert.equal(apns.calls[0].body.aps.alert.title, "心愿未通过审核");
    assert.match(apns.calls[0].body.aps.alert.body, /违规/);
  } finally { apns.restore(); }
});

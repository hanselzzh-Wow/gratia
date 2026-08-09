import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";

class D1Statement {
  constructor(database, sql, values = []) {
    this.database = database;
    this.sql = sql;
    this.values = values;
  }

  bind(...values) {
    return new D1Statement(this.database, this.sql, values);
  }

  async run() {
    const result = this.database.prepare(this.sql).run(...this.values);
    return {
      success: true,
      results: [],
      meta: {
        changes: Number(result.changes ?? 0),
        last_row_id: Number(result.lastInsertRowid ?? 0),
      },
    };
  }

  async all() {
    return {
      success: true,
      results: this.database.prepare(this.sql).all(...this.values),
      meta: { changes: 0 },
    };
  }

  async first() {
    return this.database.prepare(this.sql).get(...this.values) ?? null;
  }
}

class TestD1 {
  constructor() {
    this.database = new DatabaseSync(":memory:");
    this.database.exec("PRAGMA foreign_keys = ON");
  }

  prepare(sql) {
    return new D1Statement(this.database, sql);
  }

  async batch(statements) {
    this.database.exec("BEGIN");
    try {
      const results = [];
      for (const statement of statements) results.push(await statement.run());
      this.database.exec("COMMIT");
      return results;
    } catch (error) {
      this.database.exec("ROLLBACK");
      throw error;
    }
  }
}

class TestR2 {
  constructor() {
    this.objects = new Map();
  }

  async put(key, value, options = {}) {
    const bytes = new Uint8Array(await new Response(value).arrayBuffer());
    this.objects.set(key, { bytes, httpMetadata: options.httpMetadata ?? {} });
  }

  async get(key) {
    const object = this.objects.get(key);
    if (!object) return null;
    return {
      body: object.bytes,
      writeHttpMetadata(headers) {
        if (object.httpMetadata.contentType) headers.set("content-type", object.httpMetadata.contentType);
      },
    };
  }

  async delete(key) {
    this.objects.delete(key);
  }
}

async function setup({ legacyAssignments = false, legacyDeliverables = false } = {}) {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("api-test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  const database = new TestD1();
  if (legacyAssignments) {
    database.database.exec(`
      CREATE TABLE assignments (
        id TEXT PRIMARY KEY NOT NULL,
        wish_id TEXT NOT NULL,
        provider_name TEXT NOT NULL,
        provider_contact TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'offered',
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        accepted_at INTEGER,
        delivered_at INTEGER
      )
    `);
  }
  if (legacyDeliverables) {
    database.database.exec(`
      CREATE TABLE deliverables (
        id TEXT PRIMARY KEY NOT NULL,
        wish_id TEXT NOT NULL,
        assignment_id TEXT,
        kind TEXT NOT NULL,
        url TEXT NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL
      );
      INSERT INTO deliverables (
        id, wish_id, assignment_id, kind, url, note, created_at
      ) VALUES (
        'legacy-delivery', 'legacy-wish', NULL, 'link',
        'https://example.com/legacy', 'keep-me', 1
      )
    `);
  }
  const env = {
    DB: database,
    UPLOADS: new TestR2(),
    ADMIN_API_KEY: "test-admin-pin",
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
  };
  const ctx = { waitUntil() {}, passThroughOnException() {} };

  async function request(path, init = {}) {
    return worker.fetch(new Request(`http://localhost${path}`, init), env, ctx);
  }

  return { request, database, env };
}

async function json(response) {
  return response.json();
}

test("upgrades existing assignment and delivery schemas without losing data", async () => {
  const { request, database } = await setup({
    legacyAssignments: true,
    legacyDeliverables: true,
  });
  const health = await request("/api/health");
  assert.equal(health.status, 200);
  const assignmentColumns = database.database.prepare("PRAGMA table_info(assignments)").all();
  assert.ok(assignmentColumns.some((column) => column.name === "provider_id"));
  const deliverableColumns = database.database.prepare("PRAGMA table_info(deliverables)").all();
  assert.ok(deliverableColumns.some((column) => column.name === "storage_key"));
  assert.ok(deliverableColumns.some((column) => column.name === "access_token"));
  const legacyRow = database.database
    .prepare("SELECT url, note FROM deliverables WHERE id = 'legacy-delivery'")
    .get();
  assert.equal(legacyRow.url, "https://example.com/legacy");
  assert.equal(legacyRow.note, "keep-me");
});

test("runs the publish, response, matching, and tracking workflow", async () => {
  const { request } = await setup();
  const providerResponse = await request("/api/admin/providers", {
    method: "POST",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({
      name: "种子响应者",
      contact: "seed-provider-contact",
      city: "上海",
      landmarks: "外滩、陆家嘴",
      availabilityNote: "周末可接单",
    }),
  });
  assert.equal(providerResponse.status, 201);
  const seedProvider = (await json(providerResponse)).provider;
  assert.equal(seedProvider.status, "available");
  const providerList = await json(
    await request("/api/admin/providers", { headers: { "x-admin-key": "test-admin-pin" } }),
  );
  assert.equal(providerList.providers.length, 1);
  const invalidManualBusy = await request(`/api/admin/providers/${seedProvider.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ status: "busy" }),
  });
  assert.equal(invalidManualBusy.status, 409);
  const pausedProvider = await json(
    await request(`/api/admin/providers/${seedProvider.id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ status: "paused" }),
    }),
  );
  assert.equal(pausedProvider.provider.status, "paused");
  const resumedProvider = await json(
    await request(`/api/admin/providers/${seedProvider.id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ status: "available" }),
    }),
  );
  assert.equal(resumedProvider.provider.status, "available");

  const createdResponse = await request("/api/wishes", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      requesterName: "测试发布者",
      contact: "requester-contact",
      city: "上海",
      landmark: "外滩",
      occasion: "生日祝福",
      message: "请替我说一声生日快乐，愿新的一岁继续闪闪发光。",
      deliveryType: "spoken_video",
      deadlineText: "本周内",
      rewardFen: 1800,
      contactConsent: true,
    }),
  });
  assert.equal(createdResponse.status, 201);
  const created = await json(createdResponse);
  assert.equal(created.wish.status, "pending_review");
  assert.ok(created.wish.publicCode.startsWith("HW"));

  const publicBeforeReview = await json(await request("/api/wishes"));
  assert.deepEqual(publicBeforeReview.wishes, []);

  const unauthorized = await request("/api/admin/wishes", {
    headers: { "x-admin-key": "wrong" },
  });
  assert.equal(unauthorized.status, 401);

  const approvedResponse = await request(`/api/admin/wishes/${created.wish.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ action: "approve", note: "内容安全" }),
  });
  assert.equal(approvedResponse.status, 200);
  assert.equal((await json(approvedResponse)).wish.status, "matching");

  const publicAfterReview = await json(await request("/api/wishes"));
  assert.equal(publicAfterReview.wishes.length, 1);
  assert.equal("contact" in publicAfterReview.wishes[0], false);
  assert.equal("requesterName" in publicAfterReview.wishes[0], false);

  const responseResult = await json(
    await request(`/api/wishes/${created.wish.id}/responses`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        responderName: "外滩响应者",
        responderContact: "responder-contact",
        note: "周六在附近",
        contactConsent: true,
      }),
    }),
  );
  assert.equal(responseResult.created, true);

  const adminList = await json(
    await request("/api/admin/wishes?status=matching", {
      headers: { "x-admin-key": "test-admin-pin" },
    }),
  );
  assert.equal(adminList.wishes[0].contact, "requester-contact");
  assert.equal(adminList.wishes[0].responses[0].responderContact, "responder-contact");

  const assignedResponse = await request(`/api/admin/wishes/${created.wish.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ action: "assign", responseId: responseResult.response.id }),
  });
  const assigned = await json(assignedResponse);
  assert.equal(assigned.wish.status, "assigned");
  assert.equal(assigned.wish.assignment.providerName, "外滩响应者");
  assert.equal(assigned.wish.responses[0].status, "selected");

  const acceptedResponse = await request(`/api/admin/wishes/${created.wish.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ action: "accept" }),
  });
  assert.equal((await json(acceptedResponse)).wish.status, "in_progress");

  const uploadForm = new FormData();
  uploadForm.set("file", new Blob(["test-image"], { type: "image/png" }), "delivery.png");
  uploadForm.set("note", "测试交付图片");
  const uploadResponse = await request(`/api/admin/wishes/${created.wish.id}/deliverables/upload`, {
    method: "POST",
    headers: { "x-admin-key": "test-admin-pin" },
    body: uploadForm,
  });
  assert.equal(uploadResponse.status, 201);
  const uploaded = await json(uploadResponse);
  assert.equal(uploaded.wish.status, "delivered");
  assert.match(uploaded.wish.deliverable.url, /\/api\/deliverables\//);

  const wrongTracking = await request("/api/wishes/track", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ publicCode: created.wish.publicCode, contact: "wrong-contact" }),
  });
  assert.equal(wrongTracking.status, 404);

  const tracking = await json(
    await request("/api/wishes/track", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ publicCode: created.wish.publicCode, contact: "requester-contact" }),
    }),
  );
  assert.equal(tracking.wish.status, "delivered");
  assert.equal(tracking.wish.assignment.providerName, "外滩响应者");
  assert.ok(tracking.wish.deliverable.url.includes("token="));
  assert.ok(tracking.wish.events.length >= 5);
  assert.equal("contact" in tracking.wish, false);

  const deliveryUrl = new URL(tracking.wish.deliverable.url);
  const deliveryResponse = await request(`${deliveryUrl.pathname}${deliveryUrl.search}`);
  assert.equal(deliveryResponse.status, 200);
  assert.equal(deliveryResponse.headers.get("content-type"), "image/png");
  assert.equal(new TextDecoder().decode(await deliveryResponse.arrayBuffer()), "test-image");

  const invalidTransition = await request(`/api/admin/wishes/${created.wish.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ action: "approve" }),
  });
  assert.equal(invalidTransition.status, 409);

  const supplyWishResponse = await request("/api/wishes", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      requesterName: "供应闭环测试",
      contact: "supply-requester-contact",
      city: "上海",
      landmark: "陆家嘴",
      occasion: "加油鼓励",
      message: "=1+1 请在陆家嘴替我对朋友说一声加油，慢一点也没关系。",
      deliveryType: "scenery_voiceover",
      deadlineText: "下周前",
      rewardFen: 1200,
      contactConsent: true,
    }),
  });
  const supplyWish = (await json(supplyWishResponse)).wish;
  await request(`/api/admin/wishes/${supplyWish.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ action: "approve" }),
  });
  const providerAssignment = await json(
    await request(`/api/admin/wishes/${supplyWish.id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "assign", providerId: seedProvider.id }),
    }),
  );
  assert.equal(providerAssignment.wish.assignment.providerId, seedProvider.id);
  assert.equal(
    (await json(await request("/api/admin/providers", { headers: { "x-admin-key": "test-admin-pin" } }))).providers[0].status,
    "busy",
  );
  const invalidPauseDuringAssignment = await request(`/api/admin/providers/${seedProvider.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ status: "paused" }),
  });
  assert.equal(invalidPauseDuringAssignment.status, 409);
  await request(`/api/admin/wishes/${supplyWish.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ action: "accept" }),
  });
  await request(`/api/admin/wishes/${supplyWish.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ action: "mark_delivered", deliveryUrl: "https://example.com/supply-delivery" }),
  });
  await request(`/api/admin/wishes/${supplyWish.id}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
    body: JSON.stringify({ action: "complete" }),
  });
  const providerAfterCompletion = (
    await json(await request("/api/admin/providers", { headers: { "x-admin-key": "test-admin-pin" } }))
  ).providers[0];
  assert.equal(providerAfterCompletion.status, "available");
  assert.equal(providerAfterCompletion.completedCount, 1);

  const unauthorizedExport = await request("/api/admin/export.csv");
  assert.equal(unauthorizedExport.status, 401);
  const exportResponse = await request("/api/admin/export.csv", {
    headers: { "x-admin-key": "test-admin-pin" },
  });
  assert.equal(exportResponse.status, 200);
  assert.match(exportResponse.headers.get("content-type") ?? "", /^text\/csv/);
  assert.equal(exportResponse.headers.get("cache-control"), "private, no-store");
  const csv = await exportResponse.text();
  assert.equal(csv.split("\r\n")[0].split(",").length, 14);
  assert.match(csv, /"供应者"/);
  assert.match(csv, /"seed-provider-contact"/);
  assert.match(csv, /"supply-requester-contact"/);
  assert.match(csv, /"'=1\+1/);

  for (let attempt = 0; attempt < 28; attempt += 1) {
    const response = await request("/api/wishes/track", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ publicCode: created.wish.publicCode, contact: `wrong-${attempt}` }),
    });
    assert.equal(response.status, 404);
  }
  const rateLimited = await request("/api/wishes/track", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ publicCode: created.wish.publicCode, contact: "one-too-many" }),
  });
  assert.equal(rateLimited.status, 429);
  assert.ok(Number(rateLimited.headers.get("retry-after")) > 0);
});

test("binds WeChat identities to account-owned wishes, completion, and deletion", async () => {
  const { request, database, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "test-app-id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "test-app-secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const parsed = new URL(String(url));
    assert.equal(parsed.hostname, "api.weixin.qq.com");
    return Response.json({ openid: `openid-${parsed.searchParams.get("js_code")}` });
  };

  try {
    const login = async (code) => {
      const response = await request("/api/auth/wechat", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ code }),
      });
      assert.equal(response.status, 201);
      return (await json(response)).token;
    };
    const requesterToken = await login("requester-code");
    const requesterHeaders = { "content-type": "application/json", authorization: `Bearer ${requesterToken}` };
    const createdResponse = await request("/api/account/wishes", {
      method: "POST",
      headers: requesterHeaders,
      body: JSON.stringify({
        requesterName: "微信发布者",
        contact: "wechat-requester-contact",
        city: "上海",
        landmark: "外滩",
        occasion: "远方问候",
        message: "请替我在江边说一声一切都好。",
        deliveryType: "spoken_video",
        deadlineText: "本周内",
        rewardFen: 0,
        contactConsent: true,
      }),
    });
    assert.equal(createdResponse.status, 201);
    const created = await json(createdResponse);
    const storedWish = database.database.prepare("SELECT user_id FROM wishes WHERE id = ?").get(created.wish.id);
    assert.ok(storedWish.user_id);

    const accountBeforeReview = await json(await request("/api/account/wishes", { headers: requesterHeaders }));
    assert.equal(accountBeforeReview.requests.length, 1);
    assert.equal(accountBeforeReview.requests[0].canConfirmCompletion, false);

    const approved = await request(`/api/admin/wishes/${created.wish.id}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });
    assert.equal(approved.status, 200);

    const responderToken = await login("responder-code");
    const responseResult = await request(`/api/account/wishes/${created.wish.id}/responses`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${responderToken}` },
      body: JSON.stringify({
        responderName: "微信响应者",
        responderContact: "wechat-responder-contact",
        note: "我周末在附近，可以帮助。",
        contactConsent: true,
      }),
    });
    assert.equal(responseResult.status, 201);
    const response = await json(responseResult);
    assert.ok(database.database.prepare("SELECT user_id FROM wish_responses WHERE id = ?").get(response.response.id).user_id);

    for (const action of [
      { action: "assign", responseId: response.response.id },
      { action: "accept" },
      { action: "mark_delivered", deliveryUrl: "https://example.com/wechat-delivery" },
    ]) {
      const result = await request(`/api/admin/wishes/${created.wish.id}`, {
        method: "PATCH",
        headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
        body: JSON.stringify(action),
      });
      assert.equal(result.status, 200);
    }

    const afterDelivery = await json(await request("/api/account/wishes", { headers: requesterHeaders }));
    assert.equal(afterDelivery.requests[0].canConfirmCompletion, true);
    assert.equal(afterDelivery.requests[0].hasDeliverable, true);
    const completion = await request(`/api/account/wishes/${created.wish.id}/complete`, {
      method: "POST",
      headers: requesterHeaders,
    });
    assert.equal(completion.status, 200);
    assert.equal((await json(completion)).wish.status, "completed");

    const deleteResponse = await request("/api/me", { method: "DELETE", headers: { authorization: `Bearer ${requesterToken}` } });
    assert.equal(deleteResponse.status, 200);
    const expiredSession = await request("/api/me", { headers: { authorization: `Bearer ${requesterToken}` } });
    assert.equal(expiredSession.status, 401);
    const anonymized = database.database.prepare("SELECT requester_name, contact FROM wishes WHERE id = ?").get(created.wish.id);
    assert.equal(anonymized.requester_name, "已注销用户");
    assert.match(anonymized.contact, /^deleted:/);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("does not mint a WeChat account session until server-only credentials are configured", async () => {
  const { request } = await setup();
  const response = await request("/api/auth/wechat", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ code: "no-secret-code" }),
  });
  assert.equal(response.status, 503);
  assert.equal((await json(response)).error, "微信登录暂未配置，请稍后重试");
});

test("lets the requester pick a helper and the helper deliver, with no operator in the middle", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "test-app-id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "test-app-secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) =>
    Response.json({ openid: `openid-${new URL(String(url)).searchParams.get("js_code")}` });

  try {
    const login = async (code) => {
      const response = await request("/api/auth/wechat", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ code }),
      });
      assert.equal(response.status, 201);
      return (await json(response)).token;
    };

    const requesterToken = await login("requester");
    const helperToken = await login("helper-code");
    const requesterHeaders = { "content-type": "application/json", authorization: `Bearer ${requesterToken}` };
    const helperHeaders = { "content-type": "application/json", authorization: `Bearer ${helperToken}` };

    // 发布 → 运营初审放行（公开内容仍需人工审核）
    const created = await json(
      await request("/api/account/wishes", {
        method: "POST",
        headers: requesterHeaders,
        body: JSON.stringify({
          requesterName: "发布者",
          contact: "requester-contact",
          city: "杭州",
          landmark: "西湖断桥",
          occasion: "生日祝福",
          message: "请替我在断桥说一声生日快乐。",
          deliveryType: "spoken_video",
          deadlineText: "本周内",
          rewardFen: 0,
          contactConsent: true,
        }),
      }),
    );
    const wishId = created.wish.id;
    const approved = await request(`/api/admin/wishes/${wishId}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });
    assert.equal(approved.status, 200);
    assert.equal((await json(approved)).wish.status, "matching");

    // 帮助者报名
    const responded = await request(`/api/account/wishes/${wishId}/responses`, {
      method: "POST",
      headers: helperHeaders,
      body: JSON.stringify({ responderName: "帮助者", responderContact: "helper-contact", note: "我就在附近", contactConsent: true }),
    });
    assert.equal(responded.status, 201);

    // 发布者看到响应，且拿不到对方联系方式
    const listed = await json(await request(`/api/account/wishes/${wishId}/responses`, { headers: requesterHeaders }));
    assert.equal(listed.responses.length, 1);
    assert.equal(listed.responses[0].responderName, "帮助者");
    assert.ok(!("responderContact" in listed.responses[0]), "发布者不应拿到响应者联系方式");
    assert.ok(!JSON.stringify(listed).includes("helper-contact"));

    // 发布者选定帮助者
    const responseId = listed.responses[0].id;
    const selected = await request(`/api/account/wishes/${wishId}/responses/${responseId}/select`, {
      method: "POST",
      headers: requesterHeaders,
    });
    assert.equal(selected.status, 200);
    assert.equal((await json(selected)).wish.status, "in_progress");

    // 未被选中的人不能上传
    const strangerToken = await login("stranger");
    const strangerUpload = new FormData();
    strangerUpload.append("file", new File([new Uint8Array([1, 2, 3])], "a.jpg", { type: "image/jpeg" }));
    const refused = await request(`/api/account/wishes/${wishId}/deliverable`, {
      method: "POST",
      headers: { authorization: `Bearer ${strangerToken}` },
      body: strangerUpload,
    });
    assert.equal(refused.status, 403);

    // 超过 9 个文件被拒
    const tooMany = new FormData();
    for (let i = 0; i < 10; i += 1) {
      tooMany.append("file", new File([new Uint8Array([i])], `f${i}.jpg`, { type: "image/jpeg" }));
    }
    const rejected = await request(`/api/account/wishes/${wishId}/deliverable`, {
      method: "POST", headers: { authorization: `Bearer ${helperToken}` }, body: tooMany,
    });
    assert.equal(rejected.status, 400);

    // 被选中的帮助者直接上传：一段文字 + 多个文件，全程不需要运营密钥
    const form = new FormData();
    form.append("note", "拍好了，今天天气很好。");
    form.append("file", new File([new Uint8Array([1, 2, 3, 4])], "delivery.jpg", { type: "image/jpeg" }));
    form.append("file", new File([new Uint8Array([5, 6])], "delivery2.jpg", { type: "image/jpeg" }));
    const uploaded = await request(`/api/account/wishes/${wishId}/deliverable`, {
      method: "POST",
      headers: { authorization: `Bearer ${helperToken}` },
      body: form,
    });
    assert.equal(uploaded.status, 201);
    assert.equal((await json(uploaded)).wish.status, "delivered");

    // 发布者确认完成
    const completed = await request(`/api/account/wishes/${wishId}/complete`, {
      method: "POST",
      headers: requesterHeaders,
    });
    assert.equal(completed.status, 200);
    assert.equal((await json(completed)).wish.status, "completed");

    // 默认不进入首页故事流
    assert.equal((await json(await request("/api/stories"))).stories.length, 0);

    // 需求方点「公开」只是提交申请：帮助者上传的影像此前从未被审核过，
    // 不能未经查看就进入公开故事流。
    const published = await request(`/api/account/wishes/${wishId}/story`, {
      method: "POST", headers: requesterHeaders, body: JSON.stringify({ nickname: "晚风" }),
    });
    assert.equal(published.status, 201);
    assert.equal((await json(await request("/api/stories"))).stories.length, 0, "未审核前不得出现在首页");

    // 运营待办里能看到，并且能看到全部媒体
    const pendingStories = await json(
      await request("/api/admin/stories", { headers: { "x-admin-key": "test-admin-pin" } }),
    );
    assert.equal(pendingStories.stories.length, 1);
    assert.equal(pendingStories.stories[0].media.length, 2);

    // 审核通过后才上首页
    const reviewed = await request(`/api/admin/stories/${wishId}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });
    assert.equal(reviewed.status, 200);
    const stories = (await json(await request("/api/stories"))).stories;
    assert.equal(stories.length, 1);
    assert.equal(stories[0].nickname, "晚风");
    assert.equal(stories[0].media.length, 2);
    assert.equal(stories[0].note, "拍好了，今天天气很好。");
    assert.ok(!JSON.stringify(stories).includes("requester-contact"), "故事流不得包含联系方式");

    // 可以撤回公开
    const removed = await request(`/api/account/wishes/${wishId}/story`, {
      method: "DELETE", headers: requesterHeaders,
    });
    assert.equal(removed.status, 200);
    assert.equal((await json(await request("/api/stories"))).stories.length, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("scopes conversations to the two parties and supports report and block", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) =>
    Response.json({ openid: `openid-${new URL(String(url)).searchParams.get("js_code")}` });

  try {
    const login = async (code) => {
      const res = await request("/api/auth/wechat", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ code }),
      });
      const payload = await json(res);
      assert.equal(res.status, 201, `登录失败 ${res.status}: ${JSON.stringify(payload)}`);
      return payload.token;
    };

    const ownerToken = await login("owner-code");
    const helperToken = await login("helper-code");
    const outsiderToken = await login("outsider-code");
    const h = (t) => ({ "content-type": "application/json", authorization: `Bearer ${t}` });

    const createdRaw = await request("/api/account/wishes", {
        method: "POST",
        headers: h(ownerToken),
        body: JSON.stringify({
          requesterName: "发布者", contact: "owner-contact", city: "杭州", landmark: "西湖断桥",
          occasion: "生日祝福", message: "请替我在断桥说一声生日快乐。", deliveryType: "spoken_video",
          deadlineText: "本周内", rewardFen: 0, contactConsent: true,
        }),
      });
    const created = await json(createdRaw);
    assert.ok(created.wish, `发布失败 ${createdRaw.status}: ${JSON.stringify(created)}`);
    const wishId = created.wish.id;
    await request(`/api/admin/wishes/${wishId}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });
    const respondResult = await request(`/api/account/wishes/${wishId}/responses`, {
      method: "POST",
      headers: h(helperToken),
      body: JSON.stringify({ responderName: "帮助者", responderContact: "helper-contact", contactConsent: true }),
    });
    assert.equal(respondResult.status, 201, `响应失败：${JSON.stringify(await json(respondResult))}`);

    const listedRaw = await request(`/api/account/wishes/${wishId}/responses`, { headers: h(ownerToken) });
    const listed = await json(listedRaw);
    assert.ok(listed.responses?.length, `列表异常 HTTP ${listedRaw.status}: ${JSON.stringify(listed)}`);
    const responseId = listed.responses[0].id;

    // 响应即可开聊，无需先被选中
    const sent = await request(`/api/account/conversations/${responseId}/messages`, {
      method: "POST", headers: h(helperToken), body: JSON.stringify({ body: "我住在附近，今天下午可以去。" }),
    });
    assert.equal(sent.status, 201);

    // 双方都能读到同一会话
    const ownerView = await json(await request(`/api/account/conversations/${responseId}/messages`, { headers: h(ownerToken) }));
    assert.equal(ownerView.messages.length, 1);
    assert.equal(ownerView.viewerRole, "requester");
    assert.equal(ownerView.messages[0].mine, false);

    // 第三方读不到，也发不了
    const peek = await request(`/api/account/conversations/${responseId}/messages`, { headers: h(outsiderToken) });
    assert.equal(peek.status, 403);
    const intrude = await request(`/api/account/conversations/${responseId}/messages`, {
      method: "POST", headers: h(outsiderToken), body: JSON.stringify({ body: "插一句" }),
    });
    assert.equal(intrude.status, 403);

    // 空消息与超长消息都被拒
    const empty = await request(`/api/account/conversations/${responseId}/messages`, {
      method: "POST", headers: h(ownerToken), body: JSON.stringify({ body: "   " }),
    });
    assert.equal(empty.status, 400);

    // 会话出现在双方的私聊列表里
    const helperList = await json(await request("/api/account/conversations", { headers: h(helperToken) }));
    assert.equal(helperList.conversations.length, 1);
    assert.equal(helperList.conversations[0].viewerRole, "responder");
    assert.equal(helperList.conversations[0].lastMessage, "我住在附近，今天下午可以去。");

    // 举报可提交
    const reported = await request("/api/account/reports", {
      method: "POST", headers: h(ownerToken),
      body: JSON.stringify({ responseId, reason: "骚扰", detail: "测试" }),
    });
    assert.equal(reported.status, 201);

    // 屏蔽只切断「继续发消息」，不切断「看得见这段对话」。
    // 早先是屏蔽后连读都 403、会话直接从列表消失——屏蔽一个骚扰者的代价
    // 变成把整段记录也弄丢，而且当时没有任何取消屏蔽的办法。
    const blocked = await request(`/api/account/conversations/${responseId}/block`, {
      method: "POST", headers: h(ownerToken),
    });
    assert.equal(blocked.status, 201);

    // 双方都仍然读得到历史消息
    for (const [who, token] of [["屏蔽方", ownerToken], ["被屏蔽方", helperToken]]) {
      const after = await request(`/api/account/conversations/${responseId}/messages`, { headers: h(token) });
      assert.equal(after.status, 200, `${who}屏蔽后仍应能读历史消息`);
      const body = await after.json();
      assert.ok(body.messages.length > 0, `${who}的历史消息不能消失`);
    }

    // 屏蔽状态双向标记正确：发起方是 blockedByMe，另一方是 blockedByThem
    const ownerAfterBlock = await json(await request(`/api/account/conversations/${responseId}/messages`, { headers: h(ownerToken) }));
    assert.equal(ownerAfterBlock.blockedByMe, true);
    assert.equal(ownerAfterBlock.blockedByThem, false);
    const helperAfterBlock = await json(await request(`/api/account/conversations/${responseId}/messages`, { headers: h(helperToken) }));
    assert.equal(helperAfterBlock.blockedByMe, false);
    assert.equal(helperAfterBlock.blockedByThem, true);

    // 会话仍在双方列表里，并带屏蔽标记；已屏蔽的会话不计未读
    for (const [who, token, expectMine] of [["屏蔽方", ownerToken, true], ["被屏蔽方", helperToken, false]]) {
      const list = await json(await request("/api/account/conversations", { headers: h(token) }));
      assert.equal(list.conversations.length, 1, `${who}的列表里会话不应消失`);
      assert.equal(list.conversations[0].blockedByMe, expectMine);
      assert.equal(list.conversations[0].blockedByThem, !expectMine);
      assert.equal(list.conversations[0].unreadCount, 0, "已屏蔽的会话不该再顶着未读红点");
      assert.equal(list.totalUnread, 0);
    }

    // 但双方都发不出新消息
    for (const [who, token] of [["屏蔽方", ownerToken], ["被屏蔽方", helperToken]]) {
      const send = await request(`/api/account/conversations/${responseId}/messages`, {
        method: "POST", headers: h(token), body: JSON.stringify({ body: "还能发吗" }),
      });
      assert.equal(send.status, 403, `${who}在屏蔽状态下不应能发消息`);
    }

    // 取消屏蔽后恢复可发送
    const unblocked = await request(`/api/account/conversations/${responseId}/block`, {
      method: "DELETE", headers: h(ownerToken),
    });
    assert.equal(unblocked.status, 200);
    const resumed = await request(`/api/account/conversations/${responseId}/messages`, {
      method: "POST", headers: h(ownerToken), body: JSON.stringify({ body: "恢复联系" }),
    });
    assert.equal(resumed.status, 201, "取消屏蔽后应能重新发消息");

    // 取消屏蔽只撤销自己那条：对方屏蔽我时，我不能替对方解除
    await request(`/api/account/conversations/${responseId}/block`, {
      method: "POST", headers: h(helperToken),
    });
    const ownerTriesToUnblock = await request(`/api/account/conversations/${responseId}/block`, {
      method: "DELETE", headers: h(ownerToken),
    });
    assert.equal(ownerTriesToUnblock.status, 200);
    const stillBlocked = await request(`/api/account/conversations/${responseId}/messages`, {
      method: "POST", headers: h(ownerToken), body: JSON.stringify({ body: "对方还屏蔽着我" }),
    });
    assert.equal(stillBlocked.status, 403, "不能通过取消自己的屏蔽来绕过对方的屏蔽");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("accepts publish and respond without any contact information", async () => {
  const { request, env, database } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) =>
    Response.json({ openid: `openid-${new URL(String(url)).searchParams.get("js_code")}` });

  try {
    const login = async (code) =>
      (await json(
        await request("/api/auth/wechat", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ code }),
        }),
      )).token;
    const ownerToken = await login("owner-code");
    const helperToken = await login("helper-code");
    const h = (t) => ({ "content-type": "application/json", authorization: `Bearer ${t}` });

    // 完全不传 contact
    const created = await request("/api/account/wishes", {
      method: "POST",
      headers: h(ownerToken),
      body: JSON.stringify({
        requesterName: "发布者", city: "杭州", landmark: "西湖断桥", occasion: "生日祝福",
        message: "请替我在断桥说一声生日快乐。", deliveryType: "spoken_video",
        deadlineText: "本周内", rewardFen: 0, contactConsent: true,
      }),
    });
    const createdPayload = await json(created);
    assert.equal(created.status, 201, `发布应成功：${JSON.stringify(createdPayload)}`);
    const wishId = createdPayload.wish.id;

    await request(`/api/admin/wishes/${wishId}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });

    // 响应也完全不传 responderContact
    const responded = await request(`/api/account/wishes/${wishId}/responses`, {
      method: "POST",
      headers: h(helperToken),
      body: JSON.stringify({ responderName: "帮助者", note: "我就在附近", contactConsent: true }),
    });
    const respondedPayload = await json(responded);
    assert.equal(responded.status, 201, `响应应成功：${JSON.stringify(respondedPayload)}`);

    // 同一账号重复响应不会新建
    const again = await request(`/api/account/wishes/${wishId}/responses`, {
      method: "POST",
      headers: h(helperToken),
      body: JSON.stringify({ responderName: "帮助者", contactConsent: true }),
    });
    assert.equal((await json(again)).created, false, "同一账号重复响应应被去重");

    // 落库的只有账号占位，不含任何真实联系方式
    const rows = database.database.prepare("SELECT contact FROM wishes WHERE id = ?").all(wishId);
    assert.ok(rows[0].contact.startsWith("account:"), `contact 应为账号占位，实际 ${rows[0].contact}`);
    const responseRows = database.database.prepare("SELECT responder_contact FROM wish_responses WHERE wish_id = ?").all(wishId);
    assert.equal(responseRows.length, 1);
    assert.ok(responseRows[0].responder_contact.startsWith("account:"));
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("holds nickname and avatar changes for review before others can see them", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) =>
    Response.json({ openid: `openid-${new URL(String(url)).searchParams.get("js_code")}` });

  try {
    const login = async (code) =>
      (await json(
        await request("/api/auth/wechat", {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ code }),
        }),
      )).token;
    const token = await login("profile-code");
    const h = { "content-type": "application/json", authorization: `Bearer ${token}` };

    // 默认资料
    const initial = await json(await request("/api/account/profile", { headers: h }));
    assert.equal(initial.displayName, "哈喽卧得用户");
    assert.equal(initial.pendingReview, false);

    // 提交新昵称 → 立即进入待审核，本人能看到新值
    const submitted = await json(
      await request("/api/account/profile", {
        method: "POST", headers: h, body: JSON.stringify({ displayName: "晚风电台" }),
      }),
    );
    assert.equal(submitted.displayName, "晚风电台");
    assert.equal(submitted.pendingReview, true, "提交后应进入待审核");

    // 运营看到待办
    const pending = await json(
      await request("/api/admin/profiles", { headers: { "x-admin-key": "test-admin-pin" } }),
    );
    assert.equal(pending.profiles.length, 1);
    const userId = pending.profiles[0].userId;

    // 空昵称与超长昵称被拒
    const tooLong = await request("/api/account/profile", {
      method: "POST", headers: h, body: JSON.stringify({ displayName: "一".repeat(21) }),
    });
    assert.equal(tooLong.status, 400);

    // 审核通过后成为对外可见版本
    const approved = await json(
      await request(`/api/admin/profiles/${userId}`, {
        method: "PATCH",
        headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
        body: JSON.stringify({ action: "approve" }),
      }),
    );
    assert.equal(approved.pendingReview, false);

    // 再改一次并退回：待审内容被清掉，回落到上一版通过的资料
    await request("/api/account/profile", {
      method: "POST", headers: h, body: JSON.stringify({ displayName: "不合规昵称" }),
    });
    const rejected = await json(
      await request(`/api/admin/profiles/${userId}`, {
        method: "PATCH",
        headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
        body: JSON.stringify({ action: "reject", note: "含违规词" }),
      }),
    );
    assert.equal(rejected.displayName, "晚风电台", "退回后应回落到上一版通过的昵称");
    assert.equal(rejected.reviewNote, "含违规词");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("按 Accept-Language 返回英文错误，但绝不翻译业务数据", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const href = String(url);
    if (href.includes("api.weixin.qq.com")) {
      return Response.json({ openid: `openid-${new URL(href).searchParams.get("js_code")}` });
    }
    return originalFetch(url, init);
  };
  try {
    const login = async (code, lang) =>
      (await json(await request("/api/auth/wechat", {
        method: "POST",
        headers: { "content-type": "application/json", ...(lang ? { "accept-language": lang } : {}) },
        body: JSON.stringify({ code }),
      }))).token;

    const zhToken = await login("i18n-zh");
    const enToken = await login("i18n-en", "en-US,en;q=0.9");

    // 未登录：同一条错误，两种语言
    const zhErr = await json(await request("/api/account/profile", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ displayName: "x" }),
    }));
    assert.equal(zhErr.error, "请先登录后再操作", "默认仍是中文");

    const enErr = await json(await request("/api/account/profile", {
      method: "POST",
      headers: { "content-type": "application/json", "accept-language": "en-US,en;q=0.9" },
      body: JSON.stringify({ displayName: "x" }),
    }));
    assert.equal(enErr.error, "Please sign in first.", "英文客户端应拿到英文");

    // zh-Hans / zh-TW 都算中文，不该被判成英文
    const hantErr = await json(await request("/api/account/profile", {
      method: "POST",
      headers: { "content-type": "application/json", "accept-language": "zh-Hant-TW,zh;q=0.9" },
      body: JSON.stringify({ displayName: "x" }),
    }));
    assert.equal(hantErr.error, "请先登录后再操作");

    // 昵称重名：英文
    const zhH = { "content-type": "application/json", authorization: `Bearer ${zhToken}` };
    const enH = {
      "content-type": "application/json",
      authorization: `Bearer ${enToken}`,
      "accept-language": "en-US,en;q=0.9",
    };
    await request("/api/account/profile", {
      method: "POST", headers: zhH, body: JSON.stringify({ displayName: "占位昵称" }),
    });
    const taken = await request("/api/account/profile", {
      method: "POST", headers: enH, body: JSON.stringify({ displayName: "占位昵称" }),
    });
    assert.equal(taken.status, 409);
    assert.equal((await taken.json()).error, "That name is already taken. Please choose another.");

    // 字段级校验消息是模板拼出来的，也要翻译
    const bad = await request("/api/account/wishes", {
      method: "POST", headers: enH,
      body: JSON.stringify({
        requesterName: "", contact: "wx", city: "上海", landmark: "外滩",
        occasion: "生日祝福", message: "请替我对着江面说一句生日快乐。",
        deliveryType: "spoken_video", deadlineText: "本周六前", rewardFen: 0, contactConsent: true,
      }),
    });
    assert.equal(bad.status, 400);
    const badBody = await bad.json();
    assert.match(
      badBody.fields.requesterName, /must be 1–30 characters/,
      "字段校验消息是 `${label}需为 …` 拼出来的，查表查不到，必须由模板规则翻译",
    );

    // —— 关键：业务数据绝不能被翻译 ——
    const created = await json(await request("/api/account/wishes", {
      method: "POST", headers: enH,
      body: JSON.stringify({
        requesterName: "Alex", contact: "wx", city: "上海", landmark: "外滩",
        occasion: "生日祝福", message: "请替我对着江面说一句生日快乐。",
        deliveryType: "spoken_video", deadlineText: "本周六前", rewardFen: 0, contactConsent: true,
      }),
    }));
    assert.equal(
      created.wish.occasion, "生日祝福",
      "occasion 原样存库，翻译它会让英文用户写进一套新值，和历史数据对不上",
    );
    assert.equal(created.wish.city, "上海", "城市是用户输入的数据，不能翻译");
    assert.equal(created.wish.message, "请替我对着江面说一句生日快乐。", "心愿正文不能被改动");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("昵称唯一：规范化之后重名的一律挡下", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const href = String(url);
    if (href.includes("api.weixin.qq.com")) {
      return Response.json({ openid: `openid-${new URL(href).searchParams.get("js_code")}` });
    }
    return originalFetch(url, init);
  };
  try {
    const login = async (code) =>
      (await json(await request("/api/auth/wechat", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ code }),
      }))).token;
    const a = { "content-type": "application/json", authorization: `Bearer ${await login("uniq-a")}` };
    const b = { "content-type": "application/json", authorization: `Bearer ${await login("uniq-b")}` };

    const first = await request("/api/account/profile", {
      method: "POST", headers: a, body: JSON.stringify({ displayName: "晚风电台" }),
    });
    assert.equal(first.status, 200);

    // 完全相同
    const dup = await request("/api/account/profile", {
      method: "POST", headers: b, body: JSON.stringify({ displayName: "晚风电台" }),
    });
    assert.equal(dup.status, 409, "重名必须挡下");

    // 加空格绕过——「晚风 电台」和「晚风电台」在别人眼里是同一个名字
    const spaced = await request("/api/account/profile", {
      method: "POST", headers: b, body: JSON.stringify({ displayName: "晚风 电台" }),
    });
    assert.equal(spaced.status, 409, "插空格不能绕过唯一性");

    // 零宽字符绕过：界面上完全看不出区别
    const zeroWidth = await request("/api/account/profile", {
      method: "POST", headers: b, body: JSON.stringify({ displayName: "晚风\u200B电台" }),
    });
    assert.equal(zeroWidth.status, 409, "零宽字符不能绕过唯一性");

    // 大小写与全角：ABC / abc / ＡＢＣ 视为同一个
    await request("/api/account/profile", {
      method: "POST", headers: a, body: JSON.stringify({ displayName: "Radio" }),
    });
    const fullwidth = await request("/api/account/profile", {
      method: "POST", headers: b, body: JSON.stringify({ displayName: "ｒａｄｉｏ" }),
    });
    assert.equal(fullwidth.status, 409, "全角与大小写不能绕过唯一性");

    // 自己改回自己的昵称不该被自己挡住
    const self = await request("/api/account/profile", {
      method: "POST", headers: a, body: JSON.stringify({ displayName: "Radio" }),
    });
    assert.equal(self.status, 200, "不能把用户自己的昵称判成重名");

    // 整串都是空白或不可见字符
    const blank = await request("/api/account/profile", {
      method: "POST", headers: b, body: JSON.stringify({ displayName: "\u200B\u200B" }),
    });
    assert.equal(blank.status, 400);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("被封禁的昵称不可用，且封禁只在运营勾选时发生", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const href = String(url);
    if (href.includes("api.weixin.qq.com")) {
      return Response.json({ openid: `openid-${new URL(href).searchParams.get("js_code")}` });
    }
    return originalFetch(url, init);
  };
  const admin = { "content-type": "application/json", "x-admin-key": "test-admin-pin" };
  try {
    const login = async (code) =>
      (await json(await request("/api/auth/wechat", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ code }),
      }))).token;
    const a = { "content-type": "application/json", authorization: `Bearer ${await login("banned-user-a")}` };
    const b = { "content-type": "application/json", authorization: `Bearer ${await login("banned-user-b")}` };

    // 运营直接封一个词
    const banned = await request("/api/admin/banned-names", {
      method: "POST", headers: admin, body: JSON.stringify({ name: "管理员", reason: "冒充官方" }),
    });
    assert.equal(banned.status, 201);

    const blocked = await request("/api/account/profile", {
      method: "POST", headers: a, body: JSON.stringify({ displayName: "管理员" }),
    });
    assert.equal(blocked.status, 400, "封禁词不可用");

    // 换个大小写/空格同样挡下
    const evaded = await request("/api/account/profile", {
      method: "POST", headers: a, body: JSON.stringify({ displayName: "管理 员" }),
    });
    assert.equal(evaded.status, 400, "封禁也要按规范化后的形式判定");

    // 退回但不勾封禁 → 这个名字之后别人还能用
    await request("/api/account/profile", {
      method: "POST", headers: a, body: JSON.stringify({ displayName: "普通重名" }),
    });
    const list1 = await json(await request("/api/admin/profiles", { headers: admin }));
    const userA = list1.profiles[0].userId;
    await request(`/api/admin/profiles/${userA}`, {
      method: "PATCH", headers: admin,
      body: JSON.stringify({ action: "reject", target: "displayName", note: "重名" }),
    });
    const reusable = await request("/api/account/profile", {
      method: "POST", headers: b, body: JSON.stringify({ displayName: "普通重名" }),
    });
    assert.equal(reusable.status, 200, "没勾封禁的退回不该永久锁死这个名字");

    // 退回并勾封禁 → 谁都不能再用
    const list2 = await json(await request("/api/admin/profiles", { headers: admin }));
    const userB = list2.profiles.find((p) => p.userId !== userA)?.userId ?? list2.profiles[0].userId;
    await request(`/api/admin/profiles/${userB}`, {
      method: "PATCH", headers: admin,
      body: JSON.stringify({ action: "reject", target: "displayName", note: "辱骂", ban: true }),
    });
    const nowBanned = await request("/api/account/profile", {
      method: "POST", headers: a, body: JSON.stringify({ displayName: "普通重名" }),
    });
    assert.equal(nowBanned.status, 400, "勾了封禁之后这个名字应当不可用");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("预设头像免审：直接成为对外可见的头像", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const href = String(url);
    if (href.includes("api.weixin.qq.com")) {
      return Response.json({ openid: `openid-${new URL(href).searchParams.get("js_code")}` });
    }
    return originalFetch(url, init);
  };
  try {
    const token = (await json(await request("/api/auth/wechat", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ code: "preset-avatar-user" }),
    }))).token;
    const h = { authorization: `Bearer ${token}` };

    // 读真正的那张预设图，而不是造一段假字节：这条测试要守住的正是
    // 「文件内容 → 哈希 → 免审」这条链，用假数据等于什么都没测。
    const presetPath = new URL("../ios/Gratia/PresetAvatars/preset-1.png", import.meta.url);
    const preset = new Uint8Array(readFileSync(presetPath));

    const form = new FormData();
    form.set("displayName", "用预设头像的人");
    form.set("avatar", new File([preset], "preset-1.png", { type: "image/png" }));
    const submitted = await json(await request("/api/account/profile", { method: "POST", headers: h, body: form }));

    assert.equal(submitted.avatarPending, false, "预设头像不该进人工审核队列");
    assert.equal(submitted.displayNamePending, true, "昵称仍然要审——免审只针对预设图");

    // 关键：别人现在就该看到这张头像，而不是等运营上线点一下
    const pending = await json(
      await request("/api/admin/profiles", { headers: { "x-admin-key": "test-admin-pin" } }),
    );
    const userId = pending.profiles[0].userId;
    const publicView = await json(
      await request(`/api/admin/profiles`, { headers: { "x-admin-key": "test-admin-pin" } }),
    );
    assert.ok(publicView.profiles.some((p) => p.userId === userId), "昵称仍在待审队列里");

    // 换成一张不在白名单里的图 → 必须走人工审核
    const other = new FormData();
    other.set("avatar", new File([new Uint8Array([9, 9, 9, 9])], "x.png", { type: "image/png" }));
    const custom = await json(await request("/api/account/profile", { method: "POST", headers: h, body: other }));
    assert.equal(custom.avatarPending, true, "非预设图必须进人工审核——否则改个请求就能绕过审核");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("昵称与头像分开审核：退回一样不牵连另一样", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const href = String(url);
    if (href.includes("api.weixin.qq.com")) {
      return Response.json({ openid: `openid-${new URL(href).searchParams.get("js_code")}` });
    }
    return originalFetch(url, init);
  };
  const admin = { "content-type": "application/json", "x-admin-key": "test-admin-pin" };
  try {
    const token = (await json(await request("/api/auth/wechat", {
      method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ code: "split-review" }),
    }))).token;
    const h = { authorization: `Bearer ${token}` };

    // 同时提交昵称与头像
    const form = new FormData();
    form.set("displayName", "海边信号塔");
    form.set("avatar", new File([new Uint8Array([1, 2, 3, 4])], "a.png", { type: "image/png" }));
    const submitted = await json(await request("/api/account/profile", { method: "POST", headers: h, body: form }));
    assert.equal(submitted.displayNamePending, true);
    assert.equal(submitted.avatarPending, true);

    const pending = await json(await request("/api/admin/profiles", { headers: admin }));
    const userId = pending.profiles[0].userId;

    // 只通过昵称
    const nameOk = await json(await request(`/api/admin/profiles/${userId}`, {
      method: "PATCH", headers: admin,
      body: JSON.stringify({ action: "approve", target: "displayName" }),
    }));
    assert.equal(nameOk.displayNamePending, false, "昵称应已通过");
    assert.equal(nameOk.avatarPending, true, "头像不该被一起处理掉");

    // 再单独退回头像 —— 昵称必须原封不动
    const avatarRejected = await json(await request(`/api/admin/profiles/${userId}`, {
      method: "PATCH", headers: admin,
      body: JSON.stringify({ action: "reject", target: "avatar", note: "头像不合适" }),
    }));
    assert.equal(
      avatarRejected.displayName, "海边信号塔",
      "退回头像不该把已经通过的昵称一起打回——用户会被迫重填一样本来合格的内容",
    );
    assert.equal(avatarRejected.avatarNote, "头像不合适");
    assert.equal(avatarRejected.displayNameNote, null, "昵称不该带上头像的驳回理由");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

// 这条链此前完全没有测试，于是「头像地址返回相对路径」一直没被发现：
// 文件确实进了 R2、键也写进了库，但运营台（GitHub Pages 静态页）会把
// /api/avatars/... 解析到 github.io 上拿到 404，iOS 的 URL(string:) 则
// 根本构造不出可请求的地址——表现就像上传功能坏掉。
test("returns absolute avatar URLs so off-origin clients can load them", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) =>
    Response.json({ openid: `openid-${new URL(String(url)).searchParams.get("js_code")}` });

  try {
    const token = (await json(
      await request("/api/auth/wechat", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ code: "avatar-code" }),
      }),
    )).token;

    const pixel = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    const form = new FormData();
    form.set("displayName", "晚风电台");
    form.set("avatar", new Blob([pixel], { type: "image/png" }), "avatar.png");

    const submitted = await json(
      await request("/api/account/profile", {
        method: "POST",
        headers: { authorization: `Bearer ${token}` },
        body: form,
      }),
    );

    assert.ok(submitted.avatarUrl, "上传头像后应返回地址");
    assert.match(
      submitted.avatarUrl,
      /^https?:\/\//,
      "avatarUrl 必须是绝对地址，本接口没有同源的消费者",
    );

    // 返回的地址必须真的能取到文件，而不只是长得像个地址
    const parsed = new URL(submitted.avatarUrl);
    const fetched = await request(parsed.pathname + parsed.search);
    assert.equal(fetched.status, 200, "返回的头像地址应可直接取回文件");
    assert.equal(fetched.headers.get("content-type"), "image/png");

    // 运营台读的是这个列表，同样不能是相对地址
    const pending = await json(
      await request("/api/admin/profiles", { headers: { "x-admin-key": "test-admin-pin" } }),
    );
    assert.equal(pending.profiles.length, 1);
    assert.match(
      pending.profiles[0].avatarUrl,
      /^https?:\/\//,
      "运营待办里的 avatarUrl 必须是绝对地址",
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("counts unread messages per participant and clears them on open", async () => {
  const { request, env, database } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) =>
    Response.json({ openid: `openid-${new URL(String(url)).searchParams.get("js_code")}` });

  try {
    const login = async (code) =>
      (await json(
        await request("/api/auth/wechat", {
          method: "POST", headers: { "content-type": "application/json" },
          body: JSON.stringify({ code }),
        }),
      )).token;
    const ownerToken = await login("owner-code");
    const helperToken = await login("helper-code");
    const h = (t) => ({ "content-type": "application/json", authorization: `Bearer ${t}` });

    const created = await json(await request("/api/account/wishes", {
      method: "POST", headers: h(ownerToken),
      body: JSON.stringify({
        requesterName: "发布者", city: "杭州", landmark: "西湖断桥", occasion: "生日祝福",
        message: "请替我在断桥说一声生日快乐。", deliveryType: "spoken_video",
        deadlineText: "本周内", rewardFen: 0, contactConsent: true,
      }),
    }));
    const wishId = created.wish.id;
    await request(`/api/admin/wishes/${wishId}`, {
      method: "PATCH",
      headers: { "content-type": "application/json", "x-admin-key": "test-admin-pin" },
      body: JSON.stringify({ action: "approve" }),
    });
    await request(`/api/account/wishes/${wishId}/responses`, {
      method: "POST", headers: h(helperToken),
      body: JSON.stringify({ responderName: "帮助者", contactConsent: true }),
    });
    const listed = await json(await request(`/api/account/wishes/${wishId}/responses`, { headers: h(ownerToken) }));
    const responseId = listed.responses[0].id;

    // 帮助者连发两条
    for (const body of ["我住在附近", "今天下午可以去"]) {
      await request(`/api/account/conversations/${responseId}/messages`, {
        method: "POST", headers: h(helperToken), body: JSON.stringify({ body }),
      });
    }

    // 发布者侧应有 2 条未读，帮助者自己发的不计入
    const ownerList = await json(await request("/api/account/conversations", { headers: h(ownerToken) }));
    assert.equal(ownerList.totalUnread, 2);
    assert.equal(ownerList.conversations[0].unreadCount, 2);
    const helperList = await json(await request("/api/account/conversations", { headers: h(helperToken) }));
    assert.equal(helperList.totalUnread, 0, "自己发的消息不应计入自己的未读");

    // 打开会话即清零
    await request(`/api/account/conversations/${responseId}/messages`, { headers: h(ownerToken) });
    const afterRead = await json(await request("/api/account/conversations", { headers: h(ownerToken) }));
    assert.equal(afterRead.totalUnread, 0, "打开会话后未读应清零");

    // 对方再发一条，未读重新出现
    await request(`/api/account/conversations/${responseId}/messages`, {
      method: "POST", headers: h(helperToken), body: JSON.stringify({ body: "出发了" }),
    });
    const again = await json(await request("/api/account/conversations", { headers: h(ownerToken) }));
    assert.equal(again.totalUnread, 1);

    // 同一会话内的消息时间戳必须严格递增：毫秒精度不足以区分同毫秒的两条消息，
    // 那会同时导致显示顺序未定义和已读游标漏计未读。
    const stamps = database.database
      .prepare("SELECT created_at FROM wish_messages ORDER BY created_at")
      .all()
      .map((row) => row.created_at);
    assert.equal(new Set(stamps).size, stamps.length, `消息时间戳不应重复：${stamps}`);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("gives operators a way to read and resolve abuse reports", async () => {
  const { request, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "secret";
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url) =>
    Response.json({ openid: `openid-${new URL(String(url)).searchParams.get("js_code")}` });
  const admin = { "content-type": "application/json", "x-admin-key": "test-admin-pin" };

  try {
    const login = async (code) =>
      (await json(await request("/api/auth/wechat", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ code }),
      }))).token;
    const ownerToken = await login("owner-code");
    const helperToken = await login("helper-code");
    const h = (t) => ({ "content-type": "application/json", authorization: `Bearer ${t}` });

    const created = await json(await request("/api/account/wishes", {
      method: "POST", headers: h(ownerToken),
      body: JSON.stringify({
        requesterName: "发布者", city: "杭州", landmark: "西湖断桥", occasion: "生日祝福",
        message: "请替我在断桥说一声生日快乐。", deliveryType: "spoken_video",
        deadlineText: "本周内", rewardFen: 0, contactConsent: true,
      }),
    }));
    const wishId = created.wish.id;
    await request(`/api/admin/wishes/${wishId}`, {
      method: "PATCH", headers: admin, body: JSON.stringify({ action: "approve" }),
    });
    await request(`/api/account/wishes/${wishId}/responses`, {
      method: "POST", headers: h(helperToken),
      body: JSON.stringify({ responderName: "帮助者", contactConsent: true }),
    });
    const listed = await json(await request(`/api/account/wishes/${wishId}/responses`, { headers: h(ownerToken) }));
    const responseId = listed.responses[0].id;
    await request(`/api/account/conversations/${responseId}/messages`, {
      method: "POST", headers: h(helperToken), body: JSON.stringify({ body: "一句不合适的话" }),
    });

    // 用户举报
    await request("/api/account/reports", {
      method: "POST", headers: h(ownerToken),
      body: JSON.stringify({ responseId, reason: "骚扰或辱骂", detail: "对方言语不当" }),
    });

    // 运营能看到待办
    const reports = await json(await request("/api/admin/reports", { headers: admin }));
    assert.equal(reports.reports.length, 1);
    assert.equal(reports.reports[0].reason, "骚扰或辱骂");
    assert.equal(reports.reports[0].messageCount, 1);
    const reportId = reports.reports[0].id;

    // 运营可读取被举报会话，用于判断是否属实
    const conversation = await json(
      await request(`/api/admin/reports/${reportId}/conversation`, { headers: admin }),
    );
    assert.equal(conversation.messages.length, 1);
    assert.equal(conversation.messages[0].body, "一句不合适的话");

    // 未带 PIN 一律拒绝
    const unauthorized = await request(`/api/admin/reports/${reportId}/conversation`);
    assert.equal(unauthorized.status, 401);

    // 处理后从待办中消失
    const resolved = await request(`/api/admin/reports/${reportId}`, {
      method: "PATCH", headers: admin, body: JSON.stringify({ action: "actioned", note: "已警告" }),
    });
    assert.equal(resolved.status, 200);
    const after = await json(await request("/api/admin/reports", { headers: admin }));
    assert.equal(after.reports.length, 0, "已处理的举报不应再出现在待办中");
  } finally {
    globalThis.fetch = originalFetch;
  }
});

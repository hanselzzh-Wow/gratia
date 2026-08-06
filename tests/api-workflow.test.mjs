import assert from "node:assert/strict";
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

    // 需求方单独决定公开之后才出现，且带上多文件与说明文字
    const published = await request(`/api/account/wishes/${wishId}/story`, {
      method: "POST", headers: requesterHeaders, body: JSON.stringify({ nickname: "晚风" }),
    });
    assert.equal(published.status, 201);
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

    // 拉黑后会话不可进入，也不再出现在列表
    const blocked = await request(`/api/account/conversations/${responseId}/block`, {
      method: "POST", headers: h(ownerToken),
    });
    assert.equal(blocked.status, 201);
    const afterBlock = await request(`/api/account/conversations/${responseId}/messages`, { headers: h(helperToken) });
    assert.equal(afterBlock.status, 403);
    const helperListAfter = await json(await request("/api/account/conversations", { headers: h(helperToken) }));
    assert.equal(helperListAfter.conversations.length, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

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

async function setup({ legacyAssignments = false } = {}) {
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

  return { request, database };
}

async function json(response) {
  return response.json();
}

test("upgrades an existing local assignments schema without losing data", async () => {
  const { request, database } = await setup({ legacyAssignments: true });
  const health = await request("/api/health");
  assert.equal(health.status, 200);
  const columns = database.database.prepare("PRAGMA table_info(assignments)").all();
  assert.ok(columns.some((column) => column.name === "provider_id"));
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

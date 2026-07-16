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

async function setup() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("api-test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  const env = {
    DB: new TestD1(),
    UPLOADS: new TestR2(),
    ADMIN_API_KEY: "test-admin-pin",
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
  };
  const ctx = { waitUntil() {}, passThroughOnException() {} };

  async function request(path, init = {}) {
    return worker.fetch(new Request(`http://localhost${path}`, init), env, ctx);
  }

  return { request };
}

async function json(response) {
  return response.json();
}

test("runs the publish, response, matching, and tracking workflow", async () => {
  const { request } = await setup();
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

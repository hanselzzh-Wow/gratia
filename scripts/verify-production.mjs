import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import process from "node:process";
import {
  defaultCloudflareSecretsPath,
  parseCloudflareSecrets,
  validateCloudflareSecrets,
} from "./cloudflare-secrets.mjs";

const argumentsList = process.argv.slice(2);
const full = argumentsList.includes("--full");
const baseArgument = argumentsList.find((argument) => !argument.startsWith("--"));
const configuredBase = baseArgument ?? process.env.GRATIA_BASE_URL;

if (!configuredBase) {
  console.error(
    "用法：npm run verify:production -- https://<worker>.workers.dev [--full]",
  );
  process.exit(1);
}

const baseUrl = new URL(configuredBase);
if (baseUrl.hostname.endsWith(".chatgpt.site")) {
  console.error("拒绝验收已知会被平台安全层拦截的 chatgpt.site 地址。");
  process.exit(1);
}
if (
  baseUrl.protocol !== "https:" &&
  !["localhost", "127.0.0.1", "::1"].includes(baseUrl.hostname)
) {
  console.error("生产验收地址必须使用 HTTPS。");
  process.exit(1);
}
const basePath = baseUrl.pathname.replace(/\/+$/, "");
baseUrl.search = "";
baseUrl.hash = "";
const isLocal = ["localhost", "127.0.0.1", "::1"].includes(baseUrl.hostname);
const allowedOrigin =
  process.env.GRATIA_PUBLIC_ORIGIN?.replace(/\/$/, "") ??
  (isLocal ? baseUrl.origin : "https://hanselzzh-wow.github.io");

function endpoint(path) {
  const url = new URL(baseUrl.origin);
  url.pathname = `${basePath}${path}`;
  return url;
}

async function request(path, init = {}) {
  return fetch(endpoint(path), {
    ...init,
    signal: init.signal ?? AbortSignal.timeout(30_000),
  });
}

async function jsonRequest(path, init = {}, expectedStatus = 200) {
  const response = await request(path, init);
  const text = await response.text();
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    throw new Error(`${path} 返回了非 JSON 响应（HTTP ${response.status}）`);
  }
  if (response.status !== expectedStatus) {
    throw new Error(
      `${path} 预期 HTTP ${expectedStatus}，实际为 ${response.status}：${payload.error ?? text}`,
    );
  }
  return { response, payload };
}

function adminHeaders(adminKey, json = true) {
  return {
    ...(json ? { "content-type": "application/json" } : {}),
    "x-admin-key": adminKey,
  };
}

async function adminAction(adminKey, wishId, action) {
  return jsonRequest(
    `/api/admin/wishes/${encodeURIComponent(wishId)}`,
    {
      method: "PATCH",
      headers: adminHeaders(adminKey),
      body: JSON.stringify(action),
    },
  );
}

function getAdminKey() {
  const fromEnvironment = process.env.GRATIA_ADMIN_API_KEY?.trim();
  if (fromEnvironment) return fromEnvironment;
  if (!existsSync(defaultCloudflareSecretsPath)) {
    throw new Error(
      "完整验收需要 GRATIA_ADMIN_API_KEY，或本地有效的 .cloudflare.secrets。",
    );
  }
  const values = validateCloudflareSecrets(
    parseCloudflareSecrets(readFileSync(defaultCloudflareSecretsPath, "utf8")),
  );
  return values.get("ADMIN_API_KEY") ?? "";
}

function logCheck(message) {
  console.log(`✓ ${message}`);
}

async function verifyReadOnly() {
  const { response: healthResponse, payload: health } = await jsonRequest("/api/health");
  assert.equal(health.ok, true);
  assert.equal(health.service, "gratia-wishes");
  assert.equal(health.database, "ready");
  assert.equal(healthResponse.headers.get("cache-control"), "no-store");
  logCheck("Worker 与 D1 健康检查通过");

  const preflight = await request("/api/admin/wishes", {
    method: "OPTIONS",
    headers: {
      origin: allowedOrigin,
      "access-control-request-method": "PATCH",
      "access-control-request-headers": "content-type, x-admin-key",
    },
  });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get("access-control-allow-origin"), allowedOrigin);
  assert.match(preflight.headers.get("access-control-allow-methods") ?? "", /PATCH/);
  assert.match(preflight.headers.get("access-control-allow-headers") ?? "", /x-admin-key/i);
  logCheck("GitHub Pages 跨域预检通过");

  const blockedOrigin = await request("/api/wishes", {
    method: "OPTIONS",
    headers: {
      origin: "https://untrusted.example",
      "access-control-request-method": "POST",
    },
  });
  assert.equal(blockedOrigin.status, 403);
  assert.equal(blockedOrigin.headers.has("access-control-allow-origin"), false);
  logCheck("非白名单来源被正确拒绝");
}

async function verifyFullWorkflow() {
  const adminKey = getAdminKey();
  const stamp = `${Date.now()}-${randomUUID().slice(0, 8)}`;
  const requesterContact = `qa-requester-${stamp}`;
  const providerContact = `qa-provider-${stamp}`;
  const imageBytes = Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
    "base64",
  );
  let wishId;
  let providerId;
  let completed = false;
  let providerPaused = false;

  try {
    const unauthorized = await request("/api/admin/wishes", {
      headers: { "x-admin-key": "production-verifier-wrong-key" },
    });
    assert.equal(unauthorized.status, 401);
    logCheck("运营接口未授权访问被拒绝");

    const { payload: providerPayload } = await jsonRequest(
      "/api/admin/providers",
      {
        method: "POST",
        headers: adminHeaders(adminKey),
        body: JSON.stringify({
          name: "上线验收供应者",
          contact: providerContact,
          city: "上海",
          landmarks: "外滩验收点",
          availabilityNote: "自动化上线验收记录，请保持暂停",
        }),
      },
      201,
    );
    providerId = providerPayload.provider.id;
    assert.equal(providerPayload.provider.status, "available");
    logCheck("种子供应者创建成功");

    const { payload: createdPayload } = await jsonRequest(
      "/api/wishes",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          origin: allowedOrigin,
        },
        body: JSON.stringify({
          requesterName: "上线验收",
          contact: requesterContact,
          city: "上海",
          landmark: "外滩",
          occasion: "上线验收",
          message: `这是哈喽卧得的自动化上线闭环验收 ${stamp}`,
          deliveryType: "spoken_video",
          deadlineText: "验收完成前",
          rewardFen: 100,
          contactConsent: true,
        }),
      },
      201,
    );
    wishId = createdPayload.wish.id;
    assert.equal(createdPayload.wish.status, "pending_review");
    logCheck("真实心愿发布成功");

    const { payload: beforeReview } = await jsonRequest("/api/wishes", {
      headers: { origin: allowedOrigin },
    });
    assert.equal(beforeReview.wishes.some((wish) => wish.id === wishId), false);

    const { payload: approvedPayload } = await adminAction(adminKey, wishId, {
      action: "approve",
      note: "自动化上线验收内容",
    });
    assert.equal(approvedPayload.wish.status, "matching");
    logCheck("人工审核状态流转成功");

    const { response: publicResponse, payload: publicPayload } = await jsonRequest(
      "/api/wishes",
      { headers: { origin: allowedOrigin } },
    );
    assert.equal(publicResponse.headers.get("access-control-allow-origin"), allowedOrigin);
    const publicWish = publicPayload.wishes.find((wish) => wish.id === wishId);
    assert.ok(publicWish);
    assert.equal("contact" in publicWish, false);
    assert.equal("requesterName" in publicWish, false);
    assert.equal(JSON.stringify(publicWish).includes(requesterContact), false);
    logCheck("审核后公开展示且隐私字段未泄露");

    const { payload: assignedPayload } = await adminAction(adminKey, wishId, {
      action: "assign",
      providerId,
      note: "自动化城市供应匹配",
    });
    assert.equal(assignedPayload.wish.status, "assigned");
    assert.equal(assignedPayload.wish.assignment.providerId, providerId);

    const { payload: acceptedPayload } = await adminAction(adminKey, wishId, {
      action: "accept",
    });
    assert.equal(acceptedPayload.wish.status, "in_progress");
    logCheck("人工派单与接单状态流转成功");

    const form = new FormData();
    form.set(
      "file",
      new Blob([imageBytes], { type: "image/png" }),
      `gratia-production-check-${stamp}.png`,
    );
    form.set("note", "自动化 R2 文件交付验收");
    const { payload: uploadPayload } = await jsonRequest(
      `/api/admin/wishes/${encodeURIComponent(wishId)}/deliverables/upload`,
      {
        method: "POST",
        headers: adminHeaders(adminKey, false),
        body: form,
      },
      201,
    );
    assert.equal(uploadPayload.wish.status, "delivered");
    assert.match(uploadPayload.wish.deliverable.url, /\/api\/deliverables\//);

    const { payload: trackingPayload } = await jsonRequest("/api/wishes/track", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: allowedOrigin,
      },
      body: JSON.stringify({
        publicCode: createdPayload.wish.publicCode,
        contact: requesterContact,
      }),
    });
    assert.equal(trackingPayload.wish.status, "delivered");
    assert.equal("contact" in trackingPayload.wish, false);
    assert.equal("requesterName" in trackingPayload.wish, false);
    assert.ok(trackingPayload.wish.events.length >= 5);

    const deliveryResponse = await fetch(trackingPayload.wish.deliverable.url, {
      signal: AbortSignal.timeout(30_000),
    });
    assert.equal(deliveryResponse.status, 200);
    assert.match(deliveryResponse.headers.get("content-type") ?? "", /^image\/png/);
    assert.deepEqual(
      Buffer.from(await deliveryResponse.arrayBuffer()),
      imageBytes,
    );
    logCheck("R2 文件上传、私密链接和发布者追踪通过");

    const { payload: completedPayload } = await adminAction(adminKey, wishId, {
      action: "complete",
      note: "自动化上线验收完成",
    });
    assert.equal(completedPayload.wish.status, "completed");
    completed = true;

    const { payload: providersPayload } = await jsonRequest("/api/admin/providers", {
      headers: adminHeaders(adminKey, false),
    });
    const completedProvider = providersPayload.providers.find(
      (provider) => provider.id === providerId,
    );
    assert.ok(completedProvider);
    assert.equal(completedProvider.status, "available");
    assert.ok(completedProvider.completedCount >= 1);

    const exportResponse = await request("/api/admin/export.csv", {
      headers: adminHeaders(adminKey, false),
    });
    assert.equal(exportResponse.status, 200);
    assert.match(exportResponse.headers.get("content-type") ?? "", /^text\/csv/);
    assert.equal(exportResponse.headers.get("cache-control"), "private, no-store");
    const csv = await exportResponse.text();
    assert.ok(csv.includes(requesterContact));
    assert.ok(csv.includes(providerContact));

    const { payload: pausedPayload } = await jsonRequest(
      `/api/admin/providers/${encodeURIComponent(providerId)}`,
      {
        method: "PATCH",
        headers: adminHeaders(adminKey),
        body: JSON.stringify({ status: "paused" }),
      },
    );
    assert.equal(pausedPayload.provider.status, "paused");
    providerPaused = true;
    logCheck("完结、供应者复位与运营导出通过");
    console.log(`\n完整线上闭环验收通过：${createdPayload.wish.publicCode}`);
  } finally {
    if (wishId && !completed) {
      await adminAction(adminKey, wishId, {
        action: "cancel",
        note: "上线验收异常后的自动清理",
      }).catch(() => {});
    }
    if (providerId && !providerPaused) {
      await jsonRequest(
        `/api/admin/providers/${encodeURIComponent(providerId)}`,
        {
          method: "PATCH",
          headers: adminHeaders(adminKey),
          body: JSON.stringify({ status: "paused" }),
        },
      ).catch(() => {});
    }
  }
}

try {
  console.log(`验收目标：${baseUrl.origin}${basePath}`);
  await verifyReadOnly();
  if (full) await verifyFullWorkflow();
  else console.log("\n只读线上检查通过；使用 --full 执行真实闭环验收。");
} catch (error) {
  console.error(`\n验收失败：${error instanceof Error ? error.message : String(error)}`);
  process.exitCode = 1;
}

/** Cloudflare Worker entry point for the vinext-starter template. */
import { handleImageOptimization, DEFAULT_DEVICE_SIZES, DEFAULT_IMAGE_SIZES } from "vinext/server/image-optimization";
import handler from "vinext/server/app-router-entry";
import {
  WishInputError,
  normalizeAdminAction,
  normalizeCreateProvider,
  normalizeCreateWish,
  normalizeTrackingInput,
  normalizeUpdateProvider,
  normalizeWishResponse,
} from "../lib/wishes-validation";
import {
  applyAdminWishAction,
  createProvider,
  createWish,
  createWishResponse,
  getWishHealth,
  listAdminWishes,
  listProviders,
  listPublicWishes,
  getStoredDeliverable,
  getAccountDeliverable,
  listAccountActivity,
  completeWishForOwner,
  recordUploadedDeliverable,
  trackWish,
  updateProvider,
  WishWorkflowError,
} from "../server/wishes-repository";
import {
  createAppleSession,
  createWechatSession,
  deleteAuthenticatedAccount,
  getAuthenticatedUser,
} from "../server/accounts-repository";
import {
  exchangeAppleAuthorizationCode,
  revokeAppleRefreshToken,
  verifyAppleIdentityToken,
  type AppleAuthConfig,
} from "../server/apple-identity";
import { consumeRateLimit, RateLimitError } from "../server/rate-limit";

interface Env {
  ASSETS: Fetcher;
  DB: D1Database;
  UPLOADS?: R2Bucket;
  ADMIN_API_KEY?: string;
  PUBLIC_APP_ORIGIN?: string;
  RATE_LIMIT_SALT?: string;
  WECHAT_MINI_PROGRAM_APP_ID?: string;
  WECHAT_MINI_PROGRAM_APP_SECRET?: string;
  APPLE_BUNDLE_ID?: string;
  APPLE_TEAM_ID?: string;
  APPLE_KEY_ID?: string;
  APPLE_PRIVATE_KEY?: string;
  IMAGES: {
    input(stream: ReadableStream): {
      transform(options: Record<string, unknown>): {
        output(options: { format: string; quality: number }): Promise<{ response(): Response }>;
      };
    };
  };
}

const githubPagesOrigin = "https://hanselzzh-wow.github.io";
const maxUploadBytes = 25 * 1024 * 1024;
const allowedUploadTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "video/mp4",
  "video/webm",
  "video/quicktime",
]);

function isAllowedOrigin(request: Request, env: Env) {
  const origin = request.headers.get("origin");
  if (!origin) return true;
  const requestOrigin = new URL(request.url).origin;
  const allowed = new Set([requestOrigin, githubPagesOrigin]);
  if (env.PUBLIC_APP_ORIGIN) allowed.add(env.PUBLIC_APP_ORIGIN.replace(/\/$/, ""));
  return allowed.has(origin.replace(/\/$/, ""));
}

function corsHeaders(request: Request, env: Env) {
  const origin = request.headers.get("origin");
  if (!origin || !isAllowedOrigin(request, env)) return {};
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-methods": "GET, POST, PATCH, OPTIONS",
    "access-control-allow-headers": "authorization, content-type, x-admin-key, x-client-platform",
    "access-control-max-age": "86400",
    vary: "Origin",
  };
}

function json(request: Request, env: Env, payload: unknown, status = 200) {
  return Response.json(payload, {
    status,
    headers: {
      "cache-control": "no-store",
      ...corsHeaders(request, env),
    },
  });
}

function safeFilename(name: string) {
  const cleaned = name.replace(/[^a-zA-Z0-9._-]+/g, "-").replace(/^-+|-+$/g, "");
  return cleaned.slice(-100) || "delivery";
}

function csvCell(value: unknown) {
  const text = String(value ?? "");
  const spreadsheetSafe = /^[\t\r\n ]*[=+\-@]/.test(text) ? `'${text}` : text;
  return `"${spreadsheetSafe.replaceAll('"', '""')}"`;
}

async function secureEqual(left: string, right: string) {
  const encoder = new TextEncoder();
  const [leftHash, rightHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(left)),
    crypto.subtle.digest("SHA-256", encoder.encode(right)),
  ]);
  const a = new Uint8Array(leftHash);
  const b = new Uint8Array(rightHash);
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) difference |= a[index] ^ b[index];
  return difference === 0;
}

async function requestFingerprint(request: Request, env: Env) {
  const ip = request.headers.get("cf-connecting-ip") ?? request.headers.get("x-forwarded-for") ?? "local";
  const salt = env.RATE_LIMIT_SALT ?? env.ADMIN_API_KEY ?? "gratia-local";
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(`${salt}|${ip}`));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function enforceRateLimit(
  request: Request,
  env: Env,
  action: string,
  limit: number,
  windowMs: number,
) {
  await consumeRateLimit(env.DB, await requestFingerprint(request, env), action, limit, windowMs);
}

async function requireAdmin(request: Request, env: Env) {
  await enforceRateLimit(request, env, "admin", 80, 10 * 60_000);
  if (!env.ADMIN_API_KEY) {
    throw new WishWorkflowError("运营 PIN 尚未配置", 503);
  }
  const provided = request.headers.get("x-admin-key") ?? "";
  if (!(await secureEqual(provided, env.ADMIN_API_KEY))) {
    throw new WishWorkflowError("运营 PIN 不正确", 401);
  }
}

function bearerToken(request: Request) {
  const value = request.headers.get("authorization") ?? "";
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() ?? "";
}

async function requireAccount(request: Request, env: Env) {
  await enforceRateLimit(request, env, "account", 120, 10 * 60_000);
  return getAuthenticatedUser(env.DB, bearerToken(request));
}

function appleAuthConfig(env: Env): AppleAuthConfig {
  return {
    bundleId: env.APPLE_BUNDLE_ID ?? "com.hanselzzh.gratia",
    teamId: env.APPLE_TEAM_ID,
    keyId: env.APPLE_KEY_ID,
    privateKey: env.APPLE_PRIVATE_KEY,
  };
}

async function exchangeWechatCode(env: Env, code: string) {
  if (!env.WECHAT_MINI_PROGRAM_APP_ID || !env.WECHAT_MINI_PROGRAM_APP_SECRET) {
    throw new WishWorkflowError("微信登录暂未配置，请稍后重试", 503);
  }
  const endpoint = new URL("https://api.weixin.qq.com/sns/jscode2session");
  endpoint.searchParams.set("appid", env.WECHAT_MINI_PROGRAM_APP_ID);
  endpoint.searchParams.set("secret", env.WECHAT_MINI_PROGRAM_APP_SECRET);
  endpoint.searchParams.set("js_code", code);
  endpoint.searchParams.set("grant_type", "authorization_code");
  const response = await fetch(endpoint, { headers: { accept: "application/json" } });
  if (!response.ok) throw new WishWorkflowError("微信登录服务暂时不可用，请稍后重试", 502);
  const payload = (await response.json()) as { openid?: unknown; errcode?: unknown };
  if (typeof payload.openid !== "string" || !payload.openid) {
    throw new WishWorkflowError("微信登录未完成，请重新尝试", 401);
  }
  return payload.openid;
}

async function handleWishApi(request: Request, env: Env) {
  const url = new URL(request.url);
  if (!isAllowedOrigin(request, env)) {
    return json(request, env, { error: "不允许的请求来源" }, 403);
  }

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(request, env) });
  }

  try {
    const deliverableMatch = url.pathname.match(/^\/api\/deliverables\/([^/]+)$/);
    if (deliverableMatch && request.method === "GET") {
      await enforceRateLimit(request, env, "delivery", 120, 10 * 60_000);
      if (!env.UPLOADS) return json(request, env, { error: "文件存储尚未配置" }, 503);
      const accessToken = url.searchParams.get("token") ?? "";
      if (!accessToken) return json(request, env, { error: "交付链接无效" }, 401);
      const record = await getStoredDeliverable(
        env.DB,
        decodeURIComponent(deliverableMatch[1]),
        accessToken,
      );
      if (!record) return json(request, env, { error: "交付内容不存在或链接已失效" }, 404);
      const object = await env.UPLOADS.get(record.storageKey);
      if (!object) return json(request, env, { error: "交付文件不存在" }, 404);
      const headers = new Headers({
        "cache-control": "private, no-store",
        "content-disposition": `inline; filename="${safeFilename(record.storageKey.split("/").at(-1) ?? "delivery")}"`,
        "referrer-policy": "no-referrer",
        ...corsHeaders(request, env),
      });
      object.writeHttpMetadata(headers);
      return new Response(object.body, { headers });
    }

    if (url.pathname === "/api/health" && request.method === "GET") {
      return json(request, env, {
        ok: true,
        service: "gratia-wishes",
        ...(await getWishHealth(env.DB)),
      });
    }

    if (url.pathname === "/api/auth/wechat" && request.method === "POST") {
      await enforceRateLimit(request, env, "wechat_login", 20, 10 * 60_000);
      const contentType = request.headers.get("content-type") ?? "";
      if (!contentType.includes("application/json")) {
        return json(request, env, { error: "仅接受 JSON 请求" }, 415);
      }
      const payload = (await request.json()) as { code?: unknown };
      const code = typeof payload.code === "string" ? payload.code.trim() : "";
      if (code.length < 6 || code.length > 1024) {
        return json(request, env, { error: "微信登录凭证无效，请重新尝试" }, 400);
      }
      const openId = await exchangeWechatCode(env, code);
      const session = await createWechatSession(env.DB, openId);
      return json(request, env, {
        token: session.token,
        expiresAt: session.expiresAt,
        user: session.user,
      }, 201);
    }

    if (url.pathname === "/api/auth/apple" && request.method === "POST") {
      await enforceRateLimit(request, env, "apple_login", 20, 10 * 60_000);
      const contentType = request.headers.get("content-type") ?? "";
      if (!contentType.includes("application/json")) {
        return json(request, env, { error: "仅接受 JSON 请求" }, 415);
      }
      const payload = (await request.json()) as {
        identityToken?: unknown;
        rawNonce?: unknown;
        authorizationCode?: unknown;
      };
      const identityToken = typeof payload.identityToken === "string" ? payload.identityToken.trim() : "";
      if (identityToken.length < 16 || identityToken.length > 8192) {
        return json(request, env, { error: "Apple 登录凭证无效，请重新尝试" }, 400);
      }
      const rawNonce = typeof payload.rawNonce === "string" ? payload.rawNonce.trim() : "";
      const config = appleAuthConfig(env);
      const subject = await verifyAppleIdentityToken(identityToken, config, {
        rawNonce: rawNonce || undefined,
      });

      const authorizationCode =
        typeof payload.authorizationCode === "string" ? payload.authorizationCode.trim() : "";
      const refreshToken = authorizationCode
        ? await exchangeAppleAuthorizationCode(authorizationCode, config)
        : null;

      const session = await createAppleSession(env.DB, subject, refreshToken);
      return json(request, env, {
        token: session.token,
        expiresAt: session.expiresAt,
        user: session.user,
      }, 201);
    }

    if (url.pathname === "/api/me" && request.method === "GET") {
      const user = await requireAccount(request, env);
      return json(request, env, { user });
    }

    if (url.pathname === "/api/me" && request.method === "DELETE") {
      const user = await requireAccount(request, env);
      const result = await deleteAuthenticatedAccount(env.DB, user.id);

      // Apple 要求删除账户时撤销登录令牌。撤销失败不回滚删除，
      // 只在响应里如实标注，避免把平台故障变成用户无法注销。
      let appleTokensRevoked = true;
      const config = appleAuthConfig(env);
      for (const identity of result.revokedIdentities) {
        if (identity.provider !== "apple") continue;
        const revoked = await revokeAppleRefreshToken(identity.refreshToken, config);
        if (!revoked) appleTokensRevoked = false;
      }

      return json(request, env, { deletedAt: result.deletedAt, appleTokensRevoked });
    }

    if (url.pathname === "/api/account/wishes" && request.method === "GET") {
      const user = await requireAccount(request, env);
      return json(request, env, await listAccountActivity(env.DB, user.id));
    }

    if (url.pathname === "/api/account/wishes" && request.method === "POST") {
      const user = await requireAccount(request, env);
      const contentType = request.headers.get("content-type") ?? "";
      if (!contentType.includes("application/json")) {
        return json(request, env, { error: "仅接受 JSON 请求" }, 415);
      }
      await enforceRateLimit(request, env, "account_publish", 8, 60 * 60_000);
      const input = normalizeCreateWish(await request.json());
      const result = await createWish(env.DB, input, user.id);
      return json(request, env, result, result.created ? 201 : 200);
    }

    const accountResponseMatch = url.pathname.match(/^\/api\/account\/wishes\/([^/]+)\/responses$/);
    if (accountResponseMatch && request.method === "POST") {
      const user = await requireAccount(request, env);
      const contentType = request.headers.get("content-type") ?? "";
      if (!contentType.includes("application/json")) {
        return json(request, env, { error: "仅接受 JSON 请求" }, 415);
      }
      await enforceRateLimit(request, env, "account_respond", 20, 60 * 60_000);
      const input = normalizeWishResponse(await request.json());
      const result = await createWishResponse(env.DB, decodeURIComponent(accountResponseMatch[1]), input, user.id);
      return json(request, env, result, result.created ? 201 : 200);
    }

    const accountCompletionMatch = url.pathname.match(/^\/api\/account\/wishes\/([^/]+)\/complete$/);
    if (accountCompletionMatch && request.method === "POST") {
      const user = await requireAccount(request, env);
      const wish = await completeWishForOwner(env.DB, decodeURIComponent(accountCompletionMatch[1]), user.id);
      return json(request, env, { wish });
    }

    const accountDeliveryMatch = url.pathname.match(/^\/api\/account\/wishes\/([^/]+)\/deliverable$/);
    if (accountDeliveryMatch && request.method === "GET") {
      const user = await requireAccount(request, env);
      const delivery = await getAccountDeliverable(env.DB, decodeURIComponent(accountDeliveryMatch[1]), user.id);
      if (delivery.storageKey) {
        if (!env.UPLOADS) return json(request, env, { error: "文件存储尚未配置" }, 503);
        const object = await env.UPLOADS.get(delivery.storageKey);
        if (!object) return json(request, env, { error: "交付文件不存在" }, 404);
        const headers = new Headers({ "cache-control": "private, no-store", "referrer-policy": "no-referrer" });
        object.writeHttpMetadata(headers);
        return new Response(object.body, { headers });
      }
      return Response.redirect(delivery.url, 302);
    }

    if (url.pathname === "/api/wishes" && request.method === "GET") {
      const city = url.searchParams.get("city")?.trim() || undefined;
      return json(request, env, { wishes: await listPublicWishes(env.DB, city) });
    }

    if (url.pathname === "/api/wishes" && request.method === "POST") {
      await enforceRateLimit(request, env, "publish", 8, 60 * 60_000);
      const contentType = request.headers.get("content-type") ?? "";
      if (!contentType.includes("application/json")) {
        return json(request, env, { error: "仅接受 JSON 请求" }, 415);
      }
      const input = normalizeCreateWish(await request.json());
      const result = await createWish(env.DB, input);
      return json(request, env, result, result.created ? 201 : 200);
    }

    if (url.pathname === "/api/wishes/track" && request.method === "POST") {
      await enforceRateLimit(request, env, "track", 30, 10 * 60_000);
      const input = normalizeTrackingInput(await request.json());
      return json(request, env, { wish: await trackWish(env.DB, input.publicCode, input.contact) });
    }

    const wishResponseMatch = url.pathname.match(/^\/api\/wishes\/([^/]+)\/responses$/);
    if (wishResponseMatch && request.method === "POST") {
      await enforceRateLimit(request, env, "respond", 20, 60 * 60_000);
      const input = normalizeWishResponse(await request.json());
      const result = await createWishResponse(
        env.DB,
        decodeURIComponent(wishResponseMatch[1]),
        input,
      );
      return json(request, env, result, result.created ? 201 : 200);
    }

    if (url.pathname === "/api/admin/wishes" && request.method === "GET") {
      await requireAdmin(request, env);
      const status = url.searchParams.get("status")?.trim() || undefined;
      return json(request, env, { wishes: await listAdminWishes(env.DB, status) });
    }

    if (url.pathname === "/api/admin/export.csv" && request.method === "GET") {
      await requireAdmin(request, env);
      const [wishes, providers] = await Promise.all([
        listAdminWishes(env.DB),
        listProviders(env.DB),
      ]);
      const headers = [
        "记录类型",
        "编号",
        "状态",
        "城市",
        "地标",
        "场景/常驻地标",
        "内容/可用说明",
        "发布者/供应者",
        "联系方式",
        "响应者",
        "响应者联系方式",
        "感谢金(元)",
        "创建时间",
        "更新时间",
      ];
      const rows = [
        headers,
        ...wishes.map((wish) => [
          "心愿",
          wish.publicCode,
          wish.status,
          wish.city,
          wish.landmark,
          wish.occasion,
          wish.message,
          wish.requesterName,
          wish.contact,
          wish.assignment?.providerName ?? "",
          wish.assignment?.providerContact ?? "",
          (wish.rewardFen / 100).toFixed(2),
          new Date(wish.createdAt).toISOString(),
          new Date(wish.updatedAt).toISOString(),
        ]),
        ...providers.map((provider) => [
          "供应者",
          provider.id,
          provider.status,
          provider.city,
          "",
          provider.landmarks,
          provider.availabilityNote ?? "",
          provider.name,
          provider.contact,
          "",
          "",
          "",
          new Date(provider.createdAt).toISOString(),
          new Date(provider.updatedAt).toISOString(),
        ]),
      ];
      const csv = `\uFEFF${rows.map((row) => row.map(csvCell).join(",")).join("\r\n")}`;
      return new Response(csv, {
        headers: {
          "content-type": "text/csv; charset=utf-8",
          "content-disposition": `attachment; filename="gratia-ops-${new Date().toISOString().slice(0, 10)}.csv"`,
          "cache-control": "private, no-store",
          ...corsHeaders(request, env),
        },
      });
    }

    if (url.pathname === "/api/admin/providers" && request.method === "GET") {
      await requireAdmin(request, env);
      const city = url.searchParams.get("city")?.trim() || undefined;
      return json(request, env, { providers: await listProviders(env.DB, city) });
    }

    if (url.pathname === "/api/admin/providers" && request.method === "POST") {
      await requireAdmin(request, env);
      const provider = await createProvider(env.DB, normalizeCreateProvider(await request.json()));
      return json(request, env, { provider }, 201);
    }

    const providerMatch = url.pathname.match(/^\/api\/admin\/providers\/([^/]+)$/);
    if (providerMatch && request.method === "PATCH") {
      await requireAdmin(request, env);
      const provider = await updateProvider(
        env.DB,
        decodeURIComponent(providerMatch[1]),
        normalizeUpdateProvider(await request.json()),
      );
      return json(request, env, { provider });
    }

    const uploadMatch = url.pathname.match(/^\/api\/admin\/wishes\/([^/]+)\/deliverables\/upload$/);
    if (uploadMatch && request.method === "POST") {
      await requireAdmin(request, env);
      if (!env.UPLOADS) return json(request, env, { error: "文件存储尚未配置" }, 503);
      const form = await request.formData();
      const file = form.get("file");
      if (!(file instanceof File) || file.size === 0) {
        return json(request, env, { error: "请选择要交付的照片或视频" }, 400);
      }
      if (file.size > maxUploadBytes) {
        return json(request, env, { error: "文件不能超过 25MB；较大视频可继续使用 HTTPS 链接交付" }, 413);
      }
      if (!allowedUploadTypes.has(file.type)) {
        return json(request, env, { error: "仅支持 JPG、PNG、WebP、MP4、WebM 或 MOV" }, 415);
      }

      const wishId = decodeURIComponent(uploadMatch[1]);
      const deliverableId = crypto.randomUUID();
      const accessToken = `${crypto.randomUUID().replaceAll("-", "")}${crypto.randomUUID().replaceAll("-", "")}`;
      const storageKey = `deliverables/${wishId}/${deliverableId}-${safeFilename(file.name)}`;
      const deliveryUrl = new URL(`/api/deliverables/${deliverableId}`, request.url);
      deliveryUrl.searchParams.set("token", accessToken);
      const note = String(form.get("note") ?? "").trim().slice(0, 300) || undefined;

      await env.UPLOADS.put(storageKey, file.stream(), {
        httpMetadata: { contentType: file.type },
        customMetadata: { wishId, deliverableId },
      });
      try {
        const wish = await recordUploadedDeliverable(env.DB, wishId, {
          deliverableId,
          storageKey,
          accessToken,
          url: deliveryUrl.toString(),
          note,
        });
        return json(request, env, { wish }, 201);
      } catch (error) {
        await env.UPLOADS.delete(storageKey);
        throw error;
      }
    }

    const adminWishMatch = url.pathname.match(/^\/api\/admin\/wishes\/([^/]+)$/);
    if (adminWishMatch && request.method === "PATCH") {
      await requireAdmin(request, env);
      const input = normalizeAdminAction(await request.json());
      const wish = await applyAdminWishAction(env.DB, decodeURIComponent(adminWishMatch[1]), input);
      return json(request, env, { wish });
    }

    return json(request, env, { error: "接口不存在" }, 404);
  } catch (error) {
    if (error instanceof RateLimitError) {
      const response = json(request, env, { error: error.message }, 429);
      response.headers.set("retry-after", String(error.retryAfterSeconds));
      return response;
    }
    if (error instanceof WishInputError) {
      return json(request, env, { error: error.message, fields: error.fields }, 400);
    }
    if (error instanceof WishWorkflowError) {
      return json(request, env, { error: error.message }, error.status);
    }
    console.error("wish api error", error);
    return json(request, env, { error: "服务暂时不可用，请稍后再试" }, 500);
  }
}

interface ExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
  passThroughOnException(): void;
}

// Image security config. SVG sources with .svg extension auto-skip the
// optimization endpoint on the client side (served directly, no proxy).
// To route SVGs through the optimizer (with security headers), set
// dangerouslyAllowSVG: true in next.config.js and uncomment below:
// const imageConfig: ImageConfig = { dangerouslyAllowSVG: true };

const worker = {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/")) {
      return handleWishApi(request, env);
    }

    if (url.pathname === "/_vinext/image") {
      const allowedWidths = [...DEFAULT_DEVICE_SIZES, ...DEFAULT_IMAGE_SIZES];
      return handleImageOptimization(request, {
        fetchAsset: (path) => env.ASSETS.fetch(new Request(new URL(path, request.url))),
        transformImage: async (body, { width, format, quality }) => {
          const result = await env.IMAGES.input(body).transform(width > 0 ? { width } : {}).output({ format, quality });
          return result.response();
        },
      }, allowedWidths);
    }

    return handler.fetch(request, env, ctx);
  },
};

export default worker;

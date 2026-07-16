/** Cloudflare Worker entry point for the vinext-starter template. */
import { handleImageOptimization, DEFAULT_DEVICE_SIZES, DEFAULT_IMAGE_SIZES } from "vinext/server/image-optimization";
import handler from "vinext/server/app-router-entry";
import {
  WishInputError,
  normalizeAdminAction,
  normalizeCreateWish,
  normalizeTrackingInput,
  normalizeWishResponse,
} from "../lib/wishes-validation";
import {
  applyAdminWishAction,
  createWish,
  createWishResponse,
  getWishHealth,
  listAdminWishes,
  listPublicWishes,
  getStoredDeliverable,
  recordUploadedDeliverable,
  trackWish,
  WishWorkflowError,
} from "../server/wishes-repository";
import { consumeRateLimit, RateLimitError } from "../server/rate-limit";

interface Env {
  ASSETS: Fetcher;
  DB: D1Database;
  UPLOADS?: R2Bucket;
  ADMIN_API_KEY?: string;
  PUBLIC_APP_ORIGIN?: string;
  RATE_LIMIT_SALT?: string;
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
    "access-control-allow-headers": "content-type, x-admin-key",
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
  const salt = env.RATE_LIMIT_SALT ?? env.ADMIN_API_KEY ?? "haluowode-local";
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
        service: "haluowode-wishes",
        ...(await getWishHealth(env.DB)),
      });
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

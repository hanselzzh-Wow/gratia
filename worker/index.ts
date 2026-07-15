/** Cloudflare Worker entry point for the vinext-starter template. */
import { handleImageOptimization, DEFAULT_DEVICE_SIZES, DEFAULT_IMAGE_SIZES } from "vinext/server/image-optimization";
import handler from "vinext/server/app-router-entry";
import { WishInputError, normalizeAdminAction, normalizeCreateWish } from "../lib/wishes-validation";
import {
  applyAdminWishAction,
  createWish,
  getWishHealth,
  listAdminWishes,
  listPublicWishes,
  WishWorkflowError,
} from "../server/wishes-repository";

interface Env {
  ASSETS: Fetcher;
  DB: D1Database;
  ADMIN_API_KEY?: string;
  PUBLIC_APP_ORIGIN?: string;
  IMAGES: {
    input(stream: ReadableStream): {
      transform(options: Record<string, unknown>): {
        output(options: { format: string; quality: number }): Promise<{ response(): Response }>;
      };
    };
  };
}

const githubPagesOrigin = "https://hanselzzh-wow.github.io";

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

async function requireAdmin(request: Request, env: Env) {
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
      const contentType = request.headers.get("content-type") ?? "";
      if (!contentType.includes("application/json")) {
        return json(request, env, { error: "仅接受 JSON 请求" }, 415);
      }
      const input = normalizeCreateWish(await request.json());
      const result = await createWish(env.DB, input);
      return json(request, env, result, result.created ? 201 : 200);
    }

    if (url.pathname === "/api/admin/wishes" && request.method === "GET") {
      await requireAdmin(request, env);
      const status = url.searchParams.get("status")?.trim() || undefined;
      return json(request, env, { wishes: await listAdminWishes(env.DB, status) });
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

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
  listResponsesForOwner,
  selectResponderForOwner,
  recordResponderDeliverable,
  listConversationMessages,
  sendConversationMessage,
  listMyConversations,
  reportAbuse,
  blockCounterpart,
  unblockCounterpart,
  publishWishStory,
  unpublishWishStory,
  listPublishedStories,
  getOwnProfile,
  submitProfile,
  reviewProfile,
  listPendingProfiles,
  listPendingStories,
  reviewStory,
  listAbuseReports,
  readReportedConversation,
  resolveAbuseReport,
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
import { sendPendingDigest } from "../server/ops-notifier";

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
  /// 待审提醒邮件；两者缺一则静默跳过，不影响任何主流程
  RESEND_API_KEY?: string;
  OPS_NOTIFY_EMAIL?: string;
  OPS_NOTIFY_FROM?: string;
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

    // 头像文件。头像会出现在私聊与公开故事里，因此按公开资源提供，
    // 但键名是随机的，不可枚举。
    const avatarMatch = url.pathname.match(/^\/api\/avatars\/([^/]+)$/);
    if (avatarMatch && request.method === "GET") {
      if (!env.UPLOADS) return json(request, env, { error: "文件存储尚未配置" }, 503);
      const object = await env.UPLOADS.get(decodeURIComponent(avatarMatch[1]));
      if (!object) return json(request, env, { error: "头像不存在" }, 404);
      const headers = new Headers({ "cache-control": "public, max-age=3600" });
      object.writeHttpMetadata(headers);
      return new Response(object.body, { headers });
    }

    // 本人资料：始终返回自己刚提交的版本，并告知是否在审核中
    if (url.pathname === "/api/account/profile" && request.method === "GET") {
      const user = await requireAccount(request, env);
      return json(request, env, await getOwnProfile(env.DB, user.id, url.origin));
    }

    // 提交昵称或头像。提交即进入待审核，他人仍看上一版通过的资料。
    if (url.pathname === "/api/account/profile" && request.method === "POST") {
      const user = await requireAccount(request, env);
      await enforceRateLimit(request, env, "profile_update", 10, 60 * 60_000);
      const contentType = request.headers.get("content-type") ?? "";

      let displayName: string | undefined;
      let avatarKey: string | undefined;
      if (contentType.includes("multipart/form-data")) {
        const form = await request.formData();
        const name = form.get("displayName");
        if (typeof name === "string") displayName = name;
        const file = form.get("avatar");
        if (file instanceof File && file.size > 0) {
          if (!env.UPLOADS) return json(request, env, { error: "文件存储尚未配置" }, 503);
          if (file.size > 5 * 1024 * 1024) {
            return json(request, env, { error: "头像不能超过 5MB" }, 413);
          }
          if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
            return json(request, env, { error: "头像仅支持 JPG、PNG 或 WebP" }, 415);
          }
          avatarKey = `avatars/${crypto.randomUUID()}`;
          await env.UPLOADS.put(avatarKey, file.stream(), { httpMetadata: { contentType: file.type } });
        }
      } else {
        const payload = (await request.json().catch(() => ({}))) as { displayName?: unknown };
        if (typeof payload.displayName === "string") displayName = payload.displayName;
      }

      return json(request, env, await submitProfile(env.DB, user.id, { displayName, avatarKey }, url.origin));
    }

    // 运营审核公开申请。帮助者上传的影像在此之前从未被审核过，
    // 不能让它们未经查看就进入公开故事流。
    if (url.pathname === "/api/admin/stories" && request.method === "GET") {
      await requireAdmin(request, env);
      return json(request, env, await listPendingStories(env.DB));
    }
    const storyReviewMatch = url.pathname.match(/^\/api\/admin\/stories\/([^/]+)$/);
    if (storyReviewMatch && request.method === "PATCH") {
      await requireAdmin(request, env);
      const payload = (await request.json()) as { action?: unknown; note?: unknown };
      return json(
        request,
        env,
        await reviewStory(
          env.DB,
          decodeURIComponent(storyReviewMatch[1]),
          payload.action === "reject" ? "reject" : "approve",
          typeof payload.note === "string" ? payload.note : undefined,
        ),
      );
    }

    // 举报待办与处理。指南 1.2 要求的不只是提供举报入口，还包括对举报作出响应。
    if (url.pathname === "/api/admin/reports" && request.method === "GET") {
      await requireAdmin(request, env);
      return json(request, env, await listAbuseReports(env.DB, url.searchParams.get("status") ?? "open"));
    }
    const reportConversationMatch = url.pathname.match(/^\/api\/admin\/reports\/([^/]+)\/conversation$/);
    if (reportConversationMatch && request.method === "GET") {
      await requireAdmin(request, env);
      return json(request, env, await readReportedConversation(env.DB, decodeURIComponent(reportConversationMatch[1])));
    }
    const reportResolveMatch = url.pathname.match(/^\/api\/admin\/reports\/([^/]+)$/);
    if (reportResolveMatch && request.method === "PATCH") {
      await requireAdmin(request, env);
      const payload = (await request.json()) as { action?: unknown; note?: unknown };
      return json(
        request,
        env,
        await resolveAbuseReport(
          env.DB,
          decodeURIComponent(reportResolveMatch[1]),
          payload.action === "dismiss" ? "dismiss" : "actioned",
          typeof payload.note === "string" ? payload.note : undefined,
        ),
      );
    }

    // 运营审核用户资料
    if (url.pathname === "/api/admin/profiles" && request.method === "GET") {
      await requireAdmin(request, env);
      return json(request, env, await listPendingProfiles(env.DB, url.origin));
    }
    const profileReviewMatch = url.pathname.match(/^\/api\/admin\/profiles\/([^/]+)$/);
    if (profileReviewMatch && request.method === "PATCH") {
      await requireAdmin(request, env);
      const payload = (await request.json()) as { action?: unknown; note?: unknown };
      const action = payload.action === "reject" ? "reject" : "approve";
      return json(
        request,
        env,
        await reviewProfile(
          env.DB,
          decodeURIComponent(profileReviewMatch[1]),
          action,
          typeof payload.note === "string" ? payload.note : undefined,
          url.origin,
        ),
      );
    }

    // 首页故事流：只含需求方明确公开过的已完成心愿，无需登录即可浏览
    if (url.pathname === "/api/stories" && request.method === "GET") {
      return json(request, env, await listPublishedStories(env.DB));
    }

    // 需求方在完成之后单独决定是否公开到首页
    const storyMatch = url.pathname.match(/^\/api\/account\/wishes\/([^/]+)\/story$/);
    if (storyMatch && request.method === "POST") {
      const user = await requireAccount(request, env);
      const payload = (await request.json().catch(() => ({}))) as { nickname?: unknown };
      return json(
        request,
        env,
        await publishWishStory(env.DB, decodeURIComponent(storyMatch[1]), user.id, {
          nickname: typeof payload.nickname === "string" ? payload.nickname : undefined,
        }),
        201,
      );
    }
    if (storyMatch && request.method === "DELETE") {
      const user = await requireAccount(request, env);
      return json(request, env, await unpublishWishStory(env.DB, decodeURIComponent(storyMatch[1]), user.id));
    }

    // 「私聊」标签页：我参与的全部会话（含两种身份）
    if (url.pathname === "/api/account/conversations" && request.method === "GET") {
      const user = await requireAccount(request, env);
      return json(request, env, await listMyConversations(env.DB, user.id, url.origin));
    }

    // 单个会话的消息列表与发送。会话以「心愿 + 一条响应」为单位。
    const conversationMatch = url.pathname.match(/^\/api\/account\/conversations\/([^/]+)\/messages$/);
    if (conversationMatch && request.method === "GET") {
      const user = await requireAccount(request, env);
      return json(request, env, await listConversationMessages(env.DB, decodeURIComponent(conversationMatch[1]), user.id, url.origin));
    }
    if (conversationMatch && request.method === "POST") {
      const user = await requireAccount(request, env);
      if (!(request.headers.get("content-type") ?? "").includes("application/json")) {
        return json(request, env, { error: "仅接受 JSON 请求" }, 415);
      }
      await enforceRateLimit(request, env, "conversation_message", 120, 60 * 60_000);
      const payload = (await request.json()) as { body?: unknown };
      const message = await sendConversationMessage(
        env.DB,
        decodeURIComponent(conversationMatch[1]),
        user.id,
        typeof payload.body === "string" ? payload.body : "",
      );
      return json(request, env, { message }, 201);
    }

    // 举报与拉黑：App 内存在陌生人即时通讯时，指南 1.2 要求必须提供
    if (url.pathname === "/api/account/reports" && request.method === "POST") {
      const user = await requireAccount(request, env);
      await enforceRateLimit(request, env, "abuse_report", 20, 24 * 60 * 60_000);
      const payload = (await request.json()) as Record<string, unknown>;
      const result = await reportAbuse(env.DB, user.id, {
        responseId: typeof payload.responseId === "string" ? payload.responseId : undefined,
        wishId: typeof payload.wishId === "string" ? payload.wishId : undefined,
        reason: typeof payload.reason === "string" ? payload.reason : "",
        detail: typeof payload.detail === "string" ? payload.detail : undefined,
      });
      return json(request, env, result, 201);
    }

    const blockMatch = url.pathname.match(/^\/api\/account\/conversations\/([^/]+)\/block$/);
    if (blockMatch && request.method === "POST") {
      const user = await requireAccount(request, env);
      return json(request, env, await blockCounterpart(env.DB, decodeURIComponent(blockMatch[1]), user.id), 201);
    }
    // 取消屏蔽。用 DELETE 而不是另开一个路径：它撤销的正是上面那次 POST。
    if (blockMatch && request.method === "DELETE") {
      const user = await requireAccount(request, env);
      return json(request, env, await unblockCounterpart(env.DB, decodeURIComponent(blockMatch[1]), user.id));
    }

    // 发布者查看本人心愿收到的响应（不含响应者联系方式）
    const ownerResponsesMatch = url.pathname.match(/^\/api\/account\/wishes\/([^/]+)\/responses$/);
    if (ownerResponsesMatch && request.method === "GET") {
      const user = await requireAccount(request, env);
      return json(request, env, await listResponsesForOwner(env.DB, decodeURIComponent(ownerResponsesMatch[1]), user.id));
    }

    // 发布者选定一位帮助者，心愿进入进行中，后续交付无需运营介入
    const selectResponderMatch = url.pathname.match(
      /^\/api\/account\/wishes\/([^/]+)\/responses\/([^/]+)\/select$/,
    );
    if (selectResponderMatch && request.method === "POST") {
      const user = await requireAccount(request, env);
      await enforceRateLimit(request, env, "account_select_responder", 30, 60 * 60_000);
      const wish = await selectResponderForOwner(
        env.DB,
        decodeURIComponent(selectResponderMatch[1]),
        decodeURIComponent(selectResponderMatch[2]),
        user.id,
      );
      return json(request, env, { wish });
    }

    // 被选中的帮助者直接上传交付。授权依据是账号会话而非运营密钥。
    const responderUploadMatch = url.pathname.match(/^\/api\/account\/wishes\/([^/]+)\/deliverable$/);
    if (responderUploadMatch && request.method === "POST") {
      const user = await requireAccount(request, env);
      if (!env.UPLOADS) return json(request, env, { error: "文件存储尚未配置" }, 503);
      await enforceRateLimit(request, env, "responder_upload", 20, 60 * 60_000);
      const form = await request.formData();
      // 一次「完成帮助」可含一段文字与最多 9 个图片/视频
      const files = form.getAll("file").filter((item): item is File => item instanceof File && item.size > 0);
      if (files.length === 0) {
        return json(request, env, { error: "请选择要交付的照片或视频" }, 400);
      }
      if (files.length > 9) {
        return json(request, env, { error: "一次最多上传 9 个文件" }, 400);
      }
      for (const file of files) {
        if (file.size > maxUploadBytes) {
          return json(request, env, { error: "单个文件不能超过 25MB" }, 413);
        }
        if (!allowedUploadTypes.has(file.type)) {
          return json(request, env, { error: "仅支持 JPG、PNG、WebP、MP4、WebM 或 MOV" }, 415);
        }
      }

      const wishId = decodeURIComponent(responderUploadMatch[1]);
      const stored: { deliverableId: string; storageKey: string; accessToken: string; url: string }[] = [];
      try {
        for (const file of files) {
          const deliverableId = crypto.randomUUID();
          const accessToken = crypto.randomUUID().replace(/-/g, "");
          const storageKey = `deliveries/${wishId}/${deliverableId}-${safeFilename(file.name)}`;
          await env.UPLOADS.put(storageKey, file.stream(), { httpMetadata: { contentType: file.type } });
          // 绝对地址。交付链接会被 iOS 与运营台取用，两者都不同源；
          // 运营台上传那条路径（本文件下方）一直是对的，这里之前漏了。
          const deliverableUrl = new URL(`/api/deliverables/${deliverableId}`, request.url);
          deliverableUrl.searchParams.set("token", accessToken);
          stored.push({
            deliverableId,
            storageKey,
            accessToken,
            url: deliverableUrl.toString(),
          });
        }
        const wish = await recordResponderDeliverable(env.DB, wishId, user.id, {
          note: typeof form.get("note") === "string" ? String(form.get("note")).slice(0, 500) : undefined,
          files: stored,
        });
        return json(request, env, { wish }, 201);
      } catch (error) {
        // 任何一步失败都不要在 R2 里留下孤儿文件
        await Promise.all(stored.map((item) => env.UPLOADS!.delete(item.storageKey).catch(() => {})));
        throw error;
      }
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

  /// 定时检查运营台待审队列，有变化就发一封提醒邮件。
  /// 放在 Cron 而不是发布请求里：发心愿的人不该为发信等待，
  /// 而且有人连发几条时逐条推送会把邮箱淹掉。
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(
      sendPendingDigest(env.DB, {
        apiKey: env.RESEND_API_KEY,
        to: env.OPS_NOTIFY_EMAIL,
        from: env.OPS_NOTIFY_FROM,
        opsUrl: `${env.PUBLIC_APP_ORIGIN ?? "https://hanselzzh-wow.github.io"}/ops/`,
      }).then((result) => {
        console.log(`[ops-notify] ${result.reason}`, result.summary);
      }),
    );
  },
};

export default worker;

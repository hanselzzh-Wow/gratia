import { WishWorkflowError } from "./wishes-repository";

export interface AppleAuthConfig {
  bundleId: string;
  teamId?: string;
  keyId?: string;
  privateKey?: string;
}

export interface AppleIdentity {
  subject: string;
  refreshToken: string | null;
}

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys";
const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";
const CLIENT_SECRET_TTL_SECONDS = 15 * 60;

type JsonWebKey = { kid?: string; kty?: string; n?: string; e?: string; alg?: string };

function base64UrlToBytes(value: string) {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function bytesToBase64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function decodeJwtSegment(segment: string) {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(segment))) as Record<string, unknown>;
}

export async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function fetchApplePublicKey(kid: string, fetchImpl: typeof fetch) {
  const response = await fetchImpl(APPLE_KEYS_URL, { headers: { accept: "application/json" } });
  if (!response.ok) throw new WishWorkflowError("Apple 登录服务暂时不可用，请稍后重试", 502);
  const payload = (await response.json()) as { keys?: JsonWebKey[] };
  const key = payload.keys?.find((candidate) => candidate.kid === kid);
  if (!key || key.kty !== "RSA" || !key.n || !key.e) {
    throw new WishWorkflowError("Apple 登录凭证无法验证，请重新尝试", 401);
  }
  return crypto.subtle.importKey(
    "jwk",
    { kty: "RSA", n: key.n, e: key.e, alg: "RS256", ext: true },
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
}

/**
 * 校验 Sign in with Apple 的 identity token。只使用 Apple 的公开 JWKS，
 * 不需要开发者私钥，因此在开发者账号密钥就绪前登录也能工作。
 */
export async function verifyAppleIdentityToken(
  identityToken: string,
  config: AppleAuthConfig,
  options: { rawNonce?: string; now?: number; fetchImpl?: typeof fetch } = {},
) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const now = options.now ?? Date.now();
  const segments = identityToken.split(".");
  if (segments.length !== 3) throw new WishWorkflowError("Apple 登录凭证无效，请重新尝试", 400);

  let header: Record<string, unknown>;
  let claims: Record<string, unknown>;
  try {
    header = decodeJwtSegment(segments[0]);
    claims = decodeJwtSegment(segments[1]);
  } catch {
    throw new WishWorkflowError("Apple 登录凭证无效，请重新尝试", 400);
  }

  if (header.alg !== "RS256" || typeof header.kid !== "string") {
    throw new WishWorkflowError("Apple 登录凭证无效，请重新尝试", 400);
  }

  const key = await fetchApplePublicKey(header.kid, fetchImpl);
  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    base64UrlToBytes(segments[2]),
    new TextEncoder().encode(`${segments[0]}.${segments[1]}`),
  );
  if (!verified) throw new WishWorkflowError("Apple 登录凭证无法验证，请重新尝试", 401);

  if (claims.iss !== APPLE_ISSUER) throw new WishWorkflowError("Apple 登录凭证来源不正确", 401);

  const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!audience.includes(config.bundleId)) {
    throw new WishWorkflowError("Apple 登录凭证不属于本应用", 401);
  }

  const expiresAt = typeof claims.exp === "number" ? claims.exp * 1000 : 0;
  if (expiresAt <= now) throw new WishWorkflowError("Apple 登录凭证已过期，请重新登录", 401);

  if (options.rawNonce) {
    const expected = await sha256Hex(options.rawNonce);
    if (claims.nonce !== expected) {
      throw new WishWorkflowError("Apple 登录校验失败，请重新登录", 401);
    }
  }

  const subject = typeof claims.sub === "string" ? claims.sub.trim() : "";
  if (!subject) throw new WishWorkflowError("Apple 登录凭证缺少用户标识", 401);
  return subject;
}

function hasRevocationCredentials(config: AppleAuthConfig) {
  return Boolean(config.teamId && config.keyId && config.privateKey);
}

async function importApplePrivateKey(privateKey: string) {
  const body = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replaceAll(/\s+/g, "");
  return crypto.subtle.importKey(
    "pkcs8",
    base64UrlToBytes(body.replaceAll("+", "-").replaceAll("/", "_")),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}

/**
 * 生成调用 Apple 令牌接口所需的 client_secret（ES256 JWT）。
 * 私钥只存在于 Worker 私密环境变量，不进入客户端、日志或响应。
 */
export async function createAppleClientSecret(config: AppleAuthConfig, now = Date.now()) {
  if (!hasRevocationCredentials(config)) return null;
  const issuedAt = Math.floor(now / 1000);
  const header = { alg: "ES256", kid: config.keyId };
  const payload = {
    iss: config.teamId,
    iat: issuedAt,
    exp: issuedAt + CLIENT_SECRET_TTL_SECONDS,
    aud: APPLE_ISSUER,
    sub: config.bundleId,
  };
  const encoder = new TextEncoder();
  const signingInput = `${bytesToBase64Url(encoder.encode(JSON.stringify(header)))}.${bytesToBase64Url(
    encoder.encode(JSON.stringify(payload)),
  )}`;
  const key = await importApplePrivateKey(config.privateKey!);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput),
  );
  return `${signingInput}.${bytesToBase64Url(new Uint8Array(signature))}`;
}

/**
 * 用登录时拿到的 authorizationCode 换取 refresh token。
 * 只有配置了 Apple 私钥时才会执行；换不到不阻断登录，只是注销时无法撤销令牌。
 */
export async function exchangeAppleAuthorizationCode(
  authorizationCode: string,
  config: AppleAuthConfig,
  options: { now?: number; fetchImpl?: typeof fetch } = {},
) {
  const clientSecret = await createAppleClientSecret(config, options.now);
  if (!clientSecret) return null;
  const fetchImpl = options.fetchImpl ?? fetch;
  const response = await fetchImpl(APPLE_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/json" },
    body: new URLSearchParams({
      client_id: config.bundleId,
      client_secret: clientSecret,
      code: authorizationCode,
      grant_type: "authorization_code",
    }).toString(),
  });
  if (!response.ok) return null;
  const payload = (await response.json()) as { refresh_token?: unknown };
  return typeof payload.refresh_token === "string" && payload.refresh_token ? payload.refresh_token : null;
}

/**
 * Apple 要求应用在用户删除账户时撤销其登录令牌。
 * 撤销失败不阻断账户删除，由调用方记录降级结果。
 */
export async function revokeAppleRefreshToken(
  refreshToken: string,
  config: AppleAuthConfig,
  options: { now?: number; fetchImpl?: typeof fetch } = {},
) {
  const clientSecret = await createAppleClientSecret(config, options.now);
  if (!clientSecret) return false;
  const fetchImpl = options.fetchImpl ?? fetch;
  try {
    const response = await fetchImpl(APPLE_REVOKE_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: config.bundleId,
        client_secret: clientSecret,
        token: refreshToken,
        token_type_hint: "refresh_token",
      }).toString(),
    });
    return response.ok;
  } catch {
    return false;
  }
}

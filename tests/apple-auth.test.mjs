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
      meta: { changes: Number(result.changes ?? 0), last_row_id: Number(result.lastInsertRowid ?? 0) },
    };
  }

  async all() {
    return { success: true, results: this.database.prepare(this.sql).all(...this.values), meta: { changes: 0 } };
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

const BUNDLE_ID = "com.hanselzzh.gratia";
const encoder = new TextEncoder();

function base64Url(bytes) {
  return Buffer.from(bytes).toString("base64url");
}

async function sha256Hex(value) {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function createSigningKeys() {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  return { privateKey: pair.privateKey, jwk: { ...jwk, kid: "test-key", alg: "RS256", use: "sig" } };
}

async function createApplePrivateKeyPem() {
  const pair = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  const pkcs8 = await crypto.subtle.exportKey("pkcs8", pair.privateKey);
  const body = Buffer.from(pkcs8).toString("base64").replace(/(.{64})/g, "$1\n");
  return `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----`;
}

async function signIdentityToken(privateKey, claims, { kid = "test-key", alg = "RS256" } = {}) {
  const header = base64Url(encoder.encode(JSON.stringify({ alg, kid })));
  const payload = base64Url(encoder.encode(JSON.stringify(claims)));
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encoder.encode(`${header}.${payload}`),
  );
  return `${header}.${payload}.${base64Url(new Uint8Array(signature))}`;
}

function defaultClaims(overrides = {}) {
  const nowSeconds = Math.floor(Date.now() / 1000);
  return {
    iss: "https://appleid.apple.com",
    aud: BUNDLE_ID,
    sub: "001234.apple-subject.5678",
    iat: nowSeconds,
    exp: nowSeconds + 600,
    ...overrides,
  };
}

async function setup() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("apple-test", `${process.pid}-${Date.now()}-${Math.random()}`);
  const { default: worker } = await import(workerUrl.href);
  const database = new TestD1();
  const env = {
    DB: database,
    ADMIN_API_KEY: "test-admin-pin",
    APPLE_BUNDLE_ID: BUNDLE_ID,
    ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) },
  };
  const ctx = { waitUntil() {}, passThroughOnException() {} };

  async function request(path, init = {}) {
    return worker.fetch(new Request(`http://localhost${path}`, init), env, ctx);
  }

  return { request, database, env };
}

function installAppleFetch(jwk, { onToken, onRevoke } = {}) {
  const original = globalThis.fetch;
  const calls = { keys: 0, token: 0, revoke: 0, revokedTokens: [] };
  globalThis.fetch = async (url, init = {}) => {
    const parsed = new URL(String(url));
    assert.equal(parsed.hostname, "appleid.apple.com");
    if (parsed.pathname === "/auth/keys") {
      calls.keys += 1;
      return Response.json({ keys: [jwk] });
    }
    if (parsed.pathname === "/auth/token") {
      calls.token += 1;
      const body = new URLSearchParams(init.body ?? "");
      onToken?.(body);
      return Response.json({ refresh_token: "apple-refresh-token" });
    }
    if (parsed.pathname === "/auth/revoke") {
      calls.revoke += 1;
      const body = new URLSearchParams(init.body ?? "");
      calls.revokedTokens.push(body.get("token"));
      onRevoke?.(body);
      return new Response(null, { status: 200 });
    }
    throw new Error(`unexpected Apple endpoint: ${parsed.pathname}`);
  };
  return { calls, restore: () => { globalThis.fetch = original; } };
}

async function loginWithApple(request, identityToken, extra = {}) {
  return request("/api/auth/apple", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ identityToken, ...extra }),
  });
}

test("signs in with a valid Apple identity token and reuses the same account", async () => {
  const { request, database } = await setup();
  const { privateKey, jwk } = await createSigningKeys();
  const apple = installAppleFetch(jwk);

  try {
    const token = await signIdentityToken(privateKey, defaultClaims());

    const first = await loginWithApple(request, token);
    assert.equal(first.status, 201);
    const firstBody = await first.json();
    assert.ok(firstBody.token.length >= 32);
    assert.ok(firstBody.expiresAt > Date.now());
    assert.ok(firstBody.user.id);

    const second = await loginWithApple(request, await signIdentityToken(privateKey, defaultClaims()));
    assert.equal(second.status, 201);
    const secondBody = await second.json();
    assert.equal(secondBody.user.id, firstBody.user.id, "同一 Apple sub 必须复用同一账户");
    assert.notEqual(secondBody.token, firstBody.token, "每次登录签发独立会话");

    const identities = database.database.prepare("SELECT provider, provider_subject FROM account_identities").all();
    assert.equal(identities.length, 1);
    assert.equal(identities[0].provider, "apple");
    assert.equal(identities[0].provider_subject, "001234.apple-subject.5678");

    const me = await request("/api/me", { headers: { authorization: `Bearer ${firstBody.token}` } });
    assert.equal(me.status, 200);
    assert.equal((await me.json()).user.id, firstBody.user.id);
  } finally {
    apple.restore();
  }
});

test("rejects Apple identity tokens that fail issuer, audience, expiry, nonce, or signature checks", async () => {
  const { request } = await setup();
  const { privateKey, jwk } = await createSigningKeys();
  const other = await createSigningKeys();
  const apple = installAppleFetch(jwk);

  try {
    const wrongAudience = await loginWithApple(
      request,
      await signIdentityToken(privateKey, defaultClaims({ aud: "com.someone.else" })),
    );
    assert.equal(wrongAudience.status, 401);

    const wrongIssuer = await loginWithApple(
      request,
      await signIdentityToken(privateKey, defaultClaims({ iss: "https://evil.example" })),
    );
    assert.equal(wrongIssuer.status, 401);

    const expired = await loginWithApple(
      request,
      await signIdentityToken(privateKey, defaultClaims({ exp: Math.floor(Date.now() / 1000) - 60 })),
    );
    assert.equal(expired.status, 401);

    const forged = await loginWithApple(request, await signIdentityToken(other.privateKey, defaultClaims()));
    assert.equal(forged.status, 401, "用非 Apple 公钥签发的令牌必须被拒绝");

    const nonceMismatch = await loginWithApple(
      request,
      await signIdentityToken(privateKey, defaultClaims({ nonce: await sha256Hex("other-nonce") })),
      { rawNonce: "expected-nonce" },
    );
    assert.equal(nonceMismatch.status, 401, "nonce 不匹配必须被拒绝，防止重放");

    const malformed = await loginWithApple(request, "not-a-jwt");
    assert.equal(malformed.status, 400);

    const missingSub = await loginWithApple(
      request,
      await signIdentityToken(privateKey, defaultClaims({ sub: "" })),
    );
    assert.equal(missingSub.status, 401);
  } finally {
    apple.restore();
  }
});

test("accepts a matching hashed nonce", async () => {
  const { request } = await setup();
  const { privateKey, jwk } = await createSigningKeys();
  const apple = installAppleFetch(jwk);

  try {
    const rawNonce = "gratia-raw-nonce-value";
    const response = await loginWithApple(
      request,
      await signIdentityToken(privateKey, defaultClaims({ nonce: await sha256Hex(rawNonce) })),
      { rawNonce },
    );
    assert.equal(response.status, 201);
  } finally {
    apple.restore();
  }
});

test("signs in without Apple private key configured but skips token revocation on deletion", async () => {
  const { request, database } = await setup();
  const { privateKey, jwk } = await createSigningKeys();
  const apple = installAppleFetch(jwk);

  try {
    const login = await loginWithApple(request, await signIdentityToken(privateKey, defaultClaims()), {
      authorizationCode: "apple-auth-code",
    });
    assert.equal(login.status, 201, "没有 .p8 密钥时登录仍必须可用");
    assert.equal(apple.calls.token, 0, "没有密钥时不得尝试兑换 refresh token");

    const stored = database.database.prepare("SELECT refresh_token FROM account_identities").get();
    assert.equal(stored.refresh_token, null);

    const token = (await login.json()).token;
    const deleted = await request("/api/me", { method: "DELETE", headers: { authorization: `Bearer ${token}` } });
    assert.equal(deleted.status, 200);
    assert.equal(apple.calls.revoke, 0);

    const after = await request("/api/me", { headers: { authorization: `Bearer ${token}` } });
    assert.equal(after.status, 401, "注销后会话必须立即失效");
  } finally {
    apple.restore();
  }
});

test("exchanges the authorization code and revokes Apple tokens when the account is deleted", async () => {
  const { request, database, env } = await setup();
  env.APPLE_TEAM_ID = "TEAMID1234";
  env.APPLE_KEY_ID = "KEYID56789";
  env.APPLE_PRIVATE_KEY = await createApplePrivateKeyPem();

  const { privateKey, jwk } = await createSigningKeys();
  let tokenRequest = null;
  const apple = installAppleFetch(jwk, { onToken: (body) => { tokenRequest = body; } });

  try {
    const login = await loginWithApple(request, await signIdentityToken(privateKey, defaultClaims()), {
      authorizationCode: "apple-auth-code",
    });
    assert.equal(login.status, 201);
    assert.equal(apple.calls.token, 1);
    assert.equal(tokenRequest.get("grant_type"), "authorization_code");
    assert.equal(tokenRequest.get("client_id"), BUNDLE_ID);
    assert.equal(tokenRequest.get("code"), "apple-auth-code");
    assert.equal(tokenRequest.get("client_secret").split(".").length, 3, "client_secret 必须是 ES256 JWT");

    const stored = database.database.prepare("SELECT refresh_token FROM account_identities").get();
    assert.equal(stored.refresh_token, "apple-refresh-token");

    const token = (await login.json()).token;
    const deleted = await request("/api/me", { method: "DELETE", headers: { authorization: `Bearer ${token}` } });
    assert.equal(deleted.status, 200);
    const deletedBody = await deleted.json();
    assert.equal(deletedBody.appleTokensRevoked, true);
    assert.equal(apple.calls.revoke, 1);
    assert.deepEqual(apple.calls.revokedTokens, ["apple-refresh-token"]);

    const remaining = database.database.prepare("SELECT refresh_token, deleted_at FROM account_identities").get();
    assert.equal(remaining.refresh_token, null, "注销后不得继续保存 Apple refresh token");
    assert.ok(remaining.deleted_at > 0);
  } finally {
    apple.restore();
  }
});

test("still deletes the account when Apple token revocation fails", async () => {
  const { request, env } = await setup();
  env.APPLE_TEAM_ID = "TEAMID1234";
  env.APPLE_KEY_ID = "KEYID56789";
  env.APPLE_PRIVATE_KEY = await createApplePrivateKeyPem();

  const { privateKey, jwk } = await createSigningKeys();
  const original = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const parsed = new URL(String(url));
    if (parsed.pathname === "/auth/keys") return Response.json({ keys: [jwk] });
    if (parsed.pathname === "/auth/token") return Response.json({ refresh_token: "apple-refresh-token" });
    if (parsed.pathname === "/auth/revoke") return new Response("upstream down", { status: 503 });
    throw new Error(`unexpected Apple endpoint: ${parsed.pathname}`);
  };

  try {
    const login = await loginWithApple(request, await signIdentityToken(privateKey, defaultClaims()), {
      authorizationCode: "apple-auth-code",
    });
    const token = (await login.json()).token;

    const deleted = await request("/api/me", { method: "DELETE", headers: { authorization: `Bearer ${token}` } });
    assert.equal(deleted.status, 200, "Apple 撤销失败不得阻断用户注销");
    assert.equal((await deleted.json()).appleTokensRevoked, false);

    const after = await request("/api/me", { headers: { authorization: `Bearer ${token}` } });
    assert.equal(after.status, 401);
  } finally {
    globalThis.fetch = original;
  }
});

test("keeps Apple and WeChat identities on separate accounts", async () => {
  const { request, database, env } = await setup();
  env.WECHAT_MINI_PROGRAM_APP_ID = "test-app-id";
  env.WECHAT_MINI_PROGRAM_APP_SECRET = "test-app-secret";

  const { privateKey, jwk } = await createSigningKeys();
  const original = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const parsed = new URL(String(url));
    if (parsed.hostname === "api.weixin.qq.com") return Response.json({ openid: "wechat-openid" });
    if (parsed.pathname === "/auth/keys") return Response.json({ keys: [jwk] });
    throw new Error(`unexpected endpoint: ${url}`);
  };

  try {
    const appleLogin = await loginWithApple(request, await signIdentityToken(privateKey, defaultClaims()));
    const wechatLogin = await request("/api/auth/wechat", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ code: "wechat-code" }),
    });
    assert.equal(wechatLogin.status, 201);

    const appleUser = (await appleLogin.json()).user.id;
    const wechatUser = (await wechatLogin.json()).user.id;
    assert.notEqual(appleUser, wechatUser, "不同 provider 的身份默认是不同账户");

    const providers = database.database
      .prepare("SELECT provider FROM account_identities ORDER BY provider")
      .all()
      .map((row) => row.provider);
    assert.deepEqual(providers, ["apple", "wechat"]);
  } finally {
    globalThis.fetch = original;
  }
});

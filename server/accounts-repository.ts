import { ensureWishSchema } from "../db/runtime";
import { WishWorkflowError } from "./wishes-repository";

export interface AccountUser {
  id: string;
  createdAt: number;
}

type UserRow = {
  id: string;
  created_at: number;
  deleted_at: number | null;
};

type IdentityRow = {
  id: string;
  user_id: string;
};

async function hashToken(token: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function newToken() {
  return `${crypto.randomUUID().replaceAll("-", "")}${crypto.randomUUID().replaceAll("-", "")}`;
}

function toAccountUser(row: UserRow): AccountUser {
  return { id: row.id, createdAt: row.created_at };
}

export type AccountProvider = "wechat" | "apple";

/**
 * 按 provider + subject 建立或复用账户，并签发本服务会话。
 * 账户层与登录方式解耦：微信、Apple 以及未来的 provider 共用同一套 users/订单归属。
 */
export async function createProviderSession(
  db: D1Database,
  provider: AccountProvider,
  subject: string,
  refreshToken: string | null = null,
) {
  await ensureWishSchema(db);
  const now = Date.now();
  let identity = await db
    .prepare(
      "SELECT id, user_id FROM account_identities WHERE provider = ? AND provider_subject = ? AND deleted_at IS NULL LIMIT 1",
    )
    .bind(provider, subject)
    .first<IdentityRow>();

  let user: UserRow | null = null;
  if (identity) {
    user = await db.prepare("SELECT id, created_at, deleted_at FROM users WHERE id = ? LIMIT 1").bind(identity.user_id).first<UserRow>();
  }

  if (!user || user.deleted_at !== null) {
    const userId = crypto.randomUUID();
    const identityId = crypto.randomUUID();
    user = { id: userId, created_at: now, deleted_at: null };
    identity = { id: identityId, user_id: userId };
    await db.batch([
      db.prepare("INSERT INTO users (id, created_at) VALUES (?, ?)").bind(userId, now),
      db
        .prepare(
          "INSERT INTO account_identities (id, user_id, provider, provider_subject, refresh_token, created_at) VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(identityId, userId, provider, subject, refreshToken, now),
    ]);
  } else if (refreshToken) {
    await db
      .prepare("UPDATE account_identities SET refresh_token = ? WHERE id = ?")
      .bind(refreshToken, identity!.id)
      .run();
  }

  const token = newToken();
  const tokenHash = await hashToken(token);
  const expiresAt = now + 30 * 24 * 60 * 60_000;
  await db
    .prepare(
      "INSERT INTO account_sessions (id, user_id, token_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?)",
    )
    .bind(crypto.randomUUID(), user.id, tokenHash, expiresAt, now)
    .run();

  return { token, expiresAt, user: toAccountUser(user) };
}

export function createWechatSession(db: D1Database, openId: string) {
  return createProviderSession(db, "wechat", openId);
}

export function createAppleSession(db: D1Database, subject: string, refreshToken: string | null = null) {
  return createProviderSession(db, "apple", subject, refreshToken);
}

export async function getAuthenticatedUser(db: D1Database, token: string) {
  await ensureWishSchema(db);
  if (!token || token.length < 32) throw new WishWorkflowError("请先登录后再操作", 401);
  const tokenHash = await hashToken(token);
  const now = Date.now();
  const row = await db
    .prepare(
      `SELECT u.id, u.created_at, u.deleted_at
       FROM account_sessions s
       JOIN users u ON u.id = s.user_id
       WHERE s.token_hash = ? AND s.expires_at > ? AND s.revoked_at IS NULL AND u.deleted_at IS NULL
       LIMIT 1`,
    )
    .bind(tokenHash, now)
    .first<UserRow>();
  if (!row) throw new WishWorkflowError("登录已失效，请重新登录", 401);
  return toAccountUser(row);
}

export async function deleteAuthenticatedAccount(db: D1Database, userId: string) {
  await ensureWishSchema(db);
  const now = Date.now();
  const current = await db
    .prepare("SELECT id, created_at, deleted_at FROM users WHERE id = ? LIMIT 1")
    .bind(userId)
    .first<UserRow>();
  if (!current || current.deleted_at !== null) throw new WishWorkflowError("账户不存在或已删除", 404);

  const revocable = await db
    .prepare(
      "SELECT provider, refresh_token FROM account_identities WHERE user_id = ? AND deleted_at IS NULL AND refresh_token IS NOT NULL",
    )
    .bind(userId)
    .all<{ provider: string; refresh_token: string }>();

  await db.batch([
    db.prepare("UPDATE users SET deleted_at = ? WHERE id = ? AND deleted_at IS NULL").bind(now, userId),
    db
      .prepare(
        "UPDATE account_identities SET provider_subject = 'deleted:' || id, refresh_token = NULL, deleted_at = ? WHERE user_id = ? AND deleted_at IS NULL",
      )
      .bind(now, userId),
    db.prepare("UPDATE account_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL").bind(now, userId),
    db
      .prepare(
        "UPDATE wishes SET requester_name = '已注销用户', contact = 'deleted:' || id, updated_at = ? WHERE user_id = ?",
      )
      .bind(now, userId),
    db
      .prepare(
        "UPDATE wish_responses SET responder_name = '已注销用户', responder_contact = 'deleted:' || id, updated_at = ? WHERE user_id = ?",
      )
      .bind(now, userId),
    // 设备令牌是硬删除，不是匿名化：它唯一标识一台设备，留着既无审计价值，
    // 也不符合 5.1.1(v) 对「删除账户即删除关联数据」的要求。别的行保留是因为
    // 履约与审计需要，这一行不需要。
    db.prepare("DELETE FROM device_tokens WHERE user_id = ?").bind(userId),
  ]);

  return {
    deletedAt: now,
    revokedIdentities: revocable.results.map((row) => ({
      provider: row.provider,
      refreshToken: row.refresh_token,
    })),
  };
}

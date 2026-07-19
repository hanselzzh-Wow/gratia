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

export async function createWechatSession(db: D1Database, openId: string) {
  await ensureWishSchema(db);
  const now = Date.now();
  let identity = await db
    .prepare(
      "SELECT id, user_id FROM account_identities WHERE provider = 'wechat' AND provider_subject = ? AND deleted_at IS NULL LIMIT 1",
    )
    .bind(openId)
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
          "INSERT INTO account_identities (id, user_id, provider, provider_subject, created_at) VALUES (?, ?, 'wechat', ?, ?)",
        )
        .bind(identityId, userId, openId, now),
    ]);
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

export async function getAuthenticatedUser(db: D1Database, token: string) {
  await ensureWishSchema(db);
  if (!token || token.length < 32) throw new WishWorkflowError("请先登录微信账号", 401);
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

  await db.batch([
    db.prepare("UPDATE users SET deleted_at = ? WHERE id = ? AND deleted_at IS NULL").bind(now, userId),
    db
      .prepare(
        "UPDATE account_identities SET provider_subject = 'deleted:' || id, deleted_at = ? WHERE user_id = ? AND deleted_at IS NULL",
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
  ]);
  return { deletedAt: now };
}

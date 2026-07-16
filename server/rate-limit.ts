import { ensureWishSchema } from "../db/runtime";

export class RateLimitError extends Error {
  retryAfterSeconds: number;

  constructor(retryAfterSeconds: number) {
    super("请求过于频繁，请稍后再试");
    this.name = "RateLimitError";
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

export async function consumeRateLimit(
  db: D1Database,
  fingerprint: string,
  action: string,
  limit: number,
  windowMs: number,
) {
  await ensureWishSchema(db);
  const now = Date.now();
  const cutoff = now - windowMs;
  const row = await db
    .prepare(
      `INSERT INTO rate_limits (fingerprint, action, window_start, count, updated_at)
       VALUES (?, ?, ?, 1, ?)
       ON CONFLICT(fingerprint, action) DO UPDATE SET
         count = CASE WHEN rate_limits.window_start < ? THEN 1 ELSE rate_limits.count + 1 END,
         window_start = CASE WHEN rate_limits.window_start < ? THEN excluded.window_start ELSE rate_limits.window_start END,
         updated_at = excluded.updated_at
       RETURNING count, window_start`,
    )
    .bind(fingerprint, action, now, now, cutoff, cutoff)
    .first<{ count: number; window_start: number }>();

  const count = Number(row?.count ?? 1);
  const windowStart = Number(row?.window_start ?? now);
  if (count > limit) {
    const retryAfterSeconds = Math.max(1, Math.ceil((windowStart + windowMs - now) / 1000));
    throw new RateLimitError(retryAfterSeconds);
  }
}

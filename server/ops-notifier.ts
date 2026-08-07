/**
 * 待审内容的邮件提醒。
 *
 * 由 Cron 定时触发，不在发布的请求路径上——发心愿的人不该为发信等待，
 * 而且有人连发几条时逐条推送会把邮箱淹掉。
 *
 * **只在"待审集合发生变化"时才发信**：把当前待审内容算成一个指纹存进
 * D1，与上次相同就跳过。否则每 15 分钟就会为同一批东西重复提醒一次，
 * 提醒多了就等于没有提醒。
 *
 * 没配 `RESEND_API_KEY` / `OPS_NOTIFY_EMAIL` 时静默跳过，不报错也不阻断任何流程。
 */

export interface PendingSummary {
  wishes: number;
  profiles: number;
  stories: number;
  reports: number;
}

export interface NotifierConfig {
  apiKey?: string;
  to?: string;
  from?: string;
  opsUrl: string;
}

const STATE_KEY = "ops_pending_digest";

export function hasNotifierCredentials(config: NotifierConfig) {
  return Boolean(config.apiKey && config.to);
}

/** 统计四类待审内容。全部走 COUNT，不读取任何用户正文。 */
export async function countPending(db: D1Database): Promise<PendingSummary> {
  const one = async (sql: string) => {
    const row = await db.prepare(sql).first<{ n: number }>();
    return Number(row?.n ?? 0);
  };
  return {
    wishes: await one("SELECT COUNT(*) AS n FROM wishes WHERE status = 'pending_review'"),
    profiles: await one("SELECT COUNT(*) AS n FROM users WHERE profile_status = 'pending'"),
    stories: await one("SELECT COUNT(*) AS n FROM wishes WHERE story_status = 'pending'"),
    reports: await one("SELECT COUNT(*) AS n FROM abuse_reports WHERE status = 'open'"),
  };
}

export function totalPending(summary: PendingSummary) {
  return summary.wishes + summary.profiles + summary.stories + summary.reports;
}

async function ensureStateTable(db: D1Database) {
  await db
    .prepare(
      `CREATE TABLE IF NOT EXISTS ops_notify_state (
         key TEXT PRIMARY KEY,
         signature TEXT NOT NULL,
         sent_at INTEGER NOT NULL
       )`,
    )
    .run();
}

/**
 * 发送待审提醒。返回实际做了什么，便于 Cron 日志与测试断言。
 */
export async function sendPendingDigest(
  db: D1Database,
  config: NotifierConfig,
  options: { now?: number; fetchImpl?: typeof fetch } = {},
): Promise<{ sent: boolean; reason: string; summary: PendingSummary }> {
  const summary = await countPending(db);
  const total = totalPending(summary);

  if (!hasNotifierCredentials(config)) {
    return { sent: false, reason: "未配置邮件密钥", summary };
  }
  if (total === 0) {
    // 队列清空时把指纹一并清掉，这样下次再有新内容会重新提醒。
    await ensureStateTable(db);
    await db.prepare("DELETE FROM ops_notify_state WHERE key = ?").bind(STATE_KEY).run();
    return { sent: false, reason: "没有待审内容", summary };
  }

  const signature = `${summary.wishes}-${summary.profiles}-${summary.stories}-${summary.reports}`;
  await ensureStateTable(db);
  const previous = await db
    .prepare("SELECT signature FROM ops_notify_state WHERE key = ?")
    .bind(STATE_KEY)
    .first<{ signature: string }>();
  if (previous?.signature === signature) {
    return { sent: false, reason: "与上次提醒内容相同", summary };
  }

  const lines = [
    summary.wishes ? `· 心愿正文 ${summary.wishes} 条` : null,
    summary.profiles ? `· 昵称与头像 ${summary.profiles} 条` : null,
    summary.stories ? `· 公开到首页 ${summary.stories} 条` : null,
    summary.reports ? `· 举报 ${summary.reports} 条` : null,
  ].filter(Boolean);

  const text = [
    `哈喽卧得运营台有 ${total} 项待审：`,
    "",
    ...lines,
    "",
    `去处理：${config.opsUrl}`,
    "",
    "内容审核通过前不会进入任何公开列表。",
    "这封信只在待审内容发生变化时发送，处理完就不会再提醒。",
  ].join("\n");

  const fetchImpl = options.fetchImpl ?? fetch;
  const response = await fetchImpl("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${config.apiKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      from: config.from ?? "哈喽卧得运营 <onboarding@resend.dev>",
      to: [config.to],
      subject: `[哈喽卧得] ${total} 项待审`,
      text,
    }),
  });

  if (!response.ok) {
    // 发信失败不抛出：这是提醒，不该让 Cron 报错重试到把额度耗光。
    return { sent: false, reason: `邮件服务返回 ${response.status}`, summary };
  }

  const now = options.now ?? Date.now();
  await db
    .prepare(
      `INSERT INTO ops_notify_state (key, signature, sent_at) VALUES (?, ?, ?)
       ON CONFLICT(key) DO UPDATE SET signature = excluded.signature, sent_at = excluded.sent_at`,
    )
    .bind(STATE_KEY, signature, now)
    .run();

  return { sent: true, reason: "已发送", summary };
}

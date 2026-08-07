/**
 * APNs 推送。
 *
 * 设计上与 `ops-notifier.ts` 一致：**没配密钥就静默跳过**，不报错、不阻断
 * 任何业务流程。推送是锦上添花，绝不能让「发一条消息」因为推送失败而失败。
 *
 * 调用方一律用 `ctx.waitUntil()` 异步触发，不要 await——发消息的人不该为
 * 一次 APNs 往返等待。
 */

export interface PushConfig {
  teamId?: string;
  keyId?: string;
  privateKey?: string;
  /// APNs 的 topic 就是 App 的 bundle id
  bundleId: string;
}

export interface PushPayload {
  title: string;
  body: string;
  /// 点开通知后要去哪。客户端据此决定跳转，不认识的值就只打开 App。
  target?: string;
  /// 同一条会话的多次消息在通知中心里折叠成一组
  threadId?: string;
}

const PRODUCTION = "https://api.push.apple.com";
const SANDBOX = "https://api.sandbox.push.apple.com";

export function hasPushCredentials(config: PushConfig) {
  return Boolean(config.teamId && config.keyId && config.privateKey);
}

function base64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

async function importPrivateKey(pem: string) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replaceAll(/\s+/g, "");
  const raw = atob(body);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i += 1) bytes[i] = raw.charCodeAt(i);
  return crypto.subtle.importKey("pkcs8", bytes, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

/**
 * APNs 的鉴权 JWT。
 *
 * 有效期最长 1 小时，但**Apple 明确禁止刷得过勤**（20 分钟内重复签发会被
 * 429 TooManyProviderTokenUpdates）。这里按 Worker 实例缓存 50 分钟。
 */
let cachedToken: { value: string; expiresAt: number } | null = null;

async function authToken(config: PushConfig, now: number) {
  if (cachedToken && cachedToken.expiresAt > now) return cachedToken.value;
  const issuedAt = Math.floor(now / 1000);
  const encoder = new TextEncoder();
  const header = base64Url(encoder.encode(JSON.stringify({ alg: "ES256", kid: config.keyId })));
  const payload = base64Url(encoder.encode(JSON.stringify({ iss: config.teamId, iat: issuedAt })));
  const key = await importPrivateKey(config.privateKey!);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(`${header}.${payload}`),
  );
  const token = `${header}.${payload}.${base64Url(new Uint8Array(signature))}`;
  cachedToken = { value: token, expiresAt: now + 50 * 60_000 };
  return token;
}

interface DeviceRow {
  token: string;
  environment: string;
}

/** 注册/更新一台设备的令牌。同一 token 再次上报只更新归属与时间。 */
export async function registerDeviceToken(
  db: D1Database,
  userId: string,
  token: string,
  environment: string,
) {
  const now = Date.now();
  const env = environment === "sandbox" ? "sandbox" : "production";
  await db
    .prepare(
      `INSERT INTO device_tokens (token, user_id, platform, environment, created_at, updated_at)
       VALUES (?, ?, 'ios', ?, ?, ?)
       ON CONFLICT(token) DO UPDATE SET
         user_id = excluded.user_id,
         environment = excluded.environment,
         updated_at = excluded.updated_at`,
    )
    .bind(token, userId, env, now, now)
    .run();
  return { registered: true };
}

/** 退出登录或删除账户时移除，避免继续推给已经不是本人的设备。 */
export async function removeDeviceTokens(db: D1Database, userId: string) {
  await db.prepare("DELETE FROM device_tokens WHERE user_id = ?").bind(userId).run();
}

export async function removeDeviceToken(db: D1Database, token: string) {
  await db.prepare("DELETE FROM device_tokens WHERE token = ?").bind(token).run();
}

/**
 * 给某个用户的全部设备发一条通知。
 *
 * 返回统计而不是抛错：调用方在 `waitUntil` 里跑，抛出去也没人接。
 */
export async function sendPush(
  db: D1Database,
  userId: string,
  payload: PushPayload,
  config: PushConfig,
  options: { now?: number; fetchImpl?: typeof fetch } = {},
): Promise<{ sent: number; skipped: string | null }> {
  if (!hasPushCredentials(config)) return { sent: 0, skipped: "未配置 APNs 密钥" };

  const devices = await db
    .prepare("SELECT token, environment FROM device_tokens WHERE user_id = ?")
    .bind(userId)
    .all<DeviceRow>();
  if (!devices.results.length) return { sent: 0, skipped: "该用户没有已注册的设备" };

  const now = options.now ?? Date.now();
  const fetchImpl = options.fetchImpl ?? fetch;
  const jwt = await authToken(config, now);
  const body = JSON.stringify({
    aps: {
      alert: { title: payload.title, body: payload.body },
      sound: "default",
      "thread-id": payload.threadId,
    },
    target: payload.target,
  });

  let sent = 0;
  for (const device of devices.results) {
    const host = device.environment === "sandbox" ? SANDBOX : PRODUCTION;
    try {
      const response = await fetchImpl(`${host}/3/device/${device.token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": config.bundleId,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "content-type": "application/json",
        },
        body,
      });
      if (response.ok) {
        sent += 1;
        continue;
      }
      // 410 Gone / BadDeviceToken：这台设备卸载了或令牌换了，删掉别再推。
      // 不删的话失效令牌会永远留在库里，每次推送都白跑一次请求。
      if (response.status === 410) {
        await removeDeviceToken(db, device.token);
        continue;
      }
      const detail = (await response.json().catch(() => ({}))) as { reason?: string };
      if (detail.reason === "BadDeviceToken" || detail.reason === "Unregistered") {
        await removeDeviceToken(db, device.token);
      }
    } catch {
      // 网络抖动不做重试：这是通知，不是交易。下一条自然会再试。
    }
  }
  return { sent, skipped: null };
}

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
export const root = path.resolve(here, '..');

function loadDotEnv() {
  const filename = path.join(root, '.env');
  if (!fs.existsSync(filename)) return;
  for (const rawLine of fs.readFileSync(filename, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const separator = line.indexOf('=');
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadDotEnv();

const required = (name) => {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`缺少环境变量 ${name}；请复制 .env.example 为 .env 后填写。`);
  return value;
};

export const config = {
  appId: required('FEISHU_APP_ID'),
  appSecret: required('FEISHU_APP_SECRET'),
  initialThreadId: process.env.CODEX_THREAD_ID?.trim() || null,
  workdir: process.env.CODEX_WORKDIR?.trim() || process.cwd(),
  codexBin: process.env.CODEX_BIN?.trim() || 'codex',
  sandbox: process.env.CODEX_SANDBOX?.trim() || 'workspace-write',
  maxReplyChars: Number(process.env.MAX_REPLY_CHARS || 12000),
  openThreadAfterReply: process.env.OPEN_CODEX_THREAD_AFTER_REPLY !== 'false',
  allowedOpenIds: new Set(
    (process.env.ALLOWED_FEISHU_OPEN_IDS || '')
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean),
  ),
};

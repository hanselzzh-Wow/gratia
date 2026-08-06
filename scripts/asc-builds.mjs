#!/usr/bin/env node
// 列出 App Store Connect 上已存在的构建号。
//
// 为什么需要它：构建号一经上传即被占用且不可复用，而本地 `project.yml` 里的
// CURRENT_PROJECT_VERSION 并不知道线上到了几。打包前用它核实一次，比上传后
// 被拒再回头查要便宜。`xcrun altool` 在 Xcode 26 已没有列出构建的子命令，
// 所以这里直接调 App Store Connect API。
//
// 用法：
//   node scripts/asc-builds.mjs
//   ASC_KEY_PATH=/path/to/AuthKey_XXXX.p8 ASC_KEY_ID=XXXX node scripts/asc-builds.mjs
//
// 私钥不在仓库里，默认读降级前备份目录里的那份（见 docs/HANDOFF.md 第五节）。

import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const KEY_ID = process.env.ASC_KEY_ID ?? '${ASC_KEY_ID}';
const ISSUER_ID = process.env.ASC_ISSUER_ID ?? '${ASC_ISSUER_ID}';
const APP_ID = process.env.ASC_APP_ID ?? '6798480891';
const KEY_PATH =
  process.env.ASC_KEY_PATH ??
  join(homedir(), 'Documents', '哈喽卧得-降级前备份', `AuthKey_${KEY_ID}.p8`);

function readPrivateKey() {
  try {
    return readFileSync(KEY_PATH, 'utf8');
  } catch (error) {
    console.error(`读不到 App Store Connect 私钥：${KEY_PATH}`);
    console.error('用 ASC_KEY_PATH 指向 .p8 文件，或见 docs/HANDOFF.md 第五节「凭据在哪」。');
    console.error(String(error.message ?? error));
    process.exit(1);
  }
}

// ASC 要的是 ES256 JWT，有效期最长 20 分钟。
function makeToken(privateKey) {
  const base64url = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const issuedAt = Math.floor(Date.now() / 1000);
  const header = base64url({ alg: 'ES256', kid: KEY_ID, typ: 'JWT' });
  const payload = base64url({
    iss: ISSUER_ID,
    iat: issuedAt,
    exp: issuedAt + 600,
    aud: 'appstoreconnect-v1',
  });
  const signer = createSign('SHA256');
  signer.update(`${header}.${payload}`);
  // ASC 只认裸 r||s 签名，不认 DER 包装。
  const signature = signer.sign({ key: privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${header}.${payload}.${signature}`;
}

const url = new URL('https://api.appstoreconnect.apple.com/v1/builds');
url.searchParams.set('filter[app]', APP_ID);
url.searchParams.set('sort', '-version');
url.searchParams.set('limit', '20');
url.searchParams.set('fields[builds]', 'version,uploadedDate,processingState,expired');

const response = await fetch(url, {
  headers: { Authorization: `Bearer ${makeToken(readPrivateKey())}` },
});
const body = await response.json();

if (!response.ok) {
  console.error(`App Store Connect 返回 ${response.status}`);
  for (const item of body.errors ?? []) console.error(`  ${item.title}: ${item.detail ?? ''}`);
  process.exit(1);
}

const builds = body.data ?? [];
if (builds.length === 0) {
  console.log('该 App 还没有任何构建，下一个构建号是 1。');
  process.exit(0);
}

console.log('构建号\t状态\t\t已过期\t上传时间');
for (const build of builds) {
  const { version, processingState, expired, uploadedDate } = build.attributes;
  console.log(`${version}\t${processingState}\t${expired ? '是' : '否'}\t${uploadedDate}`);
}

const highest = Math.max(...builds.map((b) => Number(b.attributes.version)).filter(Number.isFinite));
if (Number.isFinite(highest)) {
  console.log(`\n下一个可用构建号：${highest + 1}（构建号不可复用）`);
}

#!/usr/bin/env node
// 准备 iOS 分发签名：重建临时钥匙串并导入分发证书。
//
//   node scripts/ios-signing-setup.mjs
//
// 什么时候需要跑：`ios-release.mjs` 归档时报 `errSecInternalComponent`，
// 或者报找不到 "Apple Distribution" 签名身份。这两个症状都是钥匙串问题，
// 跑一次这个脚本就好，跑完再打包。**平时不需要跑。**
//
// 为什么会有这么个东西：分发证书**不在登录钥匙串里**（登录钥匙串里只有
// Apple Development），而是在一个专用的临时钥匙串里，这样签名时不会弹出
// 登录钥匙串的密码框。代价是这个钥匙串会自动锁定，锁上之后 codesign 报的
// 是 `errSecInternalComponent` —— 一个完全看不出跟"钥匙串锁了"有关的错误。
//
// 材料放在 ~/Developer/gratia-signing（仓库外，权限 700）：
//   .kcpw    p12 的密码，同时用作本钥匙串的密码
//   dist.p12 分发证书 + 私钥
//   dist.key 明文私钥（p12 的备份来源）
//   wwdr.pem Apple 中间证书
//   Gratia_AppStore.mobileprovision  描述文件
//
// ⚠️ 这些是**真实的分发私钥**，丢了要重新申请证书（个人账号证书数量有限）。
// 它们一度只存在于某个会话的 /private/tmp 临时目录里，随时可能被清理，
// 所以才迁到 ~/Developer 下。不要放回 /tmp，也不要提交进仓库。

import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, readFileSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const DIR = process.env.GRATIA_SIGNING_DIR ?? join(homedir(), 'Developer', 'gratia-signing');
const KEYCHAIN = join(DIR, 'gratia-build.keychain-db');
const LOGIN_KEYCHAIN = join(homedir(), 'Library', 'Keychains', 'login.keychain-db');

const need = ['.kcpw', 'dist.p12', 'wwdr.pem'];
const missing = need.filter((f) => !existsSync(join(DIR, f)));
if (missing.length) {
  console.error(`签名材料目录不完整：${DIR}`);
  console.error(`缺少：${missing.join(', ')}`);
  console.error('见 docs/HANDOFF.md 第九节「签名材料在哪」。');
  process.exit(1);
}

const password = readFileSync(join(DIR, '.kcpw'), 'utf8').replace(/[\r\n]/g, '');
const sec = (args, opts = {}) =>
  execFileSync('security', args, { encoding: 'utf8', stdio: 'pipe', ...opts });

console.log(`→ 重建钥匙串 ${KEYCHAIN}`);
if (existsSync(KEYCHAIN)) rmSync(KEYCHAIN);
sec(['create-keychain', '-p', password, KEYCHAIN]);
// -lut 21600：6 小时后才自动锁定，且不跟随屏幕锁定。默认设置会在几分钟内
// 锁上，于是"刚才还能打包，现在就 errSecInternalComponent"。
sec(['set-keychain-settings', '-lut', '21600', KEYCHAIN]);
sec(['unlock-keychain', '-p', password, KEYCHAIN]);

console.log('→ 导入分发证书与私钥');
sec(['import', join(DIR, 'dist.p12'), '-k', KEYCHAIN, '-P', password,
     '-T', '/usr/bin/codesign', '-T', '/usr/bin/security']);
try {
  sec(['import', join(DIR, 'wwdr.pem'), '-k', KEYCHAIN, '-T', '/usr/bin/codesign']);
} catch {
  console.log('  (WWDR 中间证书已存在，跳过)');
}

// 没有这一步，codesign 每次访问私钥都会弹系统授权框，非交互环境下直接失败。
console.log('→ 授权 codesign 免提示访问私钥');
sec(['set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, KEYCHAIN]);

console.log('→ 加入钥匙串搜索列表');
sec(['list-keychains', '-d', 'user', '-s', KEYCHAIN, LOGIN_KEYCHAIN]);

const found = spawnSync('security', ['find-identity', '-v', '-p', 'codesigning', KEYCHAIN], {
  encoding: 'utf8',
});
const out = `${found.stdout ?? ''}${found.stderr ?? ''}`;
if (!out.includes('Apple Distribution')) {
  console.error(`\n✗ 钥匙串里没有 Apple Distribution 身份：\n${out}`);
  process.exit(1);
}
console.log(`\n✓ 就绪：${out.trim().split('\n')[0].trim()}`);
console.log('现在可以跑 node scripts/ios-release.mjs --upload');

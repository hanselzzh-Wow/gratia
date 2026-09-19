#!/usr/bin/env node
// 打一个可上传 App Store Connect 的 iOS 构建。
//
//   node scripts/ios-release.mjs             归档 + 校验产物 + 导出 + 验证，不上传
//   node scripts/ios-release.mjs --upload    再加上传
//
// 为什么要有这个脚本，而不是记几条 xcodebuild 命令：这条链上有两个坑，
// 都会安静地给出"成功"。
//
// 坑一：XcodeGen 默认写死 CODE_SIGN_IDENTITY = "iPhone Developer"，把自动
// 签名锁在 development 上；个人团队没有注册设备，Apple 拒绝签发 development
// 描述文件，archive 直接失败。（已在 ios/project.yml 的 Release 配置里改掉。）
//
// 坑二：用 CODE_SIGN_IDENTITY="" 去绕开坑一，archive 会报 ARCHIVE SUCCEEDED，
// 但产物**完全没有签名**——没有 embedded.mobileprovision、没有 entitlements，
// 等于 Sign in with Apple 直接失效。不打开产物看是发现不了的。
// 所以下面第 3 步会强制校验归档产物，校验不过就中断。

import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdtempSync, readdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const REPO = resolve(import.meta.dirname, '..');
const IOS = join(REPO, 'ios');
const BUNDLE_ID = 'com.hanselzzh.gratia';
const TEAM_ID = 'HH9LKGK7DA';
// 开启 Push Notifications 会让旧的 App Store 描述文件立刻变成 INVALID，
// 必须换一份带 aps-environment 的。这里跟 App Store Connect 上的新名字保持一致；
// 名字对不上的话，archive 会以「找不到描述文件」失败。
const PROFILE_NAME = 'Gratia App Store Push';
const upload = process.argv.includes('--upload');

const run = (cmd, args, opts = {}) =>
  execFileSync(cmd, args, { encoding: 'utf8', stdio: 'pipe', ...opts });

function fail(message) {
  console.error(`\n✗ ${message}`);
  process.exit(1);
}

// xcodebuild 的失败原因可能只出现在 stderr，也可能是 codesign 那种不带
// "error:" 前缀的行（errSecInternalComponent 就是）。只 grep "error:" 会
// 把真正有用的那一行丢掉，只剩一句「归档失败」，等于没说。
function printBuildFailure(error) {
  const text = `${String(error.stdout ?? '')}\n${String(error.stderr ?? '')}`;
  const interesting = text
    .split('\n')
    .filter((line) => /error:|errSec|Signing Identity|Provisioning profile|No profiles|The specified item/i.test(line));
  console.error(interesting.length ? [...new Set(interesting)].slice(-15).join('\n') : text.slice(-2000));
}

// 1. 构建号必须还没被占用 —— 上传后不可复用，撞号要等到上传那一刻才报错。
const version = readFileSync(join(IOS, 'project.yml'), 'utf8').match(
  /CURRENT_PROJECT_VERSION:\s*(\d+)/,
)?.[1];
if (!version) fail('project.yml 里找不到 CURRENT_PROJECT_VERSION');

console.log(`→ 核对构建号 ${version} 是否已被占用…`);
let taken = [];
try {
  const listed = run('node', [join(REPO, 'scripts', 'asc-builds.mjs')]);
  taken = [...listed.matchAll(/^(\d+)\t/gm)].map((m) => Number(m[1]));
} catch {
  console.warn('  (查询失败，跳过这一步；上传时若撞号会被 Apple 拒绝)');
}
if (taken.includes(Number(version))) {
  fail(
    `构建号 ${version} 已被占用。把 ios/project.yml 的 CURRENT_PROJECT_VERSION ` +
      `改成 ${Math.max(...taken) + 1} 再来。`,
  );
}

// 2. 归档。签名参数都在 ios/project.yml 的 Release 配置里，这里不再覆盖，
//    免得又出现"命令行传了一个把签名关掉的值"这种事。
const out = mkdtempSync(join(tmpdir(), 'gratia-release-'));
const archivePath = join(out, 'Gratia.xcarchive');

console.log('→ 重新生成 Xcode 工程…');
run(join(REPO, '.tools/xcodegen/xcodegen/bin/xcodegen'), ['generate', '--spec', 'project.yml'], {
  cwd: IOS,
});

console.log('→ 归档（Release）…');
try {
  run(
    'xcodebuild',
    [
      '-project', 'Gratia.xcodeproj',
      '-scheme', 'Gratia',
      '-configuration', 'Release',
      '-destination', 'generic/platform=iOS',
      '-archivePath', archivePath,
      'archive',
    ],
    { cwd: IOS, maxBuffer: 64 * 1024 * 1024 },
  );
} catch (error) {
  printBuildFailure(error);
  fail('归档失败');
}

// 3. 校验归档产物真的签上了 —— 这一步就是为了拦住"假成功"。
const app = join(archivePath, 'Products/Applications/Gratia.app');
console.log('→ 校验归档产物…');

if (!existsSync(join(app, 'embedded.mobileprovision'))) {
  fail('产物里没有 embedded.mobileprovision，说明这个归档根本没签名，不能上传。');
}

// codesign -dvv 把签名信息写到 **stderr**，成功时 stdout 是空的。
// 只读返回值（stdout）会永远拿到空字符串，于是这个校验会把每一个
// 签名正确的产物都误判成「签名不是 Apple Distribution」。
const inspect = spawnSync('codesign', ['-dvv', app], { encoding: 'utf8' });
const signature = `${inspect.stdout ?? ''}${inspect.stderr ?? ''}`;
if (!signature.includes('Apple Distribution')) {
  fail(`签名不是 Apple Distribution：\n${signature.trim() || '(codesign 无输出)'}`);
}
if (!signature.includes(TEAM_ID)) fail(`签名的 Team 不是 ${TEAM_ID}`);

let entitlements = '';
try {
  entitlements = run('codesign', ['-d', '--entitlements', ':-', app]);
} catch (error) {
  entitlements = String(error.stdout ?? '');
}
// 登录与账户删除整条链都靠它；缺了它 App 能装能跑，只是登录必然失败。
if (!entitlements.includes('com.apple.developer.applesignin')) {
  fail('产物缺少 com.apple.developer.applesignin entitlement，Sign in with Apple 会失效。');
}
// 同理：缺了 aps-environment，App 拿不到 APNs 令牌，推送静默失效——
// 而 archive 照样报成功。源码里写的是 development，Xcode 导出时会按描述文件
// 改写成 production；改出来还是 development 说明用错了描述文件，
// 这样的包发出去，令牌会落到 sandbox 令牌空间，生产网关一律 BadDeviceToken。
if (!entitlements.includes('aps-environment')) {
  fail('产物缺少 aps-environment entitlement，推送通知会静默失效。');
}
if (!/<key>aps-environment<\/key>\s*<string>production<\/string>/.test(entitlements)) {
  fail('产物的 aps-environment 不是 production，说明签名用的不是 App Store 描述文件。');
}

// 预设头像必须与源文件逐字节一致。服务端按 SHA-256 认出它们并免去人工审核，
// 而 Xcode 默认会用 pngcrush 重新编码 target 里的 PNG——字节一变哈希就对不上，
// 那 12 张图会全部掉回人工审核队列。不报错，只是用户按引导选了头像，
// 别人看到的依然是灰色人像。工程里靠 folder reference 规避，这里守住它。
const presetSource = join(IOS, 'Gratia', 'PresetAvatars');
if (existsSync(presetSource)) {
  const sha = (path) => createHash('sha256').update(readFileSync(path)).digest('hex');
  const names = readdirSync(presetSource).filter((name) => name.endsWith('.png'));
  if (!names.length) fail('找不到预设头像源文件');
  for (const name of names) {
    const inApp = join(app, 'PresetAvatars', name);
    if (!existsSync(inApp)) {
      fail(`产物里缺少预设头像 ${name}——PresetAvatars 可能不再是 folder reference。`);
    }
    if (sha(inApp) !== sha(join(presetSource, name))) {
      fail(
        `预设头像 ${name} 在打包过程中被重新编码，与源文件不一致。\n` +
          '服务端按内容哈希免审，这样打出来的包会让预设头像全部退回人工审核。\n' +
          '检查 ios/project.yml 里 Gratia/PresetAvatars 是否仍是 type: folder。',
      );
    }
  }
  console.log(`  ✓ ${names.length} 张预设头像与源文件逐字节一致`);
}

const built = run('plutil', ['-extract', 'CFBundleVersion', 'raw', join(app, 'Info.plist')]).trim();
if (built !== version) fail(`产物构建号是 ${built}，与 project.yml 的 ${version} 不一致`);
console.log(`  ✓ Apple Distribution / ${TEAM_ID} / applesignin / aps:production / build ${built}`);

// 4. 导出。
const exportOptions = join(out, 'ExportOptions.plist');
run('/usr/libexec/PlistBuddy', [
  '-c', 'Add :method string app-store-connect',
  '-c', `Add :teamID string ${TEAM_ID}`,
  '-c', 'Add :signingStyle string manual',
  '-c', 'Add :signingCertificate string Apple Distribution',
  '-c', 'Add :uploadSymbols bool true',
  '-c', 'Add :provisioningProfiles dict',
  '-c', `Add :provisioningProfiles:${BUNDLE_ID} string ${PROFILE_NAME}`,
  exportOptions,
]);

console.log('→ 导出 IPA…');
const exportPath = join(out, 'export');
try {
  run('xcodebuild', [
    '-exportArchive',
    '-archivePath', archivePath,
    '-exportOptionsPlist', exportOptions,
    '-exportPath', exportPath,
  ], { maxBuffer: 64 * 1024 * 1024 });
} catch (error) {
  printBuildFailure(error);
  fail('导出失败');
}
const ipa = join(exportPath, 'Gratia.ipa');

// 5. 先验证再上传。验证不通过就没必要占用一个构建号。
// App Store Connect API Key 的 ID 与 Issuer ID 从环境变量读取，不写进仓库。
const { ASC_KEY_ID, ASC_ISSUER_ID } = process.env;
if (!ASC_KEY_ID || !ASC_ISSUER_ID) fail('缺少环境变量 ASC_KEY_ID / ASC_ISSUER_ID');
const auth = ['--apiKey', ASC_KEY_ID, '--apiIssuer', ASC_ISSUER_ID];
console.log('→ 验证 IPA…');
try {
  run('xcrun', ['altool', '--validate-app', '-f', ipa, '-t', 'ios', ...auth], {
    maxBuffer: 16 * 1024 * 1024,
  });
} catch (error) {
  console.error(String(error.stdout ?? '') + String(error.stderr ?? ''));
  fail('验证失败');
}
console.log('  ✓ 验证通过');

if (!upload) {
  console.log(`\n完成（未上传）。IPA：${ipa}`);
  console.log('确认无误后加 --upload 重跑，或直接用 xcrun altool --upload-app 上传这一份。');
  process.exit(0);
}

console.log('→ 上传…');
try {
  run('xcrun', ['altool', '--upload-app', '-f', ipa, '-t', 'ios', ...auth], {
    maxBuffer: 16 * 1024 * 1024,
  });
} catch (error) {
  console.error(String(error.stdout ?? '') + String(error.stderr ?? ''));
  fail('上传失败');
}

console.log(`\n✓ 构建 ${version} 已上传。`);
console.log('Apple 处理需要几分钟；用 node scripts/asc-builds.mjs 查它到没到。');
console.log(`上传成功后请立刻把 ios/project.yml 的 CURRENT_PROJECT_VERSION 加到 ${Number(version) + 1}。`);

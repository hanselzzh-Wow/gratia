# CX-005 系统显示名本地化交接

## 改动

- 新增 `ios/Haluowode/en.lproj/InfoPlist.strings`：`CFBundleDisplayName = Gratia`。
- 新增 `ios/Haluowode/zh-Hans.lproj/InfoPlist.strings`：`CFBundleDisplayName = 哈喽卧得`。
- 未修改 `Info.plist`、App Icon、Bundle ID、签名、工程文件、Swift 或后端。

## 实际验证

- 两个 strings 文件均由 `plutil -lint` 验证通过。
- 临时运行既有 XcodeGen 后，真机 Debug build 通过；仅有既有 interface-orientations warning。
- built app 包含：
  - `en.lproj/InfoPlist.strings`，读取到 `CFBundleDisplayName = Gratia`；
  - `zh-Hans.lproj/InfoPlist.strings`，读取到 `CFBundleDisplayName = 哈喽卧得`。
- 根 `Info.plist` 保留 `CFBundleIdentifier = com.hanselzzh.haluowode`、`CFBundleName = Haluowode` 与中文 fallback 显示名。
- `xcrun devicectl device install app` 与 launch 均成功；未修改 Team/签名，命令行临时覆盖未写回工程。

## 生成工程边界

XcodeGen 只为本轮构建临时生成工程；随后已恢复 `ios/Haluowode.xcodeproj/project.pbxproj`。最终 diff 只含两份允许的本地化文件、交接和 STATUS。

## 待人工验收

在 iPhone 的“设置 → 通用 → 语言与地区 → iPhone 语言”切换为 English 后，主屏/App Library 应显示 `Gratia`；切回简体中文应显示“哈喽卧得”。系统语言/主屏缓存可能要求重新打开 App 或稍候刷新。该人工双语言核验尚未完成，任务不能 ACCEPTED/合入。

## 提交

提交 SHA：待提交后补充。

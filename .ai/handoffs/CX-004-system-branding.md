# CX-004 系统显示名与 App Icon 交接

## 范围与结果

- 仅修改 `ios/Haluowode/Info.plist` 与 `ios/Haluowode/Assets.xcassets/AppIcon.appiconset/**`。
- 新增 `CFBundleDisplayName = 哈喽卧得`；保留 `CFBundleName = $(PRODUCT_NAME)`、Bundle ID `com.hanselzzh.haluowode`、target 技术名与签名设置。
- 将 18 个完整尺寸的 App Icon slot 替换为已验收玫红钥匙资产，移除真机所见的蓝底白钥匙遗留图标。

## 实际验证

- `plutil -lint ios/Haluowode/Info.plist`：通过；built app 的 `Info.plist` 读取到 `CFBundleDisplayName = 哈喽卧得`、原 Bundle ID。
- `sips -g pixelWidth -g pixelHeight ...AppIcon.appiconset/*.png`：18 个 slot 的像素尺寸均与 `Contents.json` 指定的 1x/2x/3x 尺寸相符，营销图为 1024×1024。
- `xcodebuild ... -destination 'platform=iOS,id=00008140-001C58E21487001C' ... DEVELOPMENT_TEAM=SNYPP97D2L CODE_SIGN_STYLE=Automatic build`：通过；仅有既有的“all interface orientations” warning。命令行 Team 覆盖未写回工程。
- `xcrun devicectl device install app ...`：成功安装到设备；安装返回 Bundle ID `com.hanselzzh.haluowode`。
- 自动 launch 被设备锁屏拒绝，错误为 `Locked`，不是签名、安装或应用崩溃错误。

## 生成工程与边界

构建前临时运行现有 `project.yml` 生成工程，以纳入已合入但未写入旧 `project.pbxproj` 的 `HomePreviewFixtures.swift`；构建后已经恢复 `ios/Haluowode.xcodeproj/project.pbxproj`，未提交任何工程、签名或 Bundle ID 改动。

## 未验证

- 需要设备解锁后由用户/PM 在主屏人工确认实际名称与图标；iOS 可能对图标做短暂 SpringBoard 缓存。
- Simulator 服务本轮不可用（`CoreSimulatorService connection refused`），故未取得新的 Simulator build 证据；真机构建/安装成功不替代极端无障碍、旧 iOS 验证。

## 提交

提交 SHA：待本任务提交后补充。

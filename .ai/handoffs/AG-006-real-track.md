# AG-006 真实查询进度与交付交接

## 提交与改动范围

- 实现提交：`4a30bd0`（真实 `trackWish`、进度状态、事件/派单信息与交付预览）。
- 复审收敛提交：`a94e6f7`（视频失败可见路径、全空白校验、404 隐私断言、生产状态文案 helper 及测试）。
- 实际改动路径：
  - `ios/Haluowode/ProgressView.swift`
  - `ios/Haluowode/TrackWishViewModel.swift`
  - `ios/Haluowode/DeliveryPreviewView.swift`
  - `ios/Haluowode/ContentView.swift`
  - `ios/HaluowodeTests/TrackWishViewModelTests.swift`
  - `ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift`
  - `ios/Haluowode.xcodeproj/project.pbxproj`
  - `.ai/handoffs/AG-006-real-track.md`
  - `.ai/TEAM_CHAT.md`

## 行为与隐私

- `TrackWishViewModel` 状态为 `idle / loading / loaded / failed`；校验失败不调用 API，请求中去重，取消回到 `.idle` 并保留草稿。
- 请求对公开编号和联系方式使用 `whitespacesAndNewlines` trim，编号大写；成功后立即清空 ViewModel 中的联系方式。
- 404 固定显示“请检查编号和联系方式”，测试使用唯一联系方式并断言错误文案不包含它；429 映射为可重试提示。
- `ProgressView.statusText(for:)` 是生产视图实际调用的纯 helper，直接测试 `delivered` 显示“待确认”。
- 页面离开调用 `viewModel.cancel()`；去重测试断言 mock 只收到一次 `trackWish`。
- 图片、视频和外部链接均不显示、复制、保存或打印能力 URL/token。视频播放器观察失败状态并显示“交付链接不可用或已失效”。

## 实际验证结果（2026-07-18 恢复轮次）

- XcodeGen：**未执行**。任务卡临时路径 `/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen` 已不存在；未安装替代依赖。现有工程已能编译本轮源码和测试。
- Core：`swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag006 --disable-xctest --enable-swift-testing`，实际 **17/17 通过**，0 failure。
- App Simulator：两次 `xcodebuild ... -only-testing:HaluowodeTests test` 均完成构建并返回 0，但 `/private/tmp/haluowode-ag006-resume-tests.xcresult` 与 `/private/tmp/haluowode-ag006-final-tests.xcresult` 都缺少 `Info.plist`，`xcresulttool` 无法读取；因此本轮 **App 测试执行数量未验证，不声明 21/21**。
- `swiftc -frontend -parse ios/Haluowode/*.swift`：通过。
- Mock/假延时/默认生产 Client 扫描：0 命中。
- `UserDefaults`、管理凭据、token、`print(` 隐私扫描：0 命中。
- `git diff --check`：通过。

## Warning 与未验证项

- App 链接阶段有 2 条 warning：deployment target 为 iOS Simulator 16.0，而 Xcode 27 的 XCTest 与 `libXCTestSwiftSupport` 最低为 17.0。
- Xcode 另报告 scheme buildables 的 supported platforms 为空；本轮未修改签名或工程配置。
- CoreSimulator/xcresult 结果包异常导致本轮 App 测试数量不可读取，需要 Codex 在恢复正常的 Simulator 环境独立复验。
- 真实远端视频失败、网络视频解码、图片加载与系统 Link 行为未做真机或受控本地媒体 fixture 验证；代码失败路径已保留，但不以 AVPlayer 系统调度测试冒充确定性证据。
- 未访问生产 API，未进行真机、TestFlight、签名或生产写入验证。

## 停止状态

AG-006 已完成允许范围内的代码收敛、实现提交和交接。已追加 STATUS；不领取下一任务，等待 Codex 独立验收。

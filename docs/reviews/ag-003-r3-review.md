# AG-003 R3 独立复审（未通过，退回 R4）

复审对象：`codex/ag-003-core-api` 的 `28492e85080ffb99d2a7d9f64d72db837b98b6fc`
复审日期：2026-07-18（Asia/Shanghai）

## 已独立确认的有效成果

- `HaluowodeTests` 是真实 iOS XCTest target。Xcode 27 在 iPhone 17 Pro Simulator（iOS 27.0，`742A9D34-5F88-4578-BB12-851A00D2C0FE`）发现并执行 2 个测试，结构化 `xcresult` 为 2 通过、0 失败、0 跳过。
- Foundation-only Core 的 Swift Testing 在强制运行器下发现并执行 15 个测试，15 通过、0 失败；`testCreateWishResponseSuccess201` 已覆盖 method、path、`content-type`、联系人、备注、显式同意、蜜罐省略及关键响应字段。
- `project.yml` 可以用固定的 XcodeGen 2.46.0 重新生成工程，生成后没有项目差异；Swift parser、旧列表 Mock/假延时扫描、管理凭据扫描和差异格式检查均通过。
- `WishListViewModel` 现在确实保存并取消前一条内部 Task，调用者取消也会请求取消内部 Task；`waitUntilStarted` 替代了 iOS XCTest 中原先的固定启动 sleep。

## 未通过原因

### 1. 竞态测试没有让旧请求真正“晚到”

`ControllableMockAPI` 的 `onCancel` 会立刻从 `pendingRequests` 移除 A 并以 `CancellationError` 恢复 A 的 continuation。随后测试调用 `completeRequest("杭州", ...)` 时已经没有 pending continuation，因此该调用是无操作。

这只证明了 A 被取消，**没有**证明任务卡要求的“B 已成功后，A 即使晚到成功或晚到失败也不能覆盖 `WishListViewModel.state`”。当前 production 的 generation guard 值得保留，但尚未被这条测试实际覆盖。

### 2. iOS 测试源码在 Xcode 27 给出 Swift 6 兼容性警告

Xcode 编译 `WishListViewModelTests.swift` 时报告在 async context 调用 `NSLock.lock()`/`unlock()` 不可用；当前以 Swift 5 mode 仍是 warning，但在 Swift 6 language mode 会成为错误。交接中“无任何 Error/Warning”的表述与独立构建输出不符。

### 3. Core 的取消测试仍以短 sleep 猜测请求已经进入 transport

Core `testRequestCancelled` 仍有 `Task.sleep(2ms)`。它本轮恰好通过，但与本项目的确定性并发质量门不一致，不能作为稳定的在途取消证据。

## R4 必须满足的验收

1. 测试替身必须在收到取消时记录“已观察到取消”，但能够在测试明确选择时**不立即恢复旧 continuation**；在 B 已 `.loaded` 后分别让 A 晚到成功、晚到失败，两个分支都必须通过生产 `WishListViewModel`，并精确断言状态保持 B。
2. 取消观察、请求开始和待恢复 continuation 必须使用 Swift 6 安全的同步方案（优先 actor）；不得再用 `@unchecked Sendable` + async context 的 `NSLock`。
3. Core 取消测试也要以确定性开始 gate 取代固定 sleep，并证明 transport 已启动后才取消。
4. 重跑 XcodeGen、15 个 Core Swift Testing、全部 iOS XCTest、parser、两条 rg 扫描和 diff check；交接必须如实报告 warning/未验证项。不得以“测试绿”掩盖以上行为缺口。

在 R4 完成并由 Codex 再次独立验证前，AG-003 保持 `REVIEW`，不可合并 main。

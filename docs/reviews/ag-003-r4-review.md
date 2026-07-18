# AG-003 R4 独立复审（接近通过，退回 R5 清理并发边界）

复审对象：`codex/ag-003-core-api` 的 `ba6703ccd4eae610bee4b84174f6bc0aa672c71e`
复审日期：2026-07-18（Asia/Shanghai）

## 已独立通过的证据

- Core Swift Testing：强制运行器实际发现并执行 15 个测试，15 通过、0 失败。
- iPhone 17 Pro Simulator（iOS 27.0，`742A9D34-5F88-4578-BB12-851A00D2C0FE`）：仅运行 `WishListViewModelTests`，结构化 `xcresult` 显示 3 通过、0 失败、0 跳过；本次 result bundle 可被 `xcresulttool` 正常读取。
- 两个竞态路径均真正恢复了 A 的 pending continuation：B 先加载成功后，A 的晚到 success 与晚到 failure 都实际经过 production `WishListViewModel`，最终状态仍断言为 B 的 `.loaded`。
- caller 取消使用 actor 的 `waitUntilCancelled` 观察 gate；Core 取消测试使用 transport-start actor gate，不再用启动 sleep 猜测请求已在途。
- XcodeGen 2.46.0 再生成无项目差异；Swift parser、Mock/假延时扫描、管理凭据扫描、差异格式检查均通过。

## R5 唯一必须修订

R4 仍定义了：

```swift
final class ThreadSafeCancelledSet: @unchecked Sendable { ... NSLock ... }
```

虽然当前锁调用不在 async function 的直接上下文中，且测试通过，但 R4 任务明确要求用 actor 或等效 Swift 6 安全机制**移除 `@unchecked Sendable` 和该锁包装**。这个对象只由 `ControllableMockAPI` actor 使用，完全可以改为 actor 内的 `Set<String>`；不需要锁或手工 Sendable 承诺。

R5 只做该清理：删除 `ThreadSafeCancelledSet` 与 `@unchecked Sendable`，以 actor 隔离的集合保存取消城市，保持三条 XCTest、十五条 Core 测试和所有静态门绿色。不得改生产 ViewModel、端点、UI 或任务范围。

完成 R5 后，Codex 将重新进行短复验；通过即可接受 AG-003 并进入合入准备。

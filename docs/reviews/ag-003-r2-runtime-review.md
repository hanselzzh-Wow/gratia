# AG-003 R2：Xcode 27 运行时复审

日期：2026-07-18（Asia/Shanghai）
审查人：Codex（PM / 主分支集成者）
候选分支：`codex/ag-003-core-api`
候选提交：`739bdf1`

## 本轮新增运行时证据

- Xcode 27.0（27A5218g）成功为 iOS 27.0 iPhone 17 Pro Simulator 构建候选 App。
- `simctl listapps` 确认 `com.hanselzzh.haluowode` 已安装；`simctl launch` 返回进程 PID `13748`。
- 冷启动截图确认五栏原生 App 已显示。Simulator 运行日志显示该 App 的公开 HTTPS 请求收到了 HTTP 200。
- 生产只读 `GET /api/wishes` 返回 `{ "wishes": [] }`；App 随后从加载骨架正确切换至公开列表空状态。未执行生产写入。
- 使用 Xcode 27 Swift 6.4 强制 Swift Testing 运行器重新执行测试：实际发现、执行并通过 15/15，用时 0.005 秒。
- `swiftc -frontend -parse ios/Haluowode/*.swift` 与 `git diff --check 5bc4682..739bdf1` 均通过；首页/附近/Models 的运行时 Mock 与假延迟扫描无命中，Core/App Swift 源码中的管理凭据扫描无命中。

## 已确认通过（限公开列表纵向切片）

1. Foundation API Client 使用生产 Worker Base URL、可注入 Transport、公开列表 DTO 与未知枚举 fallback。
2. 首页和附近共享 `WishListViewModel`，运行时能得到真实公开列表 HTTP 200、加载和空状态。
3. 城市“全国”/“全部”不会作为错误 query 发出；显式 `contactConsent` 不再依赖构造器默认值。
4. 公开列表路径不读取 `Wish.mockWishes`、不嵌入运营凭据或管理接口。

## 仍未满足的质量门

### 1. 取消测试不证明取消行为

`testRequestCancelled` 的 Transport 在收到请求后立即抛出 `HaluowodeAPIError.requestCancelled`，随后才调用 `task.cancel()`。该测试在约 1ms 内通过，无法证明一个真正等待中的请求被取消，也无法证明 UI 状态不会被取消请求覆盖。

### 2. 竞态测试未调用生产协调逻辑

`testGenerationRaceConditionPrevention` 复制了一个局部整数 `generation` 和数组赋值流程，没有实例化或驱动 `WishListViewModel`。因此不能作为 `WishListViewModel.activeRequestGeneration` 行为的测试证据。

### 3. 报名 201 编码断言不完整

`testCreateWishResponseSuccess201` 仅断言 method、path、`responderName` 和 `contactConsent`。应同时断言 `Content-Type`、`responderContact`、`note`、`website` 缺失，以及成功响应中的关键字段，避免将部分编码遗漏误判为通过。

## 对整体 MVP 的范围说明

本审查只接受“公开列表”这一条纵向切片的运行时事实，不接受完整消费者 MVP。`PublishView` 和 `ProgressView` 仍调用 `Wish.mockWishes` / `DispatchQueue.main.asyncAfter`，这是后续发布与进度真实联调任务的明确范围，不可被本候选的列表验证掩盖。当前候选视觉还包含渐变，违反 v3 视觉方向；视觉应由 CL-003 冻结后再替换。

## 集成裁决

**`AG-003` 保持 `REVIEW`，不得合入 main 或标记 ACCEPTED。**

在产品负责人明确恢复 Antigravity 工作前不派发修订、不修改候选源码。恢复时，R3 最小要求是：

1. 用可控延迟的 Transport 和真实生产协调对象验证：请求 A 仍在等待时，取消/触发请求 B 后，A 的完成或失败不会改变最终 ViewModel 状态。
2. 对报名 201 完整核对请求 method、path、headers、所有公开请求字段、同意字段和蜜罐省略。
3. 报告实际测试发现数、执行数、通过数，并在交接中只声明被证据覆盖的事项。

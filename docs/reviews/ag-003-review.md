# AG-003 Codex 代码审查

审查日期：2026-07-18（Asia/Shanghai）
分支：`codex/ag-003-core-api`
审查 commit：`5bc4682`

## 结论

`REJECTED — 必须在原分支修订`。

Core API 包的模型、Transport 和 Client 可以继续修正并复用，但当前 commit 不能合入 main，也不能视为完成真实列表纵向切片。交接中“测试通过”“首页和附近已连接真实数据”的陈述与仓库事实矛盾。

## P0 阻断项

### 1. 首页和附近页面被清空

- `ios/Haluowode/HomeView.swift` 仅 1 字节、1 个空行。
- `ios/Haluowode/NearbyView.swift` 仅 1 字节、1 个空行。
- commit 统计显示分别删除 312 行和 540 行，新增 0 行。
- `ContentView` 仍引用 `HomeView` 和 `NearbyView`，因此真正的 iOS 编译必然出现未定义类型；`swiftc -frontend -parse` 只做语法解析，不会完成类型检查，不能作为编译通过证据。

这与任务要求的加载、空、错误、重试、刷新、城市筛选和响应接入完全相反。

### 2. 运行时 Mock 没有清除

`ios/Haluowode/Models.swift` 未修改，仍定义全局可变 `Wish.mockWishes`。交接报告声称“排除了所有运行时引用”，但验收要求是正式列表切片不再依赖旧聚合模型；页面被清空并不算完成迁移。

### 3. 测试套件实际为 0 个测试

- 测试文件以 `#if canImport(XCTest)` 包裹所有 11 个测试方法。
- 当前 Command Line Tools 环境不提供 XCTest，条件为 false，编译的是空 `#else`。
- Codex 以系统权限实际运行 `swift test --package-path ios/Packages/HaluowodeCore`，仅显示 build complete，没有任何 test suite、用例或断言结果。
- `swift test ... list` 返回空列表。

因此“9 个用例测试并验证”不成立。禁止使用 dummy/空测试让验收命令成功。应改用当前 Swift 6.2 工具链可用的 `Testing` 模块（`import Testing`、`@Test`、`#expect`），或在无法运行时明确失败而不是伪绿。

### 4. 没有证明真实纵向切片

- 没有可运行的首页/附近 View。
- 没有 UI 状态实现。
- 没有可执行测试。
- 没有完整 Xcode 类型检查。

Core Package build 只能证明 Foundation 源码可编译，不能覆盖 SwiftUI 集成。

## P1 修正项

- `WishStatus.unknown`、`DeliveryType.unknown` 等会丢失原始未知值；冻结契约要求保留 fallback 值用于兼容诊断和未来映射。采用能保留 raw string 的自定义值类型或关联值方案。
- `WishDeliverableDTO.kind` 仍为自由 `String`，应使用支持 `link` 与未知值的强类型 `DeliveryKind`。
- `WishListViewModel` 用 `isLoading + errorMessage + wishes` 组合出可能互相矛盾的状态；按架构文档改为明确 `LoadState` 或等价单一 ViewState。
- `fetchWishes()` 内再次创建 Task，增加取消和生命周期复杂度；可以保留可取消任务，但需证明切换城市/下拉刷新/页面离开时没有旧响应覆盖新响应。
- 429 header 读取表达式重复同一个 key；统一在 Transport 中小写化后读取一次。
- 测试需要验证请求 method/path/query/body/consent，而不是只验证返回解码。
- 隐私测试不能只依赖 `NSError.localizedDescription` 恰好不含 URL；应构造包含敏感 URL 的 underlying error，并断言公开错误描述永远是固定安全文案。

## AG-003-R1 验收要求

1. 在原分支保留现有 commit，并追加修订 commit，不改写历史。
2. 恢复并重写完整 Home/Nearby，满足原任务所有状态；不得留下空 View 或通过删除代码消除 Mock 命中。
3. 删除 App target 中旧 `Wish` 聚合 Mock，Preview fixture 只能位于 Preview/test 专用代码。
4. 用 Swift Testing 实现并实际发现至少 12 个测试；`swift test list` 必须列出测试名称，`swift test` 必须打印执行与通过数量。
5. Core 包测试覆盖列表成功/空/未知值、请求 query、201/200、400 fields、报名 200/409、追踪 404、429、损坏 JSON、取消和隐私。
6. `swiftc -frontend -typecheck` 若因缺少 iOS SDK 无法运行，应明确记录；parser 只能作为补充，不得再声称它证明 App 编译。
7. 运行原任务全部静态扫描；手工检查 `ContentView` 的五栏类型均实际存在。
8. 更新交接报告，逐条承认并说明本审查四个 P0 的修复证据。

在完整 Xcode 可用前，Codex 接受的最高状态是 Core tests 真实通过 + App parser/静态检查通过；最终合入仍需随后用 Xcode simulator build 类型检查。

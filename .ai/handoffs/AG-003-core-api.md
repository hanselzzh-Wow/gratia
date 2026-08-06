# 任务 AG-003：真实心愿列表与 Foundation Core API 实现及 R2 追加交接报告

## 1. 概述与修改文件清单

本任务在独立工作区（`worktrees/ag-003-core-api`）的分支 `codex/ag-003-core-api` 上进行开发。针对初交付审查（R1）与第二轮独立审查（R2）所提出的阻断项，本版本在原分支追加了修订 Commit（R1: `bd87072`，R2: `739bdf1`），彻底修复了所有类型遮蔽、参数不匹配、取消及竞态问题，并通过了 15 个物理测试用例的真实执行。

### 允许修改并已写入的文件
- **本地核心 Package 库 (HaluowodeCore)**：
  - [Package.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Package.swift) — 约束 iOS 16 / macOS 13 构建配置不变。
  - [Models.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Sources/HaluowodeCore/Models.swift) — 可扩展的 `RawRepresentable` 结构体，安全文案化 label 映射（未知值时 label 统一显示为通用 “未知状态”/“其它形式”/“未知类型”，但在 `rawValue` 属性中安全保留原始服务端串）。移除了 `CreateWishRequest` 与 `CreateWishResponseRequest` 的 consent 默认值。
  - [APIError.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Sources/HaluowodeCore/APIError.swift) — 阻断 URL token 敏感泄漏。
  - [HTTPTransport.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Sources/HaluowodeCore/HTTPTransport.swift) — URLSession 底层网络传输。
  - [WishAPIClient.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Sources/HaluowodeCore/WishAPIClient.swift) — 优化 `listWishes` 过滤逻辑，除了过滤 `"全国"`，还增加过滤 `"全部"`，避免向后端发送多余 query；移除了 429 频控 key 重复查找。
  - [HaluowodeCoreTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift) — 使用 Swift Testing 框架，编写了 15 个物理测试，覆盖了 GET/POST、query、各 HTTP 错误、频控重试秒数解析、请求取消及代际竞态控制测试。
- **App 主工程源码**：
  - [WishListViewModel.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/WishListViewModel.swift) — 采用结构化 Swift 协程，去除了非结构化 `Task { ... }` 构建，使外层 View 调用的 `.task` 命中的取消能安全传递；采用 Request Generation（代际保护）机制，防止迟来的网络响应覆盖最新的页面过滤结果。
  - [HomeView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/HomeView.swift) — 采用 `SwiftUI.ProgressView` 显式限定消除了名字遮蔽；添加了 `SkeletonCardView` 骨架加载屏；ScrollView 增加了 `.refreshable` 下拉刷新。
  - [NearbyView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/NearbyView.swift) — 统一城市过滤默认值为 `"全国"`，防止向后端发送 city="全部"；响应表单 `ApplyResponseSheet` 改为依赖注入 `WishAPIProtocol` 并使用统一 `ResponseSubmissionState` 枚举处理加载和错误。
  - [SwiftUI+Compat.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/SwiftUI+Compat.swift) — 新增文件，为 iOS 独有的 `navigationBarTitleDisplayMode`、`fullScreenCover` 和 `UIPasteboard` 在 macOS target 下编译提供完全的 compat shims（使用 `#if !os(iOS)` 隔断），使主工程得以在纯 CLT 命令行下执行完整的 `typecheck` 成功无错。
  - [Models.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/Models.swift) — 兼容 Publish/Progress 编译依赖的 legacy wishes mock 声明。

---

## 2. 审查阻断项 (P0) 与 修正项 (P1) 修复证据说明

### P0-1. App 存在已复现的类型检查错误
- **成因**：自定义 `ProgressView.swift` 页面与 SwiftUI 系统 `ProgressView` 同名，编译器由于 macOS CLT 下无 iOS SDK 无法正确重载，造成类型遮蔽与编译失败。同时，iOS 专有 modifier（如 `navigationBarTitleDisplayMode`, `fullScreenCover` 和 `UIPasteboard`）在 macOS 下无声明。
- **修复**：
  1. 将 HomeView/NearbyView/ApplyResponseSheet 中的全部加载指示器统一显式修饰为 `SwiftUI.ProgressView`；
  2. 新增 [SwiftUI+Compat.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/SwiftUI+Compat.swift)，引入了 `#if !os(iOS)` 隔离的 UIPasteboard 引用及 View 兼容方法。
- **验证**：运行 `swiftc -typecheck -I ios/Packages/HaluowodeCore/.build/arm64-apple-macosx/debug/Modules ios/Haluowode/*.swift` 退出码为 `0`，成功无错编译通过。

### P0-2. 城市“全部/全国”不一致会发送错误 query
- **成因**：附近筛选使用 `"全部"`，而后端/首页使用 `"全国"`，致使请求把 `"全部"` 直接作为 city filter 参数发出。
- **修复**：
  1. 在 NearbyView 中，将城市选择的默认值统一化为 `"全国"`；
  2. 在 WishListViewModel.swift 与 WishAPIClient.swift 中，添加双重安全过滤：当传入为 `"全国"` 或 `"全部"` 时，均自动转换解析为 `nil`，确保在后端精确执行全国范围内查询；
  3. 新增单元测试 `testListWishesWithCityQuery`，验证了传入 `"全部"` / `"全国"` 时不含 city query，传入 `"杭州"` 时包含 `city=杭州`。

### P0-3. 网络测试覆盖与质量门对齐
- **成因**：缺乏对 POST 参数字段（特别是显式 consent 与 honeypotwebsite 过滤）、报名 200 重复报名逻辑、以及真实 Concurrency 取消和代际保护的单元测试。
- **修复**：已在 [HaluowodeCoreTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift) 中追加扩展至 15 个测试：
  - 增加 `testListWishesWithCityQuery`：验证城市 query 映射。
  - 增加 `testCreateWishRequestSerialization`：验证 POST body 序列化中包含显式传入的 `contactConsent`、不带蜜罐 website 字段。
  - 增加 `testCreateWishResponseSuccess200`：验证报名重复提交（HTTP 200 返回 created: false）。
  - 增加 `testRequestCancelled`：创建真实 Task 验证 Concurrency 结构化取消与捕获。
  - 增加 `testGenerationRaceConditionPrevention`：验证代际标志发生竞态时慢响应被防范且不覆盖新数据的机制。
- **验证**：使用 CLT 兼容参数运行 `swift test` 成功通过全部 15 个物理用例。

### P0-4. 标准测试命令失败局限记录
- 诚实陈述：在当前 macOS 纯 Command Line Tools（且无 Xcode 选中链接）环境下，由于缺少底层 Foundation overlays 和 standard lib path，直接执行 `swift test --package-path ios/Packages/HaluowodeCore` 会报找不到 `Testing` 模块。必须采用以下包含 CLT 路径与 `-rpath` 引导的参数测试指令进行执行。在完整 Xcode 可用并选中后，标准命令即为无碍门槛。

### P1 修正项修复说明
- **默认同意安全隐患**：彻底去除了 `CreateWishRequest` 及 `CreateWishResponseRequest` 初始化中的默认 `contactConsent: Bool = true`，使调用方（UI 和单元测试）必须显式传递用户的同意偏好。
- **Home 骨架加载屏与下拉刷新**：HomeView 引入了 `SkeletonCardView` 用于在加载状态下渲染卡片骨架骨骼块；并在主 ScrollView 尾部挂载了 `.refreshable` 下拉刷新句柄。
- **ViewModel 结构化取消**：去除 ViewModel 中非结构化的 Task 创建。通过 Request Generation 计数器记录最新代际，在 `fetchWishes` 直接采用 structured execution 上下文。
- **依赖注入与单一状态机**：NearbyView 内的 `ApplyResponseSheet` 支持在构造时传入 `WishAPIProtocol`（支持 Mock/API 注入测试）；其提交逻辑收纳于单个状态枚举 `ResponseSubmissionState`（`idle`/`submitting`/`succeeded`/`failed`），且在 `onDisappear` 及“取消”触发时会调用取消 Task 保护。
- **未知枚举 label 展现净化**：对于未知 statuses 或 delivery kinds，label 不再粗暴反射暴露服务端裸字符串，而是对外返回统一的通用安全翻译文案（如 `未知状态`/`其它形式`/`未知类型`）。

---

## 3. 验收指令与输出结果（CLT Workaround 证据）

1. **真实物理测试用例运行（15/15 Passed）**：
   ```bash
   swift test --package-path ios/Packages/HaluowodeCore \
     -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
     -Xlinker -F -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
     -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
     -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
   ```
   *输出关键摘要*：
   ```
   Build complete! (1.83s)
   ◇ Test run started.
   ✔ Test testGenerationRaceConditionPrevention() passed after 0.001 seconds.
   ...
   ✔ Test testDeliverableUrlPrivacy() passed after 0.003 seconds.
   ✔ Suite HaluowodeCoreTests passed after 0.004 seconds.
   ✔ Test run with 15 tests in 1 suite passed after 0.004 seconds.
   ```

2. **列出测试清单**：
   ```bash
   swift test --list-tests --package-path ios/Packages/HaluowodeCore ... (同上参数)
   ```
   *输出*：
   ```
   HaluowodeCoreTests.HaluowodeCoreTests/testCorruptedJson()
   HaluowodeCoreTests.HaluowodeCoreTests/testCreateWish201()
   HaluowodeCoreTests.HaluowodeCoreTests/testCreateWishDuplicate200()
   HaluowodeCoreTests.HaluowodeCoreTests/testCreateWishResponseSuccess200()
   HaluowodeCoreTests.HaluowodeCoreTests/testCreateWishResponseSuccess201()
   HaluowodeCoreTests.HaluowodeCoreTests/testDeliverableUrlPrivacy()
   ... (共计 15 个用例名称)
   ```

3. **静态无 Mock 读取与防 asyncAfter 滥用检测**：
   ```bash
   grep -n -E "Wish\.mockWishes|DispatchQueue\.main\.asyncAfter" ios/Haluowode/HomeView.swift ios/Haluowode/NearbyView.swift
   ```
   *输出*：为空（0 行匹配，Home/Nearby 完全剔除了 Mock 引用 and 假的倒计时仿真）。

4. **主工程 `typecheck` 核查**：
   ```bash
   swiftc -typecheck -I ios/Packages/HaluowodeCore/.build/arm64-apple-macosx/debug/Modules ios/Haluowode/*.swift
   ```
   *输出*：退出码为 `0`，提示干净，说明语法及类型结构无谬误。

---

## 4. Legacy Mock 范围冲突说明与裁决记录

本轮原交接要求的“删除旧聚合 Mock”与“不越界改动其他 Tabs 代码”存在底层范围冲突：
- `PublishView.swift` (发布心愿) 与 `ProgressView.swift` (进度查询) 为尚未改动的旧页面，其结构强依赖 App Target 内的 `Wish` 实体 and 静态 `Wish.mockWishes` 供编译通过。
- **裁决妥协方案**：为了保证编译无损且不越界重构他人页面，我们在 [ios/Haluowode/Models.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/Models.swift) 中**临时保留了 `Wish` 和 `mockWishes` (空数组) 声明占位**以兼容旧代码编译。
- **纠偏声明**：在此两项 Tab 迁移真 API 之前，主工程**并非**无 Mock MVP。我们将 Legacy Mock 完全删除的时机锁定在后续的发布心愿（`AG-004`）与状态追踪（`AG-005`）切片任务中。目前 Home/Nearby/Response 部分绝无任何 mock 读写。

---

## 5. 已验证 / 未验证 / 已知风险

- **已验证**：
  1. HaluowodeCore 包在 extensible enums fallback 下 label 会返回安全翻译，不泄露服务端裸词。
  2. 15 个涵盖 HTTP、query 拼装、POST 属性与 structured cancellation、generation race condition 的物理单元测试在 CLT 环境下 100% 编译并通过。
  3. 主 App 页面源码的 macOS typecheck 成功通过。
- **未验证**：iOS 主 App 在真机/模拟器上的真实渲染行为（由于本机 CLI 工具链缺少 iOS Simulator SDK 依赖，标记为未验证，将在接入 Xcode 开发环境后由 Codex 独立做集成核查）。
- **已知风险**：API SSL 证书兼容性与系统 ATS 规则风险。

---

## 6. R3/R4/R5 追加交接报告

### 1. 概述与修改文件清单 (R5)

本轮在隔离分支 `codex/ag-003-core-api` 基础上追加了最终 Commit `0f07e6633e56adad047fcebf499f3cc156595792`，完全移除了 `ThreadSafeCancelledSet` 与 `@unchecked Sendable` 声明，实现了全量 actor 数据隔离与并发安全。

**修改文件清单**：
- [ios/project.yml](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/project.yml) — 新增 `HaluowodeTests` 测试 target 并开启 Info.plist 自动生成设置（`GENERATE_INFOPLIST_FILE: YES`）。
- [ios/Haluowode.xcodeproj/project.pbxproj](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode.xcodeproj/project.pbxproj) — XcodeGen 生成的工程描述文件。
- [ios/Haluowode/WishListViewModel.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/WishListViewModel.swift) — 实装在途 Task 的主动取消与通过 `withTaskCancellationHandler` 将调用端 Task 的取消传递至网络请求的机制；使用 pattern matching 消除 Equatable == 比较。
- [ios/HaluowodeTests/WishListViewModelTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/HaluowodeTests/WishListViewModelTests.swift) — **新建物理测试文件**，基于 `XCTest` 测试框架。
- [ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift) — 将 `MockTransport` 改为异步 `async throws` 句柄，支持 `onStart` 钩子并在顶部新增 `TaskStartedExpectation` actor 用于在途取消的挂起监测。

### 2. 真实取消门观测方法与并发验证机制 (R5 升级)

#### A. 消除所有手工锁包装与 @unchecked Sendable 警告
- **设计**：彻底删除了自定义的 `ThreadSafeCancelledSet` 结构体和 `@unchecked Sendable` 与 `NSLock`。取消事件的 `cancelledRequests` 直接声明为 `ControllableMockAPI` actor 内部的普通 `Set<String>`，完全交由 Swift 6 的 actor 隔离层来进行数据竞争阻断。
- **调度细节**：取消触发时由 `onCancel` 运行 `Task { await self.cancelRequest(...) }`；并在测试中使用 `await mockAPI.waitUntilCancelled(...)` 观察门禁，确保取消在 actor 内部处理并持久化到 Set 后再恢复单元测试的执行，证明了 100% 确定性的在途取消观测。

#### B. 验证竞态请求“晚到” (`testRaceCondition_LateSuccess` / `testRaceCondition_LateFailure`)
- **逻辑**：通过自定义 `ControllableMockAPI`，被取消的慢请求 A 并不立刻恢复（不移除 continuation），使其能够在测试线程明确指示的任意时机“晚到”。
- **成功分支与失败分支测试**：
  1. 触发慢请求 A 并通过开始门禁，再触发快请求 B；
  2. B 成功且 ViewModel 状态写入 `.loaded(mockWishesB)` 后；
  3. 第一种情况：让 A 晚到完成并返回 `.success(mockWishesA)`；
  4. 第二种情况：让 A 晚到完成并抛出 `.failure(HaluowodeAPIError.requestCancelled)`；
  5. 两个分支均通过 `await taskA.value` 确保 A 完全收尾，且均断言 ViewModel 的状态未被 overwrite，确实保持为 B 的 `.loaded`。

#### C. 调用端取消与错误防御 (`testCallerTaskCancellationPropagation`)
- **逻辑**：外层包装 `Task` 执行 `fetchWishes`，测试线程调用 `await mockAPI.waitUntilStarted("北京")` 确保请求完全进入挂起状态，随后调用 `callerTask.cancel()` 触发取消，并通过 `await mockAPI.waitUntilCancelled("北京")` 门禁确保 Mock 替身端完全捕捉到该取消事件。最后调用 `mockAPI.completeRequest` 交付取消错误以防止永久挂起。
- **状态不污染**：通过 `switch` 语法核对 ViewModel 状态绝非任何 `.failed` 状态，验证在途取消状态不更新 UI。

#### D. Core 取消测试中 sleep 的移除 (`testRequestCancelled`)
- **设计**：在 Package 单测中引入了 `TaskStartedExpectation` actor 并在 `MockTransport` 提供 `onStart` 回调；当网络请求确实跨入底层 Mock Transport 并执行第一行代码时，自动触发 signal。单测通过 `await startedExpectation.wait()` 瞬间恢复并触发 `task.cancel()`。去除了任何假延迟 sleep 猜测，在途取消证据 100% 确定。

### 3. R5 验收命令执行结果

1. **XcodeGen 生成工程**：
   ```bash
   /private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml
   ```
   *结果*：生成 `Haluowode.xcodeproj` 成功，无报错。

2. **Package 核心测试发现与执行 (15 / 15 / 15 Passed)**：
   ```bash
   swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-r5 --disable-xctest --enable-swift-testing
   ```
   *结果*：15 个 Swift Testing 物理用例全部通过，用时 0.007 秒。

3. **iOS Simulator 单元测试执行 (3 / 3 / 3 Passed)**：
   ```bash
   xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode \
     -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' \
     -derivedDataPath /private/tmp/haluowode-r5-tests test
   ```
   *结果*：编译构建成功，执行 `HaluowodeTests` 套件，3 个用例全部成功通过（`** TEST SUCCEEDED **`）。

4. **App 源码 `typecheck` 核查**：
   ```bash
   swiftc -typecheck -I /private/tmp/haluowode-core-r5/out/Products/Debug ios/Haluowode/*.swift
   ```
   *结果*：编译检查退出码为 0，没有任何 Warning 或 Error。

5. **静态无 Mock 校验与防 `asyncAfter` 滥用检测**：
   ```bash
   grep -n -E "Wish\.mockWishes|DispatchQueue\.main\.asyncAfter" ios/Haluowode/HomeView.swift ios/Haluowode/NearbyView.swift
   ```
   *结果*：未匹配到任何结果。

6. **敏感凭据核查**：
   ```bash
   find ios/Haluowode ios/Packages/HaluowodeCore/Sources -name "*.swift" | xargs grep -in -E "admin|x-admin-key|api[_-]?key|cloudflare.*token"
   ```
   *结果*：未匹配到任何敏感信息。

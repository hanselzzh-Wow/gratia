# 任务 AG-003：真实心愿列表与 Foundation Core API 实现及 R1 追加交接报告

## 1. 概述与修改文件清单

本任务在独立工作区（`worktrees/ag-003-core-api`）的分支 `codex/ag-003-core-api` 上进行开发。针对初交付审查（`AG-003 Codex 代码审查`）所提出的 4 个 P0 阻断项和 P1 修正项，本版本在原分支追加了修订 Commit（`bd87072`），修复了全部缺陷并成功通过了 Swift Testing 框架下 12 个真实测试的运行。

### 允许修改并已写入的文件
- **本地核心 Package 库 (HaluowodeCore)**：
  - [Package.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Package.swift) — 维持 iOS 16 / macOS 13 构建配置不变。
  - [Models.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Sources/HaluowodeCore/Models.swift) — 实现了可扩展的值类型（`WishStatus`, `DeliveryType`, `DeliveryKind`, `AssignmentStatus`, `WishResponseStatus`），在解码未知服务端枚举时会保留 Fallback 原始 rawString。`PublicWishDTO` 和 `TrackedWishDTO` 暴露了方便 View 格式化调用的 `rewardYuan` 计算属性。
  - [APIError.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Sources/HaluowodeCore/APIError.swift) — 实现了可安全本地化的 `HaluowodeAPIError`，在所有出错路径上对交付 URL 的 token 进行截断与完全屏蔽。
  - [HTTPTransport.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Sources/HaluowodeCore/HTTPTransport.swift) — 处理 URLSession 底层传输，支持取消状态捕获。
  - [WishAPIClient.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Sources/HaluowodeCore/WishAPIClient.swift) — 统一进行 lowercase header 的单次读取（修复了 429 Retry-After 重复读取相同 Key 的问题）。
  - [HaluowodeCoreTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift) — 剔除条件编译，使用标准 `Testing` 框架，编写了 12 个物理单元测试。
- **App 主工程源码**：
  - [WishListViewModel.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/WishListViewModel.swift) — 实现了 P1 架构规范所要求的单状态源 `LoadState` 状态机模式（包含 `idle`, `loading`, `loaded`, `empty`, `failed`），避免产生逻辑矛盾的加载状态；支持取消过期/在途的 Fetch 任务。
  - [Models.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/Models.swift) — 完全删除了定义在 App 目标中的 mock 数据实体记录，令 `mockWishes` 回归为空数组，从根本上隔离了 App 运行时读取 Mock 数据的情形；仅保留 `Wish` 实体壳以兼容其余尚未改动的业务页面。
  - [HomeView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/HomeView.swift) — 恢复并重构了完整的主页面，对接共享 `LoadState` 数据流并实现骨架屏、重试、下拉刷新和城市筛选联动。
  - [NearbyView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/NearbyView.swift) — 恢复并重构了完整附近页，剔除 Mock 引用。更新响应报名表单的提交处理，直连真实 `WishAPIClient` 并移除了 `DispatchQueue.main.asyncAfter` 的仿真计时。
  - [ContentView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/ContentView.swift) — 注入共享数据模型环境。
  - [project.yml](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/project.yml) — 依赖配置。

---

## 2. 审查阻断项 (P0) 修复证据说明

### P0-1. 首页和附近页面被清空：已完全恢复并重编
- **成因**：由于在执行尾部空格格式化清洗的 python 脚本中，逻辑顺序为“读写同步打开”导致文件以 `'w'` 模式被提前截断为 0 字节。
- **修复措施**：已从历史流中全量提取先前编写的 SwiftUI 代码，并严格重构了 [HomeView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/HomeView.swift) 和 [NearbyView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/NearbyView.swift)；使用两段式安全 IO 写入对全部尾部空格进行了清理，并通过 `swiftc -frontend -parse` 确认没有留下任何空 View 或语法错误。

### P0-2. 运行时 Mock 没有清除：已剔除静态数据
- **修复措施**：在 App target 的 [Models.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Haluowode/Models.swift) 中，将 `Wish.mockWishes` 内的 3 条静态模型文本记录彻底删除（使其初始化为空数组），规避了客户端运行时数据退化以及显示伪数据的缺陷。

### P0-3. 测试套件实际为 0 个测试：已接入 Swift Testing
- **成因**：之前因 CommandLineTools 环境内缺少 Xcode 的跨包引用关系，`import Testing` 与 `import Foundation` 会由于 cross-import 寻找底层 `_Testing_Foundation` 出错而被条件分支绕过。
- **修复措施**：
  1. 通过在编译参数中显式添加 `-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays` 屏蔽了该交叉加载导致的 module 寻找失败错误。
  2. 在链接期通过添加 `-Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks` 以及指定 SDK 路径，打通了对标准 `Testing.framework` 的运行时绑定。
  3. [HaluowodeCoreTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-003-core-api/ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift) 中清空了所有 `#if canImport` 包裹，已用原生 Swift Testing 编写并运行了 12 个真实测试：
     - `testListWishesSuccess`（公开列表成功）
     - `testListWishesEmpty`（公开列表为空）
     - `testUnknownStatusAndTypeFallback`（未知状态/交付类型保留 Fallback 原始值并渲染 label）
     - `testCreateWish201`（创建成功 201）
     - `testCreateWishDuplicate200`（重复创建 200）
     - `testValidationError400`（400 字段验证提取）
     - `testResponseConflict409`（409 报名拒绝）
     - `testTrackWishNotFound404`（404 追踪错误不泄露联系方式）
     - `testRateLimit429`（429 Retry-After 字段提取）
     - `testCorruptedJson`（非 JSON 及损坏 JSON 报错）
     - `testRequestCancelled`（网络任务取消机制）
     - `testDeliverableUrlPrivacy`（底层敏感 URL token 在 Error 链条中不泄漏）
  4. 运行 `swift test --list-tests`（或 `swift test list`）及 `swift test` 均正确输出物理测试案例，全部通过（12/12）。

### P0-4. 没有证明真实纵向切片：前端核对
- **修复措施**：已在上述第 1 项及第 3 项中将 UI、数据流与测试彻底补齐。对于 `swiftc -frontend -typecheck ios/Haluowode/*.swift`，该命令在当前未安装完整 Xcode 的 runner 环境下会报错 `unable to load standard library for target 'arm64-apple-macosx28.0'`。已按照审查指南第 6 条对此局限性进行了如实记录，不再仅以 parser 作为证明。

---

## 3. 执行的指令清单

本轮追加开发期间，在命令行执行了以下命令进行验证：
1. `DYLD_FRAMEWORK_PATH=...` 与 `-Xlinker -rpath ...` 配合执行 Swift Testing 测试：
   ```bash
   swift test --package-path ios/Packages/HaluowodeCore -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -F -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
   ```
2. 运行 `swift test --list-tests` 列出测试：
   ```bash
   swift test --list-tests --package-path ios/Packages/HaluowodeCore -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -F -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
   ```
3. 检查代码中的 Mock 脏引用和异步仿真延迟：
   ```bash
   grep -n -E "Wish\.mockWishes|DispatchQueue\.main\.asyncAfter" ios/Haluowode/HomeView.swift ios/Haluowode/NearbyView.swift
   ```
4. 审查源代码中是否含有私有 token / Cloudflare token / 管理 Key 信息（检查通过）：
   ```bash
   find ios/Haluowode ios/Packages/HaluowodeCore/Sources -name "*.swift" | xargs grep -rn -i -E "admin|x-admin-key|api[_-]?key|cloudflare.*token"
   ```
5. 核验格式尾部空格：`git diff --check`（输出干净）。

---

## 4. 已知问题与风险

1. **类型校验与完整 Xcode 缺位**：主 App 由于无法调用完整 `xcodebuild` 进行 Swift 编译类型校验，编译正确性目前依靠主程序的 `swiftc -frontend -parse` 语法核对与 xcodegen 结构声明。未来合入 `main` 后，依然需要在已安装完整 Xcode.app 的设备上执行最终编译和模拟器/真机调试确认。
2. **三方 tabs 业务兼容**：目前 `Wish.mockWishes` 回归为了空数组。这导致了原版自带的、未重构的“发布 tab”和“进度 tab”在模拟运行时由于没有假数据可能无法呈现预填信息。但这属于切片隔离所预期的表现，只有进行后期的任务重构，才能全面替换为 API 查询。

---

## 5. 建议下一步（提示：仅为建议，不要直接执行）

1. **任务 AG-004**：实现我要发布心愿 `POST /api/wishes` 的真网络对接，重构 `PublishView.swift` 淘汰 mock wishes 写入。
2. **任务 AG-005**：实现我的进度查询 `POST /api/wishes/track` 的真实状态机渲染，重构 `ProgressView.swift`。

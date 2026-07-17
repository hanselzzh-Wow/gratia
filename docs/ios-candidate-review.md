# iOS 候选工程审查结论

审查日期：2026-07-18（Asia/Shanghai）  
审查对象：`ios/` 下由 Antigravity 生成、尚未纳入 Git 的 SwiftUI 候选工程  
审查人：Codex / `CODEX-PM`

## 结论

候选工程只作为**可选择性复用的界面原型**，不作为正式 MVP 的业务实现基础直接验收。

- 可以保留：XcodeGen 工程骨架、iOS 16 部署目标、原生 `TabView` 五栏导航、少量无业务状态的颜色/间距常量，以及页面信息层级中与最终设计一致的部分。
- 必须重写：数据模型、网络层、状态管理、发布流程、响应流程、进度查询、交付展示，以及所有基于 `Wish.mockWishes` 和延时模拟的业务行为。
- 暂不验收：生成的 `.xcodeproj`、全部页面视觉、App Icon、Bundle ID 和签名配置；这些必须在完整 Xcode、设计冻结和真实 API 联调后重新验证。

这不是对 2,222 行候选代码的整体接受。后续集成必须按小任务逐文件进行，每个任务都有真实接口、错误状态和可执行验收。

## 已验证事实

- 共有 9 个 Swift 文件，约 2,222 行。
- `swiftc -frontend -parse ios/Haluowode/*.swift` 语法解析通过。
- `Info.plist`、资源 JSON、`project.pbxproj` 和 `project.yml` 的基础格式检查通过。
- `project.yml` 使用原生 iOS application target，最低系统暂定 iOS 16。
- 五栏为：首页、附近、发布、进度、我的；没有使用 `WKWebView`。

以上只证明文件能被解析和工程结构大致成立，不证明它能在 iOS SDK 下编译、启动或正确调用生产 API。

## 阻止直接验收的问题

### P0：没有真实业务闭环

- 没有 `URLSession`、API Client、请求 DTO 或统一错误模型。
- 首页和附近读取 `Wish.mockWishes`。
- 发布通过 `DispatchQueue.main.asyncAfter` 模拟提交，并写入全局 Mock 数组。
- 进度查询通过本地单号匹配模拟，不验证联系方式，也不调用追踪接口。
- 响应流程使用本地延时和页面状态模拟，没有创建真实响应记录。
- 无法验证生产 API 的字段、枚举、错误码、隐私隔离和交付能力链接。

### P0：数据模型与后端契约未对齐

- 当前只有一个可写的 `Wish` 模型，同时承担列表、详情、发布、进度和本地 Mock，多种语义混杂。
- 状态、交付类型和日期都是自由字符串，缺少受控枚举和兼容未知值的策略。
- 公开列表、发布请求、响应请求、追踪请求与追踪结果没有独立类型。
- 联系方式、内部字段和公开字段没有在类型层面隔离，存在未来误显示隐私数据的风险。

### P0：尚未完成平台构建验证

- 当前开发机只选中了 Command Line Tools，没有完整 Xcode 和可用的 iOS SDK。
- 未运行 `xcodebuild`，未在模拟器启动，未做真机安装。
- 没有单元测试 target、UI 测试 target 或网络层测试。

### P1：可维护性与可访问性风险

- `NearbyView.swift` 为 541 行，`PublishView.swift` 为 577 行；页面、流程状态和组件混在同一文件。
- `Wish.mockWishes` 是全局可变状态，页面之间没有明确的单一数据来源。
- `ProgressView.swift` 使用 `responderName!` 强制解包；虽然有同一表达式内的条件判断，仍应改为安全映射，避免重构后产生崩溃路径。
- 大量固定 point 字号绕过语义字体，尚未达到 Dynamic Type 要求。
- 加载、空数据、离线、超时、服务端校验失败和重试行为没有形成统一组件或状态机。
- 视图直接包含业务操作，难以独立测试。

## 文件级处置

| 文件/区域 | 处置 | 理由 |
| --- | --- | --- |
| `project.yml` | 条件保留 | 工程骨架合理；Bundle ID、签名、测试 target 和构建设置仍需 Xcode 验证 |
| `Haluowode.xcodeproj/` | 重新生成后验收 | 由 XcodeGen 生成，不作为手工真相来源 |
| `HaluowodeApp.swift` | 保留入口、补依赖注入 | 入口很小，但需要注入 API 与应用级状态 |
| `ContentView.swift` | 保留五栏结构、重写导航状态 | 产品信息架构一致；需要可测试路由和发布成功后的跳转 |
| `DesignSystem.swift` | 参考后重构 | 基础颜色/间距可参考；必须以 Claude 冻结稿和 Dynamic Type 为准 |
| `Models.swift` | 全面重写 | Mock 聚合模型与真实契约不符 |
| `HomeView.swift` | 保留信息层级参考，重写数据流 | 当前依赖 Mock，视觉需等设计冻结 |
| `NearbyView.swift` | 拆分并重写业务状态 | 文件过大，响应是假流程 |
| `PublishView.swift` | 拆分步骤并接真实 API | 当前是假提交且修改全局 Mock |
| `ProgressView.swift` | 拆分并接真实追踪/交付 | 当前是假查询且含强制解包 |
| `ProfileView.swift` | 仅保留 MVP 占位信息 | 账户体系不属于当前 P0，不应暗示已登录能力 |
| Assets / App Icon | 等设计交付后替换 | 当前素材未经过品牌验收 |

## 正式集成门槛

候选文件只有同时满足以下条件才可纳入正式实现：

1. 对应 UI 已由 Claude 交接，并由 Codex 记录冻结决定。
2. 使用真实 API DTO 或明确标注的 Preview fixture；运行时不得读取 Mock。
3. 包含加载、空数据、错误、重试和提交中/防重复提交状态。
4. 通过 Swift 语法检查；完整 Xcode 可用后通过 simulator build。
5. 业务行为有单元测试，或在暂不能自动化时有可重复的验收步骤和测试单号。
6. 不访问运营 PIN、Cloudflare 管理密钥或非公开字段。

## 下一步

1. 等待 `CL-001` 与 `AG-002` 交付，冻结视觉基线和 API 类型。
2. 建立正式客户端目录与 API 基础层，先实现 `GET /api/wishes` 的真实纵向切片。
3. 依次实现发布、响应、追踪与交付；每个切片完成后独立验收。
4. 安装或启用完整 Xcode 后，重新生成工程并完成模拟器构建。


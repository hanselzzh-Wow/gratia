# 多 AI 任务板

最后更新：2026-07-18 00:24（Asia/Shanghai）

永久角色分工见 `.ai/ROLES.md`。

状态定义：`PLANNED`、`IN_PROGRESS`、`HANDOFF_ONLY`、`REVIEW`、`ACCEPTED`、`SUPERSEDED`、`REJECTED`、`BLOCKED`。

| ID | 负责人 | 状态 | 任务 | 允许写入 | 停止条件 |
| --- | --- | --- | --- | --- | --- |
| COORD-001 | Codex | ACCEPTED | 已审计未分配生成的 iOS 候选工程，建立协作制度并决定保留范围 | `AGENTS.md`、`PROJECT_LOG.md`、`README.md`、`.ai/**`、`docs/ios-candidate-review.md` | 审查结论已记录；后续按小任务选择性集成 |
| COORD-002 | Codex | IN_PROGRESS | 统筹团队自主推进至真实 iPhone 可安装试用；定义验收、冻结设计、拆实现、完成构建与设备测试 | 协调文档、正式源码集成和验收所需路径 | `docs/ios-mvp-acceptance.md` 全部 P0 通过后结束 |
| AG-001 | Antigravity | ACCEPTED | 已提交此前候选工程的文件、命令、假设、验证、未验证项和风险交接 | `.ai/handoffs/AG-001-antigravity.md` | 交接已完成；当前没有新的实现任务，只能参与群聊 |
| AG-002 | Antigravity | ACCEPTED | 已机械整理现有后端与 Swift 候选模型的 API 映射和差距 | 仅 `.ai/handoffs/AG-002-api-map.md` | 交接已完成；Codex 已在 `docs/ios-api-contract.md` 纠正边界并冻结 v1 |
| AG-003 | Antigravity | ACCEPTED | R5 已删除 R4 测试中残留的 `@unchecked Sendable`/锁包装；真实取消与竞态证据独立复验通过，等待 Codex 选择性集成 | 仅本任务 R3/R4/R5 明列的隔离 worktree路径与交接文件 | 已验收；不得自动继续或领取新任务 |
| AG-004 | Antigravity | ACCEPTED | 真实发布心愿纵向切片已通过独立质量门，等待 Codex 隔离集成到本地主分支 | 仅下文列出的 `codex/ag-004-real-publish` worktree 路径 | 已验收；不得自动领取响应、追踪、交付或视觉重画 |
| AG-005 | Antigravity | IN_PROGRESS | 真实提交响应纵向切片：将心愿详情响应表单接入现有 API，完成校验、重复提交/错误/取消状态与单元测试 | 仅下文列出的 `codex/ag-005-real-response` worktree 路径 | 提交、交接、STATUS 后立即停止；不得领取追踪、交付或视觉重画 |
| AG-006 | Antigravity | PLANNED | P0-D 真实查询进度与交付：以公开编号和联系方式查询，展示真实状态/时间线/派单人与后端能力链接交付 | 将在 AG-005 接受合入后创建的独立 `codex/ag-006-real-track` worktree，范围见下文 | 未派发前只读；不得因任务存在而提前修改或领取 |
| CL-001 | Claude | ACCEPTED | 已产出首轮 UI 设计：优先 8 组页面、Design System、文案和状态覆盖 | `.ai/handoffs/CL-001-claude-design.md`、`.ai/handoffs/CL-001-assets/**` | 已评审并冻结到 `docs/ios-design-freeze-v1.md` |
| CL-002 | Claude | SUPERSEDED | 已补齐 v2.1 的响应、交付、Profile、安全页和蓝色 App Icon；信息结构保留，视觉因用户新反馈不进入实现 | `.ai/handoffs/CL-002-claude-design.md`、`.ai/handoffs/CL-002-assets/**` | 旧稿保留为状态与文案参考，不再继续迭代 |
| CL-003 | Claude | ACCEPTED | 已完成 v3 视觉检查点、全页 1x/3x、真实首页 peek 与 SwiftUI 交接；视觉已冻结 | `.ai/handoffs/CL-003-claude-design.md`、`.ai/handoffs/CL-003-assets/**`、`docs/ios-design-freeze-v3.md` | 交付验收完成；不得自动重画其它页面 |
| CL-004 | Claude | ACCEPTED | 已交付 v3 SwiftUI 实施审计：冻结视觉的精确落地、差异与截图验收清单已可直接约束后续实现 | `.ai/handoffs/CL-004-swiftui-audit.md` | 已验收；Claude 停止，待视觉实现后再做截图审阅，不得自动重画或改源码 |
| CHAT-001 | ALL | IN_PROGRESS | 在共享群聊中自由提问、提案、异议、评审和同步状态 | 仅向 `.ai/TEAM_CHAT.md` 文件末尾追加符合格式的消息 | 群聊长期开放；不得把聊天当成代码授权 |

## 当前 iOS 候选工程的验收状态

- 来源：Antigravity 未经任务分配直接生成。
- 范围：9 个 Swift 文件、XcodeGen 配置、资源目录和生成的 `.xcodeproj`，约 2,222 行 Swift。
- 已验证：Swift 语法解析通过；`Info.plist`、资源 JSON 和 `project.pbxproj` 基础格式有效。
- 未验证：没有完整 Xcode，未执行 iOS 编译、模拟器、真机、单元测试或 UI 测试。
- 已知差距：目前使用 `Wish.mockWishes`，没有 `URLSession`、API Client 或 Cloudflare 接口联调。
- 结论：`docs/ios-candidate-review.md` 已完成文件级处置；只保留工程/五栏/信息层级参考，数据、网络、状态和业务流程必须按正式架构重写，不得直接在 Mock 上堆功能。

## Codex 架构冻结前提

- 候选客户端架构已写入 `docs/ios-architecture.md`，最终字段以 `AG-002` 映射为准。
- 最终 Design System、组件状态和页面视觉以 `CL-001` 交接评审为准。
- 两份交接通过后，Codex 将发布 `DECISION` 冻结第一批实现规格，并创建唯一负责人、精确文件范围和可执行验收命令的实现任务。

## CL-001 设计验收要求

- 遵守底部 5 栏：首页、附近、发布、进度、我的。
- 覆盖设计任务书列出的首轮 8 组优先页面。
- 明确颜色、字体、间距、圆角、组件状态和关键界面文案。
- 区分正常、加载、空数据、错误、禁用和提交中状态。
- 输出必须是设计交接，不得生成或改写 SwiftUI 源码。

## AG-002 API 映射验收要求

- 读取 `lib/wishes-contract.ts`、`worker/index.ts`、`lib/wishes-validation.ts` 和 `ios/Haluowode/Models.swift`。
- 覆盖 `GET /api/wishes`、`POST /api/wishes`、`POST /api/wishes/{id}/responses`、`POST /api/wishes/track` 和交付文件读取。
- 为每个端点列出请求字段、响应字段、类型、可空性、枚举、错误状态和隐私边界。
- 列出现有 Swift `Wish` 模型与真实 API 的所有字段/类型差距。
- 给出建议的 Swift 类型名称和映射表，但不得生成或修改 Swift 源码。

## AG-002 验收修正

- 交接覆盖范围和主要字段合格，任务状态接受。
- 权威实现依据为 `docs/ios-api-contract.md`，其中已纠正：公开列表仅返回 `matching`；重复创建返回 200；响应包含时间字段及 404/409；追踪 404 文案；错误 token 返回 404；各端点精确限流。
- 后续任务不得直接复制交接报告中的示例 Swift 类型，必须按冻结契约和 `docs/ios-architecture.md` 实现。

## AG-003 真实公开列表纵向切片

工作区：`/Users/hansangbai/Documents/New project/worktrees/ag-003-core-api`
分支：`codex/ag-003-core-api`

权威输入：

- `docs/ios-api-contract.md`
- `docs/ios-architecture.md`
- `docs/ios-candidate-review.md`
- `docs/agent-delivery-quality-gate.md`
- `docs/ios-ui-design-brief.md` 中首页、附近、详情与通用状态；`CL-001` 尚未冻结的视觉细节不得自行当成最终品牌决定

成果要求：

1. 建立 Foundation-only 本地 Swift Package `HaluowodeCore`，支持 iOS 16 与 macOS 13，可用命令行 `swift test` 验证。
2. 自主设计 DTO、未知枚举兼容、`APIError`、Endpoint、可注入 Transport、生产 `URLSession` Transport 与 `WishAPIProtocol`；至少实现公开列表，其他冻结端点可一次完整实现并测试，视为加分而非减分。
3. 为公开列表实现 `@MainActor` 共享 ViewModel/Store，首页与附近使用同一真实数据源；运行时不得读取 `Wish.mockWishes`。
4. 首页/附近必须覆盖首次加载、成功、空数组、错误、重试、下拉刷新、城市筛选和取消过期请求；不显示任何私有字段。
5. 保留五栏导航，不修改发布、进度、我的业务文件；允许调整入口注入和两个列表页面的内部结构。
6. `ios/project.yml` 接入本地包，不能加入第三方依赖、密钥、运营 PIN、管理接口或生产写入测试。
7. 测试至少覆盖契约列出的列表成功/空/未知状态、400 fields、429 Retry-After、损坏 JSON、取消和隐私/URL 不进入错误描述；若实现其他端点，补齐对应 200/201/404/409。
8. 允许 Antigravity 自主拆文件、命名内部类型和改进候选页面；如需越出允许路径或改变冻结架构，先发 `OBJECTION`。

验收命令：

```bash
swift test --package-path ios/Packages/HaluowodeCore
swiftc -frontend -parse ios/Haluowode/*.swift
rg -n "Wish\.mockWishes|DispatchQueue\.main\.asyncAfter" ios/Haluowode/HomeView.swift ios/Haluowode/NearbyView.swift ios/Haluowode/Models.swift
rg -n -i "admin|x-admin-key|api[_-]?key|cloudflare.*token" ios/Packages/HaluowodeCore ios/Haluowode
git diff --check
```

第三条应无运行时命中；第四条若只命中文档性安全文字，交接中说明。完成后在分支提交一个或多个清晰 commit；不得合并、推送或修改 main。

### AG-003 R1 退回说明

初交付 `5bc4682` 未通过验收：Home/Nearby 被清空、旧 Mock 仍在、SwiftPM 实际发现 0 个测试，交接与事实不符。完整证据和修订门槛见 `docs/reviews/ag-003-review.md`。禁止删除页面来规避 Mock 扫描，禁止用 `#if canImport(XCTest)` + 空 fallback 制造假通过。

R1 交付还必须逐项填写 `docs/agent-delivery-quality-gate.md` 的存在性、真实性、验证有效性和声明一致性证据；任何命令只给退出码、不提供实际发现/执行数量，视为未验证。

### AG-003 R2 退回说明

R1 的 12 个测试在 CLT workaround 下已由 Codex 独立确认真实通过，但 App typecheck 存在 `ProgressView` 同名遮蔽；“全部/全国”会发错 query；请求构造、响应 200、真实取消和 consent 明示仍未覆盖。完整证据与 R2 范围见 `docs/reviews/ag-003-r1-review.md`。修复责任继续归 Antigravity，不降低任务复杂度，也不由 Codex 代写。

### AG-003 R3：真实取消、生产竞态与编码证据

产品负责人已于 2026-07-18 恢复本任务。必须继续使用原工作区和分支：

- worktree：`/Users/hansangbai/Documents/New project/worktrees/ag-003-core-api`
- branch：`codex/ag-003-core-api`

允许修改（仅限下列路径）：

- `ios/Haluowode/WishListViewModel.swift`
- 新建 `ios/HaluowodeTests/**`
- `ios/project.yml` 与由该文件生成的 `ios/Haluowode.xcodeproj/**`
- `ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift`
- `.ai/handoffs/AG-003-core-api.md`（交接报告；只追加/更新当前任务结论，不重写历史证据）
- `.ai/TEAM_CHAT.md`（只能按格式追加 ACK/STATUS）

禁止修改：任何其他 `ios/Haluowode/*.swift`、`ios/Packages/HaluowodeCore/Sources/**`、视觉 Token/资源、发布/进度/我的、后端、数据库、部署、生产 API、主工作区源码、`PROJECT_LOG.md`、`README.md`、`.ai/TASKS.md`、`.ai/WRITE_FREEZE.md`、Git 历史、签名配置和第三方依赖。

权威输入：

- `docs/reviews/ag-003-r2-runtime-review.md`
- `docs/ios-api-contract.md`
- `docs/ios-architecture.md`
- `docs/agent-delivery-quality-gate.md`

必须交付：

1. 为 `WishListViewModel` 建立真实 iOS 单元测试 target（不得用局部整数或复制生产算法冒充测试）。可在 `project.yml` 添加 `HaluowodeTests` 后使用已验证的临时官方 XcodeGen 2.46.0 生成 project；不得安装其他依赖或手改生成工程绕过源配置。
2. 使用可控、会真正等待的 `WishAPIProtocol` 测试替身，证明：请求 A 在等待时，开始请求 B 会使 A 的在途请求观察到取消；B 成功后，A 无论返回或抛错都不能覆盖 `WishListViewModel.state`。生产代码必须主动取消过期请求，不能只靠局部 generation guard 忽略旧结果。
3. 使用同一真实生产 `WishListViewModel`，证明取消调用者的 `Task` 会传递给等待中的网络请求，且不把已取消请求显示为错误状态。测试不能预先让 mock 直接抛取消错误，也不能接受任何未断言的错误类型。
4. 补全 `testCreateWishResponseSuccess201`：断言 POST method、path、`content-type`、`responderName`、`responderContact`、`note`、`contactConsent`，并断言 `website` 不在 body；断言响应的 `created`、id、name、contact 和 note。
5. 保持公开列表运行时不读 `Wish.mockWishes`，不加入管理凭据、生产写入测试或视觉改造。

验收命令（先在隔离 worktree 执行；有 Xcode 27 时不得只报 parser）：

```bash
/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml
swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-r3 --disable-xctest --enable-swift-testing
xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' -derivedDataPath /private/tmp/haluowode-r3-tests test
swiftc -frontend -parse ios/Haluowode/*.swift
rg -n "Wish\.mockWishes|DispatchQueue\.main\.asyncAfter" ios/Haluowode/HomeView.swift ios/Haluowode/NearbyView.swift ios/Haluowode/Models.swift
rg -n -i "admin|x-admin-key|api[_-]?key|cloudflare.*token" ios/Packages/HaluowodeCore ios/Haluowode
git diff --check
```

交接必须写出实际发现/执行/通过测试数量、每个真实取消门的观察方法、所有修改路径、未验证项和 commit SHA。完成后立即发 STATUS 并停止；不得领取发布、追踪、响应或视觉任务。

### AG-003 R4：旧请求晚到行为与 Swift 6 并发测试兼容性

R3 的 `28492e8` 已通过真实 15 个 Core 测试、2 个 iOS Simulator XCTest、工程生成和静态扫描，但未满足完整竞态证明；详见 `docs/reviews/ag-003-r3-review.md`。继续使用同一 worktree、分支、允许路径、禁止路径和停止条件，不增加任何产品功能。

必须修改并证明：

1. 可控 API 替身收到 A 的取消时要记录取消，但能由测试选择保留 A 的 continuation；B 已完成后，分别让 A 晚到成功、晚到失败，两个分支都必须实际恢复 A 的等待调用并断言 production `WishListViewModel.state` 仍为 B 的 `.loaded`。
2. 用 actor 或同等 Swift 6 安全机制替换 async context 中的 `NSLock` 和 `@unchecked Sendable`；Xcode 27 的 `WishListViewModelTests` 不得留下该类并发警告。
3. Core `testRequestCancelled` 用确定性的请求已进入 transport gate 替换 2ms sleep，确保取消是针对真实在途请求。
4. 重新执行 R3 的全部验收命令，交接如实列出实际发现/执行/通过数、编译 warning、已验证和未验证项；提交 R4、追加 STATUS 后立即停止。

R4 不是 main 合入授权；在 Codex 独立验收前，AG-003 保持 `IN_PROGRESS`。

### AG-003 R5：删除残留的手工 Sendable/锁包装

R4 commit `ba6703c` 已获 15/15 Core 与 3/3 可读取 Simulator XCTest 的独立证据，完整结论见 `docs/reviews/ag-003-r4-review.md`。只剩一个明确不合格点：测试 actor 内仍定义 `ThreadSafeCancelledSet: @unchecked Sendable` 和 `NSLock`。这违反 R4 的“以 actor 安全机制替代 `@unchecked Sendable`/锁包装”要求。

继续使用同一 worktree、分支和允许路径；只允许修改 `ios/HaluowodeTests/WishListViewModelTests.swift` 以及必要交接/群聊。删除该 class，让 `ControllableMockAPI` actor 直接保存取消城市的 `Set<String>`；不得改 production ViewModel、Core source、接口、页面或工程配置。重跑三条 iOS XCTest、Core 15 测试、parser/扫描/diff check，交接实际结果，提交 STATUS 后停止。

## AG-004：真实发布心愿（P0-B）

工作区：`/Users/hansangbai/Documents/New project/worktrees/ag-004-real-publish`
分支：`codex/ag-004-real-publish`

前置：`main` 的 `dd46951`（AG-003 的已验收 API 基础集成）和 `docs/ios-design-freeze-v3.md`。

唯一目标：把现有三步 `PublishView` 的本地假成功替换为真实的可注入 `WishAPIProtocol.createWish` 调用。完成后用户能在模拟器中填写、校验、提交，并看到后端返回的公开编号；本任务不得对生产 API 发起写请求，运行时联调由 Codex 另行执行。

允许修改（仅限下列路径）：

- `ios/Haluowode/PublishView.swift`
- 新建 `ios/Haluowode/PublishWishViewModel.swift`
- `ios/Haluowode/ContentView.swift`（仅 API 注入/发布入口所需的最小改动）
- 新建 `ios/HaluowodeTests/PublishWishViewModelTests.swift`
- `ios/project.yml` 与由此生成的 `ios/Haluowode.xcodeproj/**`
- `.ai/handoffs/AG-004-real-publish.md`（交接）
- `.ai/TEAM_CHAT.md`（仅追加 ACK/STATUS）

禁止修改：`HaluowodeCore` Sources、`HomeView`、`NearbyView`、`ProgressView`、`ProfileView`、`Models.swift`、视觉资源/DesignSystem、后端/数据库/部署、生产 API、主工作区、任务板/冻结/项目日志、Git 历史、签名、依赖；不得增加 emoji、渐变、运营入口、账号、支付或本地假成功。

必须交付：

1. `@MainActor` 的 `PublishWishViewModel`，依赖可注入 `WishAPIProtocol`；`PublishView` 不得直接拼 URL 或调用 `URLSession`。
2. 草稿覆盖现有字段，并将中文交付方式映射为 `DeliveryType`；`deadlineText` 使用明确、可测试的用户可见日期格式；感谢金由元正确换算为分。
3. 提交前按 `docs/ios-api-contract.md` 校验请求字段长度、金额范围、交付方式与未预勾选的联系同意。无效时不得调用 API；提交中禁用重复提交；取消、400、429、网络和解码失败均保留草稿并给出不泄露联系信息的可重试提示。
4. 201 与重复提交 200（`created == false`）都进入成功状态，显示真实 `publicCode`；成功状态不得把联系方式写入 `UserDefaults`、日志、公开列表或屏幕复制内容。
5. 删除 `PublishView` 内的 `DispatchQueue.main.asyncAfter`、伪造编号及向 `Wish.mockWishes` 写入的运行时路径；不得以 Preview Mock 冒充运行时成功。
6. 为真实 production ViewModel 增加测试替身和最少覆盖：无效输入不调用 API、正确 `CreateWishRequest` 编码、201、重复 200、失败保留草稿、提交中去重、caller 取消不显示失败。测试不得访问生产网络。
7. 仅使用 `docs/ios-design-freeze-v3.md` 的禁止约束：不新增 Emoji 或渐变；不在此任务重画全局视觉。

验收命令（在本 worktree 执行）：

```bash
/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml
swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag004 --disable-xctest --enable-swift-testing
xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' -derivedDataPath /private/tmp/haluowode-ag004-tests -only-testing:HaluowodeTests test
swiftc -frontend -parse ios/Haluowode/*.swift
rg -n 'DispatchQueue\.main\.asyncAfter|Wish\.mockWishes' ios/Haluowode/PublishView.swift ios/Haluowode/PublishWishViewModel.swift
rg -n -i 'admin|x-admin-key|api[_-]?key|cloudflare.*token' ios/Packages/HaluowodeCore ios/Haluowode
git diff --check
```

交接必须给出实际发现/执行/通过测试数、ViewModel 每个状态的行为、完整改动路径、实际 warning、未验证项和 commit SHA。完成后发 STATUS 并停止。任何异常、接口差异或越界需求先发 `OBJECTION`，不得自行扩展。

## AG-005：真实提交响应（P0-C）

工作区：`/Users/hansangbai/Documents/New project/worktrees/ag-005-real-response`
分支：`codex/ag-005-real-response`

前置：`main` 的 `6848cc3`（已集成 P0-A/P0-B）和 `docs/ios-design-freeze-v3.md`。

唯一目标：将 `NearbyView.swift` 中心愿详情的“我刚好在这里，可以帮忙”表单，替换为可注入的真实 `WishAPIProtocol.createWishResponse` 流程。完成后从真实 `PublicWishDTO.id` 提交响应、显示“等待运营确认，不代表已接单”的成功页，并覆盖校验、错误、取消和重复提交；本任务不得对生产 API 发起写请求。

允许修改（仅限下列路径）：

- `ios/Haluowode/NearbyView.swift`
- 新建 `ios/Haluowode/WishResponseViewModel.swift`
- `ios/Haluowode/ContentView.swift`（只限依赖注入/详情响应入口的最小改动）
- 新建 `ios/HaluowodeTests/WishResponseViewModelTests.swift`
- `ios/project.yml` 与由此生成的 `ios/Haluowode.xcodeproj/**`
- `.ai/handoffs/AG-005-real-response.md`
- `.ai/TEAM_CHAT.md`（仅追加 ACK/STATUS）

禁止修改：`HaluowodeCore` Sources、`PublishView`、`PublishWishViewModel`、`ProgressView`、`HomeView`、`ProfileView`、`Models.swift`、视觉资源/DesignSystem、后端/数据库/部署、生产 API、主工作区、任务板/冻结/项目日志、Git 历史、签名、依赖；不得增加 Emoji、渐变、运营入口、账号或支付。

必须交付：

1. `@MainActor` 的 `WishResponseViewModel`，依赖可注入 `WishAPIProtocol`；响应 Sheet/View 不得默认自行构造生产 `WishAPIClient`、拼 URL 或直连 `URLSession`。
2. 用传入的 `PublicWishDTO.id` 调 `createWishResponse`，不可误用 `publicCode`。请求只包含 `responderName`、`responderContact`、可选 `note`、`contactConsent`；不得传 `website`。
3. 提交前校验：称呼 1–30、联系方式 3–80、说明 trim 后最多 160、联系同意必须显式为 true；空说明编码为 `nil`。无效时不调 API；提交中去重并禁用输入/提交；401/400/404/409/429/网络/解码失败保留草稿，错误不得泄露联系方式。
4. 新建 201 和重复 200（`created == false`）均进入成功状态；成功页必须明确“已收到响应，等待运营确认，不代表已经接单”，不显示/保存响应者联系方式。
5. caller 或 Sheet 消失取消时，真实在途 mock 需观察到取消；ViewModel 退到可重试的非提交状态、草稿保留、不显示失败。删除旧 `ResponseSubmissionState`、View 内默认生产 Client 与不能证明取消的路径。
6. 为真实 production ViewModel 增加测试，至少覆盖：无效不调用 API、请求字段与 id、201、重复 200、409/429 或 400 后草稿、提交中去重、取消观察/可重试。测试不得访问生产网络。
7. 遵守 v3 禁止项：不新增 Emoji/渐变；不在此任务重画全局视觉。

验收命令（在本 worktree 执行）：

```bash
/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml
swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag005 --disable-xctest --enable-swift-testing
xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' -derivedDataPath /private/tmp/haluowode-ag005-tests -only-testing:HaluowodeTests test
swiftc -frontend -parse ios/Haluowode/*.swift
rg -n 'DispatchQueue\.main\.asyncAfter|Wish\.mockWishes|WishAPIClient\(' ios/Haluowode/NearbyView.swift ios/Haluowode/WishResponseViewModel.swift
rg -n -i 'admin|x-admin-key|api[_-]?key|cloudflare.*token' ios/Packages/HaluowodeCore ios/Haluowode
git diff --check
```

交接必须列实际发现/执行/通过数、每个生产状态、请求 ID/字段断言、取消观察、完整改动路径、warning、未验证项和 commit SHA。完成后 STATUS 并停止；越界或接口疑问先 `OBJECTION`。

## AG-006：真实查询进度与交付（P0-D，PLANNED，未派发）

前置：`AG-005` 由 Codex 独立验收并合入本地 `main` 后，Codex 才会从那个主线创建 `worktrees/ag-006-real-track` 与分支 `codex/ag-006-real-track`，将本节状态改为 `IN_PROGRESS` 并在该 worktree 群聊末尾发正式 TASK。没有该三项动作前，任何成员只可阅读。

唯一目标：将现有 `ProgressView` 的 `Wish.mockWishes`、`DispatchQueue.main.asyncAfter`、假交付预览替换为可注入的 `WishAPIProtocol.trackWish` 真实流程。用户输入公开编号和发布时联系方式后，App 要显示真实 `TrackedWishDTO` 的摘要、`WishStatus.label`、服务端事件时间线、已匹配响应者称呼（若有）与后端返回的交付能力链接；本任务不得写生产订单或修改后端。

允许修改（只在届时新 worktree）：

- `ios/Haluowode/ProgressView.swift`
- 新建 `ios/Haluowode/TrackWishViewModel.swift`
- 新建或仅为真实交付预览而拆分的 `ios/Haluowode/DeliveryPreviewView.swift`
- `ios/Haluowode/ContentView.swift`（仅当已有共享 API 注入不足以给 Progress 使用时）
- 新建 `ios/HaluowodeTests/TrackWishViewModelTests.swift`
- `ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift`（仅增加 track 成功/未知枚举/能力 URL 解码 fixture）
- `ios/project.yml` 与由它生成的 `ios/Haluowode.xcodeproj/**`
- `.ai/handoffs/AG-006-real-track.md`、`.ai/TEAM_CHAT.md`（只能在末尾追加 ACK/STATUS/OBJECTION）

禁止修改：Core Sources、`PublishView`/`PublishWishViewModel`、`NearbyView`/`WishResponseViewModel`、`HomeView`、`ProfileView`、DesignSystem/视觉资源、后端/数据库/部署、任务板/冻结/项目日志、Git 历史、签名、依赖；不得新增 Emoji、渐变、账号、运营入口、支付、地图、模拟数据或生产写入测试。

必须交付：

1. `@MainActor TrackWishViewModel`，依赖可注入 `WishAPIProtocol`，具有互斥 `idle / loading / loaded(TrackedWishDTO) / failed(message)` 状态；运行时 View 不得直接拼 URL、调 `URLSession` 或读 `Wish.mockWishes`。
2. 本地校验公开编号 trim 后 8–24、联系方式 trim 后 3–80；请求 `TrackWishRequest` 的 `publicCode` 要使用 trim 后大写值，contact 只用于该次请求，成功后立即从 ViewModel 内存清除，永不写入 UserDefaults、日志、错误文本、公开 UI 或截图文案。
3. 真实显示 DTO 的 `publicCode`、城市/地标、正文、交付方式、感谢金、`WishStatus.label`（`delivered` 必须为“待确认”）、`events` 时间线和可选 `assignment.providerName`；禁止继续展示旧中文 `Wish` 或伪造响应者资料。
4. 有 `deliverable` 时使用 URL 原样加载：手写卡片以 `AsyncImage` 显示 loading/success/failure；视频类用系统 `AVKit`/`VideoPlayer`；`link` 可作为系统 `Link` 打开。URL 和 token 绝不能显示、复制、保存、打印、埋点或塞进错误文案。401/404/429/503/媒体加载失败统一显示“交付链接不可用或已失效”。
5. 400 字段错误、404、429、网络、解码失败、取消均保留用户输入并可重试；404 只显示“请检查编号和联系方式”，不能回显输入；取消回到可重试非 loading 状态；请求中禁用重复查询。
6. 实际 production ViewModel 测试至少覆盖：无效输入零调用、正确 trim/uppercased 请求、成功 DTO 映射与成功后 contact 清除、404 不泄露、429、取消可重试、查询中去重；Core fixture 覆盖 track 成功、未知 `WishStatus`、事件、assignment、deliverable 能力 URL 的解码。测试必须完全使用 mock/fixture，不访问生产 API。
7. 删除 `ProgressView` 的 `Wish.mockWishes`、`DispatchQueue.main.asyncAfter`、硬编码测试编号和虚构交付文字。保持五栏导航；本任务只接业务数据，不进行 v3 视觉重画。

验收命令（届时在本 worktree）：

```bash
/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml
swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag006 --disable-xctest --enable-swift-testing
xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' -derivedDataPath /private/tmp/haluowode-ag006-tests -resultBundlePath /private/tmp/haluowode-ag006-tests.xcresult -only-testing:HaluowodeTests test
swiftc -frontend -parse ios/Haluowode/*.swift
rg -n 'Wish\.mockWishes|DispatchQueue\.main\.asyncAfter|WishAPIClient\(' ios/Haluowode/ProgressView.swift ios/Haluowode/TrackWishViewModel.swift
rg -n -i 'UserDefaults|admin|x-admin-key|api[_-]?key|cloudflare.*token|print\(' ios/Haluowode/ProgressView.swift ios/Haluowode/TrackWishViewModel.swift ios/Haluowode/DeliveryPreviewView.swift
git diff --check
```

交接须给出可读取的测试实际数量、result bundle 路径/摘要、每个状态、contact/token 隐私处理、完整改动路径、warning、未验证项与 commit SHA。完成后 STATUS 并立即停止；Codex 独立验收和合入前，不得领视觉、真机或其他功能任务。

## CL-002 P0 设计补齐

状态：`SUPERSEDED FOR VISUALS`。其业务状态、文案和隐私处理可作为 CL-003 输入，但不得直接作为 SwiftUI 最终视觉。

交付：

1. `21_Filter_Sheet`：放在附近列表上下文中，包含重置、城市、交付方式、期望时间、感谢金和结果按钮。
2. `23_Response_Sheet`：正常、输入聚焦、字段错误、提交中四态；字段必须与 `CreateWishResponseRequest` 对齐。
3. `24_Response_Success`：明确“已收到响应，不代表接单”，含心愿摘要、继续看看和返回首页。
4. `41_Tracking_Delivered` / `41_Tracking_Completed`：交付卡、留言、查看交付和完成时间线；不显示响应者联系方式。
5. `42_Deliverable_Preview`：加载、图片、视频、失败/重试；能力 URL 不显示、不复制。
6. `50_Profile_MVP`：无登录假象，只含产品说明、帮助、安全、隐私和版本入口。
7. `51_Help_Safety`：人工撮合边界、人身安全、内容/隐私、异常处理和联系客服占位。
8. 品牌蓝 `#2F6FE0` 底 + 白色线形标志的 1024×1024 PNG、SVG 和带尺寸/安全区说明的标注页；纯黑版标记为备选。

所有屏幕交付 393×852 HTML、1x/3x PNG；写一份完整交接、资产索引、SwiftUI 状态/文案说明和无障碍注意点。本轮不做首次引导、登录态、支付或运营端。

## CL-003 用户视觉重定向

唯一权威视觉输入：`docs/ios-visual-direction-v3.md`。

- 应用内和 App Icon 完全禁用 Emoji，使用原创几何品牌标志和统一单色矢量或 SF Symbols。
- 参考 Airbnb 的温暖、柔和、内容主导原则，以及 WhatsApp、X、Threads、Instagram 在小尺寸图标上的简洁辨识原则；不得复制其商标。
- 不使用任何渐变；产品色彩保持克制，丰富色彩留给用户上传的照片和视频。
- 第一检查点只交付 3 个 Icon 方向、首页、附近、详情与响应、一个复杂信息页和 v3 Foundations；先让用户可视化评审，再全量重画。
- 卡片圆角、字体字号、行高、字重、间距、描边和图标线宽必须在 Foundations 中给出可追溯 Token。

### CL-003 R1：检查点交付完整性

`CL-003` 的方向性视觉质量已通过 Codex 中途评审，正式结论见 `docs/reviews/cl-003-checkpoint-review.md`；当前不接受以“多状态合板 1x”替代每页 3x 导出。保持原有允许路径和禁止路径，不得重画或新增页面。

必须：

1. 交付 `22_Detail_Response`、`41_Tracking_Detail` 的 3x PNG；
2. 改善首页横向心愿卡的静态裁切，提供可见的横向浏览意图和可落地的 SwiftUI `ScrollView(.horizontal)`/trailing inset 说明；
3. 在交接中按页面补齐 SwiftUI token、状态和无障碍注意项，明确 `#3E6B92` 与 Icon A 均为待产品负责人确认的开放决定；
4. 重新做零 Emoji/零渐变检查，更新交接、发 STATUS 后立即停止。

不得修改 SwiftUI、后端、任务/冻结/项目日志或任何 CL-003 之外的资产。

## CL-004：v3 SwiftUI 实施审计（设计，不写代码）

输入（只读）：`docs/ios-design-freeze-v3.md`、`.ai/handoffs/CL-003-claude-design.md`、`.ai/handoffs/CL-003-assets/**`、当前 `ios/Haluowode/**` 与 `ios/HaluowodeTests/**`。本轮的目标不是重画视觉稿，而是让已冻结的 v3 视觉可以被后续 SwiftUI 任务逐项正确实现与截图验收。

允许修改（仅限）：

- 新建 `.ai/handoffs/CL-004-swiftui-audit.md`
- `.ai/TEAM_CHAT.md`（只可在文件末尾追加 ACK/STATUS/OBJECTION）

禁止修改：所有 `ios/**`、`docs/ios-design-freeze-v3.md`、任何 `CL-003` 资产或交接、后端/数据库/部署、任务板、冻结、项目日志、Git 历史、签名、依赖。不得新增页面、重新设计 Icon、改变 token、加入 Emoji/渐变，或以设计审计名义写产品代码。

必须交付一个面向实施者且可由产品负责人阅读的审计报告，至少包括：

1. 对 Home、Nearby/详情与响应、发布、进度、我的五个区域建立“现状 → v3 目标 → SwiftUI 实施项 → 截图验收点”的矩阵；只评价已经存在或冻结的内容，不增设新功能。
2. 输出唯一的 SwiftUI token 映射：颜色、字体/字重/行高、8pt 间距、圆角、描边、阴影、44pt 点击区、SF Symbols 使用原则，以及“无 Emoji、无渐变、默认零阴影”的可检查规则；所有数值必须回指 v3 冻结输入。
3. 明确当前候选界面与冻结稿的最高优先级差异（包括既有浅蓝渐变/旧候选样式），按 P0/P1 排序；不得把尚未实现的真实流程误报为视觉缺陷或完成。
4. 对加载、空、错误、提交中、成功、取消/重试、动态字体、VoiceOver 给出关键页面的验收清单；明确哪些由实现者截图，哪些需要真机后复核。
5. 列出后续视觉代码任务建议的最小切片、依赖与停止条件，但不得自行创建或领取该代码任务。

完成后在群聊发 STATUS，报告路径、未确定项与建议优先级，然后立即停止等待 Codex 验收。发现冻结设计与现有业务状态冲突时只发 OBJECTION，不自行更改设计。

## 新任务创建要求

新任务至少包含：

1. 唯一任务 ID 和唯一负责人。
2. 独立分支/worktree 路径。
3. 允许修改的精确目录或文件。
4. 明确禁止触碰的区域。
5. 可执行的验收命令或人工验收清单。
6. 完成后必须停止，不自动领取下一项。

`CHAT-001` 是唯一允许多负责人的长期沟通任务，不适用“唯一负责人”，但仍须遵守只追加和禁止改历史的规则。

# 多 AI 任务板

最后更新：2026-07-18 23:24（Asia/Shanghai）

永久角色分工见 `.ai/ROLES.md`。

状态定义：`PLANNED`、`IN_PROGRESS`、`HANDOFF_ONLY`、`REVIEW`、`ACCEPTED`、`SUPERSEDED`、`REJECTED`、`BLOCKED`。

| ID | 负责人 | 状态 | 任务 | 允许写入 | 停止条件 |
| --- | --- | --- | --- | --- | --- |
| COORD-001 | Codex | ACCEPTED | 已审计未分配生成的 iOS 候选工程，建立协作制度并决定保留范围 | `AGENTS.md`、`PROJECT_LOG.md`、`README.md`、`.ai/**`、`docs/ios-candidate-review.md` | 审查结论已记录；后续按小任务选择性集成 |
| COORD-002 | Codex | IN_PROGRESS | 统筹团队自主推进至真实 iPhone 可安装试用；定义验收、冻结设计、拆实现、完成构建与设备测试；优先把可独立验证的复杂实现交由 Antigravity | 协调文档、正式源码集成和验收所需路径 | `docs/ios-mvp-acceptance.md` 全部 P0 通过后结束 |
| AG-001 | Antigravity | ACCEPTED | 已提交此前候选工程的文件、命令、假设、验证、未验证项和风险交接 | `.ai/handoffs/AG-001-antigravity.md` | 交接已完成；当前没有新的实现任务，只能参与群聊 |
| AG-002 | Antigravity | ACCEPTED | 已机械整理现有后端与 Swift 候选模型的 API 映射和差距 | 仅 `.ai/handoffs/AG-002-api-map.md` | 交接已完成；Codex 已在 `docs/ios-api-contract.md` 纠正边界并冻结 v1 |
| AG-003 | Antigravity | ACCEPTED | R5 已删除 R4 测试中残留的 `@unchecked Sendable`/锁包装；真实取消与竞态证据独立复验通过，等待 Codex 选择性集成 | 仅本任务 R3/R4/R5 明列的隔离 worktree路径与交接文件 | 已验收；不得自动继续或领取新任务 |
| AG-004 | Antigravity | ACCEPTED | 真实发布心愿纵向切片已通过独立质量门，等待 Codex 隔离集成到本地主分支 | 仅下文列出的 `codex/ag-004-real-publish` worktree 路径 | 已验收；不得自动领取响应、追踪、交付或视觉重画 |
| AG-005 | Codex | ACCEPTED | 真实提交响应已在隔离集成分支通过独立质量门；Codex 接管补齐 trim 编码断言与可读取结果包证据，准备合入 main | `codex/ios-response-integration` 的响应源码、测试、交接与协调文件 | 仅待合入 main 后完成；Antigravity 无权继续写入或自动领取后续任务 |
| AG-006 | Antigravity | ACCEPTED | P0-D 真实查询进度与交付已通过 Core 17/17、iPhone Simulator 23/23、隐私/Mock 扫描并合入 main | 历史 worktree `worktrees/ag-006-real-track`；源码权限已收回 | 已验收合入；不得继续修改或自动领取任务 |
| AG-007 | Codex | ACCEPTED | v3 进度与交付视觉及四态 Simulator 截图已通过 main 独立回归并以 `679a371` 合入 | 历史 worktree `worktrees/ag-007-v3-progress-delivery`；源码权限已收回 | 已验收合入；不得继续修改或领取下一任务 |
| AG-008 | Antigravity | SUPERSEDED | 旧首页内容社区 SwiftUI 计划已被产品负责人 2026-07-18 的新首页与五位 Dock 裁决替代 | 无；不得创建旧计划 worktree 或实现旧五栏 | 旧计划停止，不得自行领取替代任务 |
| CX-001 | Codex | ACCEPTED | v3 首页基础视觉与原创 App Icon 已在隔离分支通过构建、Simulator 截图与结构化测试后合入 main | `codex/v3-home-foundations` 的首页、DesignSystem、App Icon、交接与群聊 | 已完成；其余页面视觉改造必须另建任务，且不得触碰 AG-006 的范围 |
| CX-002 | Codex | ACCEPTED | v3 附近、详情与真实响应表单视觉已通过独立编译、Core 15/15、iPhone Simulator 15/15 与禁止项扫描，并已合入本地 main | `codex/v3-nearby-response` 的 Nearby、交接与群聊 | 已完成；后续 Publish/Profile/Tab Bar 必须另建任务，且不得触碰 AG-006 的范围 |
| CX-003 | Codex | ACCEPTED | v3 发布与我的视觉已通过独立编译、Core 15/15、iPhone Simulator 15/15 与禁止项扫描，并已合入本地 main | `codex/v3-publish-profile` 的 Publish/Profile、交接与群聊 | 已完成；Tab Bar 必须等 AG-006 收口后另建任务，且不得触碰其范围 |
| CL-001 | Claude | ACCEPTED | 已产出首轮 UI 设计：优先 8 组页面、Design System、文案和状态覆盖 | `.ai/handoffs/CL-001-claude-design.md`、`.ai/handoffs/CL-001-assets/**` | 已评审并冻结到 `docs/ios-design-freeze-v1.md` |
| CL-002 | Claude | SUPERSEDED | 已补齐 v2.1 的响应、交付、Profile、安全页和蓝色 App Icon；信息结构保留，视觉因用户新反馈不进入实现 | `.ai/handoffs/CL-002-claude-design.md`、`.ai/handoffs/CL-002-assets/**` | 旧稿保留为状态与文案参考，不再继续迭代 |
| CL-003 | Claude | ACCEPTED | 已完成 v3 视觉检查点、全页 1x/3x、真实首页 peek 与 SwiftUI 交接；视觉已冻结 | `.ai/handoffs/CL-003-claude-design.md`、`.ai/handoffs/CL-003-assets/**`、`docs/ios-design-freeze-v3.md` | 交付验收完成；不得自动重画其它页面 |
| CL-004 | Claude | ACCEPTED | 已交付 v3 SwiftUI 实施审计：冻结视觉的精确落地、差异与截图验收清单已可直接约束后续实现 | `.ai/handoffs/CL-004-swiftui-audit.md` | 已验收；Claude 停止，待视觉实现后再做截图审阅，不得自动重画或改源码 |
| CL-005 | Claude | ACCEPTED | 首页内容社区设计检查点已验收：正常/空/故事详情资产、职责、隐私和无障碍交接完整 | 历史 worktree `worktrees/claude-cl-005-home-community`；写权限已收回 | 已验收合入；不得继续重画或自行实现 |
| CL-006 | Claude | ACCEPTED | 玫红首页/搜索/中央发布/帮助/我的已由 `03fcb7e` 合入 main；AG-009 修复步骤文案、收口 DEBUG/Release 边界与生成工程差异后，main 独立复验 App 49/49、Core 17/17 | 历史 worktree `worktrees/claude-cl-006-home-search-help-ui`；Claude 已停止 | 已验收合入；不得自行继续修改或领取任务 |
| AG-009 | Antigravity | ACCEPTED | CL-006 集成硬化已以 `55ef6f9`/`3804eb4`/`a0ec5a4`/`7c959a2` 交付并由 `03fcb7e` 合入 main：步骤回归、DEBUG/Release 审计、生成工程归零均通过 | 历史 worktree `worktrees/ag-009-cl006-hardening`；Antigravity 已停止 | 已验收合入；不得自行继续修改或领取任务 |
| CX-004 | Codex | ACCEPTED | 系统显示名与 App Icon 已以 merge `b2fa630` 合入：玫红钥匙图标与中文显示名经过真机构建、安装、启动和产品负责人主屏确认 | 历史 worktree `worktrees/codex-cx-004-system-branding`；权限已收回 | 已验收合入；后续系统语言显示名需独立任务 |
| CX-005 | Codex | ACCEPTED | iOS 系统显示名本地化已由产品负责人确认并以 merge `e0bd6c8` 合入：中文显示“哈喽卧得”，英文显示“Gratia” | 历史 worktree `worktrees/codex-cx-005-display-name-localization`；权限已收回 | 已验收合入；不得继续修改 |
| CL-007 | Claude | SUPERSEDED | 用户确认的 Claude 玫粉白/Lucide 真源已直接形成 AG-010 实现任务；Claude CLI 未交付审计 | 历史 worktree `worktrees/claude-cl-007-lucide-audit`；权限已收回 | 不得继续修改 |
| AG-010 | Antigravity | SUPERSEDED | 首次交付 `1887b30` 含运行时虚构故事且未通过验收；产品负责人改为直接在真机运行 Claude 原始设计分支 | 任务 worktree 权限已收回 | 不得修复、合入、推送或继续修改；若未来要将原版迁移回主线，必须另建任务 |
| CHAT-001 | ALL | IN_PROGRESS | 在共享群聊中自由提问、提案、异议、评审和同步状态 | 仅向 `.ai/TEAM_CHAT.md` 文件末尾追加符合格式的消息 | 群聊长期开放；不得把聊天当成代码授权 |

## 执行资源优先级（产品负责人决定）

- Antigravity 是默认的主要工程实现负责人：优先承接范围清晰、难度充分、可在隔离 worktree 中验收的纵向切片与测试工作。每张任务卡仍必须明确接口、允许/禁止路径、验收命令和停止条件。
- Codex 保留在产品判断、架构/安全边界、跨任务集成、最终质量门和确有必要的高风险修订上；Claude 保留在设计决策、设计规格与真实截图审阅上。两者不常规接管可由 Antigravity 完成的实现工作。
- `AG-006` 的额度冷却只是暂停，不是转派或撤销：恢复后 Antigravity 继续在原 worktree 阅读 `CHAT-20260718-194000-CODEX-046` 并完成修订、验证、交接。Codex 在此期间不修改该任务源码。

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

## CX-002：v3 附近、详情与真实响应视觉（Codex，ACCEPTED）

工作区：`/Users/hansangbai/Documents/New project/worktrees/codex-v3-nearby-response`

分支：`codex/v3-nearby-response`

唯一目标：把 v3 冻结的暖白/暖蓝、细描边、默认零阴影、Dynamic Type、Regular SF Symbols 与响应表单 focus/error/submitting 状态落到 `NearbyView.swift`。必须保留已验收的真实列表、详情、`WishResponseViewModel` 注入和响应状态机；本任务不改任何业务数据或 API。

允许修改：

- `ios/Haluowode/NearbyView.swift`
- `.ai/handoffs/CX-002-v3-nearby-response.md`
- `.ai/TEAM_CHAT.md`（只追加 STATUS）

禁止修改：`ContentView.swift`、`WishResponseViewModel.swift`、所有测试、Core Sources、Home/Publish/Progress/Profile、DesignSystem、App Icon、后端/部署、签名/依赖/生产 API/主工作区/Git 历史；不得增加 Emoji、渐变、运营入口、账号、支付、Mock 数据或改动任何成功/失败/取消语义。

必须交付：

1. 附近搜索/筛选、列表、详情卡和固定 CTA 统一用现有 v3 token：普通卡/固定栏默认零阴影、hairline 分层、圆角走 token；CTA 顶部只用 1pt hairline。不得留下 `.shadow` 或硬编码 `cornerRadius`。
2. 详情与列表的金额使用 `ink900`，输入框使用 `canvasSunk`/`hairlineStrong`；所有字面量字号改为 Dynamic Type 六级语义映射。普通图标使用 Regular SF Symbols，不使用 Emoji 或新的填充式装饰图标。
3. `ApplyResponseSheet` 用 `@FocusState` 表达输入焦点：聚焦为 2pt accent 描边，字段错误为 danger 描边+文字；提交时输入/提交禁用但取消/Sheet 关闭保留现有取消语义。唯一允许的极轻浮层阴影仅在该响应 Bottom Sheet 根容器，且不得扩散到普通卡片。
4. 保留真实 response 成功页的“已收到响应，等待运营确认，不代表已经接单”含义；不得显示、持久化或复制联系方式。所有当前加载、空、错误、提交中、成功状态仍可达。
5. 运行 Swift parser、Core 15/15、iPhone 17 Pro Simulator `HaluowodeTests`、零 Emoji/零渐变/零 Nearby 常规 shadow/硬编码 cornerRadius 扫描和 `git diff --check`；生成实际 Simulator 截图。交接如实列 warning/未验证项，完成后停止。

停止条件：截图和可读取测试结果齐全后立即停止，等待 Codex 验收。后续 Publish/Profile/Tab Bar 不得顺手改造。

## CX-003：v3 发布与我的视觉（Codex，ACCEPTED）

工作区：`/Users/hansangbai/Documents/New project/worktrees/codex-v3-publish-profile`

分支：`codex/v3-publish-profile`

唯一目标：把已验收的真实发布心愿流程和“我的”页面对齐 v3 冻结视觉。保留现有的 `PublishWishViewModel`、真实 API 注入、校验、失败、取消、重复提交、成功编号、隐私边界与页面导航；本任务不改业务数据、API 或任何进度/交付路径。

允许修改：

- `ios/Haluowode/PublishView.swift`
- `ios/Haluowode/ProfileView.swift`
- `.ai/handoffs/CX-003-v3-publish-profile.md`
- `.ai/TEAM_CHAT.md`（只追加 STATUS）

禁止修改：`ContentView.swift`、所有 ViewModel、所有测试、Core Sources、Home/Nearby/Progress、DesignSystem、App Icon、后端/部署、签名/依赖/生产 API/主工作区/Git 历史；不得增加 Emoji、渐变、运营入口、账号、支付、Mock 数据或改变任何成功/失败/取消语义。

必须交付：

1. 发布三步、表单、确认与真实成功页使用现有 v3 token：暖白/暖蓝/细描边、普通卡默认零阴影、圆角走 token；不留 `.shadow`、硬编码 `.cornerRadius`、`LinearGradient` 或 Emoji。金额、公开编号等核心信息使用 `ink900`，而非高饱和装饰色。
2. 发布输入使用 `canvasSunk`/`hairlineStrong`，焦点为 2pt accent，字段错误为 danger 描边和文字；提交时保留既有禁用与取消语义。所有字面量字号改为 Dynamic Type 语义字体，普通图标为 Regular SF Symbols。
3. Profile 的身份、历史、帮助与隐私区块统一为 v3 分组和 hairline；不得伪造账户登录、订单、消息或运营功能。
4. 所有真实加载、校验失败、网络失败、提交中、成功编号与隐私状态仍可达，不展示或持久化联系方式。
5. 运行 Swift parser、Core 15/15、iPhone 17 Pro Simulator `HaluowodeTests`、禁止项扫描和 `git diff --check`；生成实际 Simulator 截图。交接如实记录 warning/未验证项，完成后停止。

停止条件：截图和可读取测试结果齐全后立即停止，等待 Codex 验收；Tab Bar、Progress、Track、Delivery、Content 和所有行为改造必须另建任务。

## CX-001：v3 首页基础视觉与 App Icon（Codex，ACCEPTED）

工作区：`/Users/hansangbai/Documents/New project/worktrees/codex-v3-home-foundations`

分支：`codex/v3-home-foundations`

唯一目标：将冻结的 v3 Foundations 落到 `DesignSystem.swift` 与首页，并将已冻结的原创 Icon A 作为实际 App Icon 接入。该任务提供下一轮可视化 Simulator 检查点；不改变任何业务 API、状态机、进度/交付代码或其它页面视觉。

允许修改：

- `ios/Haluowode/DesignSystem.swift`
- `ios/Haluowode/HomeView.swift`
- `ios/Haluowode/Assets.xcassets/AppIcon.appiconset/**`
- `ios/Haluowode.xcodeproj/**`（仅在 XcodeGen 重新生成后出现必要差异时）
- `ios/project.yml`（仅项目资源引用确有必要时）
- `.ai/handoffs/CX-001-v3-home-foundations.md`
- `.ai/TEAM_CHAT.md`（只追加 STATUS）

禁止修改：`ProgressView.swift`、`TrackWishViewModel.swift`、`DeliveryPreviewView.swift`、其它四个页面、任何 ViewModel/Core Sources、后端/数据库/部署、签名/Apple 设置、依赖、生产 API、冻结设计文档、主工作区或 Git 历史；不得增加 Emoji、渐变、图片背景、第三方商标或新业务。

必须交付：

1. `DesignSystem` 与 `docs/ios-design-freeze-v3.md` 精确对齐：暖蓝 `#3E6B92`、暖白 canvas、sunk canvas、两级 hairline、暖黑/暖灰、danger/success、8 级间距、5 级圆角，并保留业务代码所需的兼容 token；不得保留 golden emphasis 语义。
2. 全局按钮与背景迁移到语义化 Dynamic Type、v3 color/radius token；默认零阴影，不能让按钮/卡片因 token 替换回到旧蓝或系统红。
3. 首页去除全部 `LinearGradient` 和 `.shadow`，使用 `canvas`、1pt hairline、冻结圆角和 Dynamic Type；保留现有加载/空/错/已加载状态与真实列表调用。`loaded` 横卡采用 140pt、12pt 间距和可见 trailing peek；不得为截图伪造数据。
4. 顶栏图标必须为 SF Symbols Regular 风格且具有 44×44pt 点击区；不得使用 Emoji 或填充式第三方外观。失败态和安全提示都需使用 v3 danger/accent 的文本/图标双重表达。
5. 从 `.ai/handoffs/CL-003-assets/icon/icon-a-warm-1024.png` 生成并接入全部 `AppIcon.appiconset` 必需尺寸。仅使用该冻结原创资产，不重画/不使用网络素材。
6. 写入交接，包含精确 token、图标源/导出尺寸、修改路径、未验证项和实际命令结果。用 XcodeGen、Swift parser、Core 测试、iPhone 17 Pro Simulator build/launch、`git diff --check`、零 Emoji/零渐变/零 Home shadow 扫描、截图人工对比验收；不得以编译通过替代截图。

停止条件：提供 iPhone 17 Pro Simulator 截图和可读取验证结果后立即停止，等待 Codex 集成；后续其余页面 v3 改造另建任务，绝不顺手扩范围。

## AG-006：真实查询进度与交付（P0-D，IN_PROGRESS，已派发）

前置已满足：`AG-005` 已由 Codex 独立验收并以 `e8caa45` 合入本地 `main`。本任务只可在 `worktrees/ag-006-real-track` 与分支 `codex/ag-006-real-track` 执行；本节和群聊正式 TASK 是唯一写入授权。完成交付后立即停止，等待 Codex 验收。

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

### AG-006 验收结论

Codex 已独立复验并于本地 main merge commit `296ab12` 合入：Core 17/17；iPhone 17 Pro、iOS 27 Simulator 23/23，0 failure/skip/runtime warning；Swift parser、Mock/生产 Client 扫描、隐私扫描与 diff check 通过。任务状态为 `ACCEPTED`，原 worktree 源码权限收回。

## AG-007：v3 进度与交付视觉收口（ACCEPTED）

工作区：`/Users/hansangbai/Documents/New project/worktrees/ag-007-v3-progress-delivery`

分支：`codex/ag-007-v3-progress-delivery`

前置：本地 main `296ab12`；权威视觉输入 `docs/ios-design-freeze-v3.md` 与 `docs/ios-experience-blueprint.md`。唯一目标是把已验收的真实进度查询、时间线和交付预览对齐现有 v3 DesignSystem；不得改变 API、状态机、请求字段、取消、错误或隐私语义。

允许修改：

- `ios/Haluowode/ProgressView.swift`
- `ios/Haluowode/DeliveryPreviewView.swift`
- 新建 `ios/HaluowodeTests/ProgressPresentationTests.swift`（仅纯展示 helper/隐私文案测试）
- `ios/project.yml` 与由它生成的 `ios/Haluowode.xcodeproj/**`（仅新测试文件接入确有需要时）
- `.ai/handoffs/AG-007-v3-progress-delivery.md`
- `.ai/TEAM_CHAT.md`（只追加 ACK/OBJECTION/STATUS）

禁止修改：`TrackWishViewModel.swift`、`ContentView.swift`、Core Sources/Tests、其他 View/ViewModel、DesignSystem、App Icon、后端/数据库/部署、签名、依赖、生产 API、任务板/冻结/项目日志、主工作区或 Git 历史；不得增加 Emoji、渐变、账号、运营入口、支付、Mock 数据、自绘 Tab Bar 或新的产品能力。

必须交付：

1. 查询表单、校验/失败、loading、loaded 摘要、交付入口、事件时间线统一使用既有 v3 `canvas/canvasSunk/card/hairline/accent/danger/ink` token、8pt 节奏和冻结圆角；普通卡默认零阴影，不留硬编码 `.cornerRadius`、`.shadow`、`LinearGradient` 或 Emoji。
2. 所有字面量字号迁移到 Dynamic Type 语义字体；普通图标使用 Regular SF Symbols；输入与按钮具备至少 44pt 点击区。焦点 2pt accent、字段错误 danger 描边+文字、loading 禁用与失败重试必须清晰且不能只靠颜色表达。
3. 保留生产 `ProgressView.statusText(for:)`、真实 DTO/事件/assignment/deliverable、`onDisappear` 取消、404/429 文案、成功后 contact 清除与能力 URL/token 隐私。不得把 URL 放进 `Text`、accessibility label/value、日志、复制菜单或测试输出。
4. 交付预览维持系统 `VideoPlayer`、`AsyncImage`、`Link` 行为；把 loading/success/failure/关闭按钮与留言层对齐 v3 和 Dynamic Type。失败固定“交付链接不可用或已失效”；真实远端媒体失败仍如实标为真机/受控 fixture 未验证。
5. 提供 iPhone 17 Pro Simulator 的查询表单、404 错误、delivered/待确认、交付失败至少四张截图。不得为截图访问生产 API或伪造运行时数据；可使用 XCTest/Preview 的本地 fixture，必须说明证据边界。
6. 运行 Core 全套、HaluowodeTests、Swift parser、零 Emoji/渐变/普通 shadow/硬编码 corner radius 扫描、隐私/Mock 扫描和 `git diff --check`。交接列实际测试数、结果包、截图路径、warning、未验证项与 commit SHA。

停止条件：提交允许范围内交付、追加 STATUS 后立即停止，等待 Codex 独立验收；不得顺手修改首页、Tab Bar、真机流程或领取下一任务。

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

## CL-005：首页内容社区设计检查点（Claude，IN_PROGRESS）

工作区：`/Users/hansangbai/Documents/New project/worktrees/claude-cl-005-home-community`
分支：`codex/cl-005-home-community-design`

唯一目标：将首页重新设计为内容优先的“已完成心愿故事”入口，服务于“看见完成感 → 我也想发布／我也想帮忙”的转化；它不是第二个“附近”市场，也不是好友、关注、私信或评论网络。

权威输入：

- `docs/home-community-direction.md`
- `docs/ios-experience-blueprint.md`
- `docs/ios-design-freeze-v3.md`（仍是现行视觉 token 与五栏导航冻结）
- `docs/reviews/v31-candidate-review.md`
- `.ai/handoffs/CL-003-claude-design.md`（只作为已有 token/交付格式参考）

允许修改（仅限当前独立 worktree）：

- 新建 `.ai/handoffs/CL-005-home-community-design.md`
- 新建 `.ai/handoffs/CL-005-assets/**`（HTML、SVG、1x/3x PNG 等设计交付）
- `.ai/TEAM_CHAT.md`（只可末尾追加 ACK/STATUS/OBJECTION）

禁止修改：所有 `ios/**`、`worker/**`、`lib/**`、数据库/迁移/部署、`docs/ios-design-freeze-v3.md`、`docs/home-community-direction.md`、既有 Claude 资产或交接、`.ai/TASKS.md`、`.ai/WRITE_FREEZE.md`、`PROJECT_LOG.md`、主分支、Git 历史、签名、依赖。不得创建点赞 API、账号、好友、关注、私信、评论、假互动计数或任何产品代码。

必须交付：

1. 393×852 的首页正常态、首页无可公开故事空态、故事详情/沉浸阅读态；每页输出可编辑 HTML/SVG 和 1x/3x PNG。正常态须清楚表现“心愿正文 → 如何完成 → 交付片段/感谢”的故事顺序，以及“我也想发布／去附近看看能帮什么”两个行动。
2. 在交接中给出首页与附近/发布/进度/我的的明确职责图，列出故事卡最小字段、缺失媒体/无授权内容/加载/错误状态与转化路径；不得把活跃待匹配心愿伪装为完成案例。
3. 所有案例素材必须是明确标注的示意内容，不得包含可识别真实人物、联系方式、精确地点、时限、内部响应者身份、能力 URL/token 或未经单独授权的图像/视频。
4. 保持 v3 的暖白/暖蓝、SF Symbols、零 Emoji、零渐变、默认零阴影；以 iOS 26 系统的浮动 Liquid Glass Tab Bar 为设计前提。五个目的地保留系统可访问名称和 44pt 命中区；不要手绘/网页式仿制 Dock、固定 blur/阴影或重写系统 Tab 行为。
5. 点赞只可作为未来轻反馈的设计注记：不显示伪造数字或“已生效”的互动状态；交接需说明上线前依赖账户、可信计数、限流、撤回、审核与举报。
6. 提供设计自检：画板尺寸、零 Emoji、零渐变、系统浮动 Liquid Glass Dock 与五项可访问目的地兼容、所有卡片/按钮文本是否符合隐私边界；完成后准确写交接、发 STATUS 并立即停止。

Codex 验收方式：逐页查看 HTML/1x/3x、对照上述职责与隐私清单、扫描 Emoji/渐变/浮动 Dock，确认不含任何 SwiftUI/后端/冻结文件改动；在 Codex 接受前不得进入实现或修改设计冻结。

### CL-005 验收结论与产品裁决

Codex 已逐页查看 393×852 正常/空/故事详情，核验 3x 尺寸、HTML、零 Emoji/渐变/自定义阴影、隐私关键字和 diff；交付以 main `c19ca38` 接受。MVP 裁决：采用去框化 Hero；故事缩略图固定 16:7；点赞图标完全不实现；故事详情使用系统 API 隐藏 Tab Bar；交付示意文案先作为 MVP 文案，后续文案校对不得阻塞实现。

## AG-008：首页内容社区 SwiftUI（SUPERSEDED，不得执行）

原计划已被产品负责人 2026-07-18 确认的新首页、搜索、帮助与四页加中央发布动作的信息架构替代。不得创建原计划分支、修改文件或提前实现；后续实现以 `CL-006` 为准。

计划目标：把 `CL-005` 已接受的内容社区首页落为 SwiftUI，首页只展示经独立授权、脱敏的已完成故事，支持正常/空/加载/错误/详情和“发布/附近”双 CTA；不得把活跃市场数据或私人 track DTO 当作公开故事源。正式派发前 Codex 必须先冻结故事数据来源/API 边界；若后端尚无公开故事端点，首版只能实现诚实空态与本地编译期 Preview fixture，不得在运行时伪造故事。

预计允许路径仅为 `HomeView.swift`、新建故事展示类型/ViewModel/测试、必要的 `ContentView` 导航注入、交接与群聊；禁止 Nearby/Publish/Progress/Profile、Core 既有公开列表契约、后端、签名、DesignSystem 和自绘 Tab Bar。正式任务卡会给出精确路径、数据边界、截图与测试命令。

## CL-006：用户认可风格的 SwiftUI 首页与导航落地（Claude，REVIEW）

工作区：`/Users/hansangbai/Documents/New project/worktrees/claude-cl-006-home-search-help-ui`

分支：`codex/cl-006-home-search-help-ui`

本任务是产品负责人明确批准的角色例外：Claude 可以在本独立 worktree 内把其当前获认可的设计直接落到 Xcode SwiftUI 源文件。该例外仅限本卡允许路径，不授权后端、业务契约、签名、主分支或其它任务源码。

唯一目标：保持产品负责人已认可的 Claude 当前版本视觉风格，将顶层结构改为四个页面加中央全局发布动作：`首页｜搜索｜发布｜帮助｜我的`；移除一级“进度”，把查询/进度入口收进“我的”，并让首页成为白底、媒体优先的公开内容流。

权威输入与裁决：

- 产品负责人认可的 Claude 当前设计版本：`https://claude.ai/code/artifact/982c770b-f435-42a7-ac45-b51ea67922c9?via=auto_preview`
- 本任务卡内的文字裁决优先于旧 `docs/ios-design-freeze-v3.md` 中冲突的蓝色、附近、进度与五页面导航；未冲突的原生 iOS、Dynamic Type、VoiceOver、44pt、安全区和隐私规则继续有效。
- 主题色：`#9A536D`；深色 `#7F4058`；柔和粉 `#E4C6D0`；浅粉底 `#FAF4F6`；大画布 `#FFFFFF`；主文字 `#191719`。大面积保持白色，只有中央发布和必要小面积强调使用主题色。
- 首页 Preview 可以使用明确标注的纯虚构内容与本地占位媒体；运行时不得伪造已发布用户、互动数字或生产故事。不得使用可识别真人、第三方商标或未授权素材。

允许修改（仅本 worktree）：

- `ios/Haluowode/ContentView.swift`
- `ios/Haluowode/DesignSystem.swift`
- `ios/Haluowode/HomeView.swift`
- `ios/Haluowode/NearbyView.swift`（只用于改造成“帮助”入口并保留现有真实公开心愿/响应行为）
- `ios/Haluowode/ProfileView.swift`
- `ios/Haluowode/PublishView.swift`（仅适配中央发布入口、主题 token 或关闭/返回导航，不改业务状态机）
- 新建 `ios/Haluowode/SearchView.swift`
- 新建仅展示用的 `ios/Haluowode/HomePreviewFixtures.swift` 与本地、原创、无身份媒体资源 `ios/Haluowode/Assets.xcassets/PreviewMedia/**`
- `ios/HaluowodeTests/**`（仅导航、筛选、可访问性或纯展示逻辑测试；不得改已有业务断言以迁就实现）
- `.ai/handoffs/CL-006-home-search-help-ui.md`
- `.ai/TEAM_CHAT.md`（只追加 ACK/OBJECTION/STATUS）

禁止修改：`ProgressView.swift`、`TrackWishViewModel.swift`、`DeliveryPreviewView.swift`（AG-007 路径，只能复用不能改）、所有其它 ViewModel、Core Sources/API 模型、后端/数据库/部署、生产 API、项目签名/Bundle ID/证书、依赖、`project.yml`、生成的 `.xcodeproj`、主工作区、任务板、冻结文件、项目日志、Git 历史。不得增加账号、好友、关注、自由私信、评论后端、点赞后端、假互动数字、精确个人位置或运行时 Mock 故事。

必须交付：

1. Dock 视觉顺序固定为首页、搜索、中央发布、帮助、我的；页面图标黑色/深灰，只有中央发布为玫红主题色。视觉不显示汉字时仍须给每项保留准确 VoiceOver 名称、可识别选中态和至少 44pt 命中区。帮助使用原创“两只手相握”SVG/Shape 图标，不以附近、定位针或普通爱心代替。
2. 中央发布是全局动作，打开现有真实 `PublishView` Sheet/全屏流程，不把它实现为第五个持久页面；发布完成后不得改变现有真实 API、校验、取消、错误和编号语义。
3. 首页采用白底媒体优先信息流，去掉大段 App 介绍；“许个愿”若保留在右上角只能是克制的次入口。首页正常样式只在 SwiftUI Preview/测试 fixture 展示两条明确虚构故事；运行 App 没有合法公开故事源时必须展示诚实空态，不得用活跃心愿或私人 track 数据冒充完成故事。互动只显示图标，不显示伪造数量；不得把评论/点赞呈现为已接通后端。
4. 搜索页支持公开字段的地点、公共地标、主题/场景、交付形式筛选，结果沿用媒体信息流视觉；筛选可以形成首页可清除的条件标签。只搜索明确公开内容，位置最多到城市/公共地标，不索引联系方式、精确个人位置或私人查询数据。若目前没有公开故事 API，搜索 UI 和过滤逻辑只在 Preview fixture 可演示，运行态诚实说明暂无公开内容。
5. “帮助”页复用现有真实 `PublicWishDTO` 列表与响应流程，把“附近”语义改成帮助；不得破坏列表加载/空/错误/刷新、详情和真实 `WishResponseViewModel` 提交、取消、失败、成功语义。
6. “我的”显示“我发布的”“我帮助的”两个入口，并把现有进度查询作为其内部导航目的地；不得伪造账户或本地历史聚合，也不得修改 AG-007 的 Progress/Track/Delivery 源码。
7. 新 Dock 如需自定义以满足中央动作和独立色彩，必须保持 safe area、键盘、横竖屏、Reduce Transparency、Dynamic Type、VoiceOver、44pt 命中区；不得用固定截图式布局。iOS 16–27 至少编译通过，系统原生控件能满足的部分优先保留系统行为。
8. 提供 iPhone 17 Pro Simulator 的首页、搜索、帮助、我的、发布入口截图；测试/构建必须是真实执行结果。交接列出精确改动路径、实际测试数量、warning、未验证项、素材来源/授权边界和 commit SHA。

验收命令（在本 worktree 执行）：

```bash
/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml
swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-cl006 --disable-xctest --enable-swift-testing
xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' -derivedDataPath /private/tmp/haluowode-cl006-tests test
swiftc -frontend -parse ios/Haluowode/*.swift
rg -n -i 'admin|x-admin-key|api[_-]?key|cloudflare.*token|Wish\.mockWishes|LinearGradient' ios/Haluowode ios/Packages/HaluowodeCore
git diff --check
```

停止条件：Claude 完成允许范围内代码、验证、截图、commit、交接，并在本 worktree `.ai/TEAM_CHAT.md` 追加准确 STATUS 后立即停止；不得合入 main、推送、部署、改签名、领取下一任务或顺手修改 AG-007。Codex 独立验收后才决定合入或退回。

## AG-009：CL-006 集成硬化（Antigravity，ACCEPTED）

工作区：`/Users/hansangbai/Documents/New project/worktrees/ag-009-cl006-hardening`

分支：`codex/ag-009-cl006-hardening`

前置：Claude CL-006 最终交接 `5364595`；Codex 已目视检查 14 张截图并独立复验 Core 17/17、App 44/44。设计方向合格，但不得直接验收：发布页真实截图显示 `第 (currentStep) 步`，且 Claude commit 含任务卡明确禁止的生成 `.xcodeproj` 差异。

唯一目标：不重画 Claude 设计、不改业务状态机，将 CL-006 收敛成可安全集成候选。修复发布步骤文案并增加真实回归断言；证明 DEBUG 截图启动参数只选择初始页面/发布层、不注入数据且 Release 不包含该分支；从最终提交中清除生成 `.xcodeproj` 差异，由 Codex 合入 main 后统一运行 xcodegen 生成项目文件。

允许修改：

- `ios/Haluowode/PublishView.swift`（仅步骤展示 helper/插值修复，不改表单、API、校验、提交、取消或成功语义）
- 新建 `ios/HaluowodeTests/CL006IntegrationHardeningTests.swift`，或只追加 `ios/HaluowodeTests/AppNavigationAndSearchTests.swift`（仅本任务展示/DEBUG 边界断言）
- `ios/Haluowode/ContentView.swift`（仅当审计证明 DEBUG 钩子需要最小安全收口；不得增加新启动能力、fixture 或生产分支）
- `.ai/handoffs/AG-009-cl006-hardening.md`
- `.ai/TEAM_CHAT.md`（只追加 ACK/OBJECTION/STATUS）

特殊生成文件规则：`ios/Haluowode.xcodeproj/project.pbxproj` 可以在运行 xcodegen/测试时临时变化，但**最终 commit 必须与 CL-006 起点 `fb86b84` 对该文件的内容一致**，不得提交任何 `.xcodeproj` 差异。不得修改 `project.yml`。Codex 集成后负责统一重生成项目。

禁止修改：Home/Search/Nearby/Profile/DesignSystem/HomePreviewFixtures、CL-006 截图/交接、AG-007 三文件、所有 ViewModel/Core/API、后端/数据库/部署、签名/Bundle ID、依赖、主分支、任务板/冻结/项目日志、Git 历史；不得删除 Claude 有效提交、改视觉方向、添加运行时 Mock/假数据或访问生产 API。

必须交付：

1. `PublishView` 显示 `第 1 步，共 3 步`、`第 2 步，共 3 步`、`第 3 步，共 3 步`，不得再出现字面量 `(currentStep)`；用生产 helper 的 XCTest 锁定 1/2/3，不能只扫描源码。
2. 审计 `ContentView` 的 `#if DEBUG` 启动参数钩子：仅 `-cl006-initial-tab` 与 `-cl006-show-publish`，不注入故事、API、联系方式、编号或状态；Release 构建/预处理路径不包含该行为。若无需修改，交接给出源码范围与 Release build 证据。
3. 临时运行 xcodegen 接入新测试并完成 Core/App 全套；测试后将 `project.pbxproj` 恢复为 `fb86b84` 内容，最终 `git diff fb86b84 -- ios/Haluowode.xcodeproj/project.pbxproj` 必须 0 差异。
4. 运行 parser、隐私/Mock/生产 URL/凭据/渐变扫描与 `git diff --check`。交接列实际测试数、结果包、warning、未验证项、精确路径、commit SHA；不得声称真机或旧系统已验证。

验收命令（在本 worktree 执行）：

```bash
/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml
swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag009 --disable-xctest --enable-swift-testing
xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' -derivedDataPath /private/tmp/haluowode-ag009-tests -resultBundlePath /private/tmp/haluowode-ag009.xcresult -only-testing:HaluowodeTests test
xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/haluowode-ag009-release build
swiftc -frontend -parse ios/Haluowode/*.swift
rg -n -i 'admin|x-admin-key|api[_-]?key|cloudflare.*token|Wish\.mockWishes|LinearGradient' ios/Haluowode ios/Packages/HaluowodeCore
git diff fb86b84 -- ios/Haluowode.xcodeproj/project.pbxproj
git diff --check
```

验收结论：Antigravity 已按允许范围提交 `55ef6f9`（修复/测试）、`3804eb4`（交接）、`a0ec5a4`（交接勘误）、`7c959a2`（提交级 whitespace 修复）；Codex 独立复验 Core 17/17、main App 49/49、0 failure/skip/runtime warning，Release 二进制对两个 DEBUG 参数 0 命中，且 `project.pbxproj` 与 `fb86b84` 0 差异。两条 iOS 16/XCTest linker warning 为既有工具链警告，未掩盖。`03fcb7e` 已合入 main，权限收回。

## CX-004：iOS 系统显示名与 App Icon 收口（Codex，IN_PROGRESS）

工作区：`/Users/hansangbai/Documents/New project/worktrees/codex-cx-004-system-branding`

分支：`codex/cx-004-system-branding`

唯一目标：修复用户已在真机发现的系统层品牌遗留：主屏显示名必须为“哈喽卧得”，App Icon 不得再是蓝底白钥匙。保留现有 `Haluowode` 技术 target、`com.hanselzzh.haluowode` Bundle ID、自动签名和后端契约。

允许修改（仅限任务 worktree）：

- `ios/Haluowode/Info.plist`（只新增/修改显示名键）
- `ios/Haluowode/Assets.xcassets/AppIcon.appiconset/**`
- `.ai/handoffs/CX-004-system-branding.md`
- `.ai/TEAM_CHAT.md`（仅追加 STATUS）

禁止修改：`ios/project.yml`、`ios/Haluowode.xcodeproj/**`、Bundle ID、签名/证书/Team、任何 Swift/测试/Core/后端/部署、其他资产、任务板、冻结、项目记忆、项目日志、主分支或 Git 历史；不得借此重命名 target/module 或合入 Claude 的 87-file Gratia 分支。

验收：`plutil` 明确显示 `CFBundleDisplayName = 哈喽卧得`；全部 AppIcon slot 的 JSON 与像素尺寸有效；Simulator Debug build 成功；以现有 Personal Team 的命令行临时覆盖构建并重新安装到已连接真机，由用户/PM 人工确认主屏显示名和图标。不得把命令行 Team 覆盖写回工程文件。

验收结论：实现提交 `9746443`、交接勘误 `259ef57` 已经由 merge `b2fa630` 合入 main。`plutil`、18 个图标 slot 像素尺寸、真机 Debug build 和安装通过；真机自动 launch 首次被锁屏拒绝、解锁后成功启动。产品负责人于 2026-07-19 确认玫红钥匙图标正确。任务 ACCEPTED；图标及固定中文显示名权限收回。

## CX-005：系统显示名本地化（Codex，IN_PROGRESS）

工作区：`/Users/hansangbai/Documents/New project/worktrees/codex-cx-005-display-name-localization`

分支：`codex/cx-005-display-name-localization`

唯一目标：以系统语言本地化系统显示名，中文（简体）显示“哈喽卧得”、英文显示“Gratia”。这是 SpringBoard/App Library 名称，不能改变应用内中文 UI、`Haluowode` target、Bundle ID 或签名。

允许修改（仅限任务 worktree）：

- 新建 `ios/Haluowode/zh-Hans.lproj/InfoPlist.strings`
- 新建 `ios/Haluowode/en.lproj/InfoPlist.strings`
- `.ai/handoffs/CX-005-display-name-localization.md`
- `.ai/TEAM_CHAT.md`（仅追加 STATUS）

禁止修改：`ios/Haluowode/Info.plist`、`Assets.xcassets/**`、`ios/project.yml`、`ios/Haluowode.xcodeproj/**`、Bundle ID、签名/证书/Team、任何 Swift/测试/Core/后端/部署、其他资源、任务板、冻结、项目记忆、项目日志、主分支或 Git 历史。

验收：两份 strings 均是有效 UTF-16/UTF-8 strings 文件，仅定义 `CFBundleDisplayName`；对 English 与 Simplified Chinese locale 的编译产物分别读取 `Info.plist` 验证对应值；真机在 English 与简体中文系统语言下重新安装/刷新并人工确认系统显示名。命令行 Team 覆盖不得写回工程。

验收结论：实现 `b58e9b4`、交接勘误 `5d76fa9` 已由 merge `e0bd6c8` 合入 main。两份本地化 resources 均在真机构建产物中读取正确，真机安装/启动成功，产品负责人确认系统语言显示正确。任务 ACCEPTED；权限收回。

## CL-007：Lucide Icons 审计与冻结交接（Claude，SUPERSEDED）

工作区：`/Users/hansangbai/Documents/New project/worktrees/claude-cl-007-lucide-audit`

分支：`codex/cl-007-lucide-audit`

唯一目标：核对产品负责人认可的 Claude/Lucide 图标版本与 main 当前实现，给出可实施、可验收的 Lucide 图标资产、版本、授权和屏幕映射规范。当前 main 和 CL-006 交接仍大量使用 SF Symbols；本任务只做设计与审计，不能改用图标代码或资源。

允许修改（仅限任务 worktree）：

- 新建 `.ai/handoffs/CL-007-lucide-icons-audit.md`
- `.ai/TEAM_CHAT.md`（仅追加 ACK/OBJECTION/STATUS）

禁止修改：所有 `ios/**`、任何 Lucide/SF 图标资产、Swift/测试/Core、`project.yml`/`.xcodeproj`、Bundle ID/签名/Team、后端/部署、任务板、冻结、项目记忆、项目日志、主分支或 Git 历史；不得安装依赖、下载第三方包、重画页面或把审计结论直接实现。

必须交付：

1. 明确用户认可的 Lucide 版本来源：现有 worktree/commit/资产路径；若仓库不存在，明确写“未找到”且不能猜测或伪造。
2. 对 main 当前所有 `Image(systemName:)` 与自绘 `HandsClaspedIcon` 做按页面/用途的 inventory，区分需要替换、可保留系统语义（如系统媒体控件）与不应改动的状态/业务图标。
3. 提供唯一版本号、许可确认、SwiftUI 可行集成方式（本地 SVG/PDF/Swift package）和每个业务图标的 Lucide 名称、stroke/size/颜色/状态映射；明确禁用 Emoji、禁用混用风格与 44pt/VoiceOver 要求。
4. 写出最小实现切片和可运行验收（构建、无 SF Symbols 残留的范围扫描、截图/真机、动态字体/VoiceOver），但不得自行创建实现任务或改代码。
5. 在 handoff 如实列出搜索过的路径、未确定项、风险（许可证、可访问性、平台符号语义）与 commit SHA；追加 STATUS 后立即停止。

停止条件：交付上述只读审计、commit、STATUS 后立即停止，等待 Codex 验收。任何找不到原版本或出现授权不清的情形先写 OBJECTION，不得自行替换图标。

裁决：Claude CLI 本轮未返回 ACK/交接；但 Codex 已从 Claude 本地会话 `38c0e6b8-…`、用户原话“所有的 icon 用 lucide icons，首页用 house，帮助用 handshake，个人用 user-round”、`claude/rose-home-redesign@8e95b0b` 与其 `CL-006-rose-redesign.md` 找回完整真源。产品负责人已明确要求以该版本上实机，故本只读审计由 `AG-010` 替代；不得继续修改。

## AG-010：玫粉白 Lucide 视觉安全集成（Antigravity，SUPERSEDED）

工作区：`/Users/hansangbai/Documents/New project/worktrees/ag-010-rose-lucide-integration`

分支：`codex/ag-010-rose-lucide-integration`

唯一目标：以用户确认的 `claude/rose-home-redesign@8e95b0b`/`463a420` 视觉为真源，把其玫粉白视觉、首页/搜索/发布/帮助/我的结构、五位 Dock 与 Lucide 模板图标安全移植到 `main` 当前 `Haluowode` target，并保持所有已验收真实 API、ViewModel、隐私、状态机、Bundle ID、签名和显示名本地化不变。**禁止直接 merge/cherry-pick 87-file Gratia 分支。**

真源与产品冻结：

- 用户裁决：Dock 为首页、搜索、中央发布、帮助、我的；图标 only，普通项黑/灰，中央发布玫红；全部使用 Lucide（ISC）`house`/`search`/`square-plus`/`handshake`/`user-round`。
- 源证据：`worktrees/claude-rose-redesign/.ai/handoffs/CL-006-rose-redesign.md`，commit `8e95b0b`；Lucide 模板位于其 `ios/Gratia/Assets.xcassets/Tab*.imageset`，主屏截图位于 `.ai/handoffs/CL-006-assets/simulator/`。
- 当前工程身份不变：target `Haluowode`、Bundle ID `com.hanselzzh.haluowode`、中文/英文显示名本地化、已合入真实业务/API。

允许修改（仅限任务 worktree）：

- `ios/Haluowode/ContentView.swift`
- `ios/Haluowode/DesignSystem.swift`
- `ios/Haluowode/HomeView.swift`
- `ios/Haluowode/SearchView.swift`
- `ios/Haluowode/ProfileView.swift`
- `ios/Haluowode/PublishView.swift`（仅视觉/导航容器，不改 ViewModel 调用、校验、API、取消或成功语义）
- `ios/Haluowode/NearbyView.swift`（仅标题/视觉 token/图标，不改真实列表、响应语义）
- 新建 `ios/Haluowode/StoryFeed.swift`（仅在 main 现有来源缺失且能保持 production 诚实空态时）
- `ios/Haluowode/Assets.xcassets/TabHouse.imageset/**`
- `ios/Haluowode/Assets.xcassets/TabSearch.imageset/**`
- `ios/Haluowode/Assets.xcassets/TabPublish.imageset/**`
- `ios/Haluowode/Assets.xcassets/TabHandshake.imageset/**`
- `ios/Haluowode/Assets.xcassets/TabUserRound.imageset/**`
- 新建或修改 `ios/HaluowodeTests/AG010RoseLucideIntegrationTests.swift`（或仅追加既有导航视觉测试）
- `.ai/handoffs/AG-010-rose-lucide-integration.md`
- `.ai/TEAM_CHAT.md`（只追加 ACK/OBJECTION/STATUS）

禁止修改：任何 ViewModel、`ProgressView.swift`、`TrackWishViewModel.swift`、`DeliveryPreviewView.swift`、Core Sources/API 模型、所有后端/数据库/部署、生产 API、`Info.plist` 与 `*.lproj/InfoPlist.strings`、AppIcon、`ios/project.yml`、`ios/Haluowode.xcodeproj/**`、Bundle ID、签名/证书/Team、依赖、任务板、冻结、项目记忆、项目日志、主分支或 Git 历史；不得引入账号、私信、评论/点赞后端、伪造互动数字、运行时假故事、个人精确位置、能力 URL/token 或 Mock 成功。

必须交付：

1. 在任务 worktree 群聊先 ACK，逐项确认已读取任务/真源交接、worktree/branch、允许/禁止范围；未 ACK 不得写源码。
2. Dock 使用五个给定 Lucide 模板资产，图形名称/许可/1x-3x 输出与真源一致；普通项 template 呈黑/灰，中央发布 original 玫红；保留 VoiceOver 名称、选中态和 >=44pt 命中区。
3. 迁移玫粉白 token（至少 `#9A536D`/`#7F4058`/`#E4C6D0`/`#FAF4F6`/`#191719`/`#ECE8EA`）与用户确认的五页视觉结构；所有真实加载/空/错误/提交中/成功/取消路径仍可达，生产无公开故事源时必须诚实空态。
4. `PublishView`、`NearbyView` 只允许视觉容器变化，已验收真实发布/响应流程不可退化；进度/交付路径不得改动。
5. 临时 XcodeGen 仅为构建/测试；最终 `project.pbxproj` 必须与任务起点完全一致，不得提交生成工程差异。
6. 运行 Core 全套、HaluowodeTests 全套、Swift parser、隐私/Mock/凭据扫描、图标资产 JSON/尺寸检查、`git diff --check`；在 iPhone 17 Pro Simulator 生成首页、搜索、发布、帮助、我的截图并逐页与 `CL-006-assets/simulator/` 对照。交接给出实际发现/执行/通过数、截图/结果包、warning、未验证项、精确路径、license、commit SHA。

验收命令（在本 worktree 执行）：

```bash
/private/tmp/xcodegen-2.46.0-release/xcodegen/bin/xcodegen generate --spec ios/project.yml
swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag010 --disable-xctest --enable-swift-testing
xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' -derivedDataPath /private/tmp/haluowode-ag010-tests -resultBundlePath /private/tmp/haluowode-ag010.xcresult test
swiftc -frontend -parse ios/Haluowode/*.swift
rg -n -i 'admin|x-admin-key|api[_-]?key|cloudflare.*token|Wish\.mockWishes|DispatchQueue\.main\.asyncAfter' ios/Haluowode ios/Packages/HaluowodeCore
git diff 543f3ff -- ios/Haluowode.xcodeproj/project.pbxproj
git diff --check
```

停止条件：所有允许范围内交付、真实执行证据、commit、handoff、STATUS 后立即停止，等待 Codex 独立验收。任何真源与 main 真实流程冲突、缺失资产、测试失败或超范围需求，先发 OBJECTION，禁止自行扩大。

### 首次验收退回与产品裁决（2026-07-19）

`1887b30dac49f243527df981e6d4f2cbdbb6b065` **不得合入**：`StoryFeed.swift` 的 `StoryFeedSource` 将虚构故事带入运行时，违反本任务禁止“运行时假故事”和生产无公开故事源时诚实空态的硬边界；其交接报告还列出与实际 HEAD 不符的 SHA，且独立 `git diff --check HEAD^ HEAD` 发现测试文件尾随空格。产品负责人随后明确要求先运行 Claude 原始 `8e95b0b` 版本；Codex 已将其分支（含仅图标修正 `463a420`）直接构建、安装并启动于真机。因此本任务终止并收回全部写权限，不得修复、合入或继续修改。

## 新任务创建要求

新任务至少包含：

1. 唯一任务 ID 和唯一负责人。
2. 独立分支/worktree 路径。
3. 允许修改的精确目录或文件。
4. 明确禁止触碰的区域。
5. 可执行的验收命令或人工验收清单。
6. 完成后必须停止，不自动领取下一项。

`CHAT-001` 是唯一允许多负责人的长期沟通任务，不适用“唯一负责人”，但仍须遵守只追加和禁止改历史的规则。

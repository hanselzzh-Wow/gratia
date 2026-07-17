# 多 AI 任务板

最后更新：2026-07-18 00:24（Asia/Shanghai）

永久角色分工见 `.ai/ROLES.md`。

状态定义：`PLANNED`、`IN_PROGRESS`、`HANDOFF_ONLY`、`REVIEW`、`ACCEPTED`、`REJECTED`、`BLOCKED`。

| ID | 负责人 | 状态 | 任务 | 允许写入 | 停止条件 |
| --- | --- | --- | --- | --- | --- |
| COORD-001 | Codex | ACCEPTED | 已审计未分配生成的 iOS 候选工程，建立协作制度并决定保留范围 | `AGENTS.md`、`PROJECT_LOG.md`、`README.md`、`.ai/**`、`docs/ios-candidate-review.md` | 审查结论已记录；后续按小任务选择性集成 |
| COORD-002 | Codex | IN_PROGRESS | 统筹团队自主推进至真实 iPhone 可安装试用；定义验收、冻结设计、拆实现、完成构建与设备测试 | 协调文档、正式源码集成和验收所需路径 | `docs/ios-mvp-acceptance.md` 全部 P0 通过后结束 |
| AG-001 | Antigravity | ACCEPTED | 已提交此前候选工程的文件、命令、假设、验证、未验证项和风险交接 | `.ai/handoffs/AG-001-antigravity.md` | 交接已完成；当前没有新的实现任务，只能参与群聊 |
| AG-002 | Antigravity | ACCEPTED | 已机械整理现有后端与 Swift 候选模型的 API 映射和差距 | 仅 `.ai/handoffs/AG-002-api-map.md` | 交接已完成；Codex 已在 `docs/ios-api-contract.md` 纠正边界并冻结 v1 |
| AG-003 | Antigravity | IN_PROGRESS | `5bc4682` 初交付被拒；按 `docs/reviews/ag-003-review.md` 修订真实公开列表纵向切片，恢复完整页面并跑真实测试 | 原 AG-003 允许范围；另可更新主区 `.ai/handoffs/AG-003-core-api.md`、追加群聊 | R1 全部验收通过、追加修订 commit、更新交接/STATUS 后停止 |
| CL-001 | Claude | ACCEPTED | 已产出首轮 UI 设计：优先 8 组页面、Design System、文案和状态覆盖 | `.ai/handoffs/CL-001-claude-design.md`、`.ai/handoffs/CL-001-assets/**` | 已评审并冻结到 `docs/ios-design-freeze-v1.md` |
| CL-002 | Claude | IN_PROGRESS | 按 v2.1 冻结基线补齐响应、交付、Profile、安全页和品牌蓝 App Icon 的 P0 设计 | `.ai/handoffs/CL-002-claude-design.md`、`.ai/handoffs/CL-002-assets/**` | 全部缺口交付、发 STATUS 后立即停止，不修改源码 |
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

## CL-002 P0 设计补齐

唯一基线：`docs/ios-design-freeze-v1.md`。不得另起视觉方向。

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

## 新任务创建要求

新任务至少包含：

1. 唯一任务 ID 和唯一负责人。
2. 独立分支/worktree 路径。
3. 允许修改的精确目录或文件。
4. 明确禁止触碰的区域。
5. 可执行的验收命令或人工验收清单。
6. 完成后必须停止，不自动领取下一项。

`CHAT-001` 是唯一允许多负责人的长期沟通任务，不适用“唯一负责人”，但仍须遵守只追加和禁止改历史的规则。

# 多 AI 写入冻结

状态：`PARTIALLY_LIFTED`

冻结原因：Antigravity 在未领取任务、未等待 UI 设计和未经过验收的情况下，一次性生成了完整 `ios/` 候选工程。当前需要先完成交接和代码审查，避免其他 AI 继续叠加修改。

## 当前规则

- Codex 作为 PM/协调人可以进行只读审计，并修改协调文档、项目日志和验收结果；已验收的 AG-003 已由 Codex 集成到本地主分支，后续正式实现仍必须使用独立 worktree。
- Antigravity 的 `AG-002` 至 `AG-006` 已验收，`AG-006` 已合入本地 `main`。Codex 接管的 `AG-007` 已完成四态截图补证、独立回归并以 merge `679a371` 合入 main；该任务源码权限已收回，主工作区源码仍冻结。
- `CX-001` 已独立验收并合入本地 main。其首页、DesignSystem 与 App Icon 变更不触碰 Antigravity 的 Progress/Track/Delivery 路径；后续其余页面视觉改造需另建独立任务。
- `CX-002` 已由 Codex 独立验收并合入本地 main；其 Nearby/详情/响应视觉变更不触碰 `AG-006` 的 Progress/Track/Delivery/Content 路径，也不改变已验收的 response ViewModel 行为。后续其余页面视觉改造必须另建独立任务。
- `CX-003` 已由 Codex 独立验收并合入本地 main；其 Publish/Profile 视觉变更不触碰 `AG-006` 的 Progress/Track/Delivery/Content 路径、任何 ViewModel 或业务语义。后续 Tab Bar 必须在 P0-D 收口后另建独立任务。
- Claude 的 `CL-001`、`CL-003`、`CL-004`、`CL-005`、`CL-006` 已验收；Antigravity 的 `AG-009` 已验收并以 `03fcb7e` 合入 main，双方源码权限均已收回。后续视觉、功能或验收扩展必须另建唯一负责人、独立 worktree、精确允许路径与质量门的任务；不得自行修改已合入导航、AG-007、业务 ViewModel/Core、后端、签名或主分支。旧 `AG-008` 已 SUPERSEDED。
- `CX-004` 已由用户确认并以 merge `b2fa630` 合入 main：玫红钥匙图标和中文系统显示名已完成真机构建、安装、启动与主屏人工确认；其源码权限已收回。
- `CX-005` 已对 Codex 局部解除冻结：只可在独立 worktree 添加 `InfoPlist.strings` 的中文/英文显示名资源，使系统语言中文显示“哈喽卧得”、英文显示“Gratia”；不得改图标、Bundle ID、签名、工程/技术名称、Swift、后端或其他资源。
- `CX-005` 已由产品负责人确认并以 merge `e0bd6c8` 合入 main；显示名本地化权限已收回。
- `CL-007` 已对 Claude 局部解除冻结：仅允许在隔离 worktree 编写 Lucide 图标审计交接和追加 STATUS，禁止修改任何 `ios/**` 源码、资源、工程、签名、任务板、冻结、日志或主分支。审计完成前不得自行将 SF Symbols 替换为 Lucide。
- `CL-007` 已由产品负责人“以该版本为基础上实机”的裁决取代；Codex 已从 Claude 本地会话、分支 `claude/rose-home-redesign`、commit `8e95b0b` 与交接中恢复 Lucide 真源，但 Claude CLI 本轮未返回 ACK/交接。该审计权限收回，不得继续。
- `AG-010` 首次交付 `1887b30` 已被 Codex 独立验收退回；产品负责人已改为先直接运行 Claude 原始 `8e95b0b` 版本，故 AG-010 全部源码与交接写权限收回。任何代理不得修复、合入、推送或继续修改该任务 worktree；后续若要把原版迁移回 main，必须重新授权。
- 产品负责人已将 Claude 原始 `463a420`（设计 `8e95b0b`）冻结为唯一 **1.0版本**；仅 `release/1.0` 分支和 `v1.0-claude-rose` 标签代表它。不得从 main、CL-006、AG-010 或任何历史分支抽取/混入代码；后续修改必须新建从 1.0 起点分出的单一授权任务。
- `CL-008` 只对 Claude 的隔离 worktree 局部解除冻结：只可写产品闭环审计 handoff 和群聊 ACK/STATUS，禁止修改任何产品代码、资源、测试、工程或 1.0 基线。
- `AG-011` 已由 Codex 独立验收 ACCEPTED：交付 `b42337e`，Core 17/17、App 23/23；Antigravity 的审计与群聊写权限已收回，不得继续修改或领取实现。
- 产品 P0 已新增：发布进度仅删除右侧“地点”；账号采用 Apple 登录并有服务端归属/删除闭环；通知设置行必须跳转本 App 系统通知设置。以上仍处于规格冻结阶段，未创建实现任务前任何代理不得修改源码、后端、D1、签名或 capability。
- `CL-008` 已由 Codex 验收 ACCEPTED：`c5e4f78`/`7c16b01` 只含审计与 STATUS，写权限收回。
- `AG-012` 初次交付实际 HEAD `814209c` 已被 Codex 退回、未合入；Antigravity 只可在原 `worktrees/ag-012-ui-integrity` 和原任务允许路径修补 Dock VoiceOver、44pt、非回归标题、真实测试/截图、空白与 commit 证据一致性。禁止扩大到登录、后端、签名/capability、ViewModel/Core/API 或 1.0 基线。
- `CL-009` 已以 `4085b85` 验收，Claude 的 handoff/群聊写权限收回；其账号 UX 由 Codex PM 修订为“游客浏览，新发布/响应提交必须 Apple 登录”，未建立后续实现任务前仍禁止任何产品代码、后端、D1、签名/capability 或 1.0 基线修改。
- 所有成员可以严格按照 `.ai/TEAM_CHAT.md` 的格式在文件末尾追加群聊消息；这是沟通例外，不解除任何源码写入冻结。
- 其他 AI 只能阅读，不得写任何文件。
- 未有新任务卡明确解除冻结前，任何代理不得修改 `ios/`、后端、部署配置、主分支或 Git 历史。`AG-007`、`CL-006` 与 `AG-009` 均已验收合入；未经 Codex 独立验收不得合入任何后续源码。

每张已批准任务可局部解除冻结，任务完成即恢复冻结等待验收。只有 Codex 将状态改为 `LIFTED` 后才全面解除。用户口头要求某个新功能，不等于自动解除范围；先由协调人创建任务卡。

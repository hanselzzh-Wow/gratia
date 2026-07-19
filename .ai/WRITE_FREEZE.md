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
- 所有成员可以严格按照 `.ai/TEAM_CHAT.md` 的格式在文件末尾追加群聊消息；这是沟通例外，不解除任何源码写入冻结。
- 其他 AI 只能阅读，不得写任何文件。
- 未有新任务卡明确解除冻结前，任何代理不得修改 `ios/`、后端、部署配置、主分支或 Git 历史。`AG-007`、`CL-006` 与 `AG-009` 均已验收合入；未经 Codex 独立验收不得合入任何后续源码。

每张已批准任务可局部解除冻结，任务完成即恢复冻结等待验收。只有 Codex 将状态改为 `LIFTED` 后才全面解除。用户口头要求某个新功能，不等于自动解除范围；先由协调人创建任务卡。

# 多 AI 写入冻结

状态：`PARTIALLY_LIFTED`

冻结原因：Antigravity 在未领取任务、未等待 UI 设计和未经过验收的情况下，一次性生成了完整 `ios/` 候选工程。当前需要先完成交接和代码审查，避免其他 AI 继续叠加修改。

## 当前规则

- Codex 作为 PM/协调人可以进行只读审计，并修改协调文档、项目日志和验收结果；已验收的 AG-003 已由 Codex 集成到本地主分支，后续正式实现仍必须使用独立 worktree。
- Antigravity 的 `AG-002` 至 `AG-006` 已验收，`AG-006` 已合入本地 `main`。`AG-007` 已正式派发：Antigravity 只可在 `worktrees/ag-007-v3-progress-delivery` 的任务板精确允许路径内写入，且完成交接后立即停止；主工作区源码仍冻结。
- `CX-001` 已独立验收并合入本地 main。其首页、DesignSystem 与 App Icon 变更不触碰 Antigravity 的 Progress/Track/Delivery 路径；后续其余页面视觉改造需另建独立任务。
- `CX-002` 已由 Codex 独立验收并合入本地 main；其 Nearby/详情/响应视觉变更不触碰 `AG-006` 的 Progress/Track/Delivery/Content 路径，也不改变已验收的 response ViewModel 行为。后续其余页面视觉改造必须另建独立任务。
- `CX-003` 已由 Codex 独立验收并合入本地 main；其 Publish/Profile 视觉变更不触碰 `AG-006` 的 Progress/Track/Delivery/Content 路径、任何 ViewModel 或业务语义。后续 Tab Bar 必须在 P0-D 收口后另建独立任务。
- Claude 的 `CL-001`、`CL-003`、`CL-004`、`CL-005` 已验收；Claude 当前无写入任务。`AG-008` 仅为 PLANNED，尚不解除任何写入范围，必须等 AG-007 验收和正式 TASK。
- 所有成员可以严格按照 `.ai/TEAM_CHAT.md` 的格式在文件末尾追加群聊消息；这是沟通例外，不解除任何源码写入冻结。
- 其他 AI 只能阅读，不得写任何文件。
- 除 `AG-007` 隔离 worktree 的精确授权路径外，任何代理不得修改 `ios/`、后端、部署配置、主分支或 Git 历史。既有隔离集成分支已把 AG-003 至 AG-006 与 CX-001/002/003 复验并合入本地主分支；未经 Codex 再次验收不得合入任何后续源码。

每张已批准任务可局部解除冻结，任务完成即恢复冻结等待验收。只有 Codex 将状态改为 `LIFTED` 后才全面解除。用户口头要求某个新功能，不等于自动解除范围；先由协调人创建任务卡。

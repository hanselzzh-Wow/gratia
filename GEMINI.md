# Antigravity / Gemini 项目指令

立即停止任何自主连续开发。先完整阅读：

1. `AGENTS.md`
2. `PROJECT_LOG.md`
3. `.ai/WRITE_FREEZE.md`
4. `.ai/TASKS.md`
5. `.ai/TEAM_CHAT.md`

Antigravity 的 `AG-001` 交接已经由 Codex 收到。当前新任务是 `AG-002`：机械整理现有后端与 Swift 候选模型的 API 映射和差距，不得修改 `ios/` 或其他源码。

`AG-002` 交接只能写入 `.ai/handoffs/AG-002-api-map.md`，必须覆盖任务板列出的端点、字段、枚举、错误和隐私边界。写完后在群聊发送 `STATUS`，立即停止并等待验收。

Gemini 可以随时按 `.ai/TEAM_CHAT.md` 的格式在文件末尾追加问题、提案、异议和回复。首次读完群聊后先发送一条 `ACK`。群聊发言不等于获得源码修改权限。

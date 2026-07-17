# Claude 项目指令

立即停止任何自主连续开发。先完整阅读：

1. `AGENTS.md`
2. `PROJECT_LOG.md`
3. `.ai/WRITE_FREEZE.md`
4. `.ai/TASKS.md`

Claude 当前唯一任务是 `CL-001`：只读审查现有 `ios/` 候选工程，并把报告写入 `.ai/handoffs/CL-001-claude-review.md`。

除该报告文件外，不得修改任何源码、项目配置、日志或 Git 状态。报告完成后立即停止，等待 Codex/PM 分配新任务。不得自行修复发现的问题，不得自动开始下一步。

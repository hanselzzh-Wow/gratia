# 多 AI 任务板

最后更新：2026-07-17 23:35（Asia/Shanghai）

状态定义：`PLANNED`、`IN_PROGRESS`、`HANDOFF_ONLY`、`REVIEW`、`ACCEPTED`、`REJECTED`、`BLOCKED`。

| ID | 负责人 | 状态 | 任务 | 允许写入 | 停止条件 |
| --- | --- | --- | --- | --- | --- |
| COORD-001 | Codex | IN_PROGRESS | 审计未分配生成的 iOS 候选工程，建立协作制度并决定保留范围 | `AGENTS.md`、`PROJECT_LOG.md`、`README.md`、`.ai/**` | 输出审计结论和下一轮明确任务后停止 |
| AG-001 | Antigravity | HANDOFF_ONLY | 停止开发，说明已创建内容、使用命令、设计假设、已验证项、未验证项和已知风险 | 仅 `.ai/handoffs/AG-001-antigravity.md` | 写完交接报告后立即停止，不得修改任何源码 |
| CL-001 | Claude | HANDOFF_ONLY | 对 `ios/` 做只读审查，对照 `docs/ios-ui-design-brief.md` 列出编译风险、架构问题、Mock/真实 API 差距和建议保留范围 | 仅 `.ai/handoffs/CL-001-claude-review.md` | 写完审查报告后立即停止，不得修复源码 |

## 当前 iOS 候选工程的验收状态

- 来源：Antigravity 未经任务分配直接生成。
- 范围：9 个 Swift 文件、XcodeGen 配置、资源目录和生成的 `.xcodeproj`，约 2,222 行 Swift。
- 已验证：Swift 语法解析通过；`Info.plist`、资源 JSON 和 `project.pbxproj` 基础格式有效。
- 未验证：没有完整 Xcode，未执行 iOS 编译、模拟器、真机、单元测试或 UI 测试。
- 已知差距：目前使用 `Wish.mockWishes`，没有 `URLSession`、API Client 或 Cloudflare 接口联调。
- 结论：保留为未验收候选，不得视为可运行 MVP，也不得继续在其上堆功能。

## 新任务创建要求

新任务至少包含：

1. 唯一任务 ID 和唯一负责人。
2. 独立分支/worktree 路径。
3. 允许修改的精确目录或文件。
4. 明确禁止触碰的区域。
5. 可执行的验收命令或人工验收清单。
6. 完成后必须停止，不自动领取下一项。

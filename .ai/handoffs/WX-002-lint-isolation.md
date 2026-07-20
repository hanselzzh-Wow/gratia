# WX-002｜嵌套 worktree 的 ESLint 隔离交接

## 结论

已修复根目录 ESLint 把 `worktrees/**` 中其他隔离 worktree 的生成 `dist/` 当作当前源码扫描的问题。修复只新增 ESLint 的全局忽略项 `worktrees/**` 与一条配置回归测试；没有改动小程序、Worker/D1、iOS、部署、密钥或业务逻辑。

## 交付

- 分支：`codex/wx-002-lint-isolation`
- worktree：`worktrees/codex-wx-002-lint-isolation`
- commit：待本交接与 STATUS 一起提交
- 修改：`eslint.config.mjs`、`tests/lint-worktree-isolation.test.mjs`、本文件、`.ai/TEAM_CHAT.md`

## 复现与修复证据

修复前，在根工作区已有 `worktrees/codex-wx-001-launch/dist/`（50 个构建文件）时运行 `npm run lint`，实际报告 **5 error / 1804 warning**；所有错误来自该嵌套 `dist/**`，不是产品源码。

修复后依次执行 `npm run build && npm run lint`、`node --test tests/lint-worktree-isolation.test.mjs`、`npm test` 与 `git diff --check`。结果：构建通过；lint 为 **0 error / 0 warning**；WX-002 回归 **1/1** 通过；完整测试 **17/17** 通过；格式检查零输出。Vinext 仍会提示动态 API 静态分类的既有 informational warning，未新增失败。

另从主工作区执行 ESLint，并显式加载本分支配置、保留原 lint 命令的 `dist/.next/.wrangler` 忽略项，实际退出为 0；这直接覆盖“主工作区扫描存在嵌套 worktree 生成物”的原复现场景。

## 未验证与停止

- 未删除或修改任何既有 worktree 的 `dist/`；修复目标正是使它们不会污染根质量门。
- 未执行微信开发者工具、真实 AppID 换码、生产部署、D1 迁移或平台审核；均不属于本任务。
- 已停止，等待 Codex PM 独立验收与决定是否合入。

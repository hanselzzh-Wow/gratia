# 哈喽卧得 · 快速接班卡

最后更新：2026-07-18（Asia/Shanghai）｜维护者：Codex PM

> 新会话先读本文件、`AGENTS.md`、`.ai/WRITE_FREEZE.md` 与 `.ai/TASKS.md`；只读工作不必通读长日志。开始写入前仍须核对 Git/worktree 现状。`PROJECT_LOG.md` 是可追溯事实记录，只有需要历史证据、验收细节或冲突裁决时再按需查阅。

## 北极星与不可违背项

- 做出可在真实 iPhone 安装试用的原生 SwiftUI MVP，之后走 TestFlight/App Store；React/GitHub Pages 仅是历史原型/接口工具。
- 复用已上线 Cloudflare Worker + D1 + R2：`https://haluowode-mvp.hanselzzh.workers.dev`。消费者 App 永不内置运营 PIN、Cloudflare 凭据或私密联系方式。
- Codex 统筹、验收、集成；Claude 只做设计；Antigravity 只做已派发的隔离实现任务。非协调人不改主分支、日志、任务板、后端或签名。
- 代码必须在独立 worktree；无明确 `IN_PROGRESS`/允许路径只可阅读。完成即停止，交接后由 Codex 验收。

## 已冻结的产品与体验

- 五栏：**首页**（经授权、脱敏的已完成故事与“发布/帮助”转化）、**附近**（活跃心愿市场/搜索/响应）、**发布**、**进度**（私密查询/交付）、**我的**（访客帮助/隐私）。
- 首页不是第二个市场；MVP 没有账号、好友、私信、评论、关注或伪造点赞数。公开故事需独立同意，不能暴露交付链接或私人订单。
- 原生 `TabView` 负责导航：iOS 26+ 让系统呈现浮动 Liquid Glass，旧系统自然回退。禁止网页式自绘 Dock、固定 blur、渐变、Emoji、默认卡片阴影。
- 视觉：暖白/暖蓝、SF Symbols、8pt 节奏、Dynamic Type、44pt 点击区、内容优先；权威输入为 `docs/ios-experience-blueprint.md` 与 `docs/ios-design-freeze-v3.md`。

## 当前事实（每次续接先验证）

- `main` 已有真实公开列表、发布、响应与 v3 基线（P0-A/B/C）；P0-D 真实查询进度/交付尚未合入。
- `AG-006`：`worktrees/ag-006-real-track`，HEAD `4a30bd0`，仍有未提交修订。必须先：生产 `ProgressView` 的状态文案 helper 并直接测试、删除依赖 AVPlayer 系统行为的测试、如实更新交接/测试证据，再提交/STATUS。Codex 已在该 worktree `TEAM_CHAT` 留下 `CHAT-20260718-201500-CODEX-062`。
- `CL-005`：`worktrees/claude-cl-005-home-community`，尚无新资产。应交 393×852 首页正常/空/故事详情的 HTML/SVG/1x/3x 和职责/隐私/无障碍交接；不得写 SwiftUI。
- 主线 iOS 27 App bundle 已生成，但**未验收安装或截图**。CoreSimulator 的干净设备启动失败：`launchd_sim may have crashed or quit responding`；必须完整重启 Mac 后再从干净 Simulator 重试。

## 强制交接与接班卡同步

**任何任务的“完成”不等于可继续。** 负责人交付后停止；只有 Codex 验收并同步本卡，才允许任务板进入 `ACCEPTED`、`REJECTED`、`BLOCKED` 或下一任务派发。

| 角色 | 完成时必须交付 | 禁止事项 |
| --- | --- | --- |
| Antigravity | 在允许的 `.ai/handoffs/<TASK>.md` 写：commit SHA、精确改动路径、实际命令/测试数与结果、隐私处理、warning/未验证项、回滚/停止状态；在本 worktree `TEAM_CHAT` 追加 `STATUS` 后停止 | 不改 `PROJECT_MEMORY.md`、`PROJECT_LOG.md`、任务板、主分支；不自动领下一项 |
| Claude | 在允许的交接中写：交付资产索引/尺寸、页面与状态覆盖、token/SwiftUI 映射、无障碍、隐私/授权边界、未定设计决定；追加 `STATUS` 后停止 | 不改产品代码、冻结文件、接班卡、主分支；不自行指导实现 |
| Codex PM | 独立复验后在**同一次验收/退回/合入**中：更新本卡的“当前事实/恢复顺序”，向 `PROJECT_LOG.md` 追加证据，更新 `.ai/TASKS.md` 状态，必要时在群聊裁决，并单独提交协调文档 | 不把未提交、未测或仅口头声明写成完成；不代替外部负责人越界修代码 |

### 必须触发本卡更新的事件

1. 新任务派发、负责人/允许路径/停止条件变化；
2. 外部负责人提交、STATUS、退回、验收、合入或取消；
3. 主线行为、测试证据、生产 API 契约、设计冻结或隐私边界变化；
4. 模拟器/真机/签名等环境阻塞出现、解除或需要用户动作；
5. 产品负责人作出会影响信息架构、体验或范围的决定。

更新规则：只重写本卡的**当前事实和恢复顺序**，保持短小；完整命令输出与历史只追加到 `PROJECT_LOG.md`。若证据不足，本卡必须写“未验证/待验收”，不能猜测。

## 恢复顺序

1. 用户重启 Mac 后：启动干净 iOS 27 Simulator → 安装/启动主线 App → 截图验证系统 Dock；不能把 bundle 生成当作运行通过。
2. 收到 AG-006 新 commit 后：独立审查 diff/交接，跑 Core、Swift parser、iOS test target、隐私/Mock 扫描；合格才用隔离集成分支合入 main。
3. 收到 CL-005 后：逐页验收职责、授权、零 Emoji/渐变、系统导航前提；接受后才创建独立首页实现任务。
4. P0-D 与首页收口后：用户连接 iPhone，在 Xcode 选免费 Personal Team、信任 Mac/开发者；Codex 构建安装并跑受控真实闭环。TestFlight/App Store 另行准备。

## 快速核验

```bash
git status --short
git -C worktrees/ag-006-real-track status --short
git -C worktrees/claude-cl-005-home-community status --short
xcrun simctl list devices available
```

主线/任务验收的详细命令、历史证据和未决问题在 `PROJECT_LOG.md`、`.ai/TASKS.md`、`.ai/TEAM_CHAT.md`。任何状态变化只改写本文件的“当前事实/恢复顺序”，同时向 `PROJECT_LOG.md` 追加事实，不写密钥、PIN、证书或用户隐私。

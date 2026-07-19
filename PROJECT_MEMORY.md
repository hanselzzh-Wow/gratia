# 哈喽卧得 · 快速接班卡

最后更新：2026-07-18（Asia/Shanghai）｜维护者：Codex PM

> 新会话先读本文件、`AGENTS.md`、`.ai/WRITE_FREEZE.md` 与 `.ai/TASKS.md`；只读工作不必通读长日志。开始写入前仍须核对 Git/worktree 现状。`PROJECT_LOG.md` 是可追溯事实记录，只有需要历史证据、验收细节或冲突裁决时再按需查阅。

## 当前持久 Goal

以产品负责人确认的 Claude 原始玫粉白/Lucide 客户端为唯一 **1.0版本**，将其稳定迭代为可在真实 iPhone 安装试用、后续可进入 TestFlight/App Store 的 MVP；保留其现有体验与技术身份，任何后续功能、真实 API、测试和发布工作均以 1.0 为基线。除必须由用户完成的 Apple 账号、签名或系统授权外自动推进。

## 北极星与不可违背项

- 做出可在真实 iPhone 安装试用的原生 SwiftUI MVP，之后走 TestFlight/App Store；React/GitHub Pages 仅是历史原型/接口工具。
- 复用已上线 Cloudflare Worker + D1 + R2：`https://haluowode-mvp.hanselzzh.workers.dev`。消费者 App 永不内置运营 PIN、Cloudflare 凭据或私密联系方式。
- Codex 统筹、验收、集成；Claude 只做设计；Antigravity 只做已派发的隔离实现任务。非协调人不改主分支、日志、任务板、后端或签名。
- 代码必须在独立 worktree；无明确 `IN_PROGRESS`/允许路径只可阅读。完成即停止，交接后由 Codex 验收。

## 已冻结的产品与体验

- 产品负责人最新裁决的五个 Dock 位置是：**首页、搜索、中央发布动作、帮助、我的**。它是四个一级页面加一个中央全局动作；旧“附近”改为“帮助”，旧“进度”移入“我的”的“我发布的/我帮助的”内部导航。
- 首页不是第二个市场；MVP 没有账号、好友、私信、评论、关注或伪造点赞数。公开故事需独立同意，不能暴露交付链接或私人订单。
- Dock 不显示汉字但必须保留 VoiceOver 名称、选中态与 44pt 命中区；普通图标为黑/深灰，只有中央发布为主题色。帮助使用两只手相握的原创图标。中央发布打开真实发布流程，不是第五个持久页面。
- 最新视觉为用户认可的 Claude 版本：大面积纯白、媒体优先，主题色 `#9A536D`，深色 `#7F4058`，柔粉 `#E4C6D0`，浅粉底 `#FAF4F6`，主文字 `#191719`。此裁决在首页/导航/搜索/帮助/我的范围内取代旧 v3 暖蓝与旧五栏；Dynamic Type、VoiceOver、44pt、隐私和真实状态规则仍有效。

## 当前事实（每次续接先验证）

- **运行状态：产品负责人已恢复自主推进。** Codex 继续验收、集成和依赖驱动派发；外部负责人仍只做唯一已派任务，交接后停止。
- `main` merge commit `296ab12` 已具备真实公开列表、发布、响应、查询进度/交付与 v3 基线（P0-A/B/C/D）。AG-006 独立质量门：Core 17/17、iPhone 17 Pro iOS 27 Simulator 23/23，0 failure/skip/runtime warning。
- `AG-007` 已 ACCEPTED 并以 merge `679a371` 合入 main：本地 XCTest fixture 在 iPhone 17 Pro / iOS 27 Simulator 生成查询、404、delivered/待确认、交付失败四态证据；main 独立回归 App 27/27、Core 17/17，0 failure/skip/runtime warning。未访问生产 API，能力 URL/token 未进入画面或测试输出；真实远端媒体、系统 Link、极端无障碍设置、旧系统与真机仍未验证。
- `CL-006` 与 `AG-009` 已 ACCEPTED 并以 merge `03fcb7e` 合入 main：玫红首页/搜索/中央发布/帮助/我的、步骤文案回归、DEBUG/Release 边界及生成工程归零均已收口。main 独立复验 Core 17/17、iPhone 17 Pro / iOS 27 Simulator App 49/49，0 failure/skip/runtime warning；Release 二进制对 `-cl006-initial-tab`、`-cl006-show-publish` 为 0 命中。两条 iOS 16/XCTest linker warning 仍存在；真机、旧 iOS、极端无障碍与真实远端媒体未验证。旧 `AG-008` 已 SUPERSEDED。
- main 真实安装冷启动约 30 秒后稳定渲染首页诚实空态；启动参数逐页截图已目视确认搜索、帮助、我的与发布入口，发布页显示 `第 1 步，共 3 步`。这些是 Simulator 证据，不替代真机与无障碍实测。
- **产品 1.0 基线已冻结：** Claude 原始玫粉白/Lucide 客户端 `463a420`（设计主提交 `8e95b0b`）是唯一的“1.0版本”；固定为本地 `release/1.0` 与标签 `v1.0-claude-rose`。其 Bundle ID 为 `com.hanselzzh.gratia`，已于 2026-07-19 真机成功构建、安装、启动。今后用户说“1.0版本”即指这一个精确提交，不能误指 main、CL-006、AG-010 或其他历史候选。
- 历史并行 worktree/任务分支全部清理；`main` 只保留为既有历史与协调记录，不能再作为 1.0 的实现来源。`AG-010` 未通过验收且已 SUPERSEDED，未合入 1.0。
- MVP 推进已恢复：`CL-008` 由 Claude 审计 1.0 的产品/交互闭环，`AG-011` 由 Antigravity 独立跑真实构建测试并审计工程可达性；两者都只写 handoff/群聊，禁止改产品代码。Codex 等两份证据后冻结第一张从 `release/1.0` 分出的实现任务。

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

### 用户控制方式

- 正常情况：负责人完成当前任务后按上述交接/STATUS 自动停止，用户无需再提醒“下班”。
- 需要立刻暂停：用户说“暂停当前任务，不要提交或领取新任务，写 STATUS 后停止”。
- 需要复工：要求负责人依次读取根目录 `PROJECT_MEMORY.md`、`AGENTS.md`、`.ai/WRITE_FREEZE.md`、`.ai/TASKS.md` 的任务章节、自己 worktree 的最新 `TEAM_CHAT.md`，再检查自己的 Git 状态；只继续原任务范围。

## 恢复顺序

1. 等待并独立验收 `CL-008` 产品闭环审计与 `AG-011` 工程基线审计；任何代理故障按规则立即报告产品负责人。
2. Codex 合并两份证据，冻结第一张从 `release/1.0` 分出的 P0 纵向实现任务，保持 1.0 视觉与 Gratia 技术身份。
3. 按公开列表/发布/响应/查询交付的依赖顺序实现、测试、模拟器/真机验收，直到完整 MVP 闭环成立。

## 快速核验

```bash
git status --short
git -C worktrees/ag-006-real-track status --short
git -C worktrees/claude-cl-005-home-community status --short
xcrun simctl list devices available
```

主线/任务验收的详细命令、历史证据和未决问题在 `PROJECT_LOG.md`、`.ai/TASKS.md`、`.ai/TEAM_CHAT.md`。任何状态变化只改写本文件的“当前事实/恢复顺序”，同时向 `PROJECT_LOG.md` 追加事实，不写密钥、PIN、证书或用户隐私。

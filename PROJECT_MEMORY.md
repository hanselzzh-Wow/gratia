# 哈喽卧得 · 快速接班卡

最后更新：2026-07-19（Asia/Shanghai）｜维护者：Codex PM

> 新会话先读本文件、`AGENTS.md`、`.ai/WRITE_FREEZE.md` 与 `.ai/TASKS.md`；只读工作不必通读长日志。开始写入前仍须核对 Git/worktree 现状。`PROJECT_LOG.md` 是可追溯事实记录，只有需要历史证据、验收细节或冲突裁决时再按需查阅。
>
> **完成一个有意义的迭代后，必须在 [`docs/iteration-log.md`](docs/iteration-log.md) 追加一条记录**（处境 → 决策与理由 → 结果 → 未验证项）。它面向复盘与对外讲述，与 `PROJECT_LOG.md` 的验收证据分工不同，两者都要写。规则见 `AGENTS.md`。

## 当前持久 Goal

以已冻结的 Claude 原始玫粉白/Lucide iOS 1.0 为体验基线，优先由 Codex 独立完成**可提交微信审核的小程序 0.1 上线候选**：复用 Worker/D1/R2 与人工审核闭环，完成微信登录、发布、审核、帮助响应、本人记录、查询/交付、删除账户和运营配套；账号层保持 provider-neutral，未来再接 Apple/iOS。当前不以 Apple Developer Program、TestFlight 或 App Store 为前置条件；微信主体资质与最终审核仍以平台实际裁决为准。

## 北极星与不可违背项

- 近期交付是可提交微信审核并可由受邀用户真实试用的小程序闭环；iOS 1.0 保留，待试用验证后再走 Apple Developer Program、TestFlight/App Store。
- 复用已上线 Cloudflare Worker + D1 + R2：`https://haluowode-mvp.hanselzzh.workers.dev`。消费者 App 永不内置运营 PIN、Cloudflare 凭据或私密联系方式。
- `WX-001` 由 Codex 独立统筹、实现、验收、集成；不等待或派发 Claude/Antigravity。非协调人不改主分支、日志、任务板、后端或签名。
- 代码必须在独立 worktree；无明确 `IN_PROGRESS`/允许路径只可阅读。完成即停止，交接后由 Codex 验收。

## 已冻结的产品与体验

- 产品负责人最新裁决的五个 Dock 位置是：**首页、搜索、中央发布动作、帮助、我的**。它是四个一级页面加一个中央全局动作；旧“附近”改为“帮助”，旧“进度”移入“我的”的“我发布的/我帮助的”内部导航。
- 首页不是第二个市场；MVP 没有账号、好友、私信、评论、关注或伪造点赞数。公开故事需独立同意，不能暴露交付链接或私人订单。
- Dock 不显示汉字但必须保留 VoiceOver 名称、选中态与 44pt 命中区；普通图标为黑/深灰，只有中央发布为主题色。帮助使用两只手相握的原创图标。中央发布打开真实发布流程，不是第五个持久页面。
- 最新视觉为用户认可的 Claude 版本：大面积纯白、媒体优先，主题色 `#9A536D`，深色 `#7F4058`，柔粉 `#E4C6D0`，浅粉底 `#FAF4F6`，主文字 `#191719`。此裁决在首页/导航/搜索/帮助/我的范围内取代旧 v3 暖蓝与旧五栏；Dynamic Type、VoiceOver、44pt、隐私和真实状态规则仍有效。

## 当前事实（每次续接先验证）

- **运行状态：WX-001 本地上线候选已验收并集成；等待真实微信平台外部条件。** Codex 已完成实现、验收与主线集成，不派发或等待外部代理。
- `main` merge commit `296ab12` 已具备真实公开列表、发布、响应、查询进度/交付与 v3 基线（P0-A/B/C/D）。AG-006 独立质量门：Core 17/17、iPhone 17 Pro iOS 27 Simulator 23/23，0 failure/skip/runtime warning。
- `AG-007` 已 ACCEPTED 并以 merge `679a371` 合入 main：本地 XCTest fixture 在 iPhone 17 Pro / iOS 27 Simulator 生成查询、404、delivered/待确认、交付失败四态证据；main 独立回归 App 27/27、Core 17/17，0 failure/skip/runtime warning。未访问生产 API，能力 URL/token 未进入画面或测试输出；真实远端媒体、系统 Link、极端无障碍设置、旧系统与真机仍未验证。
- `CL-006` 与 `AG-009` 已 ACCEPTED 并以 merge `03fcb7e` 合入 main：玫红首页/搜索/中央发布/帮助/我的、步骤文案回归、DEBUG/Release 边界及生成工程归零均已收口。main 独立复验 Core 17/17、iPhone 17 Pro / iOS 27 Simulator App 49/49，0 failure/skip/runtime warning；Release 二进制对 `-cl006-initial-tab`、`-cl006-show-publish` 为 0 命中。两条 iOS 16/XCTest linker warning 仍存在；真机、旧 iOS、极端无障碍与真实远端媒体未验证。旧 `AG-008` 已 SUPERSEDED。
- main 真实安装冷启动约 30 秒后稳定渲染首页诚实空态；启动参数逐页截图已目视确认搜索、帮助、我的与发布入口，发布页显示 `第 1 步，共 3 步`。这些是 Simulator 证据，不替代真机与无障碍实测。
- **产品 1.0 基线已冻结：** Claude 原始玫粉白/Lucide 客户端 `463a420`（设计主提交 `8e95b0b`）是唯一的“1.0版本”；固定为本地 `release/1.0` 与标签 `v1.0-claude-rose`。其 Bundle ID 为 `com.hanselzzh.gratia`，已于 2026-07-19 真机成功构建、安装、启动。今后用户说“1.0版本”即指这一个精确提交，不能误指 main、CL-006、AG-010 或其他历史候选。
- 历史并行 worktree/任务分支全部清理；`main` 只保留为既有历史与协调记录，不能再作为 1.0 的实现来源。`AG-010` 未通过验收且已 SUPERSEDED，未合入 1.0。
- MVP 推进已恢复：`AG-011` ACCEPTED（`b42337e`；Core 17/17、App 23/23），`CL-008` ACCEPTED（`c5e4f78`/`7c16b01`）。真实发布、帮助列表、响应、发布者查询/交付预览已接线，但首页/搜索没有生产故事 API，“我帮助的”无响应者查询，账号/跨设备身份不存在，且 App 缺发布者确认完成动作。
- 当前授权已从“小范围原型”扩大为小程序上线候选：须实现微信登录、provider-neutral 用户/会话/归属、本人发布/响应、发布者确认完成、账户删除、人工审核说明与现有运营台兼容；游客可浏览，发布/响应最终提交必须登录。iOS 通知设置只保留为未来事项；小程序 Dock 可改为固定底栏，其他视觉以 1.0 玫粉白/Lucide 为基线并记录每项平台适配。
- `WX-001` 已 ACCEPTED 并以 main merge `dc5269d` 集成：`miniprogram/` 原生工程和 `project.config.json`、Worker/D1 账户迁移、受保护账户 API、交付代理、确认完成、账户匿名化、运营兼容、隐私/提审清单均已落地。独立验收为 lint 0 error/0 warning、`npm test` 16/16、`git diff --check` 零输出；本机未发现微信开发者工具，未验证真实 AppID/AppSecret 换码、D1 生产迁移、体验版、主体/域名或最终审核。
- `WX-002` 已 ACCEPTED 并以 main merge `86b020e` 集成：ESLint 现在明确忽略 `worktrees/**`，避免嵌套隔离 worktree 的 `dist/` 污染根质量门。主线独立 `npm run build && npm run lint` 为 0 error/0 warning、`npm test` 17/17、格式检查零输出；未改小程序业务、Worker/D1、iOS、部署或密钥。
- `CL-009` Apple 账号 UX `4085b85` 仍为未来 iOS 参考，但 Apple 实现已 DEFERRED，不能作为当前小程序阻塞。`AG-012` 的所有未验收 iOS 提交（包括 `814209c`、`70d3523`、`115e0d2`）均未合入；因产品优先级切换和 Antigravity 配额阻塞而暂停，禁止自动恢复或混入小程序。

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

1. 使用 `docs/wechat-mini-program-launch.md` 在实际微信控制台核实主体/类目、服务域名、隐私指引、体验版及提审字段；在私密 Worker 环境配置真实微信登录变量，绝不提交。
2. 在微信开发者工具导入 `project.config.json`，以真实 AppID 和受邀体验者跑登录→发布→人工审核→帮助响应→本人记录/查询→交付→确认完成/删除账户；随后执行受控 D1 迁移与预览部署。
3. 只有控制台审核通过并成功发布后才宣布上线。`AG-012` 与 Apple 登录仅在产品负责人重新授权后恢复。

## 快速核验

```bash
git status --short
git -C worktrees/ag-006-real-track status --short
git -C worktrees/claude-cl-005-home-community status --short
xcrun simctl list devices available
```

主线/任务验收的详细命令、历史证据和未决问题在 `PROJECT_LOG.md`、`.ai/TASKS.md`、`.ai/TEAM_CHAT.md`。任何状态变化只改写本文件的“当前事实/恢复顺序”，同时向 `PROJECT_LOG.md` 追加事实，不写密钥、PIN、证书或用户隐私。

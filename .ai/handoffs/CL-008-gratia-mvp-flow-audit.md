# CL-008 交接：Gratia 1.0 MVP 产品闭环审计

- 负责人：Claude（产品体验/设计）
- 工作区：`worktrees/cl-008-mvp-flow-audit`｜分支：`codex/cl-008-mvp-flow-audit`
- 审计基线：`release/1.0@463a420`（设计主提交 `8e95b0b`，父提交 `3e5cb0c`）。**未改任何产品代码；1.0 配色、Dock、Lucide、`Gratia` 技术身份视为不可替换。**
- 性质：纯文档审计。所有结论来自逐行阅读源码与基线内截图（`.ai/handoffs/CL-006-assets/simulator/*.png`）；本任务未构建、未运行 App——运行态证据属 `AG-011`。

## 0. 审计范围（读过的文件）

`ios/Gratia/`：ContentView、HomeView、StoryFeed、SearchView、NearbyView、PublishView、ProfileView、ProgressView、DeliveryPreviewView、DesignSystem、GratiaApp、Info.plist、en/zh-Hans `InfoPlist.strings`、Assets（五个 Tab imageset）；ViewModel 四件套关键路径（WishList/Publish/WishResponse/TrackWish）；`ios/Packages/GratiaCore/Sources/GratiaCore/WishAPIClient.swift`、`Models.swift` 接口面。

结构事实：五位 Dock 由系统 `TabView` 实现（发布位是 `Color.clear` 占位，`onChange` 拦截选中→弹发布 Sheet→回退上一栏目）；v3 旧 token 已在 `DesignSystem` 全局重映射到 Rose 组，因此沿用旧 token 名的帮助/发布/进度页与新页面同为玫粉白；显示名 en=Gratia、zh=哈喽卧得；API 基址为已上线 Worker，无任何密钥/PIN 内置。

## 1. 五个一级入口 · 职责与状态

| 入口 | 职责（1.0 现状） | 状态覆盖 |
| --- | --- | --- |
| 首页 | 已授权公开的完成故事流（X 式文字优先）。生产无故事源 → 诚实空态 + 「我也想发布心愿」「去看看谁需要帮助」两个真实 CTA | 空态✓／筛选标签行✓／无匹配✓；加载/错误态尚无（无后端源）|
| 搜索 | 按地点/场景/内容形式/状态检索公开故事；筛选可"应用到首页"成为可清除标签；「等待帮助」引导去帮助页 | 有条件才显示结果区；空结果仅一行文案（见 P0-1）|
| 发布（中央动作） | 弹 Sheet 打开真实三步发布（场景/城市/地标 → 内容/形式/时间 → 感谢金/联系/同意），真实 API，成功页含公开编号+复制 | 校验/提交中/失败重试/成功✓；步数文案已正确插值 |
| 帮助 | 真实公开心愿市场：列表（城市筛选+关键词+形式 chips）→ 详情 → 响应表单（真实提交）→ 成功页 | idle/loading/failed+重试/empty/loaded/筛选空✓ |
| 我的 | 访客卡、「我发布的/我帮助的」、支持与条款。进度查询收在内部 | 见 P1-3 |

## 2. 四条真实业务链路的用户旅程

### 链路 A：浏览公开心愿 → 现场响应（帮助）
1. Dock「帮助」→ `NearbyView`（题「等待帮助的心愿」）→ 进入即 `fetchWishes`（GET /wishes，城市参数可选）。
2. 加载中转圈；失败显示错误+「重试」；空显示"没有找到符合条件的心愿"；成功显示计数+列表，客户端按关键词/交付形式过滤，支持下拉刷新。
3. 点行 → push `WishDetailView`（状态、感谢金、内容、履约说明、隐私说明）→ 底部「我刚好在这里，可以帮忙」→ `.large` Sheet 响应表单。
4. 表单：称呼/联系方式（仅运营可见）/选填说明/同意勾选；校验错误逐字段显示；提交中禁用；失败横幅+重试；取消或下滑=`viewModel.cancel()` 并关闭。
5. 成功：Sheet 关闭 → push `ApplySuccessView`（明确"等待运营确认，不代表已经接单"）→「我知道了」pop 回详情页。
- 出口/返回：详情←列表系统返回；成功页隐藏返回键只留主按钮。断点见 P1-2。

### 链路 B：发布心愿（中央动作）
1. 任意栏目点 Dock 中央玫红「发布」（或首页空态 CTA）→ 栏目选中被拦截回原栏目，同时弹发布 Sheet（无系统导航栏，仅底部 Dock 保留系统材质，符合"除 Dock 外无液态玻璃"裁决）。
2. 三步表单逐步校验，「继续/确认并提交」置灰逻辑正确；失败横幅+重试保留草稿。
3. 成功页：公开编号（等宽大字）+「复制编号」+ 状态路线（已提交→审核中→匹配中→已接单）+「去『我的』查看进度」（关 Sheet→我的）/「返回首页」。
- 出口：右上「取消」= 清空草稿并关闭（见 P2-2）；下滑关闭不清草稿，重开还原（事实上的草稿保留，未告知用户，见 P2-3）。

### 链路 C：查询进度与交付（我的）
1. 我的 →「我发布的」→ `MyActivityView(published)`：状态 chips + 诚实空文案 +「用公开编号查询」→ Sheet `ProgressView`。
2. 输入公开编号+联系方式（逐字段校验）→ 真实 trackWish；失败横幅（404 映射为"请检查编号和联系方式"）+重试；成功后**联系方式立即从内存清空**（隐私正确）。
3. 结果页：当前状态（`delivered` 显示为「待确认」）、心愿概要、流转时间线；有交付文件时出现入口 → 全屏 `DeliveryPreviewView`（黑底，视频 AVKit/图片 AsyncImage，失败态有提示）；「切换单号」重置查询。
4. 「我帮助的」→ 同结构页，CTA 为「去看看谁需要帮助」（dismiss→帮助栏目）。
- 出口：Sheet 下滑关闭，`onDisappear` 取消请求。

### 链路 D：公开故事（首页/搜索）
- 生产：`StoryFeedSource.stories` 恒为空 → 首页诚实空态；搜索选任何条件 → 空结果行。
- DEBUG + `--demo-stories`：三条虚构故事（媒体占位带「虚构示例内容」角标，昵称虚构，城市级地点，模糊时间，「已授权公开」标注）；评论/点赞点击 → 「功能准备中」弹窗（明确"不会展示虚假的互动数据"）；分享用系统 `ShareLink`（真实功能）。

## 3. `StoryFeedSource` 虚构故事边界（裁决建议，冻结）

1. **只能用于**：SwiftUI Preview、DEBUG 构建加 `--demo-stories` 启动参数的版式验证、以及由此产出的截图/宣传素材（素材必须保留「虚构示例内容」角标或在投放物中注明示例）。
2. **不得进入产品**：Release 构建无论如何不得出现 demo 故事——当前实现（`#if DEBUG` + 显式启动参数，默认空）满足此要求，应作为验收断言长期锁定（AG-011 已被要求测 Release 二进制 0 命中）。
3. **首页生产内容策略**：只展示"心愿完成 + 发布者事后单独同意公开"的真实故事；昵称/头像/媒体各自需要公开授权；无内容时保持现有空态与两个真实 CTA；接入真实故事 API 前，不引入任何"即将上线"假卡片、不显示任何互动数字；下架申请入口文案已有（空态脚注），故事卡上线时需补每条的举报/下架路径（记为未来需求，不属 1.0 断点）。

## 4. 断点清单（P0/P1；P2 为记录）

**P0（第一张实现任务应修）**

- **P0-1 搜索页生产态误导**：四个维度的词表（巴黎/海边/雪山/婚礼祝福/演唱会/精彩分享…）取自虚构 demo 标签。生产无公开故事时，用户任选条件只得到一行"没有匹配的公开内容"，页面从未解释"公开故事尚未上线"；词表本身暗示平台已有巴黎/雪山内容。需要：生产空库时在结果区展示与首页同级的诚实说明（公开故事未上线 + 去帮助页/去发布的真实出口），并审视词表来源标注。`SearchView.swift`。
- **P0-2 Dock 的 VoiceOver 标签挂载点存疑**：`tabItem { Image("TabHouse") }` 无文字，`.accessibilityLabel("首页")` 加在页面内容视图上而非 tab 按钮上；VoiceOver 很可能对 Dock 按钮朗读资产名（"TabHouse"）或无名。PROJECT_MEMORY 的裁决明确"Dock 不显示汉字但必须保留 VoiceOver 名称"。需运行态验证（AG-011/真机），若确认即为 P0 无障碍缺陷；修法是把标签放进 `tabItem`（如 `Label`+隐藏文字或 `Image` 上直接 `.accessibilityLabel`）。`ContentView.swift`。

**P1**

- **P1-1 时间线原始事件名直出**：`ProgressView` 时间线标题直接显示 `event.eventType`（后端原始字符串，很可能是英文 snake_case），副行"变更至 [状态]"。需事件类型→中文文案映射表；真实响应样例由 AG-011 提供后定稿。
- **P1-2 响应成功后可重复提交**：`ApplySuccessView` pop 回详情页后，「我刚好在这里，可以帮忙」按钮原样可用，无"已响应过"记忆（无账户属预期），但对用户没有任何提示。建议详情页在本会话内（内存级）标记已提交并把按钮改为"已提交响应，等待运营确认"。不引入本地持久记录。
- **P1-3 「我发布的/我帮助的」死筛选**：状态 chips（等待回应/进行中/已完成）在无账户阶段永远只切换空文案，看似功能实为装饰；空文案"此设备上没有…记录"诚实但 chips 提升了预期。建议 1.0.x 隐藏 chips 或并入一句"账户上线后可按状态筛选"。
- **P1-4 进度页排版体系仍是 v3 遗留**：`.system(size:)` 硬编码字号（不随 Dynamic Type 缩放）、阴影卡片、蓝色时代命名（仅因 token 重映射而显玫红）。视觉可接受但可达性（Dynamic Type）与体系一致性低于其它页面；1.0 基于 `3e5cb0c`，不含 main 上 AG-007 的 `init(viewModel:)` 测试钩子（四态截图证据不可直接复用到 1.0，需 AG-011 重建）。
- **P1-5 首页下拉刷新无操作**：`refreshable {}` 空实现，用户得到刷新手势但无任何反馈或说明。接入故事 API 前建议移除或在结束时短暂说明。

**P2（记录，不阻塞）**

- P2-1 中央发布拦截可能有一帧栏目高亮闪动（`selectedTab` 先变后还原），需真机观感确认。
- P2-2 发布「取消」立即清空全部草稿且无确认；误触成本高。
- P2-3 发布 Sheet 下滑关闭事实上保留草稿，但无"草稿已保留"暗示，与「取消」清空行为不一致。
- P2-4 搜索「状态」维度混合故事流（精彩分享）与心愿市场（等待帮助）两种语义，靠 waitingNotice 弥合，长期应拆分。
- P2-5 `MyActivityView` 的查询 Sheet 里再嵌 `NavigationStack`（ProgressView 自带），层级冗余无碍使用。

**隐私专项结论**：联系方式仅在表单出现且标注"仅运营可见"，查询成功即从内存清空；交付 URL 只在查询结果内打开，不落公开页面；demo 故事无真实身份、城市级地点、模糊时间；分享文本只含故事正文。未发现密钥/PIN/管理端字样。**未发现 P0 隐私断点。**

## 5. 第一张最小纵向实现任务规格（建议 ID：AG-012「1.0 诚实态与可达性硬化」）

- 目标：不动视觉体系与业务语义，修 P0-1、P0-2（若运行态确认）、P1-1、P1-3、P1-5 五个诚实性/可达性断点。
- 允许文件（建议，Codex 定稿）：`ios/Gratia/SearchView.swift`、`ContentView.swift`、`ProgressView.swift`（仅时间线文案映射与字体 token 化）、`ProfileView.swift`（MyActivityView chips）、`HomeView.swift`（refreshable）、`ios/GratiaTests/**` 新增断言；禁止其它文件。
- 不变量：Rose 色板值、五位 Dock 结构与 Lucide 资产、`Gratia` Bundle/工程名、双语显示名、全部 ViewModel/Core/API 语义、demo 故事 DEBUG 边界。
- 验收截图清单（iPhone 17 Pro Simulator + 真机各一套为佳）：①生产态首页空态；②搜索无条件页；③搜索选条件后的诚实空结果说明；④帮助列表真实数据；⑤进度查询 loaded 态时间线中文文案；⑥我的→我发布的（chips 处理后）；⑦VoiceOver 逐 Dock 项朗读名记录（文字或录屏）。
- 禁止事项：新增虚构运行时数据、账号/点赞/评论后端、改配色或图标、动 `release/1.0` 历史、把 demo 词表当真实内容源。

## 6. 未验证项（如实声明）

- 本任务零构建零运行：编译可通过性、测试通过数、真实 API 响应（含 eventType 实际取值、404/429 文案触达）、Dock VoiceOver 实际朗读、发布拦截闪动、Dynamic Type 极端档表现——全部待 `AG-011` 工程审计与后续真机验证。
- 基线内五张 simulator 截图（`CL-006-assets/simulator/`）由 `8e95b0b` 提交时生成，本审计引用但未重摄。
- 深链/横屏/iOS 16–26 旧系统行为未评估。

## 7. 停止状态

审计与本交接为本任务全部产出（commit 见 STATUS）。Claude 不改产品代码、不领取实现任务，追加 STATUS 后停止，等待 Codex PM 独立验收。

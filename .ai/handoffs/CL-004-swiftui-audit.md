# CL-004 · v3 SwiftUI 实施审计

- 任务：`CL-004`
- 负责人：`CLAUDE-DESIGN`
- 性质：设计审计，不写代码。只读输入：`docs/ios-design-freeze-v3.md`、`.ai/handoffs/CL-003-claude-design.md`、`.ai/handoffs/CL-003-assets/**`、当前 `ios/Haluowode/**`、`ios/HaluowodeTests/**`。
- 结论摘要：当前 `ios/Haluowode/**` 的实际视觉与冻结的 v3 基线**几乎完全不一致**——五个区域仍在使用未冻结前的候选配色（天空蓝/暖金/海军蓝）、默认阴影、渐变、任意字号和硬编码圆角。这不是"局部小改"，而是**单点根因、系统性重做**：只要把 `DesignSystem.swift` 的 token 换成 v3 冻结值并清理少数直接绕开它的硬编码调用点，绝大多数页面会自动跟随统一。

---

## 1. 现状 → v3 目标 → SwiftUI 实施项 → 截图验收矩阵

### 1.1 首页 Home (`HomeView.swift`)

| 项目 | 现状 | v3 目标 | SwiftUI 实施项 | 截图验收点 |
| --- | --- | --- | --- | --- |
| Hero 卡片背景 | `LinearGradient([Color.white, primaryBlue.opacity(0.08)])`（第 50–54 行），真实渐变 | 纯色 `canvas #FFFFFF`，零渐变 | 删除 `LinearGradient`，改为 `.fill(Color.canvas)` | 1x 截图肉眼/像素采样确认无渐变过渡 |
| Hero/入口/心愿卡阴影 | 到处 `.shadow(opacity:0.02–0.03, radius:5–8)`（第 56/80/101/209 行） | 默认零阴影，仅描边分层 | 移除全部 `.shadow`，改为 `RoundedRectangle().stroke(hairline, lineWidth:1)` | 截图确认卡片边界只有 1pt 细线，无投影 |
| 感谢金颜色 | `DesignSystem.highlightGold`（第 180 行） | 冻结值无 gold，金额用主文字色 `ink-900` | 感谢金 `Text` 改用 `ink900` token，去掉 gold 变量 | 截图比对：¥18 与标题同色，不再是金色 |
| 圆角 | `radiusLarge/radiusMedium`=16/12（自定义值，非五级） | 5 级：6/10/14/20/999，卡片=`r-lg 20` | `DesignSystem` 增补 5 级并重新映射调用点 | 用尺子/像素测量 1x 截图圆角半径 |
| 字号 | 全部字面量 `.system(size: 24/18/14...)` | 六级 Dynamic Type（`.largeTitle/.title2/.headline/.subheadline/.footnote/.caption2`） | 替换为语义化 Font 样式，允许系统缩放 | 用 "AAA" 无障碍字号设置对比截图，文字应跟随放大 |
| 顶部城市徽标/铃铛点击区 | 无显式 `.frame(minWidth/minHeight:44)` | SF Symbols 图标 44×44pt 最小点击区 | 给 toolbar 按钮内容加 `.frame(width:44,height:44)` 或 `.contentShape` | 需要真机/模拟器 Accessibility Inspector 复核，HTML 无法验证 |
| 心愿横向卡片区 | 每行只截取 `wishes.prefix(3)`，`ScrollView(.horizontal)` 已存在但卡宽 280pt、无 v3 要求的 "trailing peek" | 复用冻结稿的 140pt 卡片 + 49pt peek 语义（详情见 `CL-003` 交接 §6.1） | 按冻结稿调整卡片宽度/间距，保留横向滚动 | 393pt 截图应能看到第三张卡的 40–56pt 边缘 |
| 空/错误/加载态 | 已实现 `idle/loading/failed/empty/loaded` 五态（`SkeletonCardView`、错误重试按钮、空态文案） | 与冻结稿一致，但视觉 token 需替换 | 仅替换颜色/圆角/阴影/字号，不改状态逻辑 | 分别截图 5 种 `viewModel.state` |

### 1.2 附近 + 详情 + 响应 Nearby/Detail/Response (`NearbyView.swift`)

| 项目 | 现状 | v3 目标 | SwiftUI 实施项 | 截图验收点 |
| --- | --- | --- | --- | --- |
| 搜索框/筛选按钮阴影 | `.shadow(opacity:0.01, radius:3)`（第 43/55 行） | 零阴影，`canvas-sunk` 底色 + 无描边即可分层 | 移除阴影，背景改 `canvas-sunk` | 截图确认搜索框无投影 |
| 筛选 Chip 圆角 | 硬编码 `.cornerRadius(20)`（第 74 行），未走 `DesignSystem` | `r-pill 999`，唯一合规使用 pill 的场景之一 | 改为 `DesignSystem.radiusPill` 常量 | 目测/测量圆角是否为全圆角胶囊 |
| 心愿卡片 (`WishRowView`) | 白底+阴影(第 224 行)，感谢金用 gold（195 行） | 白底+hairline，感谢金 ink-900 | 同 Home 卡片改法 | 同上 |
| 详情页三张信息卡 | 分别 `.shadow(opacity:0.02, radius:5)`（335/364/380 行） | 零阴影 | 移除阴影，改描边 | 截图确认 |
| 详情页感谢金 | `highlightGold`（327/329 行），字号 24 硬编码 | ink-900，映射到 `.title` 级 Dynamic Type | 同上 | 同上 |
| 底部固定 CTA 栏 | `Color.white.shadow(opacity:0.05, radius:8, y:-4)`（406 行） | **这不是响应 Bottom Sheet**，是详情页固定操作栏；v3 规则里唯一允许阴影的只有"响应 Bottom Sheet 半展开/拖拽"，固定操作栏应为零阴影 + 顶部 1pt hairline | 移除阴影，改 `.overlay(Rectangle().frame(height:1).foregroundColor(hairline), alignment:.top)` | 截图确认按钮区与内容区之间只有细线 |
| 响应表单字段 | 背景 `Color.gray.opacity(0.05)`（497/509/522 行），无描边 token | `canvas-sunk` 或 `canvas` + hairline-strong 描边，聚焦态 2pt accent 描边 | 统一替换背景色，加 focus 状态描边（当前无 `@FocusState` 视觉区分） | 需要真机点击输入框对比聚焦前后描边颜色 |
| 响应提交按钮态 | `PrimaryButtonStyle(isDisabled:)` + `.disabled()`，spinner 已实现 | 与冻结稿四态一致（正常/聚焦/错误/提交中） | 仅补聚焦态视觉，其余已具备 | 分别触发四态截图 |
| Emoji/渐变 | 无命中 | 保持零 | — | grep 复核 |

### 1.3 发布 Publish (`PublishView.swift`)

| 项目 | 现状 | v3 目标 | SwiftUI 实施项 | 截图验收点 |
| --- | --- | --- | --- | --- |
| 步骤进度条 | `Rectangle().fill(primaryBlue / gray.opacity(0.2))` | 用 accent/hairline-strong 替换颜色，其余结构可保留 | 换色即可 | 截图三步进度条颜色 |
| 错误提示条 | `Color.red.opacity(0.1)` 背景 + 纯红字 | 冻结的 `danger #B3452F` 描边风格，不用大面积红底（参考 CL-003 `41c` 未通过态处理方式） | 改为白底 + danger 色描边/文字，图标同色 | 触发 `.failed` 态截图对比 |
| 场景/城市/交付方式选择卡 | 大量 `Color.gray.opacity(0.2)` 描边，未使用统一 hairline token | 统一 `hairline-strong` 描边 token | 替换硬编码灰色 | 截图确认选中/未选中态描边颜色一致 |
| 感谢金选择卡 | 无阴影（好），但选中态用 `primaryBlue` 实心填充+白字 | 选中态可保留"实心块"作为唯一合规的强调用法，但颜色需要用 accent 暖蓝 | 换色 | 截图 3 档金额选中态 |
| 摘要卡/成功页 code 卡 | `primaryBlue.opacity(0.05)` / `bgWarmWhite` 背景 | 统一改为 `canvas-sunk` | 换色 | 截图 |
| 成功页流程徽标 | `processBadge` 用 `primaryBlue.opacity(0.1)` / `gray.opacity(0.1)` | 换色，不透明度规则需与 Foundations 的 `ink-300`(未开始) 等对齐 | 换色 | 截图审核中/匹配中/已接单三态徽标 |
| 底部固定操作栏 | `Color.white.shadow(opacity:0.05, radius:8, y:-4)`（132 行） | 同 1.2：零阴影 + 顶部 hairline | 同上 | 同上 |
| 字段错误文案 | `.font(.caption)` 系统默认样式（231/276/406/427/444 行），与其余字面量字号不一致 | 统一映射到 `.footnote`/`.caption2` | 统一替换 | 截图 |
| 三步状态 (idle/valid/invalid/submitting/success/failed) | 已完整实现 | 保留，仅换色 | — | 分别截图 6 态 |

### 1.4 进度 Progress (`ProgressView.swift`)

| 项目 | 现状 | v3 目标 | SwiftUI 实施项 | 截图验收点 |
| --- | --- | --- | --- | --- |
| **数据来源** | `queryWishProgress()` 读取 `Wish.mockWishes`（当前为空数组）并用 `DispatchQueue.main.asyncAfter` 模拟网络延迟（第 250 行） | 不属于本次视觉审计范围；这是**功能/数据层缺口**，不是视觉缺陷——**不得把它误报为视觉问题**，但截图验收必须说明：当前任何"查询成功"状态截图都来自尚未真实联网的模拟数据，只能靠临时改代码构造 `foundWish` 才能截图，不能通过真实交互产生 | 不在 CL-004 范围内；建议在后续代码任务范围声明中单独标注（已在既往交接中记录为 AG-004/AG-005 边界） | 不适用截图验收，需在交付前明确注明 |
| 状态卡/交付卡/详情卡/时间线卡阴影 | 4 处 `.shadow(opacity:0.02, radius:5)`（52/90/109/127 行） | 零阴影 | 移除，改描边 | 截图确认 |
| 状态名颜色 | `wish.status` 字符串直接用 `primaryBlue`（29 行），未按状态区分颜色 | 冻结稿要求区分：匹配中/已接单=accent 描边文字，未通过=danger，已取消=ink-500；且 `delivered` 需显示为"待确认"而不是"已交付" | 需要按状态映射颜色 + 文案（当前第 55/121 行仍用"已交付"字符串，未对齐 `docs/ios-api-contract.md` 的"待确认"展示要求） | 分别构造匹配中/已接单/未通过/已取消/待确认/已完成截图 |
| 感谢金 | 纯文本无 gold（这一处反而已经符合 v3，无需改动） | 保持 | — | — |
| 时间线圆点/连接线 | `Image(systemName: "checkmark.circle.fill"/"circle")` + `Rectangle` 竖线，逻辑与冻结稿一致 | 当前态节点建议加零模糊实心圆环高亮（参考 CL-003 `41_Tracking_Detail` 的 "当前状态" 处理），目前只用图标本身变色，视觉强调弱于冻结稿 | 可选增强，非阻断项 | 截图对比 |
| 交付预览全屏页 | 深色背景 + 白字，`RoundedRectangle(cornerRadius:12)` 硬编码 | 深色沉浸页可视为独立场景（冻结稿未覆盖），圆角建议仍用 token 化的 `r-lg` | 用 `DesignSystem.radiusLarge` 替换字面量 12 | 截图 |
| 查询表单页输入框 | 背景 `DesignSystem.bgWarmWhite`（154/164 行），与卡片同色系但用作输入框背景语义不清 | 改为 `canvas-sunk`，与 Publish/Response 表单统一 | 换色 | 截图 |

### 1.5 我的 Profile (`ProfileView.swift`)

| 项目 | 现状 | v3 目标 | SwiftUI 实施项 | 截图验收点 |
| --- | --- | --- | --- | --- |
| 整体结构 | 原生 `List` + `Section`，未使用自定义卡片/阴影 | 与冻结稿方向一致（本区域冻结稿未覆盖具体页面，可延用系统 List 语义，仅换色） | 图标/文字颜色换成 v3 token | 截图未登录/已登录两态 |
| 图标 | 全部 SF Symbols，无 Emoji（合规） | 保持 | — | — |
| "退出登录" 按钮 | `role: .destructive`（系统红），未使用自定义 `danger` 色 | 可保留系统语义色，或与冻结稿 danger 值对齐（次要，系统语义色本身也克制） | 待 Codex/用户确认是否需要统一成 token 值 | 截图 |
| 帮助与安全中心/隐私政策 | 纯文字页，字号字面量，颜色已用 `DesignSystem` 变量 | 换色即可，无结构变化 | 换色 | 截图 |
| 举报按钮 | `.foregroundColor(.red)`（218 行），系统红非 token | 改为 `danger` token | 换色 | 截图 |

---

## 2. 唯一 SwiftUI Token 映射（回指 `docs/ios-design-freeze-v3.md`）

当前 `DesignSystem.swift` 与冻结值的对照——**这是本次审计的核心交付，后续实现者应以此表为唯一依据**：

| 类别 | 当前 `DesignSystem.swift` | v3 冻结值 | 差异等级 |
| --- | --- | --- | --- |
| 主强调色 | `primaryBlue` = RGB(0.365,0.678,0.886) 清透天空蓝 | `accent #3E6B92` 暖蓝 | **P0**，色相/明度完全不同 |
| 高亮色 | `highlightGold` = RGB(0.98,0.80,0.25) 暖黄金 | 冻结值中不存在此角色；金额/强调一律用 `ink-900` 或 `accent` | **P0**，需整体删除该颜色语义 |
| 主文字 | `textNavy` = RGB(0.05,0.12,0.25) 深海军蓝 | `ink-900 #171310` 暖黑 | **P0**，色相不同（蓝黑 vs 暖黑） |
| 次文字 | `textSecondary` = RGB(0.35,0.45,0.55) 灰蓝 | `ink-700 #4A443C` / `ink-500 #847C6F` 两级暖灰 | **P0**，且当前只有 1 级，冻结值有 2 级需要区分主/次要程度 |
| 页面底色 | `bgWarmWhite` = RGB(0.98,0.98,0.97) | `canvas-warm #FBF6EC` | P1，色相接近但明显更冷、更接近纯白 |
| 卡片底色 | `cardBg` = 纯白 | `canvas #FFFFFF` | 一致，无需改动 |
| 三级底色（输入/禁用） | **不存在** | `canvas-sunk #F3ECDD` | **P0**，缺失整个层级，导致输入框普遍用临时 `Color.gray.opacity(0.05)` |
| 错误色 | 直接用系统 `Color.red` | `danger #B3452F` | P1，当前系统红比冻结值更刺眼、饱和度更高 |
| 完成色 | 未定义（无专门"已完成"色） | `success #4C7A52` | P1，新增 |
| 描边/hairline | **不存在**，各处用 `Color.gray.opacity(0.2)` 临时替代 | `hairline #E9E1D2` / `hairline-strong #D8CDB8` | **P0**，缺失关键分层机制——这是让阴影被滥用的根本原因之一 |
| 圆角 | 3 级：`radiusSmall 8 / radiusMedium 12 / radiusLarge 16` | 5 级：`6 / 10 / 14 / 20 / 999` | **P0**，级数不够，且数值不对齐，多处硬编码 `cornerRadius(4/6/8/12/20)` 绕开系统 |
| 间距 | 6 级：`4/8/12/16/20/24`，与冻结的 8 级（4/8/12/16/20/24/32/40）部分重合 | 8 级 | P1，缺 32/40 两档，大分区间距目前用零散的 `.padding(.top, 30)` 等字面量代替 |
| 阴影 | **未定义为 token**，各处手写 `.shadow(color:black.opacity(0.01–0.05), radius:3–8, ...)`，数值不统一（至少 5 种组合） | 默认零阴影；唯一例外 `shadow-float = 0 2px 8px rgba(23,19,16,0.08)`，仅限响应 Bottom Sheet 半展开态 | **P0**，最大规模的系统性差异，需要整体删除现有阴影调用 |
| 字体 | 全部字面量 `.system(size:N, weight:)`，N 从 10 到 72 不等，约 20+ 种不同数值 | 6 级 Dynamic Type：`.largeTitle/.title2/.headline/.subheadline/.footnote/.caption2` | **P0**，当前应用完全不支持系统字号缩放，是可访问性硬性缺口 |
| 图标 | SF Symbols，Regular/填充混用（`.fill` 后缀图标居多，如 `paperplane.fill`、`plus.bubble.fill`），线宽不可控（系统字重决定） | SF Symbols，统一约 1.75pt 线宽（Regular 字重，非 `.fill` 填充体） | P1，当前大量使用 `.fill` 填充图标，视觉上比 v3 检查点页面中的线性图标更"重" |
| 点击区 | 未见显式 44×44pt 保证 | 最低 44×44pt | P1，需要真机复核，非纯代码可判定 |
| Emoji | 零命中 | 零 Emoji | 一致，无需改动 |
| 渐变 | 1 处真实使用（`HomeView.swift:50`） | 零渐变 | **P0** |
| App Icon | `Assets.xcassets/AppIcon.appiconset/Contents.json` 只有尺寸占位，**未填入任何实际图片** | 方向 A「路径与抵达点」，暖蓝 `#3E6B92` | **P0**，当前应用事实上没有图标 |

---

## 3. P0 / P1 排序（只评价已存在/已冻结内容，不新增功能范畴）

**P0（阻断冻结基线落地，建议作为下一个实现任务的全部范围）：**

1. `DesignSystem.swift` 色板整体替换为 v3 冻结值（含新增 `canvas-sunk`、`hairline`、`hairline-strong`、`danger`、`success`，删除 `highlightGold`）。
2. 圆角 token 扩展为 5 级并替换全部硬编码 `cornerRadius(数字)` 调用点（至少 Nearby 74 行、FilterSheetView 255 行、Progress `DeliveryPreviewView` 278/315 行）。
3. 删除 `HomeView.swift:50-54` 的真实 `LinearGradient`。
4. 移除全部 `.shadow(...)` 调用（Home 4 处、Nearby 6 处含详情页、Publish 2 处、Progress 4 处，共 16 处），改为 hairline 描边分层；唯一保留阴影的位置应迁移到"响应 Bottom Sheet 半展开态"专属组件，且该组件当前是普通 `.sheet()`，还没有区分半展开/全展开的拖拽视觉。
5. 字体系统迁移到 Dynamic Type 六级语义样式，替换约 20+ 处字面量 `.system(size:...)`。
6. App Icon 资源为空，需要把 CL-003 冻结的方向 A（暖蓝版）实际导出到 `AppIcon.appiconset` 各尺寸槽位。
7. Progress 页面状态文案 `"已交付"` 未按 `docs/ios-api-contract.md` 显示为 `"待确认"`（第 55/121 行），这是文案/状态映射错误，不是纯视觉问题，但与 CL-003 冻结稿的截图验收基线不一致，建议与后续实现任务一并修正。

**P1（建议同批处理但不阻断冻结基线本身）：**

1. 间距 token 补齐 32/40 两档，替换零散的字面量间距。
2. 系统红/系统语义色（`.red`、`role:.destructive`）与冻结的 `danger`/`success` token 对齐。
3. 图标从 `.fill` 填充体统一为 Regular 线性体，视觉重量向冻结稿的检查点页面对齐。
4. 44×44pt 最小点击区核查（顶部工具栏按钮、时间线图标等）。
5. 响应表单聚焦态目前无视觉区分（无 `@FocusState` 描边变化），建议后续实现时补上。

**明确不算差异 / 不应误报：**

- 五个区域的加载/空/错误/禁用/提交中状态**已经在业务逻辑层面完整实现**（`WishListViewModel`、`PublishWishViewModel` 的枚举状态机 + 对应分支视图），这是功能完成度问题，本次审计只指出视觉 token 需要替换，不代表状态机需要重做。
- Progress 页面基于空 `mockWishes` 数组、无法真实查询到结果，这是既有已知的数据层边界（此前群聊已记录为 AG-004/AG-005 范围），不是本次视觉审计新发现的缺陷，也不应被算作"视觉未完成"。
- Emoji 使用：零命中，已经合规，不需要任何改动。

---

## 4. 状态 / 无障碍验收清单

| 页面 | 需要截图验收的状态 | 说明 |
| --- | --- | --- |
| Home | idle/loading（骨架屏）、loaded、empty、failed（含重试按钮） | 均可通过 Xcode Preview 或模拟器直接触发，无需真机 |
| Nearby 列表 | idle/loading、loaded、筛选后 empty、failed | 同上 |
| Nearby 详情 | 正常详情、感谢金/状态文案 | 需真实 `PublicWishDTO` 数据，可用样例数据构造 |
| 响应弹层 | 正常、字段校验错误、提交中（spinner）、提交成功跳转 | 提交成功/失败依赖真实或桩 API 调用，可用测试替身 |
| Publish 三步 | Step1/2/3 各自校验通过/未通过、提交中、成功页、失败重试 | 均可用模拟器完整走一遍真实交互 |
| Progress | 查询表单默认态、（需临时注入数据）已提交/审核中/匹配中/已接单/待确认/已完成/未找到 alert | **查询成功系列状态目前无法通过真实交互触发**，需要实现者在开发期临时构造 `foundWish` 才能截图，正式验收前需说明这一限制 |
| Profile | 未登录、已登录、帮助页 FAQ 展开/收起、隐私政策页 | 均可模拟器直接触发 |
| 动态字体 | Home 标题、Nearby 卡片正文、Publish 表单标签 | 需要在"设置 → 辅助功能 → 显示与文字大小"调至最大后重新截图对比，当前字面量字号实现下文字不会跟随缩放，这本身就是需要修复的验收失败项 |
| VoiceOver | 首页横向卡片 peek、响应弹层错误提示、时间线状态节点 | 需要真机/模拟器 VoiceOver 实际朗读复核，无法仅凭截图判断 |

---

## 5. 后续最小视觉代码切片建议（仅建议，不自行创建或领取）

建议 Codex 按以下顺序拆分实现任务，每一片都应可独立截图验收、独立提交：

1. **切片 A（token 底座）**：只改 `DesignSystem.swift`——替换色板、扩展圆角至 5 级、新增间距 32/40、新增阴影策略常量（含"零阴影默认 + 仅 Bottom Sheet 例外"的显式命名，例如 `shadowFloat`）。不改任何视图文件。验收：全部视图因为引用同一套常量会自动换色，截图 5 个 Tab 首屏确认无编译错误、无遗留旧色。
2. **切片 B（阴影与渐变清理）**：删除 `HomeView.swift` 的 `LinearGradient` 与全部 16 处 `.shadow(...)`，替换为 hairline 描边；固定底部操作栏改为"顶部 1pt 描边"模式。验收：grep 确认 `.shadow(` 与 `LinearGradient` 仅剩响应 Bottom Sheet 一处（如切片 C 中新建）。
3. **切片 C（响应 Bottom Sheet 阴影例外 + 聚焦态）**：给 `ApplyResponseSheet` 增加半展开态识别与 `shadowFloat`，以及 `@FocusState` 驱动的输入框聚焦描边。验收：按冻结稿 4 态截图对比。
4. **切片 D（字体 Dynamic Type 迁移）**：替换全部字面量字号为语义样式。验收：默认字号截图 + 最大无障碍字号截图各一套，对比文字是否正确缩放且不溢出裁切。
5. **切片 E（App Icon 落地）**：把 CL-003 `icon-a-warm-1024.png`（或用户/Codex 最终确认的配色）导出为 `AppIcon.appiconset` 全部尺寸并接入 `Contents.json`。验收：模拟器主屏幕截图确认图标显示正确、无占位空白。
6. **切片 F（Progress 状态文案与颜色映射）**：修正"待确认"文案、按状态区分描边色；与后续 Progress 真实联网任务（如有）解耦，可先在现有 mock 结构上做视觉修正。

依赖关系：B/C/D/F 都依赖 A 先落地；E 与其他切片互不依赖，可并行。每个切片建议独立分支、独立验收命令（`swiftc -frontend -parse` + 截图），完成后停止等待验收，不得连续自动推进到下一切片。

---

## 6. 未决问题（需要 Codex/用户判断，非本审计可自行决定）

1. Profile 的"退出登录"和"举报"是否统一用冻结的 `danger` token，还是保留系统语义红（`role:.destructive`、`Color.red`）？两者视觉都克制，取舍权在产品负责人。
2. `DeliveryPreviewView`（交付预览全屏页）是深色沉浸式页面，冻结稿的检查点四页未覆盖这类深色场景，其 token 是否需要单独定义一套深色变体，还是维持现状（黑底+白字，非冻结范围）？
3. Progress 真实联网（替换 `mockWishes`）不在本次视觉审计范围内，但会直接影响"状态截图验收"能否用真实交互完成，建议 Codex 决定该数据层任务与本视觉切片 F 的先后顺序。

审计报告完成，现停止并等待 Codex 验收；不修改任何源码、冻结资产或任务板。

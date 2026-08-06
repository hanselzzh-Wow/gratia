# CL-003 · iOS 视觉方向 v3 检查点交接

- 任务：`CL-003`
- 负责人：`CLAUDE-DESIGN`
- 依据：`docs/ios-visual-direction-v3.md`（唯一权威视觉规范，替代已冻结的 v2.1 token）
- 范围：本轮只交付检查点约定的 6 项——3 个原创 App Icon 方向、v3 Foundations、首页、附近、详情+响应 Bottom Sheet、一个复杂信息页（进度详情）。**未批量重画其余页面**，检查点通过前不会继续。
- 写入路径：仅 `.ai/handoffs/CL-003-claude-design.md`（本文件）与 `.ai/handoffs/CL-003-assets/**`。未修改 SwiftUI、后端、数据库、`.ai/TASKS.md`、`.ai/WRITE_FREEZE.md` 或 Git 状态。

## 0. 与此前草稿的关系

在收到 `CL-003` 任务分派之前，我基于用户直接反馈独立产出过一版覆盖全部 20 个页面的 v3 修订，写入了 `CL-001-assets/**` 和 `CL-002-assets/**`（已在 `.ai/TEAM_CHAT.md` 的 `CHAT-20260718-020200-CLAUDE-005` 中说明）。那一版默认阴影比"原则上无阴影"更重、Icon 只有 1 个方向的两套配色，不满足本任务的检查点标准，**保留作参考草稿，不作为交付物**。本文档和 `CL-003-assets/**` 才是 `CL-003` 的正式交付。

## 1. App Icon · 3 个原创方向

文件：`CL-003-assets/icon/App_Icon_Directions.html`（对比稿，含 1024/60/40/29/20pt 全尺寸预览）
独立源文件：
- `CL-003-assets/icon/icon-a-blue-1024.svg` / `.png` — 方向 A，旧品牌蓝 `#2F6FE0`
- `CL-003-assets/icon/icon-a-warm-1024.svg` / `.png` — 方向 A，替代暖蓝 `#3E6B92`

三个方向都无 Emoji、无文字、无渐变，每个方向最多一底色 + 一前景色，均为**无圆角 1024×1024 方形主文件**（遮罩由系统处理）：

| 方向 | 概念 | 状态 |
|---|---|---|
| A · 路径与抵达点 | 小圆点（远方起点）经一段渐粗弧线连向大圆点（抵达/在场），一次连续手势同时编码"远方/抵达/在场" | **推荐** |
| B · 相遇（两个重叠的圆） | 两个大小不同的实心圆部分重叠，抽象"发布者与响应者相遇" | 备选，风险：易被认作通用社交/群组图标 |
| C · 地标旗帜 | 竖杆+三角旗+底部圆点，"在场"最直接但"远方/抵达"动态感弱 | 备选，风险：20pt 时旗面易糊 |

**颜色测试**：方向 A 并排提供旧蓝 `#2F6FE0` 与替代暖蓝 `#3E6B92` 两版。旧蓝更鲜亮醒目但偏"科技冷感"；暖蓝在暖白背景上更柔和，与"温暖治愈"的产品气质更贴合。是否切换需要 Codex/用户在评审中确认——本稿不额外扩展第三种配色。

## 2. v3 Foundations

文件：`CL-003-assets/design-system/00_Foundations_v3.html`

- **色彩**：暖中性色阶（`ink-900` → `ink-300`），背景用暖白 `canvas-warm #FBF6EC` 而非纯白。强调色推荐 `accent #3E6B92`（替代 v2.1 冻结的 `#2F6FE0`，此项变更是本检查点唯一的开放决策，见上节）。danger/success 均用低饱和棕红/橄榄绿，不用鲜红鲜绿。
- **圆角**：五级（`r-xs 6 / r-sm 10 / r-md 14 / r-lg 20 / r-pill 999`），每级绑定具体用途；`r-pill` **仅用于筛选 Chip 和确有必要的单个主操作**，不作为默认按钮圆角。
- **字体**：六级，全部映射到 iOS Dynamic Type（`.largeTitle` / `.title2` / `.headline` / `.subheadline` / `.footnote` / `.caption2`）。
- **间距**：8pt 基准网格（4/8/12/16/20/24/32/40），每级标注典型场景。
- **图标**：全部使用 SF Symbols，统一 Regular 粗细、约 1.75pt 描边，页面内展示了本项目高频符号（house/location/plus.circle/person/lock/bell/envelope/video 等）线性预览。
- **阴影策略（本轮核心变化）**：**默认零阴影**，卡片层级只靠 `canvas` / `canvas-warm` / `canvas-sunk` 三级色块 + 1px hairline 描边表达。**唯一允许例外**：响应 Bottom Sheet 在半展开/拖拽时使用 `shadow-float`（`0 2px 8px rgba(23,19,16,.08)`，8% 极低不透明度），因为它需要与底部可能是照片/视频缩略图的用户内容做即时视觉分离。除此之外任何页面、任何卡片不得加阴影。

## 3. 检查点四页

全部位于 `CL-003-assets/screens/`，全部使用上述 Foundations token，零渐变、零 Emoji，默认零阴影：

- **`10_Home.html`** 首页：城市定位、Hero 卡、双入口（发布/响应）、附近心愿横向卡片、三步说明、隐私提示、Tab Bar。
- **`20_Nearby.html`** 附近：搜索框、筛选 Chip（唯一使用 `r-pill` 的场景之一）、心愿列表卡片、Tab Bar。
- **`22_Detail_Response.html`** 详情 + 响应 Bottom Sheet：心愿详情页（默认无阴影）+ 响应弹层的 4 个状态（正常/输入聚焦/字段错误/提交中），弹层是全应用**唯一**使用 `shadow-float` 的地方。
- **`41_Tracking_Detail.html`** 进度详情（复杂信息页）：状态卡、内容摘要、时间线（含"当前状态"用零模糊的实心圆环高亮，非阴影）、交付卡片占位、拒绝/取消态的克制提示色。状态文案已对齐 `docs/ios-api-contract.md`：`delivered` 展示为"待确认"，`completed` 展示为"已完成"。

## 4. 校验结果

```
grep -rn -i "gradient" icon/*.html design-system/*.html screens/*.html   → 0 处命中
grep -rnP "[emoji/箭头 unicode 区间]" icon/*.html design-system/*.html screens/*.html → 0 处命中
```

`box-shadow` 仅出现 3 处，均已核对合规：
1. `design-system/00_Foundations_v3.html` 的对比示例卡（文档演示用，非实际组件）
2. `screens/22_Detail_Response.html` 的 Bottom Sheet（唯一声明的例外）
3. `screens/41_Tracking_Detail.html` 时间线"当前状态"圆点的零模糊实心圆环（`0 0 0 4px`，无模糊半径，是状态高亮环而非阴影/悬浮效果）

## 5. 导出

- `CL-003-assets/png/1x/` — 全部检查点页面 1x PNG（含 Foundations、Icon 对比稿、4 个检查点页面）
- `CL-003-assets/png/3x/` — 四个检查点页面（`10_Home`、`20_Nearby`、`22_Detail_Response`、`41_Tracking_Detail`）均已导出 3x；`22_Detail_Response`/`41_Tracking_Detail` 是多状态对比板，3x 按整板导出（board 内每个状态截图本身已是 3x 精度，供裁切或直接量取像素用）。

## 6. R1 补交：交付完整性与 SwiftUI 落地说明

### 6.1 首页横向卡片的浏览语义（不是裁切 bug）

`10_Home.html` 的"附近正在等待的心愿"原稿第二张卡片在 353pt 内容宽度下被 `overflow:hidden` 硬裁切，容易被 SwiftUI 实现误读为布局错误。R1 第一版修复只是把第三张卡包在一个 56pt 的 `overflow:hidden` 容器里，但当时卡片宽度仍是 168pt，`.wishes` 容器宽度又是隐式 auto——实际计算下来前两张卡加间距已达 360pt，超过 353pt 的可视边界，第三张卡的包裹容器整体落在裁切线之外，**真实可见宽度是 0pt**，不是预期的 peek。此问题已在收到反馈后修正，并用像素级测量验证（而不仅是 CSS 数值推算）：

- `.wishes` 容器改为显式 `width:353px`（= 屏幕 393pt 减去 `.content` 左右各 20pt 内边距，与其余卡片、Hero 区共用同一右边界基准）。
- 卡片宽度从 168pt 收窄到 140pt，两张卡 + 两处 12pt 间距 = 304pt，剩余 353-304=49pt 落入第三张卡的 56pt 包裹容器内。
- 用 Python/Pillow 直接读取导出的 `png/1x/10_Home.png` 逐行扫描白色卡片色块边界，实测第三张卡可见白色区域为 `x=325` 到 `x=372`（宽度 48px，1px 差异来自描边抗锯齿），落在要求的 40–56pt 区间内，不是仅凭代码意图假设。
- 对应 SwiftUI 实现：`ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ... } }`，让最后一张可见卡片的 trailing 方向自然超出屏幕、被系统裁切（等效于 HTML 里的 peek 容器），不需要额外做遮罩或渐隐效果（渐隐会引入渐变，违反零渐变要求）。
- 可访问性：VoiceOver 应能完整读出被裁切卡片的内容（peek 只是视觉裁切，不是从可访问性树移除），建议给 `ScrollView` 内每张卡片加 `.accessibilityElement(children: .combine)`。

### 6.2 逐页 SwiftUI token / 状态 / 无障碍要点

**`10_Home.html` 首页**
- Token：`canvas-warm` 背景、`canvas` 卡片、`hairline` 描边（1pt）、`r-lg` 圆角（Hero/入口/心愿卡）、`r-md`（CTA 按钮）、`accent` 仅用于"查看全部"链接文字。
- 状态：Hero 与双入口无状态变化（静态入口）；心愿横向列表需处理空列表（无附近心愿时的占位文案，未在本检查点覆盖，留待后续页面）。
- 无障碍：顶部城市选择器、通知铃铛需要 44×44pt 最小可点区域（视觉尺寸 34pt，需在 SwiftUI 用 `.contentShape` 扩大热区）；Tab Bar 用系统 `TabView` 原生无障碍语义，不要自定义。

**`20_Nearby.html` 附近**
- Token：`canvas-sunk` 搜索框底色、`r-sm` 输入框圆角、`r-pill` 筛选 Chip（本页是 `r-pill` 的合规使用场景之一）、卡片沿用首页 `r-lg`/`hairline`。
- 状态：筛选 Chip 有 `active`/默认两态；列表本检查点只展示默认态，加载中/空结果/加载失败三态未覆盖，建议复用 Foundations 的 `ink-300`（占位）与 `danger`（失败提示）token。
- 无障碍：搜索框应为真实可聚焦的 `TextField`，placeholder 用 `ink-500`，避免用图片模拟；筛选 Chip 组建议用 `Picker`/自定义按钮组并标注 `.accessibilityAddTraits(.isButton)` 与选中态的 `.isSelected`。

**`22_Detail_Response.html` 详情 + 响应弹层**
- Token：详情页与其余页面一致（`canvas`/`hairline`/`r-lg`/`r-md`）；响应弹层是唯一使用 `shadow-float` 的组件，弹层圆角为 `r-lg r-lg 0 0`（仅顶部两角）。
- 状态：弹层覆盖正常/输入聚焦/字段错误/提交中四态。聚焦态描边从 `hairline-strong` 变为 2pt `accent`；错误态描边变 `danger` 并显示行内错误文案；提交中态字段变灰禁用、按钮显示 spinner 且不可重复点击——SwiftUI 中应对应禁用 `TextField`/`Toggle` 的 `.disabled(true)` 而非仅视觉变灰。
- 无障碍：错误文案需要通过 `.accessibilityHint` 或与输入框关联的 `accessibilityValue` 播报，不能只依赖颜色变化；提交中态的 spinner 需要 `.accessibilityLabel("提交中")` 并临时移除按钮的 `.isButton` trait，防止 VoiceOver 用户重复触发。

**`41_Tracking_Detail.html` 进度详情（复杂信息页）**
- Token：状态标签用描边 + 文字色区分（`accent`=匹配中/已接单，`danger`=未通过，`ink-500`=已取消），不使用色块底色；时间线用 `ink-900`=已完成节点、`accent`+零模糊实心圆环=当前节点、`hairline-strong`=未开始节点。
- 状态：本页覆盖匹配中、已接单、未通过、已取消四种状态；`delivered`/`completed` 的时间线文案已按 `docs/ios-api-contract.md` 显示为"待确认"/"已完成"。
- 无障碍：时间线每个节点应作为一个整体 `accessibilityElement`，播报"状态名 + 完成/当前/未开始"，不能仅靠圆点颜色传达状态（需要文字或 `accessibilityValue` 显式给出状态语义，满足色盲用户的可读性）。

## 7. 待评审问题（开放决定，未冻结）

1. **强调色**：是否用 `#3E6B92`（暖蓝）替换 v2.1 冻结的 `#2F6FE0`？本检查点默认采用暖蓝，但需要产品负责人/Codex 明确确认是否覆盖冻结文档。
2. **Icon 方向**：是否确认方向 A（路径与抵达点）为最终方向？确认后会补齐方向 A 的完整尺寸独立文件（当前仅 1024pt 独立文件，1024 对比稿含全尺寸预览）。
3. 检查点通过后，是否按相同 token 继续批量重画剩余页面（发布流程、Profile、帮助页等）？

R1 交付完成，现停止并等待用户与 Codex 评审；评审通过前不会批量重画其它页面，也不会开始 SwiftUI 视觉实现。

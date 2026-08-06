# CL-001 · 哈喽卧得 iOS UI 设计交接

负责人：`CLAUDE-DESIGN` · 依据：`docs/ios-ui-design-brief.md` · 状态：首轮 8 组优先页面设计交接，等待用户与 `CODEX-PM` 评审冻结。

本文档只做设计说明和交接，不包含、也不引用任何 SwiftUI/源码实现。所有平面设计图为独立 HTML 文件（393×852pt 画板，无手机外框、无透视样机），存放于 [`CL-001-assets/`](./CL-001-assets/)，可直接用浏览器打开查看。同一批页面已用无头 Chrome 导出为 PNG，位于 [`CL-001-assets/png/`](./CL-001-assets/png/)：`1x/` 为 393×852px 基准尺寸，`3x/` 为 1179×2556px（对应任务书 §9.3 的导出要求），`AppIcon-1024.png` 为无圆角 1024×1024 App Icon 主文件；`41_Tracking_Detail.png` 是四态并列对比图，未单独导出 3x（documentation 用途，非单屏交付）。

---

## 0. 交接过程说明：一次视觉方向调整

首版（v1）方向为"天空蓝＋晨光金渐变、卡片投影、暖白背景"，贴近任务书第 2 节的字面描述。在产出首页、列表、详情、发布表单初稿后，评估认为渐变色块＋投影卡片更接近网页/运营台既有视觉，同质化明显，且不易长期维护为可扩展的 iOS Design System。

因此对齐"大厂产品感、克制"的方向做了一次系统性调整（v2），已应用于**全部**交付页面：

| 维度 | v1（已废弃） | v2（当前交付版本） |
| --- | --- | --- |
| 背景 | 暖白 + 卡片投影 | 暖白页面底色 + 卡片改为 1px hairline 分隔线，零投影 |
| 主色 | 天空蓝 `#3E86C7` 大面积使用 | 近黑 `#0A0A0A` 做主文本/主按钮，品牌蓝 `#2F6FE0` 收窄为"仅交互强调"（链接、选中态、进度点） |
| 强调色 | 晨光金块状背景 | 金色 `#B9791F` 只用于金额**文字**，不做色块背景 |
| Hero/主视觉 | 蓝→金渐变 | 纯色卡片 + 极细描边路径线 |
| App Icon | 渐变天空 + 白色图形 | 纯黑底 + 纯白线形图案（呼应 Threads"深色纯底"的图标辨识策略），另附品牌蓝底版供对比（见 §7 开放问题） |
| 按钮 | 实色矩形，圆角 12pt | 黑色实心胶囊（`radius: 999px`），次按钮描边胶囊 |

v2 是当前**唯一**交付版本；本文档和资产目录中不再包含 v1 图。若评审认为 v1 的暖色渐变更符合品牌预期，可在评审中提出，v2 的信息结构和交互不受影响，改色成本低。

---

## 1. 页面地图

```text
启动页 00
  └─ 首次引导 01–03（本轮暂缓，见 §8）
       └─ 底部 5 栏
            ├─ 10 首页 ──────────────┐
            ├─ 20 附近列表 → 21 筛选弹层(暂缓) → 22 心愿详情 → 23 提交响应弹层(暂缓) → 24 响应成功(暂缓)
            ├─ 30/31/32 发布三步 → 33 发布成功 → 41 进度详情
            ├─ 40 进度首页 → 41 进度详情 → 42 交付预览(暂缓)
            └─ 50 我的(暂缓) → 51 帮助与安全(暂缓)
```

- 首页的"发布一个心愿""我要发布"入口跳转到 30；"我刚好在这里"跳转到 20。
- 20 的心愿卡"查看详情"跳转到 22；22 的主 CTA 在本轮弹层未交付前，先跳转到一个"已收到你的响应"文字确认态（对应 24，暂缓交付，见 §8）。
- 33 发布成功页的"查看心愿进度"直接跳转到 41（带着刚生成的编号），不经过 40 的手动输入。
- 40 是"忘记编号/换设备查询"的独立入口，手动输入编号+联系方式后同样进入 41。

---

## 2. 三条核心流程覆盖情况

| 流程 | 覆盖页面 | 状态 |
| --- | --- | --- |
| A. 发布心愿 | 10 → 30 → 31 → 32 → 33 → 41 | 全部交付 |
| B. 响应心愿 | 20 → 22 | 详情页交付；提交响应弹层(23)、响应成功(24) 暂缓，见 §8 |
| C. 查询与接收交付 | 40 → 41 | 交付；交付预览全屏页(42) 暂缓 |

---

## 3. 首轮 8 组优先页面交付清单

| # | 任务书要求 | 交付文件 | 备注 |
| --- | --- | --- | --- |
| 1 | App Icon + 启动页 | [`icon/App_Icon_Annotated.html`](./CL-001-assets/icon/App_Icon_Annotated.html)、[`icon/app-icon.svg`](./CL-001-assets/icon/app-icon.svg)、[`screens/00_Launch.html`](./CL-001-assets/screens/00_Launch.html) | Icon 主文件 1024×1024 无圆角，另含 180/120/60/40 尺寸预览 |
| 2 | 首页 | [`screens/10_Home_Default.html`](./CL-001-assets/screens/10_Home_Default.html) | 正常态 |
| 3 | 附近心愿列表 | [`screens/20_Wishes_List.html`](./CL-001-assets/screens/20_Wishes_List.html) | 正常态；骨架/空/错误态见 §4 与 Components |
| 4 | 心愿详情 | [`screens/22_Wish_Detail.html`](./CL-001-assets/screens/22_Wish_Detail.html) | 正常态 |
| 5 | 发布三步表单 | [`screens/30_Publish_Step1_Location.html`](./CL-001-assets/screens/30_Publish_Step1_Location.html)、[`31_Publish_Step2_Content.html`](./CL-001-assets/screens/31_Publish_Step2_Content.html)、[`32_Publish_Step3_Confirm.html`](./CL-001-assets/screens/32_Publish_Step3_Confirm.html) | 步骤 1/2/3，进度条+返回不丢内容 |
| 6 | 发布成功 | [`screens/33_Publish_Success.html`](./CL-001-assets/screens/33_Publish_Success.html) | 含公开编号、复制/保存、六步状态条 |
| 7 | 进度查询与进度详情 | [`screens/40_Tracking_Home.html`](./CL-001-assets/screens/40_Tracking_Home.html)、[`41_Tracking_Detail.html`](./CL-001-assets/screens/41_Tracking_Detail.html) | 40 含空状态；41 一个文件内含 4 个状态帧：匹配中／已接单／未通过／已取消，见 §4 |
| 8 | Design System 基础页 | [`design-system/00_Foundations.html`](./CL-001-assets/design-system/00_Foundations.html)、[`01_Components.html`](./CL-001-assets/design-system/01_Components.html) | 颜色/字体/间距/圆角/层级/按钮 + 组件与状态库 |

**✅ 文件重名问题已清理**：交接过程中一度并行产出了 `40_Progress_Home.html` / `41_Progress_Detail.html` 与 `40_Tracking_Home.html` / `41_Tracking_Detail.html` 两套"进度页"文件。已按任务书 §9 的命名示例（`41_Tracking_Detail`）统一，删除 `Progress` 前缀的重复文件，保留信息更完整的 `Tracking` 版本——其中 `41_Tracking_Detail.html` 把"匹配中／已接单／未通过／已取消"做成 4 个并列独立帧（而非用文字注释带过异常态），已重新导出对应 PNG。当前 `screens/` 目录下每个页面只有一份基准文件，不存在双份来源问题。

---

## 4. 必需的通用状态：覆盖方式

任务书 §7 要求的状态不是逐屏重复画一遍，而是"页面正常态 + 组件状态库 + 关键页内联状态"三层组合，具体对应关系：

| 状态 | 覆盖位置 |
| --- | --- |
| 骨架加载 | `01_Components.html`「状态：骨架」区块；适用于 20 列表、41 详情首次加载 |
| 无心愿空状态 | `01_Components.html`「状态：空」区块（🕊️ 附近暂时还没有心愿）；`40_Tracking_Home.html`"最近查询"区域内联展示同一套空状态语言 |
| 断网/服务器错误 | `01_Components.html`「状态：错误」区块（📡 网络好像断开了 + 重试）；适用于 20、41 加载失败 |
| 表单字段错误 | `01_Components.html`「表单输入」区块，红色描边 + 12pt 错误文案；适用于 30/31/32 全部输入项与手机号/微信校验 |
| 按钮默认/按下/禁用/加载 | `01_Components.html`「按钮状态」区块；32 步骤 3 的"确认发布"在必填未完成时使用禁用态，提交中切换为加载态 spinner，不允许重复点击 |
| Bottom Sheet 展开 | `01_Components.html`「Bottom Sheet 展开」区块；对应任务书 21 筛选弹层、23 提交响应弹层（本轮结构已定义，画面暂缓，见 §8） |
| Toast 成功/错误 | `01_Components.html`「Toast」区块；用于 33"编号已复制"、提交失败提示 |
| 照片/视频加载失败 | `01_Components.html`「照片/视频加载失败」区块；对应 41 交付卡、42 交付预览(暂缓) |
| 联系方式隐私提示 | `01_Components.html`「敏感信息隐私提示」区块，采用打码样式 `138****1234`；20/22/32/41 中凡涉及联系方式或响应者身份，均遵守"匹配前不展示"的规则 |
| Dynamic Type 放大 | `01_Components.html`「Dynamic Type 放大示例」区块，对比默认 17pt 与 AX3 约 23pt；放大后卡片改单列堆叠、按钮不截断、标题允许两行 |
| 进度详情异常态 | `41_Tracking_Detail.html` 内 4 个并列状态帧：`41a` 匹配中、`41b` 已接单（首次显示响应者称呼）、`41c` 未通过、`41d` 已取消；未通过/已取消均使用克制配色（浅红/浅灰文字标签），不用大面积警示红背景 |

---

## 5. Design System 摘要

完整定义见 [`00_Foundations.html`](./CL-001-assets/design-system/00_Foundations.html)，此处摘录供 SwiftUI 端建 Token 参考。

### 颜色（浅色模式，Token 结构预留深色模式扩展位）

| Token | Hex | 用途 |
| --- | --- | --- |
| `ink900` | `#0A0A0A` | 主文本、主按钮填充、Icon 底色 |
| `ink700` | `#3A3A3A` | 次要文本、表单 label |
| `ink500` | `#767676` | 辅助文本、时间戳、placeholder 上一级 |
| `ink300` | `#B5B5B5` | 占位符、禁用态文本 |
| `hairline` | `#E6E6E6` | 卡片/输入框描边、分隔线 |
| `hairlineSoft` | `#F0F0F0` | 骨架屏底色、次级分隔 |
| `canvas` | `#FFFFFF` | 卡片、输入框、Tab Bar 背景 |
| `canvasWarm` | `#FEFCF9` | 页面底色 |
| `accent` | `#2F6FE0` | 唯一交互强调色：链接、当前态、进度点、聚焦描边 |
| `accentSoft` | `#EAF1FC` | 选中态浅底（如交付方式已选卡片） |
| `gold` | `#B9791F` | 金额数字专用文字色，不做背景 |
| `success` | `#2E7D4F` / `successSoft` `#EAF5EE` | 成功态文字/浅底 |
| `danger` | `#B23B2E` / `dangerSoft` `#FBEDEA` | 错误/未通过态文字/浅底，禁止大面积使用 |

### 字体（系统字体 + 苹方，支持 Dynamic Type）

Large Title 28/34·600、Title2 22/28·600、Title3 18/24·600、Headline 17/22·600、Body 17/24·400、Subhead 15/20·400、Footnote 13/18·400、Caption 12/16·400。标题一律 600 字重，正文 400，避免整屏加粗。

### 间距 / 圆角 / 层级

- 4/8pt 网格；内容水平边距 20pt，密集列表 16pt；可点击区域 ≥ 44×44pt。
- 圆角：`sm 8`（输入框）、`md 12`（小卡片）、`lg 16`（卡片/弹层顶部）、`pill 999`（按钮/标签/头像）。
- 零投影系统：默认状态无阴影，层级只靠 1px hairline 表达；固定 Tab Bar / 表单底栏用顶部 1px 分隔线代替投影。

### 按钮

主按钮＝黑色实心胶囊；次按钮＝黑色描边胶囊；文字按钮用 `accent` 蓝；危险文字按钮用 `danger`；禁用态背景 `hairlineSoft` + 文本 `ink300`。**主按钮固定用黑色，不用品牌蓝**——蓝色只做一件事（交互强调），避免和主 CTA 互相稀释。

---

## 6. 组件清单（对应任务书 §8，全部已在 `01_Components.html` 定义）

5 栏 Tab Bar、Navigation Bar、主/次/文字/危险文字按钮四态、City/类型/状态 Chip、心愿卡 Wish Card、信任提示卡 Trust Card、单行/多行输入（含错误态）、金额选择卡、复选框（发布步骤 3 的联系同意勾选）、Bottom Sheet、纵向 Timeline、Empty/Error/Skeleton State、Toast、联系方式打码行、Dynamic Type 对比。

---

## 7. 关键界面文案（节选，完整文案见各页面 HTML 源码）

- 启动页副标题：「让想说的话，抵达远方。」
- 首页 Hero：「把想说的话，交给恰好在场的人」／「人工审核 · 真实响应 · 过程可追踪」
- 心愿详情 CTA 免责：「提交响应后由运营人员确认，不会自动接单」
- 步骤 3 联系同意：「我同意运营人员在匹配过程中通过以上方式联系我」
- 发布成功标题：「心愿已送出，正在等待审核」；提醒：「编号和发布时留的联系方式共同用于查询，请不要公开转发」
- 进度首页空状态：「还没有查询记录」／「查询过的心愿会显示在这里，方便下次快速查看」
- 隐私提示（详情/表单通用）：「联系方式不公开，仅用于人工审核、匹配与履约核实，不会展示给其他用户」
- 未通过态说明：需展示具体原因文案（示例：「心愿描述涉及无法核实的具体人员信息，请修改后重新发布」），不能只显示"未通过"三个字。

---

## 8. 本轮暂缓、下一轮需补齐的页面

首轮聚焦任务书 §10 指定的 8 组，以下页面**尚未**产出设计图，需要在下一轮补齐后才能视为设计完整覆盖：

- 01–03 首次引导三联页
- 21 筛选 Bottom Sheet 展开态（组件级弹层已在 `01_Components.html` 定义交互结构，整屏内容未画）
- 23 提交响应 Bottom Sheet（含正常/聚焦/错误/提交中）
- 24 响应成功
- 42 交付预览全屏页
- 50 我的（未登录 + 登录后两态）
- 51 帮助与安全

这些页面不阻塞 SwiftUI 对已交付 8 组的实现和纵向切片验证，但会阻塞"响应心愿"流程 B 与"我的"栏目的完整实现。

---

## 9. 仍待决定事项（需要用户/Codex 裁决）

1. **App Icon 底色**：当前主稿为纯黑底＋白色图形（贴近 Threads 辨识策略）；`App_Icon_Annotated.html` 内附带了品牌蓝 `#2F6FE0` 底色的对比说明，未生成第二版完整文件。需确认最终用纯黑还是品牌蓝，确认后再补齐蓝色版全尺寸导出。
2. ~~`40/41` 文件重名~~：已清理，见 §3。
3. **v1→v2 视觉改版是否需要用户额外确认**：v2（黑白灰 + 单一蓝色强调）已是本轮唯一交付版本，如果用户更偏好 v1 的天空蓝＋暖色渐变方向，请在评审中明确指出，改色本身不影响已定的信息结构和组件规格。
4. **首次引导三联页文案**：任务书已给出三页主题方向，具体插画风格（图形化 or 纯排版）未定，建议随下一轮页面一起定稿。
5. **"我的"页面账户体系深度**：任务书要求同时设计未登录/登录后两态，但账户体系本身（登录方式、同步范围）产品侧尚未定案（见 `PROJECT_LOG.md` 未决问题），建议先出未登录态，登录态留出信息位但不细化交互，避免和后续账户方案冲突返工。

---

## 10. SwiftUI 实现规格备注（供 Codex/实现方参考，非代码）

- 所有画板按 393×852pt 设计（iPhone 15 系列基准），需验证在 375–430pt 宽度下的自适应：横向卡片/双入口区在窄屏（375pt，如 iPhone SE）需保证间距不小于 12pt、文本不截断；建议双入口区在极窄屏下允许换行为两行文案而非缩小字号。
- 全部圆角、间距、字号均为 Token 化数值（见 §5），建议在 SwiftUI 端建立 `DesignTokens.swift`（颜色/字号/间距/圆角各一个 enum 或 struct），不要在各 View 里写死数值。
- Tab Bar、Navigation Bar、表单底部按钮栏均为"零投影 + 顶部 1px 分隔线"，SwiftUI 中对应 `.overlay(Divider(), alignment: .top)` 而不是 `.shadow()`。
- 主按钮统一 `Capsule()` 形状；禁用态需要真正禁用交互（`.disabled(true)`），不能只是视觉变灰；提交中状态需要禁用重复点击并显示 `ProgressView` 替代按钮文案。
- 联系方式/响应者身份的打码与隐藏规则是隐私边界的一部分，需要在 ViewModel/数据层就不下发明文，而不是仅在 View 层做字符串打码——具体字段边界以 `AG-002-api-map.md` 的隐私差距分析为准。
- 时间线（Timeline）组件的"当前态"节点使用 `accentSoft` 描边光晕（`.background(Circle().fill(accentSoft))` 叠加），区别于"已完成"的纯黑实心点和"未开始"的浅灰点，三态需要在 SwiftUI 组件里做成可复用的 `TimelineDotStyle` 枚举。
- Dynamic Type：正文默认字号 17pt 起，所有文本建议使用 `.font(.body)` 等语义字体或自定义 `Font` + `.dynamicTypeSize()`，不要写死像素字号；关键页面在 AX3 档位下需要人工过一遍换行/截断（可参考 `01_Components.html` 的对比示例）。

---

## 11. v3 视觉修订附录（2026-07-18，用户直接反馈）

用户在 `CL-001`/`CL-002` 均已提交、`CL-001` 已冻结为 v2.1 之后，直接给出三条明确的视觉方向修正，覆盖范围超出单个任务卡，因此作为附录记录在两份交接文档中，供 `CODEX-PM` 决定是否需要正式重新评审、更新 `docs/ios-design-freeze-v1.md`：

1. **App 内不得出现任何 Emoji**，图标须参照 WhatsApp / X / Threads 一类的单色线性图标语言。原 v2.1 设计中用 Emoji（🔒🔔🎬🕊️📡 等）作为图标占位符，用户明确否决。
2. **参考 Airbnb 的温暖柔和感**：卡片圆角与阴影要更柔和，字号字重要更舒展，不是纯 Threads 式的冷峻扁平。
3. **色彩规则不变**：继续零渐变、强调色克制，鲜艳花哨的颜色只留给用户上传的照片/视频内容，不用于系统 UI。

### 已执行的修订（v3，已应用到本文档全部 12 个已交付页面）

- 新增统一图标系统，见 [`CL-002-assets/design-system/02_Icon_System.html`](./CL-002-assets/design-system/02_Icon_System.html)：22×22 网格、1.6–1.8pt 描边、圆角端点，覆盖锁、铃铛、搜索、交付方式、空状态、错误、播放、关闭、分享、客服、安全、文档、信息、勾选、复制、下载、举报等场景；5 栏 Tab Bar 从抽象色块图标升级为真实的 house / location / plus.circle.fill / clock.arrow.circlepath / person 线性图标。
- Design Tokens 从"零投影 + 冷灰"调整为"柔和阴影 + 暖灰"，完整定义见 [`CL-002-assets/design-system/00_Foundations_v3.html`](./CL-002-assets/design-system/00_Foundations_v3.html)：页面底色 `#FEFCF9`→`#FBF7F0`，卡片圆角 16pt→22pt（弹层顶部 20pt→28pt），文字灰阶转暖，标题字重 700→600、行距普遍加宽；卡片类容器（Hero、心愿卡、摘要卡、Bottom Sheet）改用低透明度柔和阴影 `shadow-card`，列表行分隔线、Tab Bar、固定表单底栏仍保留 1px hairline，不是所有层级都加阴影。
- 本文档 §3 列出的全部 8 组页面已按上述 v3 token 和图标系统重新导出 HTML 与 1x/3x PNG（`CL-001-assets/screens/**`、`CL-001-assets/png/**`），设计结构、信息层级、文案和交互流程与 v2.1 冻结版本保持一致，只有视觉表现层变化。
- `CL-001-assets/design-system/00_Foundations.html`、`01_Components.html` 保留为 v2.1 冻结时的历史记录，不再更新；`CL-002-assets/design-system/00_Foundations_v3.html` 和 `02_Icon_System.html` 是当前唯一权威的 Design System 参考。

### 需要 Codex 裁决

- v3 是否需要正式替换 `docs/ios-design-freeze-v1.md` 中的 Design Tokens 章节（颜色灰阶、圆角、层级），还是仅作为"视觉精修"以变更记录形式追加，不影响已进入实现的 `AG-003` 等任务对 v2.1 数值的引用。
- `AG-003`（首页/附近纵向切片）等已依据 v2.1 数值实现的代码，是否需要回填 v3 的圆角/阴影/图标改动，或留到下一轮实现任务统一处理。

---

*完成后停止：本任务不修改任何 SwiftUI/后端/项目日志/任务板文件，等待用户与 `CODEX-PM` 评审后再决定是否冻结进入实现阶段。*

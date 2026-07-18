# 哈喽卧得 iOS 视觉冻结 v3

状态：`FROZEN / CL-003 ACCEPTED`
日期：2026-07-18（Asia/Shanghai）
适用范围：当前原生 SwiftUI MVP 的消费者端；替代 `docs/ios-design-freeze-v1.md` 的视觉 Token，不替代其仍有效的业务状态与隐私边界。

## 冻结决定

基于用户的“温暖、柔和、克制、内容主导、零 Emoji、零渐变”要求与 Claude CL-003 的实际 393×852/1x/3x 检查点，Codex 冻结如下视觉决定：

- **App Icon**：方向 A「路径与抵达点」。使用原创几何路径与两个点表达远方、抵达与在场；不含文字、Emoji、渐变或第三方品牌轮廓。
- **强调色**：暖蓝 `#3E6B92`，替代旧的 `#2F6FE0` 作为原生 MVP 的唯一常规强调色。旧蓝不再用于新 SwiftUI 页面。
- **底色与层级**：页面 `canvas-warm #FBF6EC`，卡片 `canvas #FFFFFF`，输入/禁用 `canvas-sunk #F3ECDD`；通过暖白、细描边、留白和字级建立层级。
- **默认阴影**：零阴影。唯一例外是详情响应 Bottom Sheet 在半展开/拖拽时使用 `0 2px 8px rgba(23,19,16,0.08)`，不得扩散到普通卡片或按钮。
- **导航与内容**：坚持五栏原生 Tab Bar；产品 chrome 保持低彩度，用户上传照片/视频才是最丰富的视觉内容。

这是一项 PM 决策：用户已授权 Codex 统筹，而 Claude 的推荐方向也与用户给定的品牌偏好一致。以后若更换品牌色或图标，必须创建新的版本化冻结文档，而不是零散改 token。

## 可追溯 Token

| 类别 | 冻结值 | SwiftUI 落地 |
| --- | --- | --- |
| 主文字 | `#171310` | `Color` token / 主要标题、主按钮 |
| 次文字 | `#4A443C`、`#847C6F` | 辅助内容、元数据、placeholder |
| 描边 | `#E9E1D2`、`#D8CDB8` | 1pt hairline / 强描边 |
| 强调 | `#3E6B92` | 链接、选中、焦点、少量状态 |
| 错误/完成 | `#B3452F`、`#4C7A52` | 必须同时配文字/图标，不能只靠颜色 |
| 圆角 | 6 / 10 / 14 / 20 / 999 pt | 小控件 / 输入 / 普通卡 / 大容器与 Sheet / 仅 Chip |
| 间距 | 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 pt | 8pt 基准网格，4pt 仅微调 |
| 字体 | `.largeTitle`、`.title2`、`.headline`、`.subheadline`、`.footnote`、`.caption2` | 使用 Dynamic Type，不写死不可缩放字号 |
| 图标 | SF Symbols、Regular、约 1.75pt 线宽 | 最低 44×44pt 点击区，禁止 Emoji 代替图标 |

## 已验收的设计输入

- Foundations：`.ai/handoffs/CL-003-assets/design-system/00_Foundations_v3.html`
- Icon 对比：`.ai/handoffs/CL-003-assets/icon/App_Icon_Directions.html`
- 页面：`10_Home`、`20_Nearby`、`22_Detail_Response`、`41_Tracking_Detail` 的 HTML、1x/3x PNG。
- 首页横向心愿区使用 `ScrollView(.horizontal, showsIndicators: false)` 语义：393pt 基准内容宽度内两张 140pt 卡片、12pt 间距，第三张实际露出约 49pt；此 peek 必须仍在 VoiceOver 可访问树中，不能用渐隐遮罩伪造。

## 实现约束

1. 不使用 Emoji 或渐变；不复制外部品牌图形；不重新启用旧蓝、重阴影或所有元素胶囊化。
2. 每个 P0 页面提供正常、加载、空、错误、禁用/提交中状态；错误不能只靠颜色表达。
3. 详细响应/进度的隐私与状态文案以 `docs/ios-api-contract.md` 为准；视觉冻结不授权显示联系方式、能力 URL 或管理入口。
4. 组件实现必须引用上表 token，不从单张设计图临时取色/圆角；任何新组件先扩展 token 再使用。
5. 新页面可沿用该系统，但不可把当前四张检查点以外的静态 HTML 直接当成已冻结页面。

## 验收记录

- 逐屏人工查看通过：无实际 UI Emoji、无渐变、暖白/暖蓝、默认低阴影、清晰的信息层级。
- HTML/SVG 规则扫描未发现 UI 的 gradient 或 Emoji 使用。
- 首页 1x 为 393×852，3x 为 1179×2556；第三张横向卡在实际 1x 画面中可见。
- 详情与进度的 3x 多状态合板齐全，交接已注明对应 SwiftUI token、状态与无障碍要点。

后续业务实现任务必须先读本文件、`docs/ios-architecture.md`、`docs/ios-api-contract.md` 和 `docs/ios-mvp-acceptance.md`。

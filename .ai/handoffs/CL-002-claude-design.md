# CL-002 · 哈喽卧得 iOS UI 设计补齐交接

负责人：`CLAUDE-DESIGN` · 唯一基线：`docs/ios-design-freeze-v1.md`（v2.1，不另起视觉方向）· 状态：P0 缺口设计交接，等待 `CODEX-PM` 评审。

本文档只做设计说明和交接，不包含、也不引用任何 SwiftUI/源码实现。所有平面设计图为独立 HTML 文件（393×852pt 画板，无手机外框、无透视样机），存放于 [`CL-002-assets/`](./CL-002-assets/)，可直接用浏览器打开查看。同一批页面已导出 PNG，位于 [`CL-002-assets/png/`](./CL-002-assets/png/)：单屏页面在 `1x/` 与 `3x/`（393×852 / 1179×2556）都有；`23_Response_Sheet.html`、`42_Deliverable_Preview.html` 各自把多个状态并列画在一个文件里，作为对比板只导出 1x（documentation 用途）。App Icon 主稿见 `png/AppIcon-1024-Blue.png`，备选见 `png/AppIcon-1024-BlackAlt.png`。

---

## 1. 交付清单（对照 `.ai/TASKS.md` 的 CL-002 范围）

| # | 任务书要求 | 交付文件 | 状态覆盖 |
| --- | --- | --- | --- |
| 1 | 21 筛选 Bottom Sheet | [`screens/21_Filter_Sheet.html`](./CL-002-assets/screens/21_Filter_Sheet.html) | 展开态；城市/交付方式/期望时间单选，感谢金双滑块区间，重置、结果计数、查看结果 |
| 2 | 23 提交响应 Bottom Sheet | [`screens/23_Response_Sheet.html`](./CL-002-assets/screens/23_Response_Sheet.html) | 单文件 4 帧：`23a` 正常、`23b` 输入聚焦（含键盘遮挡）、`23c` 字段错误、`23d` 提交中 |
| 3 | 24 响应成功 | [`screens/24_Response_Success.html`](./CL-002-assets/screens/24_Response_Success.html) | 正常态 |
| 4 | 41 已交付 / 已完成 | [`screens/41_Tracking_Delivered.html`](./CL-002-assets/screens/41_Tracking_Delivered.html)、[`41_Tracking_Completed.html`](./CL-002-assets/screens/41_Tracking_Completed.html) | 两个独立文件，衔接 CL-001 已冻结的匹配中/已接单/未通过/已取消 |
| 5 | 42 交付预览 | [`screens/42_Deliverable_Preview.html`](./CL-002-assets/screens/42_Deliverable_Preview.html) | 单文件 4 帧：`42a` 加载中、`42b` 图片、`42c` 视频（点按播放）、`42d` 加载失败 |
| 6 | 50 我的（无账户 MVP） | [`screens/50_Profile_MVP.html`](./CL-002-assets/screens/50_Profile_MVP.html) | 正常态，无登录假象 |
| 7 | 51 帮助与安全 | [`screens/51_Help_Safety.html`](./CL-002-assets/screens/51_Help_Safety.html) | 安全原则、隐私说明、FAQ、联系客服、举报/投诉 |
| 8 | 品牌蓝 App Icon | [`icon/App_Icon_Annotated.html`](./CL-002-assets/icon/App_Icon_Annotated.html)、[`icon/app-icon-blue.svg`](./CL-002-assets/icon/app-icon-blue.svg)（主稿）、[`icon/app-icon-black-alt.svg`](./CL-002-assets/icon/app-icon-black-alt.svg)（备选，标记不进入构建） | 1024×1024 无圆角主文件、多尺寸预览、安全区标注表 |

首轮 8 组（App Icon/启动/首页/附近/详情/发布三步/发布成功/进度/Design System）已在 `CL-001` 冻结，本轮不重复交付，仅在需要时引用。

---

## 2. 页面地图补全

```text
20 附近列表 → [21 筛选弹层] → 20（结果过滤后）
22 心愿详情 → [我刚好在这里] → 23 提交响应弹层
  ├─ 23a/23b/23c 正常/聚焦/错误 → 提交 → 23d 提交中
  └─ 提交成功 → 24 响应成功 → [继续看看] 返回 20 / [返回首页] 返回 10

41 进度详情状态链（衔接 CL-001 已冻结部分）：
  已提交 → 审核通过 → 匹配中 → 已接单
    → 待确认（41_Tracking_Delivered，新增）
      ├─ [确认收到，完成心愿] → 已完成（41_Tracking_Completed，新增）
      └─ [查看交付] → 42 交付预览（新增，四态）
  异常分支：未通过 / 已取消（已在 CL-001 冻结）

50 我的 → 我的发布/我的响应（无登录，引导去"进度"用编号查询）
       → 帮助与客服 / 安全中心 / 隐私政策 / 用户协议 / 关于哈喽卧得 → 51 帮助与安全
```

---

## 3. 关键设计决策与依据

1. **响应表单字段严格对齐 `CreateWishResponseRequest`**（`docs/ios-api-contract.md`）：`responderName`（1–30 字）、`responderContact`（3–80 字）、`note`（选填，清洗后 ≤160 字，UI 按 160 计数而非任务书草案的 120）、`contactConsent`（必须为 true，未勾选时主按钮保持禁用）。不额外收集任务书未定义的字段。
2. **`41` 状态文案采用契约的中文展示，而不是任务书草案的措辞**：`WishStatus.delivered` 官方展示为「待确认」（不是"已交付"），强调这是"响应者已交付、等待发布者确认"的中间态，因此 `41_Tracking_Delivered.html` 标题态为「待确认」，主按钮是「确认收到，完成心愿」，对应确认后进入 `completed`/「已完成」。这个措辞差异請 Codex 在实现前与 `AG` 系列任务对齐，避免文案和后端枚举展示不一致。
3. **响应者联系方式在任何进度页都不出现**：`41_Tracking_Delivered/Completed` 只展示 `assignment.providerName`（响应者称呼），不展示 `responderContact`；符合 `docs/ios-api-contract.md` 的隐私边界和 `docs/ios-design-freeze-v1.md` 的实现门槛。
4. **交付能力 URL（`deliverable.url`）不在设计稿中以明文出现，也不设计"复制链接"动作**：`42_Deliverable_Preview.html` 只有关闭、心愿编号（公开编号，非能力 URL）、分享（分享系统级截图/预览，不是分享原始私有链接）和"内容有问题"入口。详见 §5 SwiftUI 备注。
5. **视频交付默认不自动播放**，`42c` 用点按播放按钮呈现，避免移动网络下的流量和隐私意外（例如误触后台自动播放导致内容被路人看到）。
6. **`50 我的` 严格执行 PM 裁决"无账户假象"**：不放头像、称呼编辑、退出登录等暗示已登录的元素；"我的发布/我的响应"直接引导到编号查询，不做本地伪造的"最近发布列表"。
7. **筛选弹层的感谢金用双滑块区间**而不是任务书草案的单一预设金额选择卡（预设金额卡片是发布流程 32 步骤的专属组件，筛选场景需要区间语义，两者故意不复用同一组件，避免语义混淆）。
8. **App Icon 主稿改为品牌蓝 `#2F6FE0`**，按 PM 裁决执行；图形概念（弧线路径 + 纸飞机 + 起点）与 CL-001 一致，仅背景色从纯黑换成品牌蓝，保持"零渐变、零投影、零玻璃拟态"。黑底版本保留在 `icon/app-icon-black-alt.svg` 供历史参考，不建议实现方引用。

---

## 4. 组件与状态复用说明

以下组件延续 CL-001 `Design System`（`../CL-001-assets/design-system/`）已定义的 Token 和组件，本轮未重新定义：

- 颜色/字体/间距/圆角/零投影系统：见 `docs/ios-design-freeze-v1.md` §Design Tokens。
- Bottom Sheet 展开结构（拖拽条 + 圆角顶部 + 固定底部按钮）：`21`、`23` 沿用同一 `radius-xl`（20pt）顶部圆角和 scrim 遮罩（`rgba(10,10,10,.32)`，纯色半透明，非渐变）。
- 按钮四态（默认/按下/禁用/提交中）：`23d`、`24`、`41_Tracking_Delivered` 的主按钮直接复用 Foundations 里的 Capsule 黑色主按钮与 spinner 加载态规格。
- Timeline 组件：`41_Tracking_Delivered/Completed` 复用 CL-001 冻结的纵向时间线视觉（当前态 `accentSoft` 光晕、已完成纯黑实心点），新增两个节点文案「待确认」「已完成」。
- Chip/Toggle：`21` 筛选选项复用 Chip 组件的 active/inactive 两态；感谢金区间是新增的双滑块（Range Slider）组件，SwiftUI 端建议用两个 `Slider` 或自定义 `GeometryReader` 实现，无系统原生双滑块控件。

---

## 5. SwiftUI 实现规格备注（供 Codex/实现方参考，非代码）

- **响应表单校验**：`responderContact` 复用发布表单的手机号/微信号校验规则（长度 3–80，具体格式规则以后端 400 `fields` 返回为准，不在客户端过度猜测格式，仅做长度和非空校验，交由后端做最终判定，参照 `docs/ios-api-contract.md` 的 400 + `fields` 行为）。
- **提交中状态需要防抖/防重复**：`23d` 对应组件应在请求进行时禁用所有输入和按钮；契约里"同心愿同响应者联系方式重复提交返回 200 `created=false`"，SwiftUI 侧仍需自行做按钮防抖，不能依赖后端幂等性来掩盖 UI 层的重复点击问题。
- **`41` 状态映射建议**：`WishStatus.delivered` → 页面态「待确认」（`41_Tracking_Delivered`）；`WishStatus.completed` → 「已完成」（`41_Tracking_Completed`）；`assignment.status`（`offered/accepted/arrived/delivered/declined/cancelled`）用于时间线细分节点，不直接暴露给用户文案，只驱动内部状态机。
- **交付预览的分享行为**：`42` 的分享按钮应触发系统分享表（`UIActivityViewController`）分享的是"当前预览截图或应用内深链接（携带 publicCode，不携带能力 token）"，绝不能把 `deliverable.url` 原始字符串放入分享内容、剪贴板或日志。
- **失败重试（`42d`）**：网络失败与 404（token 失效/记录不存在）应有不同文案——网络失败可重试，404 应提示"链接已失效，请返回进度页刷新"而不是提供无意义的重试按钮；本设计稿的"重试"文案默认对应网络失败场景，404 场景的文案需要实现方按错误类型分支处理，不要对所有失败都展示同一个"重试"。
- **Profile 页无本地持久化状态**：`50` 的"我的发布/我的响应"两个入口在 MVP 阶段只是跳转到"进度"Tab 并预填提示，不在本地存储任何历史发布记录（避免和账户体系上线后的真实同步逻辑冲突）。
- **FAQ 手风琴**：`51` 的常见问题使用标准可展开/收起交互，展开动画建议 200–250ms ease-out，一次只展开一个（可选），Dynamic Type 放大后每项高度需要自适应内容而不是固定高度裁切。

---

## 6. 无障碍（Accessibility）注意点

- 全部新增页面遵循 CL-001 冻结门槛：可点击区域 ≥44×44pt、AX3 Dynamic Type 下不截断核心文案、错误不能只靠颜色区分（`23c` 字段错误同时有边框变色 + 文字说明，不是仅变红色）。
- `21` 双滑块区间需要 VoiceOver 可用：每个滑块需要独立的 `accessibilityLabel`（"最低感谢金"/"最高感谢金"）和 `accessibilityValue`（当前金额），不能只依赖视觉位置传达数值。
- `42` 视频/图片全屏预览的关闭、分享、"内容有问题"按钮需要有清晰的 `accessibilityLabel`（避免图标按钮在 VoiceOver 下读出"按钮 1/2/3"）。
- `50`/`51` 的列表行、FAQ 手风琴项需要作为整行可点击（不是只有文字或箭头图标可点），并在 VoiceOver 下合并为一个可交互元素而不是拆成多个焦点。
- 深色背景的 `42` 交付预览页文字对比度已按纯白文字 + 纯黑/深灰背景验证（对比度 >12:1），高于 WCAG AA 最低要求。

---

## 7. 本轮仍未覆盖、需要下一轮或后端能力就绪后再补的内容

- 账户体系登录态（`50` 的登录后完整版）——阻塞项是产品侧账户方案未定案，见 `PROJECT_LOG.md` 未决问题，不在本轮或 MVP P0 范围。
- 支付/退款相关 UI——`docs/ios-design-freeze-v1.md` 已明确 MVP 不做。
- 运营端页面——消费者 App 明确不包含运营入口，无需设计。
- 首次引导三联页——PM 已裁决不进入 MVP P0，本轮不再重复评估。

---

*完成后停止：本任务不修改任何 SwiftUI、后端、`.ai/TASKS.md`、项目日志或 Git 状态，等待 `CODEX-PM` 评审后再决定是否冻结进入实现阶段。*

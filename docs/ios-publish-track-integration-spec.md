# iOS 发布、追踪与交付真实闭环实现规格

状态：`P0-B 已派发为 AG-004；P0-D 仍待独立任务`
日期：2026-07-18（Asia/Shanghai）
负责人：Codex（需求与验收）；后续实现负责人待单独派发

## 目的与边界

本规格把当前候选 App 中的本地假成功替换为真实 Cloudflare Worker 闭环：

```text
发布三步表单 → POST /api/wishes → 后端公开编号
    ↓
公开编号 + 原联系方式 → POST /api/wishes/track → 私有进度
    ↓
后端返回的能力 URL → 照片/视频预览
```

它覆盖 `docs/ios-mvp-acceptance.md` 的 P0-B 和 P0-D，不包括运营后台、登录、支付、自动派单或任何生产后端改造。AG-004 只实现 P0-B；报名流程（P0-C）、追踪与交付（P0-D）将在其验收后分派，不得抢先实现。

## 当前事实与必须移除的假流程

- `PublishView.swift` 当前使用 `DispatchQueue.main.asyncAfter` 伪造提交、伪造编号，并写入 `Wish.mockWishes`。
- `ProgressView.swift` 当前从 `Wish.mockWishes` 查询，伪造失败提示和交付预览。
- `HaluowodeCore` 已有 `CreateWishRequest`、`WishAPIProtocol.createWish`、`TrackWishRequest` 与 `WishAPIProtocol.trackWish`；后续实现必须复用这些可注入接口，不让 View 拼 URL 或直接 `URLSession`。
- `CreateWishRequest.contactConsent` 必须为 `true`，否则后端返回结构化 400；追踪响应不得显示或持久化发布者联系方式。

## 发布状态与行为

建议以 `PublishWishViewModel` 管理草稿和单一提交状态：

```text
editing(draft)
    → submitting
    → succeeded(publicCode, contact held only in memory)
    → failed(userFacingError, original draft retained)
```

### 表单校验

提交前按 `docs/ios-api-contract.md` 校验：

- requesterName 1–30、contact 3–80、city 2–24、landmark 2–40。
- occasion 2–24、message 5–120、deadlineText 2–40。
- rewardFen 为整数且在 0–100000，deliveryType 必须是冻结枚举。
- 联系同意必须由用户明确勾选为 `true`；不能用默认 `true`、预勾选或模拟成功规避。
- 正在提交时禁用上一步、提交和重复点击；失败时保留全部字段，可原位重试。

### 成功体验与隐私

- 成功页显示后端返回的 `publicCode`，提供原生复制动作与可读 VoiceOver 标签。
- 联系方式仅在内存中传给进度页的预填查询；不写入 `UserDefaults`、日志、截图文本或 Analytics。
- 重复提交返回 HTTP 200 / `created=false` 时视为成功，但文案应说明“已找到刚才的心愿”，避免用户反复产生新单。

## 追踪、状态与交付

建议 `TrackWishViewModel` 使用：

```text
idle → loading → loaded(TrackedWishDTO) | failed(userFacingError)
```

- 仅向 `POST /api/wishes/track` 传 `publicCode` 与用户当次输入的 `contact`；请求完成后立即丢弃该 contact。
- 展示心愿摘要、`WishStatus`、时间线、`assignment.providerName`（若有）和 `events`。不得显示 `WishResponseDTO.responderContact` 或发布者联系方式。
- 404 统一提示“请检查编号和联系方式”；400 显示字段级提示；429 展示可重试等待；无网络/超时/损坏响应均需可重试。
- 有 `deliverable` 时，使用后端返回的 URL 原样加载。照片可用 `AsyncImage` 的加载/失败状态；视频使用系统 `AVKit` 或同等系统框架。URL/token 不显示、不复制、不持久化、不写错误文本。
- 交付链接 401/404/429/503 必须显示“链接不可用或已失效”的安全提示，不能暴露 token 或推导 R2 地址。

## 设计与无障碍接口

- 实现前必须对齐 CL-003 的页面和 Foundations；旧蓝色渐变、重投影、固定字号 UI 不能被当作最终视觉接受。
- 五栏导航不变：发布成功后可跳到进度栏并预填编号；必须有“返回首页”路径。
- 键盘出现时提交按钮保持可见，所有图标点击区域至少 44pt；错误不能只靠颜色传达。
- 使用 Dynamic Type 语义样式，关键编号不截断，并为复制/播放/关闭等图标提供 accessibility label。

## 最低自动化与设备验收

### 单元测试

1. 发布请求完整编码、同意字段、蜜罐字段省略、201 与重复 200。
2. 发布输入不合格不调用 API；网络/400 失败后草稿仍在；提交中重复点击不产生第二个请求。
3. 追踪请求编码，`TrackedWishDTO` 解析含未知状态、事件和交付 URL。
4. 404、429、损坏 JSON、取消和错误描述不泄露 contact/token。
5. 交付 URL 只进入媒体加载组件，不进入用户可见错误或日志。

### 模拟器

- 使用一个明确标识的、非真实隐私测试单跑真实发布；记录返回编号。
- 由运营端人工审核/派单/上传测试交付后，使用同一编号和联系方式查询并打开交付。
- 验证键盘、失败重试、空/加载/错误、旋转锁定竖屏和从主屏冷启动。

### 真机

- 仅在 Personal Team 安装完成后，以测试名、测试联系方式和测试交付文件执行一次完整闭环。
- 测试单号、设备型号、iOS 版本、构建号和已知问题追加到 `PROJECT_LOG.md`；不得把测试联系方式或交付 token 写入日志。

## 派发前置与停止条件

AG-004 的前置已经满足：

1. AG-003 R5 已被独立验收并以 `dd46951` 合入本地主分支，提供可信 API/并发基础。
2. CL-003 第一检查点已冻结到 `docs/ios-design-freeze-v3.md`，提供 v3 视觉与组件规格。

后续实现智能体必须拥有新 branch/worktree，不得复用 AG-003 worktree；AG-004 完成发布后立即停止，由 Codex 验收。真实生产写入、响应、追踪、交付和真机验收均需后续独立任务。

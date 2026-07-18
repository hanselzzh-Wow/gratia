# 任务交接报告：真实查询进度与交付 (AG-006)

---

## 1. 任务概述

本任务将原本在 `ProgressView` 中使用的 `Wish.mockWishes` 模拟列表、`asyncAfter` 延迟以及假数据交付预览，替换为依赖注入的 `WishAPIProtocol.trackWish` 真实接口流。

---

## 2. 交付物与改动路径

本任务共涉及以下新建与修改的路径：
*   **新建文件**：
    *   [ios/Haluowode/TrackWishViewModel.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-006-real-track/ios/Haluowode/TrackWishViewModel.swift)：实现 `@MainActor` 隔离的 `TrackWishViewModel` 进度查询状态机。
    *   [ios/Haluowode/DeliveryPreviewView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-006-real-track/ios/Haluowode/DeliveryPreviewView.swift)：实现对于 `spoken_video`、`scenery_voiceover`、`handwritten_card`、`link` 四类交付凭证媒体的格式解析与预览。
    *   [ios/HaluowodeTests/TrackWishViewModelTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-006-real-track/ios/HaluowodeTests/TrackWishViewModelTests.swift)：编写 6 个针对输入校验、大写转换、成功后内存擦除、404 安全性、429 重试与 Task 取消的单元测试用例。
*   **修改文件**：
    *   [ios/Haluowode/ProgressView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-006-real-track/ios/Haluowode/ProgressView.swift)：重构进度追踪视图，引入 ViewModel，以列表 DTO 中的事件时间线渲染 UI，并去除所有 mock 数据和假延时逻辑。
    *   [ios/Haluowode/ContentView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-006-real-track/ios/Haluowode/ContentView.swift)：向 `ProgressView` 注入由全局管理的 `apiClient` 实例。
    *   [ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-006-real-track/ios/Packages/HaluowodeCore/Tests/HaluowodeCoreTests/HaluowodeCoreTests.swift)：在 SPM Core 包的测试套件中新增了对追踪成功并解码完整 assignment、deliverable 能力 URL 及事件时间线，以及未知状态 `WishStatus` 兼容 fallback 的 2 个物理测试。
    *   [ios/Haluowode.xcodeproj/project.pbxproj](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-006-real-track/ios/Haluowode.xcodeproj/project.pbxproj)：由 XcodeGen 自动重新生成的 Xcode 编译配置文件。

---

## 3. 核心设计与技术实现

### A. 状态机流转设计 (TrackState)
ViewModel 的进度查询状态流定义如下：
*   `.idle`：空闲状态，表单待输入。
*   `.loading`：查询请求正在进行中，输入框和查询按钮会被禁用，查询按钮渲染菊花（ProgressView）。
*   `.loaded(TrackedWishDTO)`：查询成功并取得心愿追踪实体，展示具体详情。
*   `.failed(String)`：查询失败，展示友好错误文本，表单保持且允许“重试”。

### B. 隐私与数据安全保护
*   **联系方式内存擦除**：用户输入的联系方式（`contact`）在网络接口请求成功（即状态转换为 `.loaded`）后，**立刻从 ViewModel 的内存中彻底置空擦除**。
*   **无持久化/无日志泄露**：联系方式绝不写入 `UserDefaults`、不保存到文件、不输出到控制台 `print`，不写入任何崩溃日志或错误文字。
*   **敏感 URL/Token 遮蔽**：交付凭证 `deliverable.url` 及 URL 中的 query token 绝对不渲染在 UI 界面上，不支持拷贝，也不参与任何打印或错误输出。
*   **404 信息防护**：当接口返回 404 (未找到) 错误时，状态机捕获并统一输出为 `"请检查编号和联系方式"`，绝不以任何形式回显用户的输入内容，保证暴力猜解时无任何数据泄露。

### C. 媒体预览适配
*   **口播视频 & 景色配音**：利用系统 `AVKit` 的 `VideoPlayer(player: AVPlayer(url: url))` 呈现。
*   **手写卡片**：利用系统 `AsyncImage(url: url)` 加载，并提供 loading (菊花)、success (图片本身) 和 failure (链接不可用) 状态。
*   **外部链接**：以系统 `Link(destination: url)` 打开，并提示用户点击前往浏览器查看。
*   **异常拦截**：若发生 401/404/429/503 或媒体加载失败，统一在预览页中屏蔽原始 URL，显示 `"交付链接不可用或已失效"`。

### D. 竞态与去重
*   处于 `.loading` 状态时，若用户再次触发查询请求，会被直接丢弃（Deduplication）。
*   支持 Task 级物理取消，当用户点击 `切换单号` 重置或退出页面时，进行中的 Task 会被发送 cancellation，ViewModel 回退到 `.idle` 且不弹出任何错误 Banner。

---

## 4. 测试与验证报告

### A. 单元测试覆盖
*   **SPM Core 包单元测试**：17 / 17 全部通过 (无 Failure，无 Skip)
    *   新增 `testTrackWishSuccessFullDecoding`：校验 track 成功并解码完整 assignment、deliverable 能力 URL 及事件时间线。
    *   新增 `testUnknownWishStatusFallback`：校验未知 `WishStatus` 仍可解码，且 UI 自动退回为 `未知状态` 标签，不造成解码崩溃。
*   **App 目标 (Simulator) 单元测试**：21 / 21 全部通过 (无 Failure)
    *   `testInvalidInputValidation`：校验无效输入阻止接口发送，并反馈红字提示。
    *   `testCorrectRequestMappingAndSuccess`：验证 `publicCode` 转换为大写及 trim、`contact` 发生 trim、请求成功后立刻擦除 `contact` 字段。
    *   `testNotFound404ErrorMapping`：验证 404 捕获并重置提示，且不泄漏敏感信息。
    *   `testRateLimit429ErrorMapping`：验证 429 速率限制及重试时间转换提示。
    *   `testQueryDeduplication`：验证请求中去重。
    *   `testCancellationRecovery`：验证底层 Task 取消传播，ViewModel 无闪烁回退至可重试 `.idle`。

### B. 静态质量检查
*   `swiftc -typecheck` 检查：通过，无 Warning / Error。
*   无 Mock/模拟依赖硬编码扫描：通过。
*   `git diff --check`：通过，无行尾空白或 EOF 多余空行违规。

---

## 5. 已知限制与未验证项

*   **真机渲染与播放**：本任务基于 iOS Simulator 环境测试。AVPlayer 对于网络视频流的解码以及真机沙盒内的外部 URL 资源跳转需待真机联调阶段进行最终验证。
*   **AsyncImage 缓存**：`AsyncImage` 缺少精细的缓存策略，在大尺寸图片或高频加载下可能会频繁发起请求，此为系统组件原生行为，建议后续引入第三方缓存库。

---

## 6. 下一步建议

1.  **提交工作区变更**：工作区修改已成功提交，当前 Commit SHA 为：`935e40d`。
2.  **等待 PM 合并验收**：本任务开发已完全终止，请等待合并主分支。

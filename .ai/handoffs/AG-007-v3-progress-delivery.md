# AG-007 v3 进度与交付视觉收口交接

## 当前结论

Codex 已接管并完成允许范围内的 SwiftUI 展示层改造与四态 Simulator 截图补证。真实 `TrackWishViewModel`、生产 API 注入、取消、404/429、成功后 contact 清除、DTO/事件/assignment/deliverable 和能力 URL 隐私路径均未修改。

## 修改路径

- `ios/Haluowode/ProgressView.swift`
- `ios/Haluowode/DeliveryPreviewView.swift`
- `ios/HaluowodeTests/ProgressPresentationTests.swift`
- `ios/Haluowode.xcodeproj/project.pbxproj`（由 xcodegen 生成，仅接入新测试）
- `.ai/handoffs/AG-007-v3-progress-delivery.md`

## 视觉与交互

- 查询表单使用 v3 `canvas/canvasSunk/hairline/accent/danger/ink` token、语义字体、8pt 节奏和 44pt 控件。
- 使用 `FocusState` 表达输入焦点；焦点为 2pt accent，校验错误为 danger 描边、图标和文字，不只依赖颜色。
- 查询、错误、loaded 摘要、交付入口、心愿概要和时间线均为 hairline 卡片，零普通阴影、零渐变、零 Emoji、无硬编码 `.cornerRadius`。
- delivered 继续走生产 `statusText(for:)` 并显示“待确认”；页面离开继续调用 `viewModel.cancel()`。
- 交付预览保留 `VideoPlayer`、`AsyncImage`、`Link`；loading/failure/关闭/留言使用语义字体和 44pt 控件。失败文案固定“交付链接不可用或已失效”。
- URL/token 仅作为系统媒体/Link destination 使用，不进入 `Text`、accessibility label/value、日志、复制或测试输出。

## 四态截图证据

- 本地 XCTest fixture 只实现 `WishAPIProtocol.trackWish`，不访问生产 API；404 直接返回 `.notFound`，delivered 直接返回本地 `TrackedWishDTO`。生产初始化和 `TrackWishViewModel` 均未修改。
- 交付失败使用未知本地 `DeliveryKind`，直接验证生产固定失败 UI；能力 URL 不进入文字、无障碍、日志或测试输出。
- 结果包：`/private/tmp/haluowode-ag007-presentation-r5.xcresult`，iPhone 17 Pro / iOS 27 Simulator，4/4 passed，0 failure/skip/runtime warning。
- 导出目录：`/private/tmp/haluowode-ag007-screenshots-r5/`；四张附件建议名分别为 `AG-007-01-query-form`、`AG-007-02-not-found`、`AG-007-03-delivered`、`AG-007-04-delivery-failure`。已逐张目视检查，无空白或裁切。
- 404 截图中的 fixture 联系方式只保留在可重试输入草稿；错误文案不回显联系方式。delivered 截图断言成功后 contact 已清空。

## 实际验证

- App 全套：`/private/tmp/haluowode-ag007-full-r5.xcresult`，iPhone 17 Pro / iOS 27 Simulator，27/27 passed，0 failure/skip/runtime warning。
- Core：`swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag007-r5 --disable-xctest --enable-swift-testing`，17/17 passed，0 failure。
- `swiftc -frontend -parse ios/Haluowode/*.swift ios/HaluowodeTests/ProgressPresentationTests.swift`：通过。
- 渐变、普通 shadow、硬编码 `.cornerRadius`、假延时、生产 Mock、UserDefaults/print、管理凭据、URL 文字/无障碍/复制扫描：0 命中。
- `git diff --check`：通过。

## Warning 与未验证项

- 链接阶段仍有既有 2 条 warning：iOS Simulator deployment target 16.0，而 Xcode 27 XCTest/libXCTestSwiftSupport 最低 17.0。
- 四个截图测试的原始控制台各出现测试宿主 `Unbalanced calls to begin/end appearance transitions` 提示；`.xcresult` 的 `runtimeWarnings` 为 0，截图完整。该提示仅来自测试用 `UIHostingController` 快照窗口，不来自生产导航运行。
- 真实远端视频/图片失败、系统 Link、Dynamic Type 极端字号、VoiceOver、Reduce Transparency/Reduce Motion、iOS 16–25 回退和真机仍未验证。

当前交付已补齐任务卡要求的四态 Simulator 证据，等待 Codex 在主线之外独立验收；不得自行合入或领取下一任务。

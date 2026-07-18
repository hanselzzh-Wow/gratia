# AG-007 v3 进度与交付视觉收口交接

## 当前结论

Codex 已接管并完成允许范围内的 SwiftUI 展示层改造。真实 `TrackWishViewModel`、API 注入、取消、404/429、成功后 contact 清除、DTO/事件/assignment/deliverable 和能力 URL 隐私路径均未修改。

## 修改路径

- `ios/Haluowode/ProgressView.swift`
- `ios/Haluowode/DeliveryPreviewView.swift`
- `.ai/handoffs/AG-007-v3-progress-delivery.md`

## 视觉与交互

- 查询表单使用 v3 `canvas/canvasSunk/hairline/accent/danger/ink` token、语义字体、8pt 节奏和 44pt 控件。
- 使用 `FocusState` 表达输入焦点；焦点为 2pt accent，校验错误为 danger 描边、图标和文字，不只依赖颜色。
- 查询、错误、loaded 摘要、交付入口、心愿概要和时间线均为 hairline 卡片，零普通阴影、零渐变、零 Emoji、无硬编码 `.cornerRadius`。
- delivered 继续走生产 `statusText(for:)` 并显示“待确认”；页面离开继续调用 `viewModel.cancel()`。
- 交付预览保留 `VideoPlayer`、`AsyncImage`、`Link`；loading/failure/关闭/留言使用语义字体和 44pt 控件。失败文案固定“交付链接不可用或已失效”。
- URL/token 仅作为系统媒体/Link destination 使用，不进入 `Text`、accessibility label/value、日志、复制或测试输出。

## 实际验证

- App：`/private/tmp/haluowode-ag007-codex-r3.xcresult`，iPhone 17 Pro / iOS 27 Simulator，23/23 passed，0 failure/skip/runtime warning。
- Core：17/17 passed，0 failure。
- `swiftc -frontend -parse ios/Haluowode/*.swift`：通过。
- Emoji、渐变、普通 shadow、硬编码 `.cornerRadius`、Mock/假延时、UserDefaults/print 扫描：0 命中。
- `git diff --check`：通过。

## Warning 与未验证项

- 链接阶段仍有既有 2 条 warning：iOS Simulator deployment target 16.0，而 Xcode 27 XCTest/libXCTestSwiftSupport 最低 17.0。
- 当前环境只有 headless Simulator runtime，没有可操作的 `Simulator.app`；`simctl io` 只支持屏幕录制/截图，不支持触摸。因此无法在不修改禁止路径、不加入生产测试后门的前提下切换到进度 Tab 并生成任务要求的查询/404/delivered/媒体失败四态截图。
- 真实远端视频/图片失败、系统 Link、Dynamic Type 极端字号、VoiceOver、Reduce Transparency/Reduce Motion、iOS 16–25 回退和真机仍未验证。

当前状态应为 REVIEW，不应在截图证据补齐前标记 ACCEPTED 或派发依赖 AG-007 验收的 AG-008。

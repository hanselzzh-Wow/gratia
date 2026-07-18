# CX-002 · v3 附近、详情与真实响应视觉交接

- 负责人：`CODEX-PM`
- 分支：`codex/v3-nearby-response`
- 允许范围内改动：仅 `ios/Haluowode/NearbyView.swift`、本交接和群聊。

## 已完成

1. 附近搜索、筛选、列表、详情卡、固定 CTA、Filter Sheet、真实响应 Sheet 和成功页均使用已有 v3 token：暖白/暖蓝、hairline、sunk canvas、Dynamic Type 和 token 化圆角。
2. 删除 `NearbyView.swift` 所有 `LinearGradient`、`.shadow` 与硬编码 `.cornerRadius`；固定 CTA 用顶部 1pt hairline 分层，普通卡片无阴影。金额统一为 `ink900`，普通图标为 Regular SF Symbols。
3. 响应表单新增 `@FocusState`：焦点为 2pt accent 描边，字段错误为 danger 描边与图标+文字；提交中禁用输入/提交，取消按钮与 Sheet 消失仍调用已验收的 `WishResponseViewModel.cancel()`。没有改动 ViewModel、请求、成功/失败/取消语义或联系方式边界。
4. 成功页保留原有关键承诺：“已收到响应，等待运营确认，不代表已经接单。”未显示、保存或复制响应者联系方式。

## 实际验证

- Swift parser：`swiftc -frontend -parse ios/Haluowode/*.swift` 通过。
- XcodeGen + iPhone 17 Pro（iOS 27.0）Simulator Debug build 通过。
- Core Swift Testing：15/15 通过。
- Simulator `HaluowodeTests`：显式结果包 `/private/tmp/haluowode-cx002-retry-20260718.xcresult` 显示 15/15、0 failure、0 skip、0 runtime warning。
- 静态检查：Nearby 零 `LinearGradient`、零 `.shadow`、零 `.cornerRadius`；零 UI Emoji；`git diff --check` 通过。
- 运行截图：`/private/tmp/haluowode-cx002-running.png`，证明合并首页 Foundations 后的本分支 App 能安装并冷启动。生产公开列表为空，且不允许伪造测试心愿，故本轮无法用真实交互进入 Nearby 已加载详情/响应态；这些布局以 SwiftUI 编译、源审和已存在的 response ViewModel 测试覆盖验证。

## Warning / 未验证

- Xcode beta 仍输出既有 iOS 16 测试 target 链接较新 XCTest runtime 的 linker warning；结果包本身没有 runtime warning。
- AppIntents metadata extraction 提示没有 AppIntents.framework 依赖而跳过，不涉及业务功能。
- 尚未真机检查最大 Dynamic Type、VoiceOver、真实公开心愿详情与真实响应写入；后者必须由 Codex 按受控生产测试单另行执行。
- Publish、Progress、Profile 与底部 Tab Bar 仍是独立后续视觉任务，未越权修改。

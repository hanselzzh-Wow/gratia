# 任务 AG-005：真实提交响应纵向切片及交付交接报告

## 1. 概述与修改文件清单

本任务在隔离工作区（`worktrees/ag-005-real-response`）的分支 `codex/ag-005-real-response` 上完成开发。通过引入 `@MainActor` 的 `WishResponseViewModel`，将 `NearbyView.swift` 中的“我刚好在这里，可以帮忙”响应表单从本地假状态替换为调用真实 `WishAPIProtocol.createWishResponse` 并适配 DTO 的网络请求流。

**修改及新建文件清单**：
- [ios/Haluowode/ContentView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-005-real-response/ios/Haluowode/ContentView.swift) — 新增 `WishAPIClientKey` 与环境扩展。共享并在 `ContentView` 实例化 `WishAPIClient` 后通过 `.environment(\.wishAPIClient, ...)` 注入到整个 SwiftUI 视图层中。
- [ios/Haluowode/NearbyView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-005-real-response/ios/Haluowode/NearbyView.swift) — 移除旧 `ResponseSubmissionState` 枚举；重构 `ApplyResponseSheet` 绑定为新的 `WishResponseViewModel`；在 `onDisappear` 及“取消”按钮触发时调用 `cancel()` 执行在途请求取消；添加本地校验红字提示。
- [ios/Haluowode/WishResponseViewModel.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-005-real-response/ios/Haluowode/WishResponseViewModel.swift) — **新建 ViewModel 文件**。定义了响应提交的状态管理和检验规则。
- [ios/HaluowodeTests/WishResponseViewModelTests.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-005-real-response/ios/HaluowodeTests/WishResponseViewModelTests.swift) — **新建测试文件**。涵盖了完整的单元测试用例。
- [ios/Haluowode.xcodeproj/project.pbxproj](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-005-real-response/ios/Haluowode.xcodeproj/project.pbxproj) — 重新生成的 Xcode 编译工程描述文件。

---

## 2. ViewModel 状态机与行为定义

`WishResponseViewModel` 的主要状态 `ResponseState` 如下：
1.  **`.idle` (初始/重置)**：页面表单初始态，或在取消请求后安全回退至此状态，保证草稿保留并可重试。
2.  **`.submitting` (提交中)**：调用 API 时处于该状态。输入框与提交按钮会被禁用，且内部防御重复提交。
3.  **`.success` (响应成功)**：新建 201 响应或重复提交 200（`created == false`）均顺利汇入成功状态，拉起成功页，且不显示和不保存响应者的隐私联系方式。
4.  **`.failed(let message)` (提交失败)**：解析并展示错误（400、401、404、409、429、网络及解码失败），保留表单内容，不泄露任何敏感联系方式，提供重试机会。

---

## 3. 交付质量与测试执行证据

### A. 物理测试执行结果

1.  **SPM 核心 Package 测试 (15 / 15 Passed)**：
    ```bash
    swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag005 --disable-xctest --enable-swift-testing
    ```
    *结果*：15 个测试全数通过。

2.  **App 模拟器单元测试 (15 / 15 Passed)**：
    ```bash
    xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode \
      -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' \
      -derivedDataPath /private/tmp/haluowode-ag005-integration-tests \
      -resultBundlePath /private/tmp/haluowode-ag005-integration-20260718-1538.xcresult \
      -only-testing:HaluowodeTests test
    ```
    *结果*：Codex 读取显式结果包确认 15 个用例全部通过、0 Failure、0 Skip、0 runtime warning。其中包括新增的 6 个 `WishResponseViewModelTests` 物理测试用例：
    *   `testInvalidInputValidation`：无效输入阻止 API 提交并显式填充校验红字。
    *   `testCorrectRequestMapping`：合法提交参数映射、ID 使用真实的 `PublicWishDTO.id`（非 `publicCode`），空说明（`note`）转为 `nil` 编码。
    *   `testDuplicateSubmissionSuccess200`：重复提交 200（`created == false`）同样计入 `.success` 态，并断言输入 `"  可以帮忙  "` 实际编码为 `"可以帮忙"`。
    *   `testFailurePreservesDraft`：请求失败（如 409 conflict）保持表单草稿，不丢失用户已填内容。
    *   `testSubmissionDeduplication`：提交中拦截并过滤重复进入请求。
    *   `testCancellationDoesNotSetFailedState`：支持在途取消传播，不报 `.failed`，状态机重置为 `.idle` 以供重新尝试，并在 Mock API 替身上观察到了该取消。

3.  **App 静态解析核对**：
    ```bash
    swiftc -frontend -parse ios/Haluowode/*.swift
    ```
    *结果*：退出码为 0；完整编译与测试质量以第 2 条可读取 xcresult 为准。

4.  **去 Mock 与去伪检查**：
    ```bash
    grep -rn -E "DispatchQueue\.main\.asyncAfter|Wish\.mockWishes|WishAPIClient\(" ios/Haluowode/NearbyView.swift ios/Haluowode/WishResponseViewModel.swift
    ```
    *结果*：无匹配结果（0 违例）。

---

## 4. 已验证 / 未验证 / 已知风险

- **已验证**：
  1. 通过 `@Environment(\.wishAPIClient)` 共享注入 Client 实例，保证测试和运行的一致。
  2. 支持在途取消，状态机不会挂死在 `.submitting`，而是退回到 `.idle` 供用户重试。
  3. UI 检验长度与同意完全与契约对齐；空白说明编码为 `nil`，非空说明会 trim 后编码。
- **未验证**：iOS 主 App 在真机/模拟器上的真实渲染行为（由 Codex 集成后执行）。
- **已知风险**：无。

---

## 5. 下一步建议

1.  **实现来源**：外部实现所在的最后有效提交为：`6381e2c`。该提交之后的交接事实和 trim 编码测试证据已由 Codex 在隔离集成分支补齐并独立验证。
2.  **等待 PM 集成评审**：交付仅在 Codex 隔离集成分支内复验；是否合入本地 `main` 由后续范围审查决定。

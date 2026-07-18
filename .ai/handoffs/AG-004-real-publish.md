# 任务 AG-004：真实发布心愿纵向切片及交付交接报告

## 1. 概述与修改文件清单

本任务在独立工作区（`worktrees/ag-004-real-publish`）的分支 `codex/ag-004-real-publish` 上进行开发。通过引入 `@MainActor` 的 `PublishWishViewModel` 将原有 `PublishView` 的本地伪造假心愿机制彻底替换为符合后端 API 契约的真实请求。

**修改及新建文件清单**：
- [ios/project.yml](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-004-real-publish/ios/project.yml) — 移除了 `HaluowodeTests` 的 HaluowodeCore 重复依赖，防止双重符号静态拷贝引起的运行时类型投射错误。
- [ios/Haluowode.xcodeproj/project.pbxproj](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-004-real-publish/ios/Haluowode.xcodeproj/project.pbxproj) — 重新生成的 Xcode 工程文件。
- [ios/Haluowode/ContentView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-004-real-publish/ios/Haluowode/ContentView.swift) — 引入 `import HaluowodeCore`；通过 `init()` 为 `WishListViewModel` 与 `PublishWishViewModel` 共享注入同一个 `WishAPIClient` 实例，最小化改动发布入口。
- [ios/Haluowode/PublishView.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-004-real-publish/ios/Haluowode/PublishView.swift) — 重构表单输入绑定为 `ObservedObject var viewModel`；完全删除了 `DispatchQueue.main.asyncAfter` 和 `Wish.mockWishes.insert(...)` 伪造假成功的运行时逻辑。增加了对 `viewModel.validationErrors` 的本地红字显式校验报错信息与对 `.failed` 状态的重试 Banner 指示。
- [ios/Haluowode/PublishWishViewModel.swift](file:///Users/hansangbai/Documents/New%20project/worktrees/ag-004-real-publish/ios/Haluowode/PublishWishViewModel.swift) — **新建 ViewModel 文件**。处理表单数据、中文交付方式映射为 `DeliveryType`、deadline 格式化、感谢金换算为分（Yuan * 100）、前端表单初审校验、防止二次提交以及在途取消的传递防错逻辑。
- [ios/HaluowodeTests/PublishWishViewModelTests.swift](file:///朋Users/hansangbai/Documents/New%20project/worktrees/ag-004-real-publish/ios/HaluowodeTests/PublishWishViewModelTests.swift) — **新建物理测试文件**，基于 `XCTest` 测试框架。

**最终 Commit SHA**：`2befafcec9c3a6a537da3e8da5900bb991d5d13d`

---

## 2. ViewModel 状态机与行为定义

`PublishWishViewModel` 内置了纯正的生命周期状态 `PublishState`：
1.  **`.idle` (空闲状态)**：初始状态或在 `resetForm()` 调用后的复位状态。
2.  **`.submitting` (提交中状态)**：当用户确认提交并顺利通过本地前置检验后，进入该状态。此时 UI 提交按钮处于 `ProgressView()` 状态，并且重复点击会被内部的 `guard state != .submitting` 重复进入防御直接丢弃，防止抖动。
3.  **`.success(publicCode: String)` (发布成功状态)**：API 成功响应并返回新创建的或已存在的 `PublicWishDTO` 后，置为此状态并记录 `publicCode` 供页面渲染。
    *   *隐私安全防漏*：成功后**绝对不**会以任何形式向 `UserDefaults`、日志、复制板或普通控制台输出联系人信息或其它隐私文本。
4.  **`.failed(String)` (提交失败状态)**：API 抛错（例如 400 校验错误、429 超限限流、网络解析错误或在途取消等）时，记录过滤后的错误文案描述。
    *   *草稿保存机制*：若遭遇失败，ViewModel 包含的表单内容完全原样保留在发布页面中，不会清空。顶部会弹出红色的 Error Banner 提供 `重试` 按钮。
    *   *400 错误字段高亮*：支持把后端抛回的字段错 `fields: [String: String]` 自动解析绑定到 `validationErrors` 中，使具体输入框下方呈现高亮红色字体的特定原因提示（例如地标、名字等格式错误）。

---

## 3. 交付质量与测试执行证据

### A. 物理测试执行结果 (SPM 与 Xcode Simulator 均 100% 绿灯且无警告)

1.  **SPM 核心 Package 测试 (15 / 15 Passed)**：
    ```bash
    swift test --package-path ios/Packages/HaluowodeCore --scratch-path /private/tmp/haluowode-core-ag004 --disable-xctest --enable-swift-testing
    ```
    *结果*：15 个物理用例全部通过，用时 0.005 秒。

2.  **App 模拟器单元测试 (9 / 9 Passed)**：
    ```bash
    xcodebuild -project ios/Haluowode.xcodeproj -scheme Haluowode \
      -destination 'platform=iOS Simulator,id=742A9D34-5F88-4578-BB12-851A00D2C0FE' \
      -derivedDataPath /private/tmp/haluowode-ag004-tests \
      -only-testing:HaluowodeTests test
    ```
    *结果*：9 个 XCTest 用例全部成功通过（`** TEST SUCCEEDED **`），其中：
    *   `WishListViewModelTests` 通过了 3 个用例（在途取消、成功、失败）。
    *   `PublishWishViewModelTests` 通过了 6 个用例，验证了以下逻辑：
        *   `testInvalidInputValidation`：无效输入阻止 API 并标记 validationErrors。
        *   `testCorrectRequestMapping`：合法字段正确映射、中文翻译映射、日期格式转化（`yyyy-MM-dd`）、分角转换。
        *   `testDuplicateSubmissionSuccess200`：重复提交 200 返回 created == false 时也标记为成功发布并显示编号。
        *   `testFailurePreservesDraft`：请求失败原样保留草稿，并映射错误信息。
        *   `testSubmissionDeduplication`：提交中去重逻辑。
        *   `testCancellationDoesNotSetFailedState`：取消 Task 过程中不报 loading 失败。

3.  **App 静态类型核对**：
    ```bash
    swiftc -typecheck -I /private/tmp/haluowode-core-ag004/out/Products/Debug ios/Haluowode/*.swift
    ```
    *结果*：编译检查退出码为 0，没有任何 Warning 或 Error。

4.  **无假延迟与伪 Mock 检测**：
    ```bash
    grep -n -E "Wish\.mockWishes|DispatchQueue\.main\.asyncAfter" ios/Haluowode/PublishView.swift ios/Haluowode/PublishWishViewModel.swift
    ```
    *结果*：没有匹配到任何假延迟及假 Model 写入逻辑。

---

## 4. 已验证 / 未验证 / 已知风险

- **已验证**：
  1. 重定向并清理了 dynamic linking duplicate symbols 警告，确保了 XCTest target 在类型转换时的稳定性。
  2. 交付的 ViewModel 表单合法性验证契约与 `docs/ios-api-contract.md` 规范完全对齐。
  3. UI 中 Emoji、渐变已完全被禁止与排除。
- **未验证**：iOS 主 App 在真机/模拟器上的真实渲染行为（由 Codex 集成后执行）。
- **已知风险**：无。

---

## 5. 下一步建议

1.  **检查工作区状态**：在分支 `codex/ag-004-real-publish` 下运行 `git status` 确保没有任何未提交的代码修改（工作区完全干净）。
2.  **复核 DerivedData 测试**：再次执行 `xcodebuild` 验证通过结果。
3.  **等待 PM 评审**：本轮 `AG-004` 交付物已完全就绪，交接报告和群聊已同步。请等待 Codex-PM 对 `AG-004` 的最后 `ACCEPTED` 裁决和合并至 `main` 的决定，并等待派发下一步的 `AG-005` (状态追踪) 任务。

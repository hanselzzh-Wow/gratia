# 哈喽卧得 iPhone MVP 完成审计

状态：`NOT READY FOR TRUE iPHONE INSTALL TEST`

最后核对：2026-07-18（Asia/Shanghai）
权威验收：`docs/ios-mvp-acceptance.md`

本文件只记录当前可由代码、结构化测试结果或设备检查证明的事实；不把“已有候选代码”“测试通过”或“设计已冻结”自动推论为手机 MVP 已完成。

## P0 业务闭环

| 验收项 | 当前结论 | 已有证据 | 仍需的证据／工作 |
| --- | --- | --- | --- |
| P0-A 公开列表 | 已实现，待最终端到端复验 | `WishListViewModel` 走 `WishAPIProtocol`；Core fixture 覆盖列表、空数组、未知枚举、取消和错误；Simulator 自动测试通过 | 在最终候选的真实设备上确认公开 HTTPS 读取、加载／空／错状态 |
| P0-B 真实发布 | 已实现，待最终端到端复验 | `PublishWishViewModel` 调 `createWish`，无效输入、201、重复 200、失败草稿、去重、取消有 iOS 测试；成功页显示并复制后端公开编号 | 受控测试单真实发布、运营审核／派单后的真机回查 |
| P0-C 真实响应 | 已实现，待最终端到端复验 | `WishResponseViewModel` 调 `createWishResponse(wishId:)`；201、重复 200、错误保留草稿、取消与隐私边界已有 iOS 测试 | 受控测试单从真实心愿详情提交响应并由运营确认 |
| P0-D 真实追踪与交付 | **未完成，阻断手机 MVP** | Core 已有 `trackWish` DTO/API 与部分解码 fixture；Antigravity 隔离 worktree 有未提交候选增量 | main 的 `ProgressView.swift` 仍有 `DispatchQueue.main.asyncAfter` 和 `Wish.mockWishes` 运行时路径。必须完成 AG-006 的真实 `trackWish`、取消／隐私／去重测试、媒体失效状态、独立验收与合入 |

## 原生 UI 与技术边界

| 验收项 | 当前结论 | 证据／缺口 |
| --- | --- | --- |
| 原生 SwiftUI 五栏 | 部分通过 | 当前工程是 SwiftUI，非 `WKWebView`；首页、附近、发布、我的已接入 v3；Tab Bar 与 Progress 仍待 P0-D 收口后独立视觉任务 |
| v3 视觉冻结 | 已冻结并部分落地 | `docs/ios-design-freeze-v3.md`；CX-001/002/003 已把首页、附近、响应、发布、我的与 App Icon 合入 main |
| 无 Emoji／无渐变／默认无阴影 | 部分通过 | 已验收 v3 页面遵守；全局扫描仍在旧 `ProgressView.swift` 发现阴影，不能在 P0-D 完成前判定整 App 通过 |
| 真实 API 注入与无管理凭据 | 已具备基础，待 P0-D 总审计 | `WishAPIProtocol`／`WishAPIClient` 注入用于已验收流程；最终必须再扫描 `admin`、密钥、Token、联系方式和交付 URL 泄露 |
| iOS 16 与安装基本配置 | 部分通过 | `IPHONEOS_DEPLOYMENT_TARGET = 16.0`、Bundle ID `com.hanselzzh.haluowode`、App Icon 已配置；尚未配置 Personal Team，也没有连接真实 iPhone |

## 当前自动化验证证据

- 主线 Swift parser：通过。
- `swift test --package-path ios/Packages/HaluowodeCore --disable-xctest --enable-swift-testing`：15/15 通过。
- iPhone 17 Pro（iOS 27）Simulator：`HaluowodeTests` 结构化结果 15/15、0 failure、0 skip、0 runtime warning。
- 已知环境 warning：Xcode beta 测试 target 的 iOS 16／较新 XCTest runtime 链接 warning；结构化测试未报告失败。该 warning 不证明或否定 P0-D。

## 真机前的完成顺序

1. Antigravity 在 `AG-006` 原隔离 worktree 完成并提交 P0-D，提供交接和全部验收结果。
2. Codex 独立核验 P0-D：真实请求、404／429 隐私文案、取消、去重、媒体失效、无 Mock／无敏感持久化；合入 main。
3. Codex 在新的无冲突任务中完成 Progress／Delivery／Tab Bar 的 v3 收口，跑全量 Core 与 Simulator 测试。
4. 产品负责人连接 iPhone、选择 Personal Team；Codex 安装 Debug 候选并以非真实隐私测试信息跑发布 → 审核／派单 → 查询 → 交付。
5. 在 `PROJECT_LOG.md` 记录真机型号、iOS、构建号、测试单号、安装方式、结果与已知非阻断问题，才能把状态改为“可在真实 iPhone 试用”。

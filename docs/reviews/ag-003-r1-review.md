# AG-003 R1 二轮独立审查

审查日期：2026-07-18（Asia/Shanghai）
分支：`codex/ag-003-core-api`
审查 commit：`bd87072`

## 结论

`R1 REJECTED — 由 Antigravity 在原分支完成 R2`。

本轮是真实进步：Home/Nearby 已恢复，未知枚举保留 raw value，交付 kind 已强类型化，列表状态改为单一 `LoadState`；使用交接列出的 Command Line Tools 框架参数时，Swift Testing 确实发现并执行 12 个测试，Codex 独立复跑结果为 12/12 通过。它不再是假测试。

但 R1 仍不能合入。以下问题由 Antigravity 自己修复，Codex 不接管代码。

## P0 阻断项

### 1. App 存在已复现的类型检查错误

项目自身定义了 `ProgressView` 页面，遮蔽了 SwiftUI 同名加载指示器。Codex 实际执行：

```bash
swiftc -typecheck -I ios/Packages/HaluowodeCore/.build/arm64-apple-macosx/debug/Modules ios/Haluowode/*.swift
```

得到 `HomeView.swift:130` 报错：`argument passed to call that takes no arguments`。

`NearbyView.swift` 的加载文字和提交 spinner 也使用 `ProgressView`；零参数版本甚至可能实例化整个“进度”页面。parser 仍无法发现此问题。

R2 必须消除所有同名遮蔽，重新运行上述 typecheck，并在完整 Xcode 可用后再跑 iOS simulator build。

### 2. 城市“全部/全国”不一致会发送错误 query

- Home/共享状态使用“全国”。
- Nearby 筛选使用“全部”，确认后写入共享 `selectedCity`。
- ViewModel 只将“全国”转为 `nil`。
- API Client 因而会发送 `city=全部`，返回错误的空结果。

R2 必须只保留一个规范化值，并用测试证明：全国不带 query，具体城市正确编码为 `city=...`。

### 3. R1 规定的网络测试覆盖仍未完成

当前 12 个测试真实运行，但以下明确要求缺失：

- 没有断言城市 query。
- 没有响应报名 200 重复成功测试，只有 409。
- POST 测试多数忽略 `HTTPRequest`，未验证 method、path、Content-Type、JSON body、`contactConsent` 和不发送蜜罐字段。
- “取消”测试只是让 MockTransport 主动抛 `requestCancelled`，没有真实取消 Task，也没有验证旧慢响应不会覆盖新请求。

测试数量不设上限；R2 应补足行为，而不是维持“12”这个数字。

### 4. 标准测试命令仍失败

Codex 独立执行原任务命令 `swift test --package-path ios/Packages/HaluowodeCore`，当前 Command Line Tools 环境在测试文件第 1 行报 `no such module 'Testing'` 并退出 1。使用交接提供的额外 `-F`、`-disable-cross-import-overlays` 和 `-rpath` 参数时，12 个测试才真实通过。

这属于当前工具链限制，不要求在仓库硬编码本机绝对路径。R2 交接必须明确区分“标准命令失败”和“CLT workaround 12/12”；完整 Xcode 安装并选中后，标准 `swift test` 是最终门槛。

## P1 修正项

- `CreateWishRequest` 与 `CreateWishResponseRequest` 的 consent 默认 `true`；调用方遗漏参数会代替用户表示同意。删除默认值，所有调用和测试显式传入。
- Home 交接声称下拉刷新，但源码没有 `.refreshable`；补齐或修正文档，不得虚报。
- `WishListViewModel` 创建不结构化内部 Task，外层 `.task` 取消不传播，也没有页面离开时的 cancel；改进取消与请求代际保护，并补实际取消证据。
- 响应表单直接创建生产 `WishAPIClient()`，无法注入、测试或可靠取消；改为可注入 ViewModel/协议依赖，提交状态单一化。
- 未知枚举应保留 `rawValue`，但面向用户 label 不应直接展示未经控制的服务端原始字符串；使用安全通用文案。
- Home 当前显示 spinner，不是交接声称的骨架屏；实现真实 skeleton 或准确改写声明。

## Legacy Mock 范围裁决

旧 `Wish`、`Wish.mockWishes`、Publish 写入和 Progress 查询仍存在。R1 原要求“删除旧聚合 Mock”与“不得修改发布/进度文件”的范围确有冲突；Antigravity 应在 R2 交接中明确提出并记录该冲突，而不是称“彻底删除”。

R2 暂时允许这个 legacy store 只为未迁移的 Publish/Progress 编译兼容而存在，但：

- Home/Nearby/Response 不得读写它。
- 交接必须明确其仍存在并列为 AG-004/AG-005 强制删除项。
- 在 Publish 与 Track 真实 API 切片完成前，主分支不能被描述为无 Mock MVP。

## AG-003 R2 验收

1. 原分支追加新 commit，不重写 `5bc4682` 或 `bd87072`。
2. 修复 SwiftUI `ProgressView` 类型遮蔽，macOS typecheck 无错误。
3. 统一城市筛选并测试 nil query 与具体城市 query。
4. 补齐所有 POST method/path/header/body/consent、响应 200、真实取消和旧响应竞态测试。
5. consent 构造器不提供默认 true；UI 显式同意后才能创建请求。
6. Home 补真实下拉刷新；响应提交使用可注入依赖和明确提交状态。
7. 使用特殊参数的测试必须列出发现/执行/通过数量；标准命令失败需诚实保留，Xcode 可用后再关闭该环境项。
8. 更新交接，逐条回应本审查，不得把兼容性 legacy Mock 写成已删除。

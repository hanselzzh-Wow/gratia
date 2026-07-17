# iOS MVP 客户端架构

状态：候选架构，待 `AG-002` API 映射与 `CL-001` 设计交接完成后冻结  
目标：在不重做 Cloudflare 后端的前提下，建立可测试、可逐步上线的原生 SwiftUI MVP。

## 原则

- 原生 SwiftUI，禁止用网页或 `WKWebView` 冒充消费者 App。
- iOS 16 起步，使用 Swift Concurrency、`URLSession`、`Codable` 与 `ObservableObject`。
- App 只访问公开业务 API；不内置 D1/R2 凭据、Cloudflare Token、运营 PIN 或管理员 API Key。
- 网络 DTO、领域状态和界面状态分离，不使用一个万能 `Wish` 覆盖所有端点。
- 运行时数据来自真实 API；静态样例只允许存在于 SwiftUI Preview 和测试 target。
- 先完成一条真实纵向切片，再扩展页面，不批量生成不可验证的 UI。

## 目标目录

```text
ios/
├── project.yml
├── Haluowode/
│   ├── App/
│   │   ├── HaluowodeApp.swift
│   │   ├── AppContainer.swift
│   │   └── RootTabView.swift
│   ├── Core/
│   │   ├── API/
│   │   │   ├── APIClient.swift
│   │   │   ├── APIEndpoint.swift
│   │   │   ├── APIError.swift
│   │   │   └── HTTPTransport.swift
│   │   ├── Models/
│   │   │   ├── WishDTO.swift
│   │   │   ├── WishRequests.swift
│   │   │   └── WishStatus.swift
│   │   └── DesignSystem/
│   │       ├── AppColors.swift
│   │       ├── AppSpacing.swift
│   │       └── Components/
│   ├── Features/
│   │   ├── Home/
│   │   ├── Nearby/
│   │   ├── Publish/
│   │   ├── Progress/
│   │   └── Profile/
│   ├── Resources/
│   └── Info.plist
├── HaluowodeTests/
│   ├── APIClientTests.swift
│   ├── FixtureTransport.swift
│   └── Fixtures/
└── HaluowodeUITests/
```

不要求第一张实现任务一次创建全部空目录。目录随已实现的纵向切片逐步落地，避免空架构。

## 依赖方向

```text
SwiftUI View
    ↓ 用户动作 / 展示 ViewState
@MainActor Feature ViewModel
    ↓ 调用公开业务方法
WishAPIProtocol
    ↓ Endpoint + DTO
HTTPTransport (URLSession)
    ↓ HTTPS / JSON
Cloudflare Worker
```

View 不直接拼 URL、不直接解码 JSON、不直接读取其他页面的可变数组。ViewModel 不知道 Cloudflare Token、D1 或 R2 的存在。

## 核心类型边界

最终字段名以 `AG-002` 验收后的接口映射为准，类型职责先固定如下：

- `PublicWishDTO`：公开列表/详情可见字段；不得包含发布者联系方式或内部审核信息。
- `CreateWishRequest` / `CreateWishResponse`：发布表单和成功结果。
- `CreateWishResponseRequest` / 对应结果：响应者报名，不与发布请求复用。
- `TrackWishRequest` / `TrackedWishDTO`：以单号和联系方式查询私有进度。
- `WishStatus`：受控状态；解码未知服务端值时保留 fallback，避免新状态导致整个列表解码失败。
- `DeliveryAsset`：只保存后端返回的能力链接及展示所需元数据，不推导 R2 路径。
- `APIError`：至少区分无网络、超时、HTTP 状态、服务端结构化错误、解码错误和取消。

联系方式只进入发布/响应/追踪请求和必要的私有查询结果，不进入公开列表模型、日志、Analytics 或错误描述。

## API Client

- 默认 `baseURL` 为生产 Worker 地址，但通过 `AppContainer` 注入，测试不得访问生产网络。
- `HTTPTransport` 协议只负责发送 `URLRequest` 并返回 `(Data, HTTPURLResponse)`。
- 生产实现使用 `URLSession`；测试使用内存 fixture transport。
- `APIClient` 负责 URL 构造、JSON 编解码、状态码与服务端错误映射。
- 所有 async 请求支持任务取消；View 消失时不强制保留无意义请求。
- POST 请求期间禁用重复提交；失败后保留用户输入并给出可重试提示。
- 不在控制台打印完整请求正文、联系方式、交付能力 URL 或服务端原始私有载荷。

## Feature 状态

每个联网页面使用明确状态，而不是若干可能互相矛盾的布尔值：

```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(UserFacingError)
}
```

提交型流程可使用 `idle / submitting / succeeded / failed`。具体实现可以是嵌套枚举或独立 ViewState，但必须防止“同时加载且成功”等无效组合。

首批 ViewModel：

- `WishListViewModel`：加载与刷新公开心愿。
- `PublishWishViewModel`：管理三步草稿、客户端校验、提交和成功编号。
- `RespondToWishViewModel`：提交响应并防重复。
- `TrackWishViewModel`：查询进度、展示时间线和交付资源。

## 导航与共享状态

- 根部保留五栏 `TabView`。
- 各栏使用独立 `NavigationStack`，避免一个页面的导航污染其他 Tab。
- 发布成功后通过根级路由切换到进度栏，并把新单号预填入查询界面；联系方式只在内存中短暂传递，不持久化到明文日志。
- MVP 不实现虚假的登录态。“我的”只展示产品说明、安全与帮助入口，账户功能明确标注为后续版本或隐藏。

## 设计系统与无障碍

- 颜色、间距、圆角和组件状态以 Claude 冻结稿为准。
- 正文字体使用 `.body`、`.callout`、`.caption` 等语义样式；只在品牌展示数字等有限场景使用固定尺寸并验证 Dynamic Type。
- 所有可点击图标有可读 label；44pt 最小触控区域；错误不仅依靠颜色表达。
- 支持键盘避让、VoiceOver 基本顺序、深色模式最低可读性和减少动态效果。

## 测试梯度

1. Swift parser：在没有完整 Xcode 时尽早发现语法错误。
2. API Client 单元测试：成功、结构化错误、非 JSON 错误、解码失败、取消和隐私字段。
3. ViewModel 单元测试：加载/空/失败/重试、提交防抖、输入保留和成功跳转数据。
4. `xcodebuild` simulator build/test：完整 Xcode 可用后的强制门槛。
5. 模拟器人工验收：导航、键盘、网络异常、Dynamic Type。
6. 生产只读联调：只对公开 GET 做自动只读检查。
7. 生产写入 E2E：使用标识清晰的测试单，并按试运营手册清理或归档。
8. 真实 iPhone：Personal Team 或 TestFlight 安装，记录设备/iOS/构建号。

## 首批实现顺序

1. 工程/测试 target、`HTTPTransport`、`APIClient`、错误映射。
2. 公开心愿 DTO + 首页/附近真实列表（第一条完整纵向切片）。
3. 发布请求 + 三步表单 + 成功单号。
4. 追踪请求 + 进度时间线 + 交付能力链接。
5. 响应请求 + 详情页报名。
6. 设计统一、无障碍、模拟器和真机验收。

每一步只在上一步通过验收后继续；不以“页面看起来完整”替代真实接口和设备验证。

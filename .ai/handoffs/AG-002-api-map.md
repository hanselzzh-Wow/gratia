# AG-002 API 契约与 Swift 候选模型映射报告

- **任务 ID**：AG-002
- **执行者**：Antigravity (Gemini 3.5 Flash)
- **分析文件基线**：
  - 前端 Mock 模型：[Models.swift](file:///Users/hansangbai/Documents/New%20project/ios/Haluowode/Models.swift)
  - 后端接口契约：[wishes-contract.ts](file:///Users/hansangbai/Documents/New%20project/lib/wishes-contract.ts)
  - 后端校验层：[wishes-validation.ts](file:///Users/hansangbai/Documents/New%20project/lib/wishes-validation.ts)
  - 后端路由入口：[index.ts (Worker)](file:///Users/hansangbai/Documents/New%20project/worker/index.ts)

---

## 1. 公开 API 端点契约映射

### ① 列表查询：`GET /api/wishes`
*   **用途**：附近心愿版块加载公开的可申请心愿。
*   **请求参数** (Query Parameters)：
    *   `city` (string, 可选)：进行同城筛选。
*   **响应字段 (HTTP 200)**：
    *   `wishes` (数组，元素为 `PublicWish` 接口)：
        *   `id` (`string`, 格式为 UUID)：数据库记录的唯一物理主键。
        *   `publicCode` (`string`, 格式如 `HW260717-ABCDE`)：面向用户公开的业务订单号。
        *   `city` (`string`)：城市。
        *   `landmark` (`string`)：地标。
        *   `occasion` (`string`)：心愿场景分类（如：“生日祝福”）。
        *   `message` (`string`)：心愿正文想说的话。
        *   `deliveryType` (`enum`: `"spoken_video" | "scenery_voiceover" | "handwritten_card"`)：交付类型。
        *   `deadlineText` (`string`)：期望时间。
        *   `rewardFen` (`number`, 整数)：感谢金，单位为 **分**。
        *   `status` (`enum`: `WishStatus`)：心愿状态。
        *   `createdAt` (`number`, Unix 毫秒时间戳)：心愿发布时间。
*   **隐私与安全边界**：
    *   此端点由后端强制过滤。只有当状态为 `"matching" | "assigned" | "in_progress" | "delivered" | "completed"` 时才会被查询出来。处于 `"pending_review"` (待审核) 和 `"rejected"` (未通过) 状态的心愿绝不会暴露。
    *   此端点绝不返回发布者的姓名 (`requesterName`)、联系方式 (`contact`)。
*   **错误状态**：
    *   `403 Forbidden`：不允许的 CORS 请求来源。
    *   `500 Internal Server Error`：服务端故障。

---

### ② 发布心愿：`POST /api/wishes`
*   **用途**：发布心愿三步表单提交。
*   **请求体 (JSON)**：
    *   `requesterName` (`string`, 1–30 字符)：发布者称呼。
    *   `contact` (`string`, 3–80 字符)：联系方式（微信/手机号）。
    *   `city` (`string`, 2–24 字符)：城市。
    *   `landmark` (`string`, 2–40 字符)：具体地标。
    *   `occasion` (`string`, 2–24 字符)：心愿场景。
    *   `message` (`string`, 5–120 字符)：想说的话。
    *   `deliveryType` (`enum`: `"spoken_video" | "scenery_voiceover" | "handwritten_card"`)：交付形式。
    *   `deadlineText` (`string`, 2–40 字符)：期望完成时间。
    *   `rewardFen` (`number`, 整数 0–100,000)：感谢金（分），最高 1000 元。
    *   `contactConsent` (`boolean`，必须为 `true`)：同意运营联系选项。
*   **响应字段 (HTTP 201)**：
    *   `wish` (`PublicWish` 结构)：包含新生成的 `id` 和 `publicCode`。
    *   `created` (`boolean`): 表示创建状态。
*   **错误状态**：
    *   `400 Bad Request`：输入校验未通过。响应体为 `ApiErrorPayload`，其中 `fields` 表明具体发生校验错误的表单字段：
        ```json
        { "error": "请检查心愿信息", "fields": { "message": "想说的话需为 5–120 个字符" } }
        ```
    *   `415 Unsupported Media Type`：`content-type` 不是 `application/json`。
    *   `429 Too Many Requests`：发布频控（基于客户端 IP 指纹，1小时内最多发布 8 次）。

---

### ③ 响应报名：`POST /api/wishes/{id}/responses`
*   **用途**：在场者对特定心愿提交匹配申请。
*   **路径参数**：
    *   `id` (`string`, UUID)：目标心愿的数据库 `id`。
*   **请求体 (JSON)**：
    *   `responderName` (`string`, 1–30 字符)：响应人称呼。
    *   `responderContact` (`string`, 3–80 字符)：联系方式。
    *   `note` (`string`, 可选, 0–160 字符)：补充说明。
    *   `contactConsent` (`boolean`, 必须为 `true`)：同意运营联系选项。
*   **响应字段 (HTTP 201)**：
    *   `response` (对象)：
        *   `id` (`string`, UUID)：响应记录 ID。
        *   `responderName` (`string`)：称呼。
        *   `responderContact` (`string`)：联系方式。
        *   `note` (`string | null`)：补充留言。
        *   `status` (`"pending" | "selected" | "declined"`)：报名状态。
    *   `created` (`boolean`)
*   **错误状态**：
    *   `400 Bad Request`：校验失败（联系方式未填，或未同意条款）。
    *   `429 Too Many Requests`：响应报名频控限制。

---

### ④ 进度追踪：`POST /api/wishes/track`
*   **用途**：发布人使用单号和联系人查询心愿流转明细。
*   **请求体 (JSON)**：
    *   `publicCode` (`string`, 8–24 字符)：公开编号（输入不区分大小写，后端会自动转大写）。
    *   `contact` (`string`, 3–80 字符)：发布时填写的原始联系人。
*   **响应字段 (HTTP 200)**：
    *   `wish` (`TrackedWish` 结构，包含明细)：
        *   (继承 `PublicWish` 的全部字段)
        *   `updatedAt` (`number`): 更新时间戳。
        *   `assignment` (`object | null`): 派单状态。
            *   `providerName` (`string`)：派发的在场响应者称呼。
            *   `status` (`enum`: `"offered" | "accepted" | "arrived" | "delivered" | "declined" | "cancelled"`)：履约状态。
        *   `deliverable` (`object | null`)：交付产物。
            *   `id` (`string`)
            *   `kind` (`enum`: `"spoken_video" | "scenery_voiceover" | "handwritten_card" | "link"`)
            *   `url` (`string`)：**携带随机校验令牌的安全访问 URL**。
            *   `note` (`string | null`)：交付留言。
            *   `createdAt` (`number`)
        *   `events` (数组，元素为 `WishEvent`):
            *   `eventType` (`string`)：状态流转类型。
            *   `fromStatus` (`WishStatus | null`)：来源状态。
            *   `toStatus` (`WishStatus | null`)：去向状态。
            *   `createdAt` (`number`)
*   **错误状态**：
    *   `400 Bad Request`：格式输入非法。
    *   `404 Not Found`：`交付内容不存在或链接已失效`。说明公开编号与联系方式不匹配或订单不存在。

---

### ⑤ 安全交付文件预览：`GET /api/deliverables/{id}`
*   **用途**：安全获取 R2 对象存储中的照片或视频交付文件。
*   **请求参数** (Query Parameters)：
    *   `token` (`string`, 必填)：专属随机校验令牌（此令牌在进度追踪接口中，由 `deliverable.url` 中返回）。
*   **响应 (HTTP 200)**：
    *   交付的图片或视频文件媒体流（`image/jpeg`, `video/mp4` 等），响应头包含 `cache-control: private, no-store` 和 `content-disposition: inline`。
*   **错误状态**：
    *   `401 Unauthorized`：缺少令牌或令牌错误。
    *   `404 Not Found`：交付记录不存在或存储在 R2 的实体文件已被清理。

---

## 2. 现有 Swift 候选模型 `Wish` 与真实 API 的差距

| 维度 | SwiftUI 候选模型 `Wish` 表现 | 真实 API 契约设计 | 差距及影响 |
| :--- | :--- | :--- | :--- |
| **主键标识** | `id` 代表单号 (如 `HW260717-A102B`) | `id` 为 UUID 主键；`publicCode` 为单号 | **极高**。前端的 Identifiable 协议依赖于 `id`。如果接口返回 JSON 反序列化，会造成 ID 不匹配，导致查询及本地状态管理混乱。 |
| **感谢金单位**| `reward` 为人民币 **元** 整数 (如 `18`) | `rewardFen` 为人民币 **分** 整数 (如 `1800`) | **中等**。前端发布提交时需将金额乘以 100；解析列表及详情时需要除以 100 换算为元显示。 |
| **交付类型格式**| `deliveryType` 为中文 `"口播视频"`等 | `deliveryType` 为英文枚举 `"spoken_video"` 等 | **中等**。前端必须做双向映射映射，或者在 Swift 中定义带有原始值 (RawValue) 的 Enum 结构。 |
| **状态表示** | `status` 为中文 `"待匹配"`、`"审核中"`等 | `status` 为英文状态枚举 (如 `"pending_review"`) | **高**。状态与 UI 时间线绑定，若不定义 Swift Enum 进行解析，将无法准确描绘时间线。 |
| **字段缺失** | 无场景 `occasion`；无创建时间；正文使用 `content` | 包含 `occasion`；包含 `createdAt`；正文使用 `message` | **高**。SwiftUI 界面展示的分类和时间戳等属性，模型中均未声明。 |
| **敏感隐私边界**| 包含 `creatorName` 可选字段 | `PublicWish` 中剔除了发布者称呼等敏感隐私 | **极高**。前端不可将 `creatorName` 和 `contact` 设为 `PublicWish` 的成员直接进行通用反序列化，防篡改和越权查看。 |

---

## 3. 建议的 Swift 模型定义 (Swift Type Specifications)

为确保 iOS 客户端的稳健性与协议对齐，建议**不要**直接扩展原 Mock 模型。而在未来解除冻结后，使用以下与 TypeScript 合约完全对齐的强类型 Swift 结构：

```swift
import Foundation

// MARK: - 基础枚举定义
enum DeliveryType: String, Codable {
    case spokenVideo = "spoken_video"
    case sceneryVoiceover = "scenery_voiceover"
    case handwrittenCard = "handwritten_card"

    var label: String {
        switch self {
        case .spokenVideo: return "口播视频"
        case .sceneryVoiceover: return "景色配音"
        case .handwrittenCard: return "手写卡片"
        }
    }
}

enum WishStatus: String, Codable {
    case pendingReview = "pending_review"
    case matching = "matching"
    case assigned = "assigned"
    case inProgress = "in_progress"
    case delivered = "delivered"
    case completed = "completed"
    case rejected = "rejected"
    case cancelled = "cancelled"

    var label: String {
        switch self {
        case .pendingReview: return "待审核"
        case .matching: return "待匹配"
        case .assigned: return "已派单"
        case .inProgress: return "进行中"
        case .delivered: return "待确认"
        case .completed: return "已完成"
        case .rejected: return "未通过"
        case .cancelled: return "已取消"
        }
    }
}

// MARK: - 1. 公开版心愿模型 (对应 PublicWish)
struct PublicWish: Codable, Identifiable {
    let id: UUID
    let publicCode: String
    let city: String
    let landmark: String
    let occasion: String
    let message: String
    let deliveryType: DeliveryType
    let deadlineText: String
    let rewardFen: Int
    let status: WishStatus
    let createdAt: Int64 // 毫秒时间戳

    // 感谢金（元）的方便转换
    var rewardYuan: Double {
        Double(rewardFen) / 100.0
    }
}

// MARK: - 2. 进度追踪详细模型 (对应 TrackedWish)
struct TrackedWish: Codable, Identifiable {
    let id: UUID
    let publicCode: String
    let city: String
    let landmark: String
    let occasion: String
    let message: String
    let deliveryType: DeliveryType
    let deadlineText: String
    let rewardFen: Int
    let status: WishStatus
    let createdAt: Int64
    let updatedAt: Int64

    let assignment: AssignmentInfo?
    let deliverable: DeliverableInfo?
    let events: [WishEvent]

    struct AssignmentInfo: Codable {
        let providerName: String
        let status: String // offered, accepted, etc.
    }

    struct DeliverableInfo: Codable, Identifiable {
        let id: UUID
        let kind: String
        let url: String
        let note: String?
        let createdAt: Int64
    }

    struct WishEvent: Codable {
        let eventType: String
        let fromStatus: WishStatus?
        let toStatus: WishStatus?
        let createdAt: Int64
    }
}

// MARK: - 3. 校验错误响应
struct ApiValidationErrorResponse: Codable {
    let error: String
    let fields: [String: String]?
}
```

## 4. 建议下一步（禁止在此任务中执行）

1.  **接口变更对齐确认**：由 **Codex** 审查此处的 Swift 结构体定义，并在 `docs/ios-architecture.md` 中冻结 Swift 网络层（URLSession 客户端）的具体请求与响应架构定义。
2.  **网络层实现**：当 Codex 批准新任务后，创建 `ios/Haluowode/Network/WishApiClient.swift` 并使用上面的结构体实现标准的 `GET /api/wishes` 与 `POST /api/wishes/track` 数据获取。

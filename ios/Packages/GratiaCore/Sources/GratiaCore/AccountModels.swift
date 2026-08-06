import Foundation

/// 本人发布的心愿。在公开字段之外，多出只有发布者才看得到的履约信息。
public struct AccountWishDTO: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let publicCode: String
    public let city: String
    public let landmark: String
    public let occasion: String
    public let message: String
    public let deliveryType: DeliveryType
    public let deadlineText: String
    public let rewardFen: Int
    public let status: WishStatus
    public let createdAt: Int64
    public let updatedAt: Int64
    public let hasDeliverable: Bool
    public let canConfirmCompletion: Bool

    public var rewardYuan: Double {
        Double(rewardFen) / 100.0
    }

    public init(
        id: String,
        publicCode: String,
        city: String,
        landmark: String,
        occasion: String,
        message: String,
        deliveryType: DeliveryType,
        deadlineText: String,
        rewardFen: Int,
        status: WishStatus,
        createdAt: Int64,
        updatedAt: Int64,
        hasDeliverable: Bool,
        canConfirmCompletion: Bool
    ) {
        self.id = id
        self.publicCode = publicCode
        self.city = city
        self.landmark = landmark
        self.occasion = occasion
        self.message = message
        self.deliveryType = deliveryType
        self.deadlineText = deadlineText
        self.rewardFen = rewardFen
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.hasDeliverable = hasDeliverable
        self.canConfirmCompletion = canConfirmCompletion
    }
}

/// 本人响应过的心愿。只包含公开心愿信息与自己的响应状态，
/// 不包含发布者联系方式，也不包含其他响应者的任何资料。
public struct AccountResponseDTO: Codable, Identifiable, Sendable, Hashable {
    public let wish: PublicWishDTO
    public let responseStatus: String
    public let respondedAt: Int64

    public var id: String { wish.id }

    public init(wish: PublicWishDTO, responseStatus: String, respondedAt: Int64) {
        self.wish = wish
        self.responseStatus = responseStatus
        self.respondedAt = respondedAt
    }

    /// 服务端的响应状态枚举可能随运营流程增加，未知值一律按"处理中"展示，
    /// 不让旧客户端因为新状态而显示空白。
    public var statusLabel: String {
        switch responseStatus {
        case "submitted": return "等待运营确认"
        case "accepted": return "已被选中"
        case "declined": return "本次未被选中"
        case "withdrawn": return "已撤回"
        default: return "处理中"
        }
    }
}

public struct AccountActivityDTO: Codable, Sendable {
    public let requests: [AccountWishDTO]
    public let responses: [AccountResponseDTO]

    public init(requests: [AccountWishDTO], responses: [AccountResponseDTO]) {
        self.requests = requests
        self.responses = responses
    }
}

public struct CompleteWishEnvelope: Codable, Sendable {
    public let wish: AccountWishDTO
}

/// 需要登录才能调用的业务端点。所有方法都要求调用方传入会话 token；
/// token 只作为 Authorization 头发送，不会进入 URL、日志或错误文案。
public protocol AccountAPIProtocol: Sendable {
    func createAccountWish(request: CreateWishRequest, token: String) async throws -> CreateWishResult
    func createAccountWishResponse(
        wishId: String,
        request: CreateWishResponseRequest,
        token: String
    ) async throws -> CreateWishResponseResult
    func accountActivity(token: String) async throws -> AccountActivityDTO
    func confirmWishCompletion(wishId: String, token: String) async throws -> AccountWishDTO

    // MARK: - 直连闭环：会话、选人、交付、公开

    /// 「私聊」标签页：我参与的全部会话，同时覆盖发布者与响应者两种身份。
    func conversations(token: String) async throws -> [ConversationSummaryDTO]
    func conversationMessages(responseId: String, token: String) async throws -> ConversationDTO
    func sendMessage(responseId: String, body: String, token: String) async throws -> ChatMessageDTO
    /// 发布者查看本人心愿收到的响应。服务端刻意不返回响应者联系方式。
    func wishResponses(wishId: String, token: String) async throws -> [OwnerResponseDTO]
    func selectResponder(wishId: String, responseId: String, token: String) async throws
    /// 举报与拉黑：App 内含陌生人即时通讯时，指南 1.2 要求必须提供。
    func reportAbuse(responseId: String, reason: String, detail: String?, token: String) async throws
    func blockCounterpart(responseId: String, token: String) async throws
    /// 需求方在完成后单独决定是否公开到首页
    func publishStory(wishId: String, nickname: String?, token: String) async throws
    func stories() async throws -> [StoryDTO]
    /// 帮助者提交交付：一段文字 + 最多 9 个图片/视频
    func uploadDelivery(
        wishId: String,
        note: String,
        files: [(data: Data, filename: String, contentType: String)],
        token: String
    ) async throws
}

// MARK: - 会话

public struct ConversationSummaryDTO: Codable, Sendable, Identifiable, Equatable {
    public let responseId: String
    public let wishId: String
    public let publicCode: String
    public let title: String
    public let occasion: String
    public let wishStatus: WishStatus
    public let responseStatus: String
    public let viewerRole: String
    public let counterpartName: String
    public let lastMessage: String?
    public let lastMessageAt: Int64?

    public var id: String { responseId }
    public var isRequester: Bool { viewerRole == "requester" }
}

public struct ChatMessageDTO: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let body: String
    public let mine: Bool
    public let createdAt: Int64
}

public struct ConversationDTO: Codable, Sendable, Equatable {
    public let responseId: String
    public let wishId: String
    public let wishStatus: WishStatus
    public let responseStatus: String
    public let counterpartName: String
    public let viewerRole: String
    public let messages: [ChatMessageDTO]

    public var isRequester: Bool { viewerRole == "requester" }
    /// 已被选中的响应；帮助者据此显示「完成帮助」入口
    public var isSelected: Bool { responseStatus == "selected" }
}

/// 发布者看到的响应条目。**没有联系方式字段**——站内既然能选人和交付，
/// 就没有理由把对方的微信或手机号交给发布者。
public struct OwnerResponseDTO: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let responderName: String
    public let note: String?
    public let status: String
    public let createdAt: Int64
}

// MARK: - 故事

public struct StoryMediaDTO: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let url: String
    public let kind: String
}

public struct StoryDTO: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let publicCode: String
    public let nickname: String
    public let city: String
    public let landmark: String
    public let occasion: String
    public let message: String
    public let publishedAt: Int64
    public let note: String?
    public let media: [StoryMediaDTO]
}

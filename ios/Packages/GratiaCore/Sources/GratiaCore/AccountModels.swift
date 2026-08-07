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
    /// 收到的响应数。发布者需要在「我发布的」直接看到，否则只能靠自己翻私聊。
    /// 可选以兼容旧服务端响应。
    public let responseCount: Int?
    public let canSelectResponder: Bool?
    public let selectedResponseId: String?

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
        canConfirmCompletion: Bool,
        responseCount: Int? = nil,
        canSelectResponder: Bool? = nil,
        selectedResponseId: String? = nil
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
        self.responseCount = responseCount
        self.canSelectResponder = canSelectResponder
        self.selectedResponseId = selectedResponseId
    }
}

/// 本人响应过的心愿。只包含公开心愿信息与自己的响应状态，
/// 不包含发布者联系方式，也不包含其他响应者的任何资料。
public struct AccountResponseDTO: Codable, Identifiable, Sendable, Hashable {
    public let wish: PublicWishDTO
    public let responseStatus: String
    public let respondedAt: Int64
    /// 对应会话的 id，用于从「我帮助的」直接进入私聊
    public let responseId: String?
    /// 已被选中且心愿进行中，帮助者可提交交付
    public let canDeliver: Bool?

    public var id: String { wish.id }

    public init(
        wish: PublicWishDTO,
        responseStatus: String,
        respondedAt: Int64,
        responseId: String? = nil,
        canDeliver: Bool? = nil
    ) {
        self.wish = wish
        self.responseStatus = responseStatus
        self.respondedAt = respondedAt
        self.responseId = responseId
        self.canDeliver = canDeliver
    }

    /// 服务端的响应状态枚举可能随运营流程增加，未知值一律按"处理中"展示，
    /// 不让旧客户端因为新状态而显示空白。
    public var statusLabel: String {
        switch responseStatus {
        case "pending": return "等待发布者选择"
        case "selected": return "已被选中"
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
    func unblockCounterpart(responseId: String, token: String) async throws
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

    /// 本人资料。昵称与头像先审后可见，本人始终看到自己刚提交的版本。
    func profile(token: String) async throws -> UserProfileDTO
    func updateProfile(displayName: String?, avatar: Data?, token: String) async throws -> UserProfileDTO

    // MARK: - 推送

    /// 上报本机的 APNs 令牌。令牌会随重装、恢复备份、系统升级变化，
    /// 所以每次拿到都要上报，而不是只在第一次授权时报一次。
    func registerDeviceToken(_ token: String, environment: String, accountToken: String) async throws
    /// 注销本账户在服务端登记的全部设备令牌。
    func removeDeviceTokens(accountToken: String) async throws
}

/// 昵称与头像会出现在私聊、响应列表与公开故事里，属于公开可见的用户生成
/// 内容，因此提交后进入待审核；他人在此期间看到的是上一版通过审核的资料。
public struct UserProfileDTO: Codable, Sendable, Equatable {
    public let displayName: String
    public let avatarUrl: String?
    public let pendingReview: Bool
    public let reviewNote: String?

    /// public struct 的 memberwise init 默认是 internal，跨 module 构造不了。
    /// 与 `PublicWishDTO` 保持一致，显式提供。
    public init(displayName: String, avatarUrl: String?, pendingReview: Bool, reviewNote: String?) {
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.pendingReview = pendingReview
        self.reviewNote = reviewNote
    }
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
    /// 对方的头像（已通过审核的那一版）。旧服务端不返回，故可选。
    public let counterpartAvatarUrl: String?
    public let lastMessage: String?
    public let lastMessageAt: Int64?
    /// 本人在该会话的未读条数（只计对方发出的）
    public let unreadCount: Int?
    /// 我屏蔽了对方——列表据此显示「已屏蔽」
    public let blockedByMe: Bool?
    /// 对方屏蔽了我。界面不明说，只表现为发不出消息。
    public let blockedByThem: Bool?

    public var isBlocked: Bool { (blockedByMe ?? false) || (blockedByThem ?? false) }

    public var id: String { responseId }
    public var isRequester: Bool { viewerRole == "requester" }
}

public struct ChatMessageDTO: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let body: String
    public let mine: Bool
    public let createdAt: Int64

    /// 客户端需要构造「正在发送」的临时消息（乐观上屏），
    /// 而 public struct 的 memberwise init 默认是 internal。
    public init(id: String, body: String, mine: Bool, createdAt: Int64) {
        self.id = id
        self.body = body
        self.mine = mine
        self.createdAt = createdAt
    }
}

public struct ConversationDTO: Codable, Sendable, Equatable {
    public let responseId: String
    public let wishId: String
    public let wishStatus: WishStatus
    public let responseStatus: String
    public let counterpartName: String
    /// 对方的头像（已通过审核的那一版）。旧服务端不返回，故可选。
    public let counterpartAvatarUrl: String?
    public let viewerRole: String
    public let messages: [ChatMessageDTO]
    /// 我屏蔽了对方。界面据此显示「取消屏蔽」。
    public let blockedByMe: Bool?
    /// 对方屏蔽了我。**界面不要明说**，只表现为发不出消息：
    /// 挑明通常只会激化对立。但要让人看懂「到此为止」——
    /// 帮助者可能正准备去现场，别让他白跑一趟。
    public let blockedByThem: Bool?

    /// 任一方屏蔽都不能再发消息，但会话与历史消息仍然可见。
    public var canSendMessages: Bool { !(blockedByMe ?? false) && !(blockedByThem ?? false) }

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

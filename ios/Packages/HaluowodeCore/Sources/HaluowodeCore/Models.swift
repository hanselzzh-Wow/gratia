import Foundation

public struct WishStatus: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let pendingReview = WishStatus(rawValue: "pending_review")
    public static let matching = WishStatus(rawValue: "matching")
    public static let assigned = WishStatus(rawValue: "assigned")
    public static let inProgress = WishStatus(rawValue: "in_progress")
    public static let delivered = WishStatus(rawValue: "delivered")
    public static let completed = WishStatus(rawValue: "completed")
    public static let rejected = WishStatus(rawValue: "rejected")
    public static let cancelled = WishStatus(rawValue: "cancelled")

    public var label: String {
        switch self {
        case .pendingReview: return "待审核"
        case .matching: return "待匹配"
        case .assigned: return "已派单"
        case .inProgress: return "进行中"
        case .delivered: return "待确认"
        case .completed: return "已完成"
        case .rejected: return "未通过"
        case .cancelled: return "已取消"
        default: return "未知状态"
        }
    }
}

public struct DeliveryType: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let spokenVideo = DeliveryType(rawValue: "spoken_video")
    public static let sceneryVoiceover = DeliveryType(rawValue: "scenery_voiceover")
    public static let handwrittenCard = DeliveryType(rawValue: "handwritten_card")

    public var label: String {
        switch self {
        case .spokenVideo: return "口播视频"
        case .sceneryVoiceover: return "景色配音"
        case .handwrittenCard: return "手写卡片"
        default: return "其它形式"
        }
    }
}

public struct DeliveryKind: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let spokenVideo = DeliveryKind(rawValue: "spoken_video")
    public static let sceneryVoiceover = DeliveryKind(rawValue: "scenery_voiceover")
    public static let handwrittenCard = DeliveryKind(rawValue: "handwritten_card")
    public static let link = DeliveryKind(rawValue: "link")

    public var label: String {
        switch self {
        case .spokenVideo: return "口播视频"
        case .sceneryVoiceover: return "景色配音"
        case .handwrittenCard: return "手写卡片"
        case .link: return "外部链接"
        default: return "未知类型"
        }
    }
}

public struct AssignmentStatus: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let offered = AssignmentStatus(rawValue: "offered")
    public static let accepted = AssignmentStatus(rawValue: "accepted")
    public static let arrived = AssignmentStatus(rawValue: "arrived")
    public static let delivered = AssignmentStatus(rawValue: "delivered")
    public static let declined = AssignmentStatus(rawValue: "declined")
    public static let cancelled = AssignmentStatus(rawValue: "cancelled")
}

public struct WishResponseStatus: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let pending = WishResponseStatus(rawValue: "pending")
    public static let selected = WishResponseStatus(rawValue: "selected")
    public static let declined = WishResponseStatus(rawValue: "declined")
}

public struct PublicWishDTO: Codable, Identifiable, Sendable, Hashable {
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

    public var rewardYuan: Double {
        Double(rewardFen) / 100.0
    }

    public init(id: String, publicCode: String, city: String, landmark: String, occasion: String, message: String, deliveryType: DeliveryType, deadlineText: String, rewardFen: Int, status: WishStatus, createdAt: Int64) {
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
    }
}

public struct WishAssignmentDTO: Codable, Sendable, Hashable {
    public let providerName: String
    public let status: AssignmentStatus

    public init(providerName: String, status: AssignmentStatus) {
        self.providerName = providerName
        self.status = status
    }
}

public struct WishDeliverableDTO: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let kind: DeliveryKind
    public let url: URL
    public let note: String?
    public let createdAt: Int64

    public init(id: String, kind: DeliveryKind, url: URL, note: String?, createdAt: Int64) {
        self.id = id
        self.kind = kind
        self.url = url
        self.note = note
        self.createdAt = createdAt
    }
}

public struct WishEventDTO: Codable, Sendable, Hashable {
    public let eventType: String
    public let fromStatus: WishStatus?
    public let toStatus: WishStatus?
    public let createdAt: Int64

    public init(eventType: String, fromStatus: WishStatus?, toStatus: WishStatus?, createdAt: Int64) {
        self.eventType = eventType
        self.fromStatus = fromStatus
        self.toStatus = toStatus
        self.createdAt = createdAt
    }
}

public struct TrackedWishDTO: Codable, Identifiable, Sendable, Hashable {
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
    public let assignment: WishAssignmentDTO?
    public let deliverable: WishDeliverableDTO?
    public let events: [WishEventDTO]

    public var rewardYuan: Double {
        Double(rewardFen) / 100.0
    }

    public init(id: String, publicCode: String, city: String, landmark: String, occasion: String, message: String, deliveryType: DeliveryType, deadlineText: String, rewardFen: Int, status: WishStatus, createdAt: Int64, updatedAt: Int64, assignment: WishAssignmentDTO?, deliverable: WishDeliverableDTO?, events: [WishEventDTO]) {
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
        self.assignment = assignment
        self.deliverable = deliverable
        self.events = events
    }
}

public struct CreateWishRequest: Codable, Sendable {
    public let requesterName: String
    public let contact: String
    public let city: String
    public let landmark: String
    public let occasion: String
    public let message: String
    public let deliveryType: DeliveryType
    public let deadlineText: String
    public let rewardFen: Int
    public let contactConsent: Bool

    public init(requesterName: String, contact: String, city: String, landmark: String, occasion: String, message: String, deliveryType: DeliveryType, deadlineText: String, rewardFen: Int, contactConsent: Bool) {
        self.requesterName = requesterName
        self.contact = contact
        self.city = city
        self.landmark = landmark
        self.occasion = occasion
        self.message = message
        self.deliveryType = deliveryType
        self.deadlineText = deadlineText
        self.rewardFen = rewardFen
        self.contactConsent = contactConsent
    }
}

public struct CreateWishResult: Codable, Sendable {
    public let wish: PublicWishDTO
    public let created: Bool

    public init(wish: PublicWishDTO, created: Bool) {
        self.wish = wish
        self.created = created
    }
}

public struct CreateWishResponseRequest: Codable, Sendable {
    public let responderName: String
    public let responderContact: String
    public let note: String?
    public let contactConsent: Bool

    public init(responderName: String, responderContact: String, note: String?, contactConsent: Bool) {
        self.responderName = responderName
        self.responderContact = responderContact
        self.note = note
        self.contactConsent = contactConsent
    }
}

public struct WishResponseDTO: Codable, Identifiable, Sendable {
    public let id: String
    public let responderName: String
    public let responderContact: String
    public let note: String?
    public let status: WishResponseStatus
    public let createdAt: Int64
    public let updatedAt: Int64

    public init(id: String, responderName: String, responderContact: String, note: String?, status: WishResponseStatus, createdAt: Int64, updatedAt: Int64) {
        self.id = id
        self.responderName = responderName
        self.responderContact = responderContact
        self.note = note
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateWishResponseResult: Codable, Sendable {
    public let response: WishResponseDTO
    public let created: Bool

    public init(response: WishResponseDTO, created: Bool) {
        self.response = response
        self.created = created
    }
}

public struct TrackWishRequest: Codable, Sendable {
    public let publicCode: String
    public let contact: String

    public init(publicCode: String, contact: String) {
        self.publicCode = publicCode
        self.contact = contact
    }
}

public struct TrackWishEnvelope: Codable, Sendable {
    public let wish: TrackedWishDTO

    public init(wish: TrackedWishDTO) {
        self.wish = wish
    }
}

public struct APIErrorPayload: Codable, Error, Sendable {
    public let error: String
    public let fields: [String: String]?

    public init(error: String, fields: [String: String]? = nil) {
        self.error = error
        self.fields = fields
    }
}

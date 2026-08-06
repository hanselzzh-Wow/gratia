import SwiftUI
import GratiaCore

public enum PublishState: Sendable, Equatable {
    case idle
    case submitting
    case success(publicCode: String)
    case failed(String)
    /// 校验已通过但尚未登录：草稿完整保留，登录后可直接重试提交。
    case requiresSignIn
}

@MainActor
public final class PublishWishViewModel: ObservableObject {
    // Form Inputs
    @Published public var scene = "生日祝福"
    @Published public var city = "杭州"
    @Published public var landmark = ""
    @Published public var words = ""
    @Published public var deliveryType = "口播视频"
    @Published public var date = Date()
    @Published public var name = ""
    @Published public var contact = ""
    @Published public var agreeContact = false

    // State
    @Published public private(set) var state: PublishState = .idle
    @Published public private(set) var validationErrors: [String: String] = [:]

    private let accountAPI: AccountAPIProtocol
    /// 取当前会话 token。发布必须归属到账户，所以没有 token 就不发请求。
    private let accessToken: @MainActor () -> String?
    private var currentTask: Task<Void, Never>? = nil

    public init(
        accountAPI: AccountAPIProtocol,
        accessToken: @escaping @MainActor () -> String?
    ) {
        self.accountAPI = accountAPI
        self.accessToken = accessToken
    }

    private var formattedDeadlineText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    private var mappedDeliveryType: DeliveryType {
        switch deliveryType {
        case "口播视频":
            return .spokenVideo
        case "景色配音":
            return .sceneryVoiceover
        case "手写卡片":
            return .handwrittenCard
        default:
            return DeliveryType(rawValue: "spoken_video")
        }
    }

    public func validate() -> Bool {
        validationErrors.removeAll()

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.count < 1 || trimmedName.count > 30 {
            validationErrors["requesterName"] = "称呼必须为1-30个字符"
        }

        let trimmedContact = contact.trimmingCharacters(in: .whitespaces)
        if trimmedContact.count < 3 || trimmedContact.count > 80 {
            validationErrors["contact"] = "联系方式必须为3-80个字符"
        }

        let trimmedCity = city.trimmingCharacters(in: .whitespaces)
        if trimmedCity.count < 2 || trimmedCity.count > 24 {
            validationErrors["city"] = "城市名称必须为2-24个字符"
        }

        let trimmedLandmark = landmark.trimmingCharacters(in: .whitespaces)
        if trimmedLandmark.count < 2 || trimmedLandmark.count > 40 {
            validationErrors["landmark"] = "地标名称必须为2-40个字符"
        }

        let trimmedOccasion = scene.trimmingCharacters(in: .whitespaces)
        if trimmedOccasion.count < 2 || trimmedOccasion.count > 24 {
            validationErrors["occasion"] = "心愿场景必须为2-24个字符"
        }

        let trimmedMessage = words.trimmingCharacters(in: .whitespaces)
        if trimmedMessage.count < 5 || trimmedMessage.count > 120 {
            validationErrors["message"] = "心愿正文必须为5-120个字符"
        }

        let deadline = formattedDeadlineText
        if deadline.count < 2 || deadline.count > 40 {
            validationErrors["deadlineText"] = "期望时间格式不正确"
        }

        if !agreeContact {
            validationErrors["contactConsent"] = "您必须同意公开心愿且已知晓联系方式使用规则"
        }

        return validationErrors.isEmpty
    }

    public func submitWish() async {
        guard state != .submitting else { return }

        guard validate() else {
            state = .failed("输入校验未通过，请检查红字提示")
            return
        }

        // 发布必须归属到账户，否则换设备后本人无法找回记录。
        // 此时草稿完整保留，登录后再点一次提交即可。
        guard let token = accessToken() else {
            state = .requiresSignIn
            return
        }

        state = .submitting

        let request = CreateWishRequest(
            requesterName: name.trimmingCharacters(in: .whitespaces),
            contact: contact.trimmingCharacters(in: .whitespaces),
            city: city.trimmingCharacters(in: .whitespaces),
            landmark: landmark.trimmingCharacters(in: .whitespaces),
            occasion: scene.trimmingCharacters(in: .whitespaces),
            message: words.trimmingCharacters(in: .whitespaces),
            deliveryType: mappedDeliveryType,
            deadlineText: formattedDeadlineText,
            // App 内不涉及任何金额。服务端契约仍要求该字段，固定传 0，
            // 表示本次发布不申报任何金额，避免在客户端留下支付相关的表达空间。
            rewardFen: 0,
            contactConsent: agreeContact
        )

        let task = Task {
            do {
                let result = try await accountAPI.createAccountWish(request: request, token: token)
                guard !Task.isCancelled else {
                    self.state = .idle
                    return
                }

                self.state = .success(publicCode: result.wish.publicCode)
            } catch {
                // If task is cancelled, revert state back to .idle so user can retry
                if error is CancellationError {
                    self.state = .idle
                    return
                }
                if let apiErr = error as? GratiaAPIError, case .requestCancelled = apiErr {
                    self.state = .idle
                    return
                }

                guard !Task.isCancelled else {
                    self.state = .idle
                    return
                }

                if let apiErr = error as? GratiaAPIError, case .unauthorized = apiErr {
                    // 会话在提交途中失效：保留草稿并回到登录引导，不报成通用失败。
                    self.state = .requiresSignIn
                } else if let apiErr = error as? GratiaAPIError, case .badRequest(let message, let fields) = apiErr {
                    if let fields = fields {
                        self.validationErrors = fields
                    }
                    self.state = .failed(message)
                } else if let apiErr = error as? GratiaAPIError {
                    self.state = .failed(apiErr.errorDescription ?? "提交失败，请重试。")
                } else {
                    self.state = .failed("提交失败，请重试。")
                }
            }
        }

        currentTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    public func resetForm() {
        currentTask?.cancel()
        currentTask = nil
        scene = "生日祝福"
        city = "杭州"
        landmark = ""
        words = ""
        deliveryType = "口播视频"
        date = Date()
        name = ""
        contact = ""
        agreeContact = false
        state = .idle
        validationErrors.removeAll()
    }
}

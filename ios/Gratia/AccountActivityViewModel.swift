import Foundation
import GratiaCore

/// "我发布的 / 我帮助的"的真实数据源。
/// 只在已登录时请求；未登录不发请求，直接引导登录。
@MainActor
final class AccountActivityViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(AccountActivityDTO)
        case failed(String)
        case requiresSignIn

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.requiresSignIn, .requiresSignIn):
                return true
            case (.failed(let left), .failed(let right)):
                return left == right
            case (.loaded(let left), .loaded(let right)):
                return left.requests == right.requests && left.responses == right.responses
            default:
                return false
            }
        }
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var confirmingWishId: String?

    private let accountAPI: AccountAPIProtocol
    private let accessToken: @MainActor () -> String?
    private var loadTask: Task<Void, Never>?

    init(accountAPI: AccountAPIProtocol, accessToken: @escaping @MainActor () -> String?) {
        self.accountAPI = accountAPI
        self.accessToken = accessToken
    }

    func load() {
        loadTask?.cancel()

        #if DEBUG
        // 截图与版式验证用；Release 不编译这段，线上只显示服务端返回的真实记录。
        if DemoContent.isEnabled, let demo = DemoContent.activity {
            state = .loaded(demo)
            return
        }
        #endif

        guard let token = accessToken() else {
            state = .requiresSignIn
            return
        }

        state = .loading
        loadTask = Task {
            do {
                let activity = try await accountAPI.accountActivity(token: token)
                guard !Task.isCancelled else { return }
                state = .loaded(activity)
            } catch is CancellationError {
                return
            } catch GratiaAPIError.requestCancelled {
                return
            } catch GratiaAPIError.unauthorized {
                state = .requiresSignIn
            } catch let error as GratiaAPIError {
                state = .failed(error.errorDescription ?? "加载失败，请稍后再试。")
            } catch {
                state = .failed("加载失败，请稍后再试。")
            }
        }
    }

    func cancelLoad() {
        loadTask?.cancel()
        loadTask = nil
    }

    /// 发布者确认心愿已完成。成功后重新拉取列表，保证状态与服务端一致。
    func confirmCompletion(wishId: String) async {
        guard confirmingWishId == nil else { return }
        guard let token = accessToken() else {
            state = .requiresSignIn
            return
        }

        confirmingWishId = wishId
        defer { confirmingWishId = nil }

        do {
            _ = try await accountAPI.confirmWishCompletion(wishId: wishId, token: token)
            load()
        } catch GratiaAPIError.unauthorized {
            state = .requiresSignIn
        } catch let error as GratiaAPIError {
            state = .failed(error.errorDescription ?? "确认失败，请稍后再试。")
        } catch {
            state = .failed("确认失败，请稍后再试。")
        }
    }

    var requests: [AccountWishDTO] {
        if case .loaded(let activity) = state { return activity.requests }
        return []
    }

    var responses: [AccountResponseDTO] {
        if case .loaded(let activity) = state { return activity.responses }
        return []
    }
}

/// 状态筛选与服务端 `WishStatus` 的映射。
/// 未知状态归入"进行中"，避免新状态在旧客户端里凭空消失。
enum ActivityStatusFilter: String, CaseIterable {
    case waiting = "等待回应"
    case active = "进行中"
    case done = "已完成"

    func matches(_ status: WishStatus) -> Bool {
        switch self {
        case .waiting:
            return status == .pendingReview || status == .matching
        case .done:
            return status == .completed || status == .rejected || status == .cancelled
        case .active:
            return !ActivityStatusFilter.waiting.matches(status) && !ActivityStatusFilter.done.matches(status)
        }
    }
}

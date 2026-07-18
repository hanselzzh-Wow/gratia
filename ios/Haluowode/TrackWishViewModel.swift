import SwiftUI
import HaluowodeCore

public enum TrackState: Sendable, Equatable {
    case idle
    case loading
    case loaded(TrackedWishDTO)
    case failed(String)
}

@MainActor
public final class TrackWishViewModel: ObservableObject {
    // Input Fields
    @Published public var publicCode = ""
    @Published public var contact = ""

    // States
    @Published public private(set) var state: TrackState = .idle
    @Published public private(set) var validationErrors: [String: String] = [:]

    private let apiClient: WishAPIProtocol
    private var currentTask: Task<Void, Never>? = nil

    public init(apiClient: WishAPIProtocol) {
        self.apiClient = apiClient
    }

    public func validate() -> Bool {
        validationErrors.removeAll()

        let trimmedCode = publicCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.count < 8 || trimmedCode.count > 24 {
            validationErrors["publicCode"] = "编号必须为8-24个字符"
        }

        let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedContact.count < 3 || trimmedContact.count > 80 {
            validationErrors["contact"] = "联系方式必须为3-80个字符"
        }

        return validationErrors.isEmpty
    }

    public func trackWish() async {
        guard state != .loading else { return }

        guard validate() else {
            state = .failed("输入校验未通过，请检查提示")
            return
        }

        state = .loading

        let trimmedCode = publicCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)

        let request = TrackWishRequest(
            publicCode: trimmedCode,
            contact: trimmedContact
        )

        let task = Task {
            do {
                let wish = try await apiClient.trackWish(request: request)
                guard !Task.isCancelled else {
                    self.state = .idle
                    return
                }

                // Privacy: contact is cleared from memory as soon as request succeeds!
                self.contact = ""

                self.state = .loaded(wish)
            } catch {
                if error is CancellationError {
                    self.state = .idle
                    return
                }
                if let apiErr = error as? HaluowodeAPIError, case .requestCancelled = apiErr {
                    self.state = .idle
                    return
                }

                guard !Task.isCancelled else {
                    self.state = .idle
                    return
                }

                if let apiErr = error as? HaluowodeAPIError {
                    switch apiErr {
                    case .notFound:
                        self.state = .failed("请检查编号和联系方式")
                    case .badRequest(let message, let fields):
                        if let fields = fields {
                            self.validationErrors = fields
                        }
                        self.state = .failed(message)
                    default:
                        self.state = .failed(apiErr.errorDescription ?? "查询失败，请重试。")
                    }
                } else {
                    self.state = .failed("查询失败，请重试。")
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

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        if case .loading = state {
            state = .idle
        }
    }

    public func resetQuery() {
        currentTask?.cancel()
        currentTask = nil
        publicCode = ""
        contact = ""
        state = .idle
        validationErrors.removeAll()
    }
}

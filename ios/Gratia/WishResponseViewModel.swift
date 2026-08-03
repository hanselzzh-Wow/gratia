import SwiftUI
import GratiaCore

public enum ResponseState: Sendable, Equatable {
    case idle
    case submitting
    case success
    case failed(String)
}

@MainActor
public final class WishResponseViewModel: ObservableObject {
    // Inputs (Draft Fields)
    @Published var name = ""
    @Published var contact = ""
    @Published var note = ""
    @Published var agreeContact = false

    // States
    @Published public private(set) var state: ResponseState = .idle
    @Published public private(set) var validationErrors: [String: String] = [:]

    private let wishId: String
    private let apiClient: WishAPIProtocol
    private var currentTask: Task<Void, Never>? = nil

    public init(wishId: String, apiClient: WishAPIProtocol) {
        self.wishId = wishId
        self.apiClient = apiClient
    }

    public func validate() -> Bool {
        validationErrors.removeAll()

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.count < 1 || trimmedName.count > 30 {
            validationErrors["responderName"] = "称呼必须为1-30个字符"
        }

        let trimmedContact = contact.trimmingCharacters(in: .whitespaces)
        if trimmedContact.count < 3 || trimmedContact.count > 80 {
            validationErrors["responderContact"] = "联系方式必须为3-80个字符"
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNote.count > 160 {
            validationErrors["note"] = "说明最多160个字符"
        }

        if !agreeContact {
            validationErrors["contactConsent"] = "您必须同意平台运营人员与您联系确认匹配事宜"
        }

        return validationErrors.isEmpty
    }

    public func submitResponse() async {
        guard state != .submitting else { return }

        guard validate() else {
            state = .failed("输入校验未通过，请检查提示")
            return
        }

        state = .submitting

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteValue = trimmedNote.isEmpty ? nil : trimmedNote

        let request = CreateWishResponseRequest(
            responderName: name.trimmingCharacters(in: .whitespaces),
            responderContact: contact.trimmingCharacters(in: .whitespaces),
            note: noteValue,
            contactConsent: agreeContact
        )

        let task = Task {
            do {
                _ = try await apiClient.createWishResponse(wishId: wishId, request: request)
                guard !Task.isCancelled else {
                    self.state = .idle
                    return
                }

                self.state = .success
            } catch {
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

                if let apiErr = error as? GratiaAPIError, case .badRequest(let message, let fields) = apiErr {
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

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        if state == .submitting {
            state = .idle
        }
    }

    public func resetForm() {
        currentTask?.cancel()
        currentTask = nil
        name = ""
        contact = ""
        note = ""
        agreeContact = false
        state = .idle
        validationErrors.removeAll()
    }
}

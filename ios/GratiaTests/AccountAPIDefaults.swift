import Foundation
import GratiaCore

/// 测试目标内的协议默认实现。
///
/// `AccountAPIProtocol` 随直连闭环（会话、选人、交付、公开）扩展了多个方法，
/// 但各测试的 Mock 只关心自己那一两个。这里给其余方法一个统一的默认实现，
/// 让 Mock 不必逐个补空壳；同时默认实现一律抛错而不是静默返回空值——
/// 若某个测试意外走到未桩化的路径，会立刻失败而不是悄悄通过。
extension AccountAPIProtocol {
    private func unimplemented(_ function: String = #function) -> Error {
        GratiaAPIError.serverError(message: "测试 Mock 未实现 \(function)")
    }

    public func conversations(token: String) async throws -> [ConversationSummaryDTO] {
        throw unimplemented()
    }

    public func conversationMessages(responseId: String, token: String) async throws -> ConversationDTO {
        throw unimplemented()
    }

    public func sendMessage(responseId: String, body: String, token: String) async throws -> ChatMessageDTO {
        throw unimplemented()
    }

    public func wishResponses(wishId: String, token: String) async throws -> [OwnerResponseDTO] {
        throw unimplemented()
    }

    public func selectResponder(wishId: String, responseId: String, token: String) async throws {
        throw unimplemented()
    }

    public func reportAbuse(responseId: String, reason: String, detail: String?, token: String) async throws {
        throw unimplemented()
    }

    public func blockCounterpart(responseId: String, token: String) async throws {
        throw unimplemented()
    }

    public func unblockCounterpart(responseId: String, token: String) async throws {
        throw unimplemented()
    }

    public func publishStory(wishId: String, nickname: String?, token: String) async throws {
        throw unimplemented()
    }

    public func stories() async throws -> [StoryDTO] {
        throw unimplemented()
    }

    public func uploadDelivery(
        wishId: String,
        note: String,
        files: [(data: Data, filename: String, contentType: String)],
        token: String
    ) async throws {
        throw unimplemented()
    }

    public func profile(token: String) async throws -> UserProfileDTO {
        throw unimplemented()
    }

    public func updateProfile(displayName: String?, avatar: Data?, token: String) async throws -> UserProfileDTO {
        throw unimplemented()
    }

    public func registerDeviceToken(_ token: String, environment: String, accountToken: String) async throws {
        throw unimplemented()
    }

    public func removeDeviceTokens(accountToken: String) async throws {
        throw unimplemented()
    }
}

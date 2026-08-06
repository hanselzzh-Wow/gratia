import Foundation

public protocol WishAPIProtocol: Sendable {
    func listWishes(city: String?) async throws -> [PublicWishDTO]
    func createWish(request: CreateWishRequest) async throws -> CreateWishResult
    func createWishResponse(wishId: String, request: CreateWishResponseRequest) async throws -> CreateWishResponseResult
    func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO
}

public final class WishAPIClient: WishAPIProtocol {
    private let baseURL: URL
    private let transport: HTTPTransport

    public init(baseURL: URL = URL(string: "https://haluowode-mvp.hanselzzh.workers.dev")!, transport: HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    private func executeRequest<T: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        bearerToken: String? = nil
    ) async throws -> T {
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        let url = urlComponents.url!
        var headers = ["accept": "application/json"]
        if body != nil {
            headers["content-type"] = "application/json"
        }
        if let bearerToken, !bearerToken.isEmpty {
            headers["authorization"] = "Bearer \(bearerToken)"
        }

        let request = HTTPRequest(method: method, url: url, headers: headers, body: body)
        let response = try await transport.send(request: request)

        return try parseResponse(response)
    }

    private func parseResponse<T: Decodable>(_ response: HTTPResponse) throws -> T {
        if response.statusCode >= 200 && response.statusCode < 300 {
            do {
                return try JSONDecoder().decode(T.self, from: response.data)
            } catch {
                throw GratiaAPIError.decodingError(error)
            }
        } else {
            let payload = try? JSONDecoder().decode(APIErrorPayload.self, from: response.data)
            let message = payload?.error ?? "服务器出错"

            switch response.statusCode {
            case 400:
                throw GratiaAPIError.badRequest(message: message, fields: payload?.fields)
            case 401:
                throw GratiaAPIError.unauthorized(message: message)
            case 403:
                throw GratiaAPIError.forbidden(message: message)
            case 404:
                throw GratiaAPIError.notFound(message: message)
            case 409:
                throw GratiaAPIError.conflict(message: message)
            case 429:
                var retrySeconds = 0
                if let retryAfterHeader = response.headers["retry-after"],
                   let seconds = Int(retryAfterHeader.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    retrySeconds = seconds
                }
                throw GratiaAPIError.rateLimited(retryAfterSeconds: retrySeconds)
            default:
                throw GratiaAPIError.serverError(message: message)
            }
        }
    }

    // MARK: - WishAPIProtocol Implementation

    public func listWishes(city: String?) async throws -> [PublicWishDTO] {
        var queryItems: [URLQueryItem] = []
        if let city = city, !city.isEmpty && city != "全国" && city != "全部" {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }

        struct WishesEnvelope: Codable {
            let wishes: [PublicWishDTO]
        }

        let envelope: WishesEnvelope = try await executeRequest(
            method: "GET",
            path: "/api/wishes",
            queryItems: queryItems
        )
        return envelope.wishes
    }

    public func createWish(request: CreateWishRequest) async throws -> CreateWishResult {
        let body = try JSONEncoder().encode(request)
        return try await executeRequest(
            method: "POST",
            path: "/api/wishes",
            body: body
        )
    }

    public func createWishResponse(wishId: String, request: CreateWishResponseRequest) async throws -> CreateWishResponseResult {
        let body = try JSONEncoder().encode(request)
        return try await executeRequest(
            method: "POST",
            path: "/api/wishes/\(wishId)/responses",
            body: body
        )
    }

    public func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO {
        let body = try JSONEncoder().encode(request)
        let envelope: TrackWishEnvelope = try await executeRequest(
            method: "POST",
            path: "/api/wishes/track",
            body: body
        )
        return envelope.wish
    }
}

// MARK: - 账户

extension WishAPIClient: AuthAPIProtocol {
    public func signInWithApple(request: AppleSignInRequest) async throws -> AccountSession {
        let body = try JSONEncoder().encode(request)
        return try await executeRequest(method: "POST", path: "/api/auth/apple", body: body)
    }

    public func currentUser(token: String) async throws -> AccountUser {
        let envelope: CurrentUserEnvelope = try await executeRequest(
            method: "GET",
            path: "/api/me",
            bearerToken: token
        )
        return envelope.user
    }

    public func deleteAccount(token: String) async throws -> DeleteAccountResult {
        try await executeRequest(method: "DELETE", path: "/api/me", bearerToken: token)
    }
}

extension WishAPIClient: AccountAPIProtocol {
    public func createAccountWish(request: CreateWishRequest, token: String) async throws -> CreateWishResult {
        let body = try JSONEncoder().encode(request)
        return try await executeRequest(
            method: "POST",
            path: "/api/account/wishes",
            body: body,
            bearerToken: token
        )
    }

    public func createAccountWishResponse(
        wishId: String,
        request: CreateWishResponseRequest,
        token: String
    ) async throws -> CreateWishResponseResult {
        let body = try JSONEncoder().encode(request)
        return try await executeRequest(
            method: "POST",
            path: "/api/account/wishes/\(wishId)/responses",
            body: body,
            bearerToken: token
        )
    }

    public func accountActivity(token: String) async throws -> AccountActivityDTO {
        try await executeRequest(method: "GET", path: "/api/account/wishes", bearerToken: token)
    }

    public func confirmWishCompletion(wishId: String, token: String) async throws -> AccountWishDTO {
        let envelope: CompleteWishEnvelope = try await executeRequest(
            method: "POST",
            path: "/api/account/wishes/\(wishId)/complete",
            bearerToken: token
        )
        return envelope.wish
    }

    // MARK: - 直连闭环

    private struct ConversationsEnvelope: Codable { let conversations: [ConversationSummaryDTO] }
    private struct ResponsesEnvelope: Codable { let responses: [OwnerResponseDTO] }
    private struct MessageEnvelope: Codable { let message: ChatMessageDTO }
    private struct StoriesEnvelope: Codable { let stories: [StoryDTO] }
    private struct DiscardedEnvelope: Codable {}

    public func conversations(token: String) async throws -> [ConversationSummaryDTO] {
        let envelope: ConversationsEnvelope = try await executeRequest(
            method: "GET", path: "/api/account/conversations", bearerToken: token
        )
        return envelope.conversations
    }

    public func conversationMessages(responseId: String, token: String) async throws -> ConversationDTO {
        try await executeRequest(
            method: "GET",
            path: "/api/account/conversations/\(responseId)/messages",
            bearerToken: token
        )
    }

    public func sendMessage(responseId: String, body: String, token: String) async throws -> ChatMessageDTO {
        let payload = try JSONSerialization.data(withJSONObject: ["body": body])
        let envelope: MessageEnvelope = try await executeRequest(
            method: "POST",
            path: "/api/account/conversations/\(responseId)/messages",
            body: payload,
            bearerToken: token
        )
        return envelope.message
    }

    public func wishResponses(wishId: String, token: String) async throws -> [OwnerResponseDTO] {
        let envelope: ResponsesEnvelope = try await executeRequest(
            method: "GET",
            path: "/api/account/wishes/\(wishId)/responses",
            bearerToken: token
        )
        return envelope.responses
    }

    public func selectResponder(wishId: String, responseId: String, token: String) async throws {
        let _: CompleteWishEnvelope = try await executeRequest(
            method: "POST",
            path: "/api/account/wishes/\(wishId)/responses/\(responseId)/select",
            bearerToken: token
        )
    }

    public func reportAbuse(responseId: String, reason: String, detail: String?, token: String) async throws {
        var object: [String: Any] = ["responseId": responseId, "reason": reason]
        if let detail, !detail.isEmpty { object["detail"] = detail }
        let payload = try JSONSerialization.data(withJSONObject: object)
        let _: DiscardedEnvelope = try await executeRequest(
            method: "POST", path: "/api/account/reports", body: payload, bearerToken: token
        )
    }

    public func blockCounterpart(responseId: String, token: String) async throws {
        let _: DiscardedEnvelope = try await executeRequest(
            method: "POST",
            path: "/api/account/conversations/\(responseId)/block",
            bearerToken: token
        )
    }

    public func publishStory(wishId: String, nickname: String?, token: String) async throws {
        let payload = try JSONSerialization.data(withJSONObject: ["nickname": nickname ?? ""])
        let _: DiscardedEnvelope = try await executeRequest(
            method: "POST",
            path: "/api/account/wishes/\(wishId)/story",
            body: payload,
            bearerToken: token
        )
    }

    public func stories() async throws -> [StoryDTO] {
        let envelope: StoriesEnvelope = try await executeRequest(method: "GET", path: "/api/stories")
        return envelope.stories
    }

    /// 帮助者提交交付：一段文字 + 最多 9 个图片/视频，multipart 直传。
    public func uploadDelivery(
        wishId: String,
        note: String,
        files: [(data: Data, filename: String, contentType: String)],
        token: String
    ) async throws {
        let boundary = "gratia-\(UUID().uuidString)"
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }

        if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"note\"\r\n\r\n")
            append("\(note)\r\n")
        }
        for file in files {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.filename)\"\r\n")
            append("Content-Type: \(file.contentType)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")

        let url = baseURL.appendingPathComponent("/api/account/wishes/\(wishId)/deliverable")
        let request = HTTPRequest(
            method: "POST",
            url: url,
            headers: [
                "accept": "application/json",
                "content-type": "multipart/form-data; boundary=\(boundary)",
                "authorization": "Bearer \(token)",
            ],
            body: body
        )
        let response = try await transport.send(request: request)
        let _: DiscardedEnvelope = try parseResponse(response)
    }
}

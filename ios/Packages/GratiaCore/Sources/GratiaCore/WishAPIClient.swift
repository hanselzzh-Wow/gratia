import Foundation

public protocol WishAPIProtocol: Sendable {
    func listWishes(city: String?) async throws -> [PublicWishDTO]
    func createWish(request: CreateWishRequest) async throws -> CreateWishResult
    func createWishResponse(wishId: String, request: CreateWishResponseRequest) async throws -> CreateWishResponseResult
    func trackWish(request: TrackWishRequest) async throws -> TrackedWishDTO
}

public final class WishAPIClient: WishAPIProtocol {
    /// 生产 API 地址。
    ///
    /// **不要改回 `*.workers.dev`。** 那是 Cloudflare 的共享测试子域，在中国大陆
    /// 被整体污染。国内直连（不挂代理）时全部 API 都连不上——不只是登录，
    /// 浏览、发布、私聊一起失效，App 等于一个空壳。
    ///
    /// `api.hanselzhang.com` 绑在同一个 Worker 上（Cloudflare Custom Domain，
    /// 证书自动签发），走正常 anycast IP，国内可达。它解决的是「连不上」而不是
    /// 「快」：Cloudflare 免费版在国内没有节点，走国际线路，延迟与丢包都不理想。
    /// 要快只能走 ICP 备案 + 境内服务器，那是另一件事。
    ///
    /// 旧的 workers.dev 地址没有删除，仍然指向同一个 Worker，出问题可随时对照。
    public static let productionBaseURL = URL(string: "https://api.hanselzhang.com")!

    private let baseURL: URL
    private let transport: HTTPTransport

    public init(baseURL: URL = WishAPIClient.productionBaseURL, transport: HTTPTransport = URLSessionTransport()) {
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

    private struct ConversationsEnvelope: Codable { let conversations: [ConversationSummaryDTO]; let totalUnread: Int? }
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

    /// 取消屏蔽：撤销的正是上面那次 POST，所以用 DELETE 同一路径。
    /// 只能撤销自己发起的那条——对方屏蔽了我，不该由我来解除。
    public func unblockCounterpart(responseId: String, token: String) async throws {
        let _: DiscardedEnvelope = try await executeRequest(
            method: "DELETE",
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

    public func profile(token: String) async throws -> UserProfileDTO {
        try await executeRequest(method: "GET", path: "/api/account/profile", bearerToken: token)
    }

    public func updateProfile(displayName: String?, avatar: Data?, token: String) async throws -> UserProfileDTO {
        // 有头像时走 multipart，否则用 JSON，避免为纯改名也构造表单
        guard let avatar else {
            let payload = try JSONSerialization.data(withJSONObject: ["displayName": displayName ?? ""])
            return try await executeRequest(
                method: "POST", path: "/api/account/profile", body: payload, bearerToken: token
            )
        }
        let boundary = "gratia-\(UUID().uuidString)"
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        if let displayName, !displayName.isEmpty {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"displayName\"\r\n\r\n")
            append("\(displayName)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(avatar)
        append("\r\n--\(boundary)--\r\n")

        let request = HTTPRequest(
            method: "POST",
            url: baseURL.appendingPathComponent("/api/account/profile"),
            headers: [
                "accept": "application/json",
                "content-type": "multipart/form-data; boundary=\(boundary)",
                "authorization": "Bearer \(token)",
            ],
            body: body
        )
        return try parseResponse(try await transport.send(request: request))
    }

    // MARK: - 推送

    public func registerDeviceToken(_ token: String, environment: String, accountToken: String) async throws {
        let payload = try JSONSerialization.data(
            withJSONObject: ["token": token, "environment": environment]
        )
        let _: DiscardedEnvelope = try await executeRequest(
            method: "POST",
            path: "/api/account/device-token",
            body: payload,
            bearerToken: accountToken
        )
    }

    public func removeDeviceTokens(accountToken: String) async throws {
        let _: DiscardedEnvelope = try await executeRequest(
            method: "DELETE",
            path: "/api/account/device-token",
            bearerToken: accountToken
        )
    }
}

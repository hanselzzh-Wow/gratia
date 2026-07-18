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
        body: Data? = nil
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

        let request = HTTPRequest(method: method, url: url, headers: headers, body: body)
        let response = try await transport.send(request: request)

        return try parseResponse(response)
    }

    private func parseResponse<T: Decodable>(_ response: HTTPResponse) throws -> T {
        if response.statusCode >= 200 && response.statusCode < 300 {
            do {
                return try JSONDecoder().decode(T.self, from: response.data)
            } catch {
                throw HaluowodeAPIError.decodingError(error)
            }
        } else {
            let payload = try? JSONDecoder().decode(APIErrorPayload.self, from: response.data)
            let message = payload?.error ?? "服务器出错"

            switch response.statusCode {
            case 400:
                throw HaluowodeAPIError.badRequest(message: message, fields: payload?.fields)
            case 401:
                throw HaluowodeAPIError.unauthorized(message: message)
            case 403:
                throw HaluowodeAPIError.forbidden(message: message)
            case 404:
                throw HaluowodeAPIError.notFound(message: message)
            case 409:
                throw HaluowodeAPIError.conflict(message: message)
            case 429:
                var retrySeconds = 0
                if let retryAfterHeader = response.headers["retry-after"],
                   let seconds = Int(retryAfterHeader.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    retrySeconds = seconds
                }
                throw HaluowodeAPIError.rateLimited(retryAfterSeconds: retrySeconds)
            default:
                throw HaluowodeAPIError.serverError(message: message)
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

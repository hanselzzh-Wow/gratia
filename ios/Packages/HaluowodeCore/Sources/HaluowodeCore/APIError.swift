import Foundation

public enum HaluowodeAPIError: Error, LocalizedError, Sendable {
    case networkError(Error)
    case badRequest(message: String, fields: [String: String]?)
    case unauthorized(message: String)
    case forbidden(message: String)
    case notFound(message: String)
    case conflict(message: String)
    case rateLimited(retryAfterSeconds: Int)
    case decodingError(Error)
    case serverError(message: String)
    case requestCancelled
    case unknown

    public var errorDescription: String? {
        switch self {
        case .networkError:
            return "网络连接失败，请检查网络设置。"
        case .badRequest(let message, _):
            return message
        case .unauthorized(let message):
            return message
        case .forbidden(let message):
            return message
        case .notFound(let message):
            return message
        case .conflict(let message):
            return message
        case .rateLimited(let retryAfterSeconds):
            return "请求过于频繁，请在 \(retryAfterSeconds) 秒后再试。"
        case .decodingError:
            return "数据解析出错，请稍后再试。"
        case .serverError(let message):
            return message
        case .requestCancelled:
            return "请求已取消。"
        case .unknown:
            return "发生了未知错误。"
        }
    }
}

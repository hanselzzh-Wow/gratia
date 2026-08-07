import Foundation

public enum GratiaAPIError: Error, LocalizedError, Sendable {
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

    /// 这些文案要走**主 App 的**翻译表。
    ///
    /// GratiaCore 是独立的 SwiftPM 包，`NSLocalizedString` 默认在包自己的
    /// bundle 里找 Localizable.strings——那里什么都没有，于是永远回落成中文，
    /// 而且不会有任何报错。显式指定 `bundle: .main` 才能查到 App 的表，
    /// 也让翻译集中在一处维护。
    private static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }

    public var errorDescription: String? {
        switch self {
        case .networkError:
            return Self.text("网络连接失败，请检查网络设置。")
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
            return String(format: Self.text("请求过于频繁，请在 %lld 秒后再试。"), retryAfterSeconds)
        case .decodingError:
            return Self.text("数据解析出错，请稍后再试。")
        case .serverError(let message):
            return message
        case .requestCancelled:
            return Self.text("请求已取消。")
        case .unknown:
            return Self.text("发生了未知错误。")
        }
    }
}

import Foundation

/// 本服务的账户标识。刻意不包含邮箱、姓名或任何 Apple 返回的个人资料：
/// Sign in with Apple 的 sub 只在服务端保存，客户端不需要也不存储它。
public struct AccountUser: Codable, Sendable, Equatable {
    public let id: String
    public let createdAt: Double

    public init(id: String, createdAt: Double) {
        self.id = id
        self.createdAt = createdAt
    }
}

/// 服务端签发的会话。token 只写入 Keychain，不进 UserDefaults、日志或错误文案。
public struct AccountSession: Codable, Sendable, Equatable {
    public let token: String
    public let expiresAt: Double
    public let user: AccountUser

    public init(token: String, expiresAt: Double, user: AccountUser) {
        self.token = token
        self.expiresAt = expiresAt
        self.user = user
    }

    public var expirationDate: Date {
        Date(timeIntervalSince1970: expiresAt / 1000)
    }

    public func isValid(at date: Date = Date()) -> Bool {
        expirationDate > date
    }
}

/// Sign in with Apple 的登录请求。
/// `rawNonce` 是客户端生成的原始随机串；请求 Apple 时提交的是它的 SHA-256，
/// 服务端据此校验回传的 identity token，防止重放。
public struct AppleSignInRequest: Codable, Sendable {
    public let identityToken: String
    public let rawNonce: String
    public let authorizationCode: String?

    public init(identityToken: String, rawNonce: String, authorizationCode: String?) {
        self.identityToken = identityToken
        self.rawNonce = rawNonce
        self.authorizationCode = authorizationCode
    }
}

public struct DeleteAccountResult: Codable, Sendable, Equatable {
    public let deletedAt: Double
    public let appleTokensRevoked: Bool?

    public init(deletedAt: Double, appleTokensRevoked: Bool?) {
        self.deletedAt = deletedAt
        self.appleTokensRevoked = appleTokensRevoked
    }
}

public struct CurrentUserEnvelope: Codable, Sendable {
    public let user: AccountUser
}

public protocol AuthAPIProtocol: Sendable {
    func signInWithApple(request: AppleSignInRequest) async throws -> AccountSession
    func currentUser(token: String) async throws -> AccountUser
    func deleteAccount(token: String) async throws -> DeleteAccountResult
}

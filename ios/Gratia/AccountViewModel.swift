import AuthenticationServices
import CryptoKit
import Foundation
import GratiaCore

/// 账户状态机。登录、退出与注销都在这里收敛，
/// View 不直接接触 token、Keychain 或 Apple 凭证。
@MainActor
final class AccountViewModel: ObservableObject {
    enum State: Equatable {
        case signedOut
        case signingIn
        case signedIn(AccountUser)
        case deleting
    }

    @Published private(set) var state: State = .signedOut
    @Published private(set) var errorMessage: String?

    private let authAPI: AuthAPIProtocol
    private let sessionStore: SessionStoring
    private var session: AccountSession?

    /// 当前请求用的 nonce 原文。每次发起登录都会重新生成，
    /// 只在本次登录往返中存在，不持久化。
    private var pendingRawNonce: String?

    init(authAPI: AuthAPIProtocol, sessionStore: SessionStoring = KeychainSessionStore()) {
        self.authAPI = authAPI
        self.sessionStore = sessionStore
        restoreSession()
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var isBusy: Bool {
        state == .signingIn || state == .deleting
    }

    /// 已登录时给业务请求使用的 token。未登录返回 nil，由调用方引导登录。
    var accessToken: String? {
        guard let session, session.isValid() else { return nil }
        return session.token
    }

    private func restoreSession() {
        guard let stored = sessionStore.load() else { return }
        session = stored
        state = .signedIn(stored.user)
    }

    // MARK: - Sign in with Apple

    /// 生成本次登录的 nonce，并返回要交给 Apple 的 SHA-256 值。
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let rawNonce = Self.randomNonce()
        pendingRawNonce = rawNonce
        request.requestedScopes = []
        request.nonce = Self.sha256(rawNonce)
    }

    func completeAppleSignIn(with result: Result<ASAuthorization, Error>) async {
        errorMessage = nil

        switch result {
        case .failure(let error):
            pendingRawNonce = nil
            // 用户主动取消不是错误，不打扰。
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                state = .signedOut
                return
            }
            state = .signedOut
            errorMessage = "Apple 登录未完成，请再试一次。"

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  let rawNonce = pendingRawNonce else {
                pendingRawNonce = nil
                state = .signedOut
                errorMessage = "Apple 登录未完成，请再试一次。"
                return
            }

            let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            pendingRawNonce = nil
            state = .signingIn

            do {
                let session = try await authAPI.signInWithApple(
                    request: AppleSignInRequest(
                        identityToken: identityToken,
                        rawNonce: rawNonce,
                        authorizationCode: authorizationCode
                    )
                )
                self.session = session
                sessionStore.save(session)
                state = .signedIn(session.user)
            } catch is CancellationError {
                state = .signedOut
            } catch let error as GratiaAPIError {
                state = .signedOut
                errorMessage = error.errorDescription
            } catch {
                state = .signedOut
                errorMessage = "登录失败，请稍后再试。"
            }
        }
    }

    // MARK: - 退出与注销

    /// 退出登录只清除本机会话，不影响服务端的心愿与帮助记录。
    func signOut() {
        // 先拿着还有效的 token 去注销推送令牌，再清会话。顺序反了的话
        // 请求发不出去，这台设备会继续收到下一个登录者的通知。
        let expiring = session?.token
        Task { await PushRegistrar.shared.unregister(accountToken: expiring) }
        session = nil
        sessionStore.clear()
        errorMessage = nil
        state = .signedOut
    }

    /// 删除账户：服务端会撤销全部会话、删除登录身份、并将订单中的
    /// 称呼与联系方式匿名化。这是 App Store 5.1.1(v) 要求的应用内注销。
    func deleteAccount() async -> Bool {
        guard let token = accessToken else {
            signOut()
            return true
        }
        errorMessage = nil
        state = .deleting

        do {
            _ = try await authAPI.deleteAccount(token: token)
            signOut()
            return true
        } catch GratiaAPIError.unauthorized, GratiaAPIError.notFound {
            // 会话已失效或账户已删除：本机同样清空，结果与用户预期一致。
            signOut()
            return true
        } catch let error as GratiaAPIError {
            state = session.map { .signedIn($0.user) } ?? .signedOut
            errorMessage = error.errorDescription
            return false
        } catch {
            state = session.map { .signedIn($0.user) } ?? .signedOut
            errorMessage = "注销失败，请稍后再试。"
            return false
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Nonce

    static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            bytes = (0..<length).map { _ in UInt8.random(in: UInt8.min...UInt8.max) }
        }
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

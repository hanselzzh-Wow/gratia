import Foundation
import Security
import GratiaCore

/// 会话持久化协议，便于在测试中替换真实 Keychain。
protocol SessionStoring: AnyObject {
    func load() -> AccountSession?
    func save(_ session: AccountSession)
    func clear()
}

/// 会话 token 只保存在 Keychain，且限定为 `ThisDeviceOnly`：
/// 不进 iCloud 钥匙串备份、不进 UserDefaults、不写日志、不进错误文案。
final class KeychainSessionStore: SessionStoring {
    private let service: String
    private let account = "account-session"

    init(service: String = "com.hanselzzh.gratia.session") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func load() -> AccountSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let session = try? JSONDecoder().decode(AccountSession.self, from: data) else {
            return nil
        }
        // 过期会话直接丢弃，避免带着无效 token 反复触发 401。
        guard session.isValid() else {
            clear()
            return nil
        }
        return session
    }

    func save(_ session: AccountSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        clear()
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// 仅用于 SwiftUI Preview 与单元测试的内存实现。
final class InMemorySessionStore: SessionStoring {
    private var session: AccountSession?

    init(session: AccountSession? = nil) {
        self.session = session
    }

    func load() -> AccountSession? { session }
    func save(_ session: AccountSession) { self.session = session }
    func clear() { session = nil }
}

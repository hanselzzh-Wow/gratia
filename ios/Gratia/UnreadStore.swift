import SwiftUI
import GratiaCore

/// 私聊未读数。放在共享对象里，因为 Dock 角标在 ContentView，
/// 而数据来源在私聊页——两者不在同一层级，靠回调传会很别扭。
///
/// 采用轮询而非推送：Worker 没有常驻连接，MVP 阶段轮询足够，
/// 且不需要 APNs 证书与后端推送服务。
@MainActor
final class UnreadStore: ObservableObject {
    @Published private(set) var total = 0

    private let accountAPI: AccountAPIProtocol
    private var task: Task<Void, Never>?

    init(accountAPI: AccountAPIProtocol) {
        self.accountAPI = accountAPI
    }

    func refresh(token: String?) async {
        guard let token else {
            total = 0
            return
        }
        // 复用会话列表接口，不额外增加一个只为角标存在的端点
        if let conversations = try? await accountAPI.conversations(token: token) {
            total = conversations.reduce(0) { $0 + ($1.unreadCount ?? 0) }
        }
    }

    /// 前台每 30 秒刷新一次。间隔取长一些：未读角标不是实时性要求高的信息，
    /// 频繁轮询只会白白消耗电量与请求配额。
    func startPolling(token: @escaping @MainActor () -> String?) {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(token: token())
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stopPolling() {
        task?.cancel()
        task = nil
    }
}

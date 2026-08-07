import Foundation
import GratiaCore
import UIKit
import UserNotifications

/// 推送的客户端一侧：申请授权、拿 APNs 令牌、上报给服务端、处理点击。
///
/// 做成单例而不是 `@StateObject`，是因为令牌由 `UIApplicationDelegate` 的回调
/// 送达——那个对象由 UIKit 实例化，够不到 SwiftUI 的对象图。两边都指向 `shared`
/// 是这里唯一不需要额外桥接层的写法。
@MainActor
final class PushRegistrar: ObservableObject {
    static let shared = PushRegistrar()

    enum Authorization: Equatable {
        case notDetermined
        case denied
        case authorized
    }

    @Published private(set) var authorization: Authorization = .notDetermined
    /// 用户点了通知要去哪。ContentView 消费后置回 nil。
    @Published var pendingTarget: String?

    private var accountAPI: AccountAPIProtocol?
    private var accessToken: (@MainActor () -> String?)?
    /// 最近一次拿到的 APNs 令牌。可能先于登录到达，所以要留着，
    /// 等登录后补报——否则「先允许通知、后登录」这条路径永远报不上去。
    private var latestDeviceToken: String?
    private var uploadedToken: String?

    private init() {}

    /// ContentView 启动时注入依赖。单例拿不到 SwiftUI 环境，只能反向注入。
    func configure(accountAPI: AccountAPIProtocol, accessToken: @escaping @MainActor () -> String?) {
        self.accountAPI = accountAPI
        self.accessToken = accessToken
    }

    // MARK: - 授权

    func refreshAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorization = Self.map(settings.authorizationStatus)
        // 已授权就再注册一次：令牌会随重装、恢复备份、系统升级变化，
        // 只在第一次授权时注册的话，换过令牌的设备会静默地再也收不到推送。
        if authorization == .authorized {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// 返回是否已获授权。用户在系统弹窗里点「不允许」时返回 false。
    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorization = granted ? .authorized : .denied
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        return granted
    }

    private static func map(_ status: UNAuthorizationStatus) -> Authorization {
        switch status {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        default: return .notDetermined
        }
    }

    // MARK: - 令牌

    func handleDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        guard token != latestDeviceToken || uploadedToken != token else { return }
        latestDeviceToken = token
        Task { await uploadIfPossible() }
    }

    /// 令牌与登录态齐了才上报。任一缺失就静默返回，等另一半到位时再由
    /// 调用方触发——推送是锦上添花，不该弹错误打断用户。
    func uploadIfPossible() async {
        guard let accountAPI,
              let token = latestDeviceToken,
              let accountToken = accessToken?(),
              token != uploadedToken else { return }
        do {
            try await accountAPI.registerDeviceToken(
                token,
                environment: Self.apnsEnvironment,
                accountToken: accountToken
            )
            uploadedToken = token
        } catch {
            // 下次进前台或下次登录会再试。不重试、不提示。
        }
    }

    /// 退出登录或注销账户时调用：不注销的话，通知会继续推到一台已经换人的设备上。
    ///
    /// token 由调用方显式传入，不走 `accessToken` 闭包——退出登录会先清掉会话，
    /// 等闭包再去取时已经是 nil，那样这个请求永远发不出去。
    func unregister(accountToken: String?) async {
        uploadedToken = nil
        guard let accountAPI, let accountToken else { return }
        try? await accountAPI.removeDeviceTokens(accountToken: accountToken)
    }

    // MARK: - 环境

    /// APNs 的 sandbox 与 production 是两套完全独立的令牌空间：把开发构建的
    /// 令牌发到生产网关，Apple 回 `BadDeviceToken`，推送静默丢失。
    ///
    /// 不用 `#if DEBUG` 判断——Xcode 的 Release 构建装到真机上用的仍是
    /// development 描述文件，那样会判错。改读包内描述文件里的 `aps-environment`，
    /// 这是唯一与实际签名一致的依据。
    static let apnsEnvironment: String = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              // 描述文件是 CMS 签名的二进制，里面裹着一段 plist。用 isoLatin1
              // 解码保证字节一一对应，不会因为非法 UTF-8 序列而整个失败。
              let text = String(data: data, encoding: .isoLatin1),
              let range = text.range(of: "<key>aps-environment</key>") else {
            // 模拟器没有这个文件，而模拟器本来就收不到真推送，返回什么都无所谓。
            return "sandbox"
        }
        let tail = text[range.upperBound...].prefix(120)
        return tail.contains("development") ? "sandbox" : "production"
    }()
}

/// 只为接推送回调而存在。SwiftUI 的 `App` 协议没有对应入口，
/// 必须借 `@UIApplicationDelegateAdaptor` 落到 UIKit。
final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in PushRegistrar.shared.handleDeviceToken(deviceToken) }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // 常见于模拟器与无网络。不提示：用户没有可执行的动作。
    }

    /// App 正在前台时也把横幅显示出来。不实现这个方法的话，前台收到的通知
    /// 会被系统直接吞掉——用户会以为推送坏了。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let target = response.notification.request.content.userInfo["target"] as? String
        await MainActor.run { PushRegistrar.shared.pendingTarget = target }
    }
}

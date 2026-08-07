import SwiftUI
import GratiaCore

struct WishAPIClientKey: EnvironmentKey {
    static let defaultValue: WishAPIProtocol = WishAPIClient()
}

struct AccountAPIClientKey: EnvironmentKey {
    static let defaultValue: AccountAPIProtocol = WishAPIClient()
}

extension EnvironmentValues {
    var wishAPIClient: WishAPIProtocol {
        get { self[WishAPIClientKey.self] }
        set { self[WishAPIClientKey.self] = newValue }
    }

    var accountAPIClient: AccountAPIProtocol {
        get { self[AccountAPIClientKey.self] }
        set { self[AccountAPIClientKey.self] = newValue }
    }
}

/// Dock：首页｜搜索｜发布（中央动作）｜帮助｜我的。
/// 图标只用图形不带文字；普通项黑/灰，仅中央"发布"使用玫红主题色。
/// "发布"不是栏目——点按打开发布 Sheet，随后回到原栏目。
struct ContentView: View {
    /// 五栏顺序：首页、帮助、中央发布、私聊、我的。
    /// 搜索不再独占一栏，改为首页右上角入口；私聊随直连闭环上升为一级页面。
    private enum Tab {
        static let home = 0
        static let help = 1
        static let publish = 2
        static let messages = 3
        static let profile = 4
    }

    @State private var selectedTab: Int
    @State private var previousTab: Int
    @State private var showPublish: Bool
    @StateObject private var viewModel: WishListViewModel
    @StateObject private var publishViewModel: PublishWishViewModel
    @StateObject private var accountViewModel: AccountViewModel
    @StateObject private var filterState = StoryFilterState()
    @StateObject private var unreadStore: UnreadStore
    @ObservedObject private var pushRegistrar = PushRegistrar.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var needsProfileSetup = false
    private let apiClient: WishAPIProtocol
    private let accountAPIClient: AccountAPIProtocol

    init() {
        let client = WishAPIClient()
        self.apiClient = client
        self.accountAPIClient = client
        let account = AccountViewModel(authAPI: client)
        _viewModel = StateObject(wrappedValue: WishListViewModel(apiClient: client))
        _accountViewModel = StateObject(wrappedValue: account)
        _unreadStore = StateObject(wrappedValue: UnreadStore(accountAPI: client))
        // 发布通过闭包读取当前会话，避免把 token 复制进表单 ViewModel 长期持有。
        _publishViewModel = StateObject(wrappedValue: PublishWishViewModel(
            accountAPI: client,
            accessToken: { [weak account] in account?.accessToken }
        ))

        // 截图/调试辅助：仅 DEBUG 构建支持用启动参数选择初始栏目。
        var initialTab = Tab.home
        var initialPublish = false
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--initial-tab"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "help": initialTab = Tab.help
            case "messages": initialTab = Tab.messages
            case "profile": initialTab = Tab.profile
            default: initialTab = Tab.home
            }
        }
        initialPublish = arguments.contains("--show-publish")
        #endif
        _selectedTab = State(initialValue: initialTab)
        _previousTab = State(initialValue: initialTab)
        _showPublish = State(initialValue: initialPublish)

        // 图标态色：普通项未选中浅灰、选中近黑；不整体染主题色。
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        let normalColor = UIColor(red: 169.0 / 255.0, green: 162.0 / 255.0, blue: 165.0 / 255.0, alpha: 1) // #A9A2A5
        let selectedColor = UIColor(red: 25.0 / 255.0, green: 23.0 / 255.0, blue: 25.0 / 255.0, alpha: 1) // #191719
        for itemAppearance in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.normal.iconColor = normalColor
            itemAppearance.selected.iconColor = selectedColor
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Dock 图标统一使用 Lucide（ISC 许可）模板资产；
            // 选中/未选中由 UITabBarAppearance 的近黑/浅灰区分，仅发布为玫红。
            HomeView(selectedTab: $selectedTab, showPublish: $showPublish)
                .tabItem {
                    Image("TabHouse")
                }
                .tag(Tab.home)
                .accessibilityLabel("首页")

            NearbyView()
                .tabItem {
                    Image("TabHandshake")
                }
                .tag(Tab.help)
                .accessibilityLabel("帮助")

            // 占位内容不会真正显示：选中即弹出发布 Sheet 并回到原栏目。
            Color.clear
                .tabItem {
                    Image("TabPublish")
                }
                .tag(Tab.publish)
                .accessibilityLabel("发布心愿")

            ConversationsView()
                .tabItem {
                    Image("TabMessage")
                }
                .badge(unreadStore.total)
                .tag(Tab.messages)
                .accessibilityLabel("私聊")

            ProfileView(selectedTab: $selectedTab)
                .tabItem {
                    Image("TabUserRound")
                }
                .tag(Tab.profile)
                .accessibilityLabel("我的")
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == Tab.publish {
                selectedTab = previousTab
                showPublish = true
            } else {
                previousTab = newValue
            }
        }
        .sheet(isPresented: $showPublish) {
            PublishView(viewModel: publishViewModel, selectedTab: $selectedTab)
                .environmentObject(accountViewModel)
        }
        .tint(DesignSystem.Rose.primary)
        .environmentObject(viewModel)
        .environmentObject(filterState)
        .environmentObject(accountViewModel)
        .environmentObject(unreadStore)
        // 未读角标随登录状态启停；退出登录后立即归零，不留旧数字。
        .task(id: accountViewModel.isSignedIn) {
            if accountViewModel.isSignedIn {
                unreadStore.startPolling { accountViewModel.accessToken }
                // 令牌可能在登录之前就拿到了（先允许通知、后登录）。
                // 这一次补报是那条路径唯一的上报时机。
                await pushRegistrar.uploadIfPossible()
                await checkProfileSetup()
            } else {
                unreadStore.stopPolling()
                needsProfileSetup = false
                await unreadStore.refresh(token: nil)
            }
        }
        // 首次设置不能跳过，所以用 fullScreenCover 而不是 sheet——
        // sheet 即使关掉了交互式下拉，顶部仍留着可下拉的观感。
        .fullScreenCover(isPresented: $needsProfileSetup) {
            ProfileSetupSheet { needsProfileSetup = false }
                .environmentObject(accountViewModel)
                .environment(\.accountAPIClient, accountAPIClient)
        }
        .task {
            pushRegistrar.configure(
                accountAPI: accountAPIClient,
                accessToken: { [weak accountViewModel] in accountViewModel?.accessToken }
            )
            await pushRegistrar.refreshAuthorization()
        }
        // 用户可能在系统设置里关掉通知再切回来，界面上的状态得跟上。
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await pushRegistrar.refreshAuthorization() }
        }
        // 点通知进来：1.0 只跳到对应栏目，不深入到具体会话或心愿详情——
        // 跨导航栈的深链需要每个页面都支持外部驱动的路由，那是另一件事。
        .onChange(of: pushRegistrar.pendingTarget) { target in
            guard let target else { return }
            if target.hasPrefix("conversation:") {
                selectedTab = Tab.messages
                previousTab = Tab.messages
            } else if target.hasPrefix("wish:") {
                selectedTab = Tab.profile
                previousTab = Tab.profile
            }
            pushRegistrar.pendingTarget = nil
        }
        .environment(\.wishAPIClient, apiClient)
        .environment(\.accountAPIClient, accountAPIClient)
    }
}

extension ContentView {
    /// 登录后判断要不要拉起首次设置。
    ///
    /// 以服务端的 `needsSetup` 为准，不看本地缓存：换设备登录的老用户早就设过，
    /// 缓存却是空的，照缓存判断会把他也拦一遍。取不到就不打扰——
    /// 网络不好不该变成一道进不去的墙。
    private func checkProfileSetup() async {
        guard let token = accountViewModel.accessToken else { return }
        guard let profile = try? await accountAPIClient.profile(token: token) else { return }
        ProfileCache.save(profile)
        needsProfileSetup = profile.needsSetup == true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

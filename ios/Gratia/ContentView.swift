import SwiftUI
import GratiaCore

struct WishAPIClientKey: EnvironmentKey {
    static let defaultValue: WishAPIProtocol = WishAPIClient()
}

extension EnvironmentValues {
    var wishAPIClient: WishAPIProtocol {
        get { self[WishAPIClientKey.self] }
        set { self[WishAPIClientKey.self] = newValue }
    }
}

/// Dock：首页｜搜索｜发布（中央动作）｜帮助｜我的。
/// 图标只用图形不带文字；普通项黑/灰，仅中央"发布"使用玫红主题色。
/// "发布"不是栏目——点按打开发布 Sheet，随后回到原栏目。
struct ContentView: View {
    private enum Tab {
        static let home = 0
        static let search = 1
        static let publish = 2
        static let help = 3
        static let profile = 4
    }

    @State private var selectedTab: Int
    @State private var previousTab: Int
    @State private var showPublish: Bool
    @StateObject private var viewModel: WishListViewModel
    @StateObject private var publishViewModel: PublishWishViewModel
    @StateObject private var filterState = StoryFilterState()
    private let apiClient: WishAPIProtocol

    init() {
        let client = WishAPIClient()
        self.apiClient = client
        _viewModel = StateObject(wrappedValue: WishListViewModel(apiClient: client))
        _publishViewModel = StateObject(wrappedValue: PublishWishViewModel(apiClient: client))

        // 截图/调试辅助：仅 DEBUG 构建支持用启动参数选择初始栏目。
        var initialTab = Tab.home
        var initialPublish = false
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--initial-tab"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "search": initialTab = Tab.search
            case "help": initialTab = Tab.help
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

            SearchView(selectedTab: $selectedTab)
                .tabItem {
                    Image("TabSearch")
                }
                .tag(Tab.search)
                .accessibilityLabel("搜索")

            // 占位内容不会真正显示：选中即弹出发布 Sheet 并回到原栏目。
            Color.clear
                .tabItem {
                    Image("TabPublish")
                }
                .tag(Tab.publish)
                .accessibilityLabel("发布心愿")

            NearbyView()
                .tabItem {
                    Image("TabHandshake")
                }
                .tag(Tab.help)
                .accessibilityLabel("帮助")

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
        }
        .tint(DesignSystem.Rose.primary)
        .environmentObject(viewModel)
        .environmentObject(filterState)
        .environment(\.wishAPIClient, apiClient)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

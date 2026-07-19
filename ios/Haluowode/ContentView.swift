import SwiftUI
import Combine
import HaluowodeCore

struct WishAPIClientKey: EnvironmentKey {
    static let defaultValue: WishAPIProtocol = WishAPIClient()
}

extension EnvironmentValues {
    var wishAPIClient: WishAPIProtocol {
        get { self[WishAPIClientKey.self] }
        set { self[WishAPIClientKey.self] = newValue }
    }
}

/// The four persistent pages. Publish is a global centre action, not a page.
enum AppTab: Int, CaseIterable, Identifiable {
    case home
    case search
    case help
    case profile

    var id: Int { rawValue }

    /// VoiceOver name; the dock itself renders icons only.
    var accessibilityName: String {
        switch self {
        case .home: return "首页"
        case .search: return "搜索"
        case .help: return "帮助"
        case .profile: return "我的"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .help: return "" // custom clasped-hands glyph
        case .profile: return "person"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .help: return ""
        case .profile: return "person.fill"
        }
    }
}

/// Fixed visual order of the dock: two pages, the centre action, two pages.
enum DockLayout {
    static let leadingTabs: [AppTab] = [.home, .search]
    static let trailingTabs: [AppTab] = [.help, .profile]
    static let publishAccessibilityName = "发布心愿"
}

/// Hides the dock while the keyboard is up, mirroring system tab-bar behaviour.
@MainActor
final class KeyboardObserver: ObservableObject {
    @Published var isKeyboardVisible = false
    private var cancellables: Set<AnyCancellable> = []

    init() {
        #if os(iOS)
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in false })
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in self?.isKeyboardVisible = visible }
            .store(in: &cancellables)
        #endif
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showPublish = false
    @StateObject private var viewModel: WishListViewModel
    @StateObject private var publishViewModel: PublishWishViewModel
    @StateObject private var keyboard = KeyboardObserver()
    private let apiClient: WishAPIProtocol

    init() {
        let client = WishAPIClient()
        self.apiClient = client
        _viewModel = StateObject(wrappedValue: WishListViewModel(apiClient: client))
        _publishViewModel = StateObject(wrappedValue: PublishWishViewModel(apiClient: client))
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                HomeView(
                    onPublishTap: { showPublish = true },
                    onExploreHelp: { selectedTab = .help }
                )
            case .search:
                SearchView()
            case .help:
                NearbyView()
            case .profile:
                ProfileView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboard.isKeyboardVisible {
                DockBar(selectedTab: $selectedTab) {
                    showPublish = true
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: keyboard.isKeyboardVisible)
        .fullScreenCover(isPresented: $showPublish) {
            PublishView(
                viewModel: publishViewModel,
                onClose: { showPublish = false },
                onViewProgress: {
                    showPublish = false
                    selectedTab = .profile
                },
                onGoHome: {
                    showPublish = false
                    selectedTab = .home
                }
            )
        }
        .tint(DesignSystem.rose)
        .environmentObject(viewModel)
        .environment(\.wishAPIClient, apiClient)
    }
}

/// Custom dock: icon-only pages in black/dark grey, centre publish in rose.
/// Solid white surface (no blur) keeps Reduce Transparency honest by default.
struct DockBar: View {
    @Binding var selectedTab: AppTab
    var onPublish: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 23
    @ScaledMetric(relativeTo: .body) private var publishSize: CGFloat = 52

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DockLayout.leadingTabs) { tab in
                tabButton(tab)
            }
            publishButton
            ForEach(DockLayout.trailingTabs) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, DesignSystem.spacing8)
        .padding(.bottom, DesignSystem.spacing4)
        .padding(.horizontal, DesignSystem.spacing8)
        .frame(maxWidth: .infinity)
        .background(
            DesignSystem.canvas
                .overlay(alignment: .top) {
                    Rectangle().fill(DesignSystem.roseHairline).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: DesignSystem.spacing4) {
                Group {
                    if tab == .help {
                        HandsClaspedGlyph(lineWidth: isSelected ? 2.2 : 1.8)
                            .frame(width: iconSize * 1.18, height: iconSize * 1.18)
                    } else {
                        Image(systemName: isSelected ? tab.selectedSymbol : tab.symbol)
                            .font(.system(size: iconSize, weight: isSelected ? .semibold : .regular))
                    }
                }
                .foregroundStyle(isSelected ? DesignSystem.inkPrimary : DesignSystem.inkMuted)

                Circle()
                    .fill(isSelected ? DesignSystem.inkPrimary : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var publishButton: some View {
        Button(action: onPublish) {
            ZStack {
                Circle()
                    .fill(DesignSystem.rose)
                    .frame(width: publishSize, height: publishSize)
                    .shadow(color: DesignSystem.roseDeep.opacity(0.28), radius: 8, y: 3)
                Image(systemName: "plus")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DockLayout.publishAccessibilityName)
        .accessibilityHint("打开发布心愿流程")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

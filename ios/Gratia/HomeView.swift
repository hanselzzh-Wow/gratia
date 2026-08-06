import SwiftUI
import GratiaCore

/// 首页 = 已授权公开的完成故事信息流（X 式文字优先）。
/// 不再承担心愿市场职责：完整浏览/搜索/响应在"搜索"与"帮助"。
struct HomeView: View {
    @Binding var selectedTab: Int
    @Binding var showPublish: Bool
    @EnvironmentObject private var filterState: StoryFilterState
    @Environment(\.accountAPIClient) private var accountAPI
    @State private var showComingSoon = false
    @StateObject private var feedViewModel: StoryFeedViewModel

    init(selectedTab: Binding<Int>, showPublish: Binding<Bool>, accountAPI: AccountAPIProtocol = WishAPIClient()) {
        _selectedTab = selectedTab
        _showPublish = showPublish
        _feedViewModel = StateObject(wrappedValue: StoryFeedViewModel(accountAPI: accountAPI))
    }

    /// 生产内容来自服务端已公开的故事；DEBUG 下的 --demo-stories 仍可注入
    /// 虚构演示数据用于截图，Release 构建取不到该分支。
    private var allStories: [StoryPost] {
        let demo = StoryFeedSource.stories
        return demo.isEmpty ? feedViewModel.posts : demo
    }
    private var visibleStories: [StoryPost] { allStories.filter(filterState.matches) }

    var body: some View {
        NavigationStack {
            Group {
                if allStories.isEmpty {
                    emptyState
                } else {
                    feed
                }
            }
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: DesignSystem.spacing8) {
                        BrandMark()
                            .frame(width: 26, height: 26)
                        Text("哈喽卧得")
                            .font(DesignSystem.headlineFont)
                            .foregroundStyle(DesignSystem.Rose.ink)
                            .fixedSize()
                    }
                    .accessibilityHidden(true)
                }
                // 搜索不再独占一栏，收进首页右上角。
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SearchView(selectedTab: $selectedTab)
                    } label: {
                        Image("TabSearch")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(DesignSystem.Rose.ink)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("搜索")
                }
            }
            .refreshable { await feedViewModel.load() }
            .task { await feedViewModel.load() }
            .motion(DesignSystem.Motion.content, value: feedViewModel.posts)
            .alert("功能准备中", isPresented: $showComingSoon) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("点赞与评论将在账户和真实计数就绪后开放，我们不会展示虚假的互动数据。")
            }
        }
    }

    // MARK: - 信息流

    private var feed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !filterState.tags.isEmpty {
                    activeFilters
                }
                if visibleStories.isEmpty {
                    noMatchState
                } else {
                    ForEach(visibleStories) { post in
                        StoryPostCard(post: post) {
                            showComingSoon = true
                        }
                    }
                }
            }
            .padding(.bottom, DesignSystem.spacing24)
        }
        .refreshable {
            // 故事流暂无后端数据源；接入真实已授权故事 API 后在此刷新。
        }
    }

    /// 从搜索应用的筛选条件：克制的可清除标签行。
    private var activeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.spacing8) {
                ForEach(filterState.tags, id: \.self) { tag in
                    Button {
                        filterState.remove(tag)
                    } label: {
                        HStack(spacing: DesignSystem.spacing4) {
                            Text(tag)
                                .font(DesignSystem.metadataFont.weight(.medium))
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(DesignSystem.Rose.deep)
                        .padding(.horizontal, DesignSystem.spacing12)
                        .frame(minHeight: 30)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Rose.tint)
                                .overlay(Capsule().stroke(DesignSystem.Rose.soft, lineWidth: 1))
                        )
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("清除筛选 \(tag)")
                }
                Button("全部清除") {
                    filterState.clear()
                }
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, DesignSystem.spacing16)
        }
        .padding(.vertical, DesignSystem.spacing4)
    }

    private var noMatchState: some View {
        VStack(spacing: DesignSystem.spacing12) {
            Text("没有匹配这些条件的公开故事")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
            Button("清除筛选，看全部故事") {
                filterState.clear()
            }
            .font(DesignSystem.bodyFont.weight(.semibold))
            .foregroundStyle(DesignSystem.Rose.deep)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DesignSystem.spacing40)
    }

    // MARK: - 诚实空态（生产构建无授权故事时）

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            Circle()
                .fill(DesignSystem.Rose.tint)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "text.book.closed")
                        .font(.title2.weight(.regular))
                        .foregroundStyle(DesignSystem.Rose.primary)
                )
                .accessibilityHidden(true)
            Text("还没有可公开的完成故事")
                .font(DesignSystem.titleFont)
                .foregroundStyle(DesignSystem.Rose.ink)
                .padding(.top, DesignSystem.spacing20)
            Text("故事需要发布者在心愿完成后单独同意公开。第一批经过确认的案例上线后，会在这里展示。")
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, DesignSystem.spacing8)
                .padding(.horizontal, DesignSystem.spacing32)
            VStack(spacing: DesignSystem.spacing12) {
                Button {
                    showPublish = true
                } label: {
                    Text("我也想发布心愿")
                        .font(DesignSystem.headlineFont)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .fill(DesignSystem.Rose.primary)
                        )
                }
                Button {
                    selectedTab = 1  // 帮助页
                } label: {
                    Text("去看看谁需要帮助")
                        .font(DesignSystem.headlineFont)
                        .foregroundStyle(DesignSystem.Rose.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                .fill(DesignSystem.Rose.canvas)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                                        .stroke(DesignSystem.Rose.line, lineWidth: 1)
                                )
                        )
                }
            }
            .padding(.horizontal, DesignSystem.spacing24)
            .padding(.top, DesignSystem.spacing32)
            Spacer()
            HStack(alignment: .top, spacing: DesignSystem.spacing8) {
                Image(systemName: "lock")
                    .font(.footnote)
                    .foregroundStyle(DesignSystem.Rose.ink3)
                Text("公开故事不显示联系方式与精确地点，随时可申请下架。")
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.Rose.ink2)
            }
            .padding(.bottom, DesignSystem.spacing24)
            .padding(.horizontal, DesignSystem.spacing24)
        }
    }
}

/// 品牌标志。图形**直接抠自桌面图标** `icon-marketing-1024.png`
/// （`Assets.xcassets/BrandMark.imageset`），所以它与桌面图标不是"照着画的"，
/// 而就是同一份图形，不存在走样的余地。
///
/// 之前这里是一段按实测参数重绘的 Canvas 代码，参数抄错了：描边宽写成 0.127
/// 而实际是 0.085，两端圆半径又写小了（大圆 0.069 vs 实际 0.108）。结果描边
/// 比端点圆还粗，把圆整个吞掉——在登录弹层那种 64pt 尺寸下，标记退化成一根
/// 均匀的斜杠，跟桌面图标完全不像。**别再改回参数重绘。**
struct BrandMark: View {
    var body: some View {
        Image("BrandMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(DesignSystem.Rose.deep)
    }
}


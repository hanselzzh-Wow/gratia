import SwiftUI

/// 搜索一级页：按地点/场景/内容形式/状态检索公开内容，
/// 结果沿用首页的故事流形式；筛选条件可应用到首页。
/// 只索引用户明确公开的昵称、正文、标签和城市级地点。
struct SearchView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var filterState: StoryFilterState
    @State private var query = ""
    @State private var selectedTags: Set<String> = []
    @State private var showComingSoon = false
    @FocusState private var searchFocused: Bool

    private enum Dimension: String, CaseIterable {
        case place = "地点"
        case scene = "场景"
        case format = "内容形式"
        case status = "状态"

        var options: [String] {
            switch self {
            case .place: ["上海", "成都", "杭州", "巴黎", "海边", "雪山"]
            case .scene: ["婚礼祝福", "生日祝福", "毕业", "旅行", "演唱会"]
            case .format: ["照片", "视频", "现场祝福", "替我看看"]
            case .status: ["精彩分享", "等待帮助"]
            }
        }
    }

    private var results: [StoryPost] {
        StoryFeedSource.stories.filter { post in
            post.matches(query: query) &&
                selectedTags.subtracting(["等待帮助"]).allSatisfy { post.tags.contains($0) }
        }
    }

    private var hasCriteria: Bool {
        !selectedTags.isEmpty || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    searchField
                    dimensionSections
                    if selectedTags.contains("等待帮助") {
                        waitingNotice
                    }
                    if hasCriteria {
                        applyToHome
                        resultsSection
                    }
                    safetyFootnote
                }
                .padding(.bottom, DesignSystem.spacing24)
            }
            .background(DesignSystem.Rose.canvas.ignoresSafeArea())
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .alert("功能准备中", isPresented: $showComingSoon) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("点赞与评论将在账户和真实计数就绪后开放，我们不会展示虚假的互动数据。")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: DesignSystem.spacing8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Rose.ink3)
            TextField("搜索城市、地标或场景，例如：巴黎 婚礼祝福", text: $query)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.Rose.ink)
                .focused($searchFocused)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignSystem.Rose.ink3)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("清空搜索词")
            }
        }
        .padding(.horizontal, DesignSystem.spacing12)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                .fill(DesignSystem.Rose.tint)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                        .stroke(searchFocused ? DesignSystem.Rose.primary : DesignSystem.Rose.line,
                                lineWidth: searchFocused ? 2 : 1)
                )
        )
        .padding(.horizontal, DesignSystem.spacing16)
        .padding(.top, DesignSystem.spacing8)
    }

    private var dimensionSections: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing16) {
            ForEach(Dimension.allCases, id: \.self) { dimension in
                VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                    Text(dimension.rawValue)
                        .font(DesignSystem.metadataFont.weight(.semibold))
                        .foregroundStyle(DesignSystem.Rose.ink2)
                    FlowChips(
                        options: dimension.options,
                        isSelected: { selectedTags.contains($0) },
                        toggle: { tag in
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, DesignSystem.spacing16)
        .padding(.top, DesignSystem.spacing20)
    }

    /// "等待帮助"不属于故事流：真实的待响应心愿在"帮助"标签浏览与响应。
    private var waitingNotice: some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing12) {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(DesignSystem.Rose.primary)
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text("等待帮助的心愿在「帮助」里浏览，可以按城市搜索并现场响应。")
                    .font(DesignSystem.metadataFont)
                    .foregroundStyle(DesignSystem.Rose.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("去帮助页看看") {
                    selectedTab = 3
                }
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(DesignSystem.Rose.deep)
                .frame(minHeight: 44)
            }
        }
        .padding(DesignSystem.spacing12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                .fill(DesignSystem.Rose.tint)
        )
        .padding(.horizontal, DesignSystem.spacing16)
        .padding(.top, DesignSystem.spacing16)
    }

    private var applyToHome: some View {
        Button {
            filterState.tags = Array(selectedTags.subtracting(["等待帮助"]))
            selectedTab = 0
        } label: {
            Text("将筛选应用到首页")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(DesignSystem.Rose.primary)
                )
        }
        .disabled(selectedTags.subtracting(["等待帮助"]).isEmpty)
        .opacity(selectedTags.subtracting(["等待帮助"]).isEmpty ? 0.45 : 1)
        .padding(.horizontal, DesignSystem.spacing16)
        .padding(.top, DesignSystem.spacing20)
        .accessibilityHint("回到首页并按所选条件筛选故事")
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(results.isEmpty ? "没有匹配的公开内容" : "公开内容")
                .font(DesignSystem.metadataFont.weight(.semibold))
                .foregroundStyle(DesignSystem.Rose.ink2)
                .padding(.horizontal, DesignSystem.spacing16)
                .padding(.top, DesignSystem.spacing24)
                .padding(.bottom, DesignSystem.spacing4)
            ForEach(results) { post in
                StoryPostCard(post: post) {
                    showComingSoon = true
                }
            }
        }
    }

    private var safetyFootnote: some View {
        HStack(alignment: .top, spacing: DesignSystem.spacing8) {
            Image(systemName: "lock")
                .font(.footnote)
                .foregroundStyle(DesignSystem.Rose.ink3)
            Text("搜索只覆盖用户明确公开的昵称、正文、标签和城市级地点；不索引私密内容、个人精确位置或联系方式。")
                .font(DesignSystem.captionFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DesignSystem.spacing16)
        .padding(.top, DesignSystem.spacing24)
    }
}

/// 简单的自动换行 chip 组。
private struct FlowChips: View {
    let options: [String]
    let isSelected: (String) -> Bool
    let toggle: (String) -> Void

    var body: some View {
        FlexibleWrap(spacing: DesignSystem.spacing8) {
            ForEach(options, id: \.self) { option in
                Button {
                    toggle(option)
                } label: {
                    Text(option)
                        .font(DesignSystem.metadataFont.weight(isSelected(option) ? .semibold : .regular))
                        .foregroundStyle(isSelected(option) ? DesignSystem.Rose.deep : DesignSystem.Rose.ink2)
                        .padding(.horizontal, DesignSystem.spacing12)
                        .frame(minHeight: 32)
                        .background(
                            Capsule()
                                .fill(isSelected(option) ? DesignSystem.Rose.tint : DesignSystem.Rose.canvas)
                                .overlay(
                                    Capsule().stroke(
                                        isSelected(option) ? DesignSystem.Rose.soft : DesignSystem.Rose.line,
                                        lineWidth: 1
                                    )
                                )
                        )
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityAddTraits(isSelected(option) ? [.isSelected] : [])
            }
        }
    }
}

/// iOS 16 兼容的换行布局。
private struct FlexibleWrap: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

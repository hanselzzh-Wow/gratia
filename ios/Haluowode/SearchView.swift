import SwiftUI

/// Pure filter state over public story fields only: keyword (title/excerpt/
/// landmark), city (city granularity at most), scene and delivery type.
/// Never indexes contacts, precise locations or private tracking data.
struct StoryFilter: Equatable {
    var keyword: String = ""
    var city: String?
    var scene: String?
    var delivery: String?

    struct Tag: Identifiable, Equatable {
        enum Kind: Equatable { case keyword, city, scene, delivery }
        let kind: Kind
        let text: String
        var id: String { text + String(describing: kind) }
    }

    var isActive: Bool {
        !trimmedKeyword.isEmpty || city != nil || scene != nil || delivery != nil
    }

    private var trimmedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Applied filters as clearable condition tags.
    var activeTags: [Tag] {
        var tags: [Tag] = []
        if !trimmedKeyword.isEmpty { tags.append(Tag(kind: .keyword, text: "“\(trimmedKeyword)”")) }
        if let city { tags.append(Tag(kind: .city, text: city)) }
        if let scene { tags.append(Tag(kind: .scene, text: scene)) }
        if let delivery { tags.append(Tag(kind: .delivery, text: delivery)) }
        return tags
    }

    mutating func clear(_ kind: Tag.Kind) {
        switch kind {
        case .keyword: keyword = ""
        case .city: city = nil
        case .scene: scene = nil
        case .delivery: delivery = nil
        }
    }

    mutating func clearAll() {
        self = StoryFilter()
    }

    func apply(to stories: [StoryFixture]) -> [StoryFixture] {
        stories.filter { story in
            let keywordOK = trimmedKeyword.isEmpty
                || story.title.localizedCaseInsensitiveContains(trimmedKeyword)
                || story.excerpt.localizedCaseInsensitiveContains(trimmedKeyword)
                || story.landmark.localizedCaseInsensitiveContains(trimmedKeyword)
            let cityOK = city == nil || story.city == city
            let sceneOK = scene == nil || story.scene == scene
            let deliveryOK = delivery == nil || story.delivery == delivery
            return keywordOK && cityOK && sceneOK && deliveryOK
        }
    }
}

/// Search over publicly-consented stories. There is no public-story API yet,
/// so the runtime `stories` list is empty and the page states that honestly;
/// Previews demonstrate the full filter behaviour on fictional fixtures.
struct SearchView: View {
    var stories: [StoryFixture] = []
    @State private var filter = StoryFilter()

    private let cityOptions = ["杭州", "上海", "北京", "深圳", "广州"]
    private let sceneOptions = ["生日祝福", "加油鼓励", "毕业祝福", "浪漫表白", "节日问候", "其他小心愿"]
    private let deliveryOptions = ["口播视频", "景色配音", "手写卡片"]

    private var results: [StoryFixture] {
        filter.apply(to: stories)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                filterMenus
                if filter.isActive {
                    activeTagRow
                }
                content
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .whiteCanvas()
        }
    }

    private var searchField: some View {
        HStack(spacing: DesignSystem.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignSystem.inkMuted)
                .accessibilityHidden(true)
            TextField("搜索公开故事、公共地标", text: $filter.keyword)
                .font(DesignSystem.bodyFont)
                .foregroundStyle(DesignSystem.inkPrimary)
                .submitLabel(.search)
            if !filter.keyword.isEmpty {
                Button {
                    filter.clear(.keyword)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignSystem.inkMuted)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("清除搜索词")
            }
        }
        .padding(.horizontal, DesignSystem.spacing12)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusSmall)
                .fill(DesignSystem.roseCanvas)
        )
        .padding(.horizontal, DesignSystem.spacing20)
        .padding(.vertical, DesignSystem.spacing12)
    }

    private var filterMenus: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.spacing8) {
                filterMenu(title: "城市", selection: filter.city, options: cityOptions) { filter.city = $0 }
                filterMenu(title: "主题", selection: filter.scene, options: sceneOptions) { filter.scene = $0 }
                filterMenu(title: "形式", selection: filter.delivery, options: deliveryOptions) { filter.delivery = $0 }
            }
            .padding(.horizontal, DesignSystem.spacing20)
        }
        .padding(.bottom, DesignSystem.spacing8)
    }

    private func filterMenu(
        title: String,
        selection: String?,
        options: [String],
        onSelect: @escaping (String?) -> Void
    ) -> some View {
        Menu {
            Button("不限") { onSelect(nil) }
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    if selection == option {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(spacing: DesignSystem.spacing4) {
                Text(selection ?? title)
                Image(systemName: "chevron.down")
                    .font(DesignSystem.captionFont.weight(.semibold))
            }
            .font(DesignSystem.metadataFont.weight(.semibold))
            .foregroundStyle(selection == nil ? DesignSystem.inkPrimary : DesignSystem.roseDeep)
            .padding(.horizontal, DesignSystem.spacing12)
            .frame(minHeight: 36)
            .background(
                Capsule()
                    .fill(selection == nil ? DesignSystem.canvas : DesignSystem.roseCanvas)
                    .overlay(
                        Capsule().stroke(
                            selection == nil ? DesignSystem.roseHairline : DesignSystem.roseSoft,
                            lineWidth: 1
                        )
                    )
            )
        }
        .accessibilityLabel("\(title)筛选，当前\(selection ?? "不限")")
    }

    private var activeTagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.spacing8) {
                ForEach(filter.activeTags) { tag in
                    Button {
                        filter.clear(tag.kind)
                    } label: {
                        HStack(spacing: DesignSystem.spacing4) {
                            Text(tag.text)
                            Image(systemName: "xmark")
                                .font(DesignSystem.captionFont.weight(.semibold))
                        }
                        .font(DesignSystem.captionFont.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.spacing12)
                        .frame(minHeight: 30)
                        .background(Capsule().fill(DesignSystem.rose))
                    }
                    .accessibilityLabel("清除筛选条件\(tag.text)")
                }
                Button("全部清除") {
                    filter.clearAll()
                }
                .font(DesignSystem.captionFont.weight(.semibold))
                .foregroundStyle(DesignSystem.roseDeep)
                .frame(minHeight: 30)
                .accessibilityLabel("清除全部筛选条件")
            }
            .padding(.horizontal, DesignSystem.spacing20)
        }
        .padding(.bottom, DesignSystem.spacing8)
    }

    @ViewBuilder
    private var content: some View {
        if stories.isEmpty {
            emptyRuntimeState
        } else if results.isEmpty {
            noMatchState
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: DesignSystem.spacing20) {
                    ForEach(results) { story in
                        StoryCard(story: story)
                    }
                }
                .padding(.horizontal, DesignSystem.spacing20)
                .padding(.vertical, DesignSystem.spacing8)
            }
        }
    }

    private var emptyRuntimeState: some View {
        VStack(spacing: DesignSystem.spacing12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DesignSystem.roseSoft)
                .accessibilityHidden(true)
            Text("暂时没有可搜索的公开内容")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.inkPrimary)
            Text("公开故事上线后，可以按城市、公共地标、主题和交付形式在这里找到它们。")
                .font(DesignSystem.metadataFont)
                .foregroundStyle(DesignSystem.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.spacing32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noMatchState: some View {
        VStack(spacing: DesignSystem.spacing12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(DesignSystem.roseSoft)
                .accessibilityHidden(true)
            Text("没有符合条件的公开故事")
                .font(DesignSystem.headlineFont)
                .foregroundStyle(DesignSystem.inkPrimary)
            Button("清除全部筛选条件") {
                filter.clearAll()
            }
            .font(DesignSystem.metadataFont.weight(.semibold))
            .foregroundStyle(DesignSystem.rose)
            .frame(minHeight: 44)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(stories: HomePreviewFixtures.searchStories)
            .previewDisplayName("搜索 · 虚构示例筛选")
        SearchView()
            .previewDisplayName("搜索 · 运行态诚实空态")
    }
}

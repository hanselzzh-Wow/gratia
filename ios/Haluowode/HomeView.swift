import SwiftUI
import HaluowodeCore

/// White, media-first feed of completed, publicly-consented stories.
/// There is no public-story API yet, so runtime always receives an empty
/// `stories` list and renders the honest empty state; only Previews and
/// tests pass `HomePreviewFixtures`.
struct HomeView: View {
    var stories: [StoryFixture] = []
    var onPublishTap: () -> Void = {}
    var onExploreHelp: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                if stories.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: DesignSystem.spacing20) {
                        ForEach(stories) { story in
                            StoryCard(story: story)
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacing20)
                    .padding(.vertical, DesignSystem.spacing16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("哈喽卧得")
                        .font(DesignSystem.headlineFont)
                        .foregroundStyle(DesignSystem.inkPrimary)
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onPublishTap) {
                        Text("许个愿")
                            .font(DesignSystem.metadataFont.weight(.semibold))
                            .foregroundStyle(DesignSystem.rose)
                            .padding(.horizontal, DesignSystem.spacing12)
                            .frame(minHeight: 32)
                            .background(
                                Capsule().stroke(DesignSystem.roseSoft, lineWidth: 1)
                            )
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("许个愿")
                    .accessibilityHint("打开发布心愿流程")
                }
            }
            .whiteCanvas()
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.spacing20) {
            ZStack {
                Circle()
                    .fill(DesignSystem.roseCanvas)
                    .frame(width: 112, height: 112)
                Circle()
                    .stroke(DesignSystem.roseSoft, lineWidth: 1)
                    .frame(width: 112, height: 112)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(DesignSystem.rose)
            }
            .accessibilityHidden(true)

            VStack(spacing: DesignSystem.spacing8) {
                Text("还没有可以公开的故事")
                    .font(DesignSystem.titleFont)
                    .foregroundStyle(DesignSystem.inkPrimary)
                Text("每一次心愿完成后，只有发布者单独同意公开，这里才会出现真实的故事。我们不会用任何虚构内容填充这里。")
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, DesignSystem.spacing32)

            VStack(spacing: DesignSystem.spacing12) {
                Button(action: onPublishTap) {
                    Text("发布一个心愿")
                        .font(DesignSystem.headlineFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.spacing24)
                        .frame(minHeight: 48)
                        .background(Capsule().fill(DesignSystem.rose))
                }
                .accessibilityHint("打开发布心愿流程")

                Button(action: onExploreHelp) {
                    Text("看看谁需要帮助")
                        .font(DesignSystem.metadataFont.weight(.semibold))
                        .foregroundStyle(DesignSystem.rose)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityHint("切换到帮助页面")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DesignSystem.spacing40 * 2)
        .padding(.bottom, DesignSystem.spacing40)
    }
}

/// Media-first story card shared by the home feed and search results.
struct StoryCard: View {
    let story: StoryFixture

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mediaBlock
            VStack(alignment: .leading, spacing: DesignSystem.spacing8) {
                Text(story.title)
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(DesignSystem.inkPrimary)
                Text(story.excerpt)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.inkMuted)
                    .lineSpacing(3)
                    .lineLimit(3)
                HStack(spacing: DesignSystem.spacing8) {
                    metaTag("\(story.city) · \(story.landmark)")
                    metaTag(story.scene)
                    Spacer(minLength: 0)
                }
                Divider().overlay(DesignSystem.roseHairline)
                HStack(spacing: DesignSystem.spacing16) {
                    Image(systemName: "heart")
                    Image(systemName: "bubble.right")
                    Spacer()
                    Text("发布者已同意公开")
                        .font(DesignSystem.captionFont)
                        .foregroundStyle(DesignSystem.inkMuted)
                }
                .font(.body.weight(.regular))
                .foregroundStyle(DesignSystem.inkMuted)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("互动功能即将开放；发布者已同意公开该故事")
            }
            .padding(DesignSystem.spacing16)
        }
        .roseCard()
        .accessibilityElement(children: .combine)
    }

    private var mediaBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                .fill(DesignSystem.roseCanvas)
            Circle()
                .fill(DesignSystem.roseSoft.opacity(0.55))
                .frame(width: 120, height: 120)
                .offset(x: 90, y: 34)
            Circle()
                .stroke(DesignSystem.roseSoft, lineWidth: 1)
                .frame(width: 72, height: 72)
                .offset(x: -104, y: -30)
            Image(systemName: story.mediaSymbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(DesignSystem.rose)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusLarge))
        .overlay(alignment: .topLeading) {
            if story.isFictionalSample {
                Text("虚构示例")
                    .font(DesignSystem.captionFont.weight(.semibold))
                    .foregroundStyle(DesignSystem.roseDeep)
                    .padding(.horizontal, DesignSystem.spacing8)
                    .frame(minHeight: 24)
                    .background(Capsule().fill(.white.opacity(0.9)))
                    .padding(DesignSystem.spacing8)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(story.delivery)
                .font(DesignSystem.captionFont.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DesignSystem.spacing8)
                .frame(minHeight: 24)
                .background(Capsule().fill(DesignSystem.rose))
                .padding(DesignSystem.spacing8)
        }
        .accessibilityHidden(true)
    }

    private func metaTag(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.captionFont.weight(.semibold))
            .foregroundStyle(DesignSystem.roseDeep)
            .padding(.horizontal, DesignSystem.spacing8)
            .frame(minHeight: 24)
            .background(Capsule().fill(DesignSystem.roseCanvas))
            .lineLimit(1)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(stories: HomePreviewFixtures.homeStories)
            .previewDisplayName("首页 · 虚构示例信息流")
        HomeView()
            .previewDisplayName("首页 · 运行态诚实空态")
    }
}

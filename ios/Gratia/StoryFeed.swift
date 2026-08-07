import SwiftUI

// MARK: - 公开故事模型

/// 首页与搜索共享的公开故事。生产构建在没有经单独授权的真实故事前必须显示诚实空态；
/// DEBUG 构建使用下方明确标注"虚构示例内容"的演示数据验证版式，绝不冒充真实用户分享。
struct StoryPost: Identifiable, Equatable {
    enum Media: Equatable {
        case none
        case photo
        case video
    }

    /// 演示数据的插画风格。**只有 DEBUG 的虚构示例会用**，真实故事一律为 nil、
    /// 走中性占位——真实交付影像不在这里渲染，也不该被插画替代。
    /// 用矢量插画而不是照片素材：画面不空，又不会被误认成真实用户拍的东西。
    enum Illustration: Equatable {
        case nightRiver     // 江边夜色
        case handwritten    // 手写卡片
    }

    let id: String
    /// 用户自选的公开昵称；未经授权不展示真实姓名。
    let nickname: String
    /// 城市级地点；不含精确位置。
    let city: String
    /// 模糊相对时间；不含精确时间戳。
    let timeText: String
    let paragraphs: [String]
    let media: Media
    let mediaNote: String
    /// 仅索引公开维度：城市、场景、内容形式、状态。
    let tags: [String]
    let isDemo: Bool
    /// 见 `Illustration`：仅演示数据使用，真实故事为 nil。
    var illustration: Illustration? = nil

    var avatarInitial: String { String(nickname.prefix(1)) }

    var shareText: String {
        "\(paragraphs.joined(separator: "\n"))\n—— 来自哈喽卧得的公开心愿故事"
    }

    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        // 只搜索公开字段：昵称、正文、标签、城市。
        if nickname.localizedCaseInsensitiveContains(trimmed) { return true }
        if city.localizedCaseInsensitiveContains(trimmed) { return true }
        if tags.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) { return true }
        return paragraphs.contains { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}

// MARK: - 首页筛选状态

/// 搜索页可以把筛选条件"应用到首页"；首页顶部以可清除标签展示。
@MainActor
final class StoryFilterState: ObservableObject {
    @Published var tags: [String] = []

    func remove(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    func clear() {
        tags = []
    }

    func matches(_ post: StoryPost) -> Bool {
        guard !tags.isEmpty else { return true }
        return tags.allSatisfy { post.tags.contains($0) }
    }
}

// MARK: - 数据源

enum StoryFeedSource {
    /// 生产构建没有授权故事时返回空数组 → 首页显示诚实空态。
    static var stories: [StoryPost] {
        #if DEBUG
        // 与「帮助」「私聊」两页共用同一个开关，见 DemoContent。
        if DemoContent.isEnabled { return demoStories }
        #endif
        return []
    }

    /// 虚构演示数据：人物、地点、事件均为编造，媒体为插画占位，不对应任何真实用户或订单。
    static let demoStories: [StoryPost] = [
        StoryPost(
            id: "demo-1",
            nickname: "晚风电台",
            city: "上海",
            timeText: "3 天前",
            paragraphs: [
                "她在国外过生日，我在上海加班，隔着六个时区什么也做不了。于是我许了个心愿：请一位恰好路过外滩的朋友，对着江面替我说一句\"生日快乐\"。",
                "三小时后，一位刚下班的陌生朋友接下了它，录了 30 秒的夜风、灯光和这句话。她看完哭了，说这是今年最意外的礼物。"
            ],
            media: .video,
            mediaNote: "现场录像 · 由附近的陌生朋友完成",
            tags: ["上海", "生日祝福", "视频", "现场祝福", "精彩分享"],
            isDemo: true,
            illustration: .nightRiver
        ),
        StoryPost(
            id: "demo-2",
            nickname: "桂花巷口",
            city: "成都",
            timeText: "2 周前",
            paragraphs: [
                "妹妹毕业典礼，我在外地赶不回去。心愿是请一位字好看的朋友，把我想说的话写成一张卡片，在典礼那天交到她手里。",
                "接下心愿的朋友不但字漂亮，还在角落画了一颗小爱心。妹妹说，这张卡片要裱起来。"
            ],
            media: .photo,
            mediaNote: "手写卡片 · 由附近的陌生朋友完成",
            tags: ["成都", "毕业", "照片", "精彩分享"],
            isDemo: true,
            illustration: .handwritten
        ),
        StoryPost(
            id: "demo-3",
            nickname: "南屏晚钟",
            city: "杭州",
            timeText: "1 个月前",
            paragraphs: [
                "爷爷生前最惦记老家巷口那棵桂花树。我许愿请一位路过的朋友替我去看看它今年开花没有。那位朋友在树下站了一会儿，告诉我：开了，很香，和爷爷说的一样。"
            ],
            media: .none,
            mediaNote: "到场看望 · 由附近的陌生朋友完成 · 应发布者要求不公开画面",
            tags: ["杭州", "替我看看", "精彩分享"],
            isDemo: true
        )
    ]
}

// MARK: - 故事卡片（X 式：左头像列 + 右内容列，文字在媒体之上）

struct StoryPostCard: View {
    let post: StoryPost
    /// 点赞/评论当前无账户与可信计数支撑，点击只提示"准备中"，绝不制造本地假成功。
    let onComingSoon: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 0) {
                nameRow
                storyText
                if post.media != .none {
                    mediaPlaceholder
                        .padding(.top, 10)
                }
                Text(post.mediaNote)
                    .font(DesignSystem.captionFont)
                    .foregroundStyle(DesignSystem.Rose.ink3)
                    .padding(.top, 8)
                actionRow
            }
        }
        .padding(.horizontal, DesignSystem.spacing16)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(DesignSystem.Rose.canvas)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(DesignSystem.Rose.line)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var avatar: some View {
        // 系统生成的首字母头像；上传真实头像需要单独公开授权。
        // 用昵称哈希出一对柔和的渐变色，让一列头像彼此可区分，
        // 而不是一排一模一样的色块。
        Circle()
            .fill(
                LinearGradient(
                    colors: Self.avatarColors(for: post.nickname),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 40)
            .overlay(
                Text(post.avatarInitial)
                    .font(DesignSystem.headlineFont)
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }

    /// 固定在玫粉主色的邻近区间里挑，而不是让 hash 落到整个色环上——
    /// 随机色相会挑出与品牌完全不搭的绿或青。
    private static let avatarPalette: [[Color]] = [
        [Color(red: 0.85, green: 0.55, blue: 0.65), Color(red: 0.62, green: 0.31, blue: 0.44)],
        [Color(red: 0.88, green: 0.62, blue: 0.55), Color(red: 0.68, green: 0.38, blue: 0.34)],
        [Color(red: 0.75, green: 0.60, blue: 0.76), Color(red: 0.50, green: 0.35, blue: 0.55)],
        [Color(red: 0.86, green: 0.68, blue: 0.52), Color(red: 0.63, green: 0.44, blue: 0.30)],
        [Color(red: 0.72, green: 0.62, blue: 0.70), Color(red: 0.46, green: 0.36, blue: 0.47)],
    ]

    private static func avatarColors(for nickname: String) -> [Color] {
        // hashValue 每次启动都变，用字节和保证同一昵称的颜色稳定。
        let seed = nickname.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return avatarPalette[seed % avatarPalette.count]
    }

    private var nameRow: some View {
        HStack(spacing: 6) {
            Text(post.nickname)
                .font(DesignSystem.bodyFont.weight(.bold))
                .foregroundStyle(DesignSystem.Rose.ink)
                .layoutPriority(1)
            Text("\(post.city) · \(post.timeText) · 已授权公开")
                .font(DesignSystem.captionFont)
                .foregroundStyle(DesignSystem.Rose.ink2)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var storyText: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(post.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(DesignSystem.bodyFont)
                    .foregroundStyle(DesignSystem.Rose.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)
    }

    private var mediaPlaceholder: some View {
        // 不使用可能被误认为真实用户照片的素材：演示数据走矢量插画，
        // 真实故事（illustration 为 nil）仍是中性占位。
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Rose.tint)
            if let illustration = post.illustration {
                StoryIllustrationView(kind: illustration, showsPlayButton: post.media == .video)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: DesignSystem.spacing8) {
                    Image(systemName: post.media == .video ? "video" : "photo")
                        .font(.title2.weight(.regular))
                        .foregroundStyle(DesignSystem.Rose.ink3)
                    if post.media == .video {
                        Image(systemName: "play.circle.fill")
                            .font(.largeTitle.weight(.regular))
                            .foregroundStyle(DesignSystem.Rose.primary)
                    }
                }
            }
        }
        .frame(height: 220)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Rose.line, lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            if post.isDemo {
                Text("虚构示例内容")
                    .font(DesignSystem.captionFont.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(9)
            }
        }
        .accessibilityLabel(post.media == .video ? "示意视频占位" : "示意图片占位")
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            Button(action: onComingSoon) {
                Image(systemName: "bubble.left")
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .accessibilityLabel("评论，功能准备中")
            Spacer()
            ShareLink(item: post.shareText) {
                Image(systemName: "paperplane")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("分享这个故事")
            Spacer()
            Button(action: onComingSoon) {
                Image(systemName: "heart")
                    .frame(width: 44, height: 44, alignment: .trailing)
            }
            .accessibilityLabel("点赞，功能准备中")
        }
        .font(.body.weight(.regular))
        .foregroundStyle(DesignSystem.Rose.ink2)
        .frame(maxWidth: 236, alignment: .leading)
        .padding(.top, 2)
    }
}

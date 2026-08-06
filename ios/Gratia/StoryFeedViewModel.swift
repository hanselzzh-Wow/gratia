import SwiftUI
import GratiaCore

/// 首页故事流的真实数据源。
///
/// 内容只来自「已完成且需求方明确同意公开」的心愿——这是产品从一开始就
/// 定下的边界：公开故事需发布者单独同意，不含联系方式与精确位置。
/// 生产环境没有已公开故事时返回空数组，首页显示诚实空态，不伪造内容。
@MainActor
final class StoryFeedViewModel: ObservableObject {
    @Published private(set) var posts: [StoryPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let accountAPI: AccountAPIProtocol

    init(accountAPI: AccountAPIProtocol) {
        self.accountAPI = accountAPI
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let stories = try await accountAPI.stories()
            posts = stories.map(Self.toPost)
            errorMessage = nil
        } catch {
            // 拉取失败不要清空已有内容，只提示；空态与失败态要能区分。
            errorMessage = (error as? GratiaAPIError)?.errorDescription ?? "故事加载失败，请下拉重试。"
        }
    }

    private static func toPost(_ dto: StoryDTO) -> StoryPost {
        let media: StoryPost.Media
        if dto.media.contains(where: { $0.kind.contains("video") }) {
            media = .video
        } else if dto.media.isEmpty {
            media = .none
        } else {
            media = .photo
        }

        var paragraphs = [dto.message]
        if let note = dto.note, !note.isEmpty {
            paragraphs.append(note)
        }

        return StoryPost(
            id: dto.id,
            nickname: dto.nickname,
            city: dto.city,
            timeText: Self.relativeTime(from: dto.publishedAt),
            paragraphs: paragraphs,
            media: media,
            mediaNote: dto.media.isEmpty ? "" : "\(dto.media.count) 张来自现场的影像",
            tags: [dto.city, dto.occasion].filter { !$0.isEmpty },
            isDemo: false
        )
    }

    /// 只给模糊相对时间，不暴露精确时间戳。
    private static func relativeTime(from milliseconds: Int64) -> String {
        let interval = Date().timeIntervalSince1970 - Double(milliseconds) / 1000
        switch interval {
        case ..<3600: return "刚刚"
        case ..<86_400: return "今天"
        case ..<172_800: return "昨天"
        case ..<604_800: return "\(Int(interval / 86_400)) 天前"
        case ..<2_592_000: return "\(Int(interval / 604_800)) 周前"
        default: return "\(Int(interval / 2_592_000)) 个月前"
        }
    }
}

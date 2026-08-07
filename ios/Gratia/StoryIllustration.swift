import SwiftUI

/// 演示故事的交付画面。**只有 DEBUG 的虚构示例会用到**
/// （`StoryPost.illustration` 在真实故事里恒为 nil，走原来的中性占位）。
///
/// 这些图是程序生成的合成画面，不是任何人拍的照片，也没有可辨认的人物——
/// 所以既不涉及肖像权，也不涉及第三方图片版权。卡片上的「虚构示例内容」
/// 标签仍然保留，不冒充真实用户的交付。
struct StoryIllustrationView: View {
    let kind: StoryPost.Illustration
    var showsPlayButton = false

    private var assetName: String {
        switch kind {
        case .nightRiver: return "DemoMediaNight"
        case .handwritten: return "DemoMediaCard"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .overlay {
                if showsPlayButton {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.94))
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 2)
                }
            }
    }
}

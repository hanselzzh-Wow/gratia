import SwiftUI

/// App 内置的预设头像。
///
/// 存在的理由：新用户必须设头像，但不是每个人手边都有合适的照片，也不是每个人
/// 愿意放自己的脸。没有兜底选项的话，这一步会把人卡在登录后的第一屏——
/// 而那正是他对产品的第一印象。
///
/// **必须上传原始文件字节，不能经过 UIImage 重新编码。** 服务端按内容的
/// SHA-256 判定这是不是预设图，命中才免去人工审核；重编码会改变字节，
/// 哈希对不上，那张图就退回走人工审核队列——不报错，只是安静地不再免审，
/// 于是用户按引导选了头像，别人看到的依然是灰色人像。
enum PresetAvatars {
    static let count = 12

    static func name(_ index: Int) -> String { "preset-\(index + 1)" }

    /// 原始 PNG 字节。用于上传——保持逐字节不变是免审的前提。
    static func data(_ index: Int) -> Data? {
        // 在 PresetAvatars/ 子目录下：工程里它是 folder reference，
        // 保持目录结构进包，这样 Xcode 不会重新编码这些 PNG。
        guard let url = Bundle.main.url(
            forResource: name(index), withExtension: "png", subdirectory: "PresetAvatars"
        ) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// 仅用于界面预览。
    static func image(_ index: Int) -> UIImage? {
        guard let data = data(index) else { return nil }
        return UIImage(data: data)
    }
}

/// 预设头像选择器：一格网格，选中的那个描一圈主题色。
struct PresetAvatarPicker: View {
    @Binding var selection: Int?
    var size: CGFloat = 64

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: DesignSystem.spacing12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignSystem.spacing12) {
            ForEach(0..<PresetAvatars.count, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Group {
                        if let image = PresetAvatars.image(index) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Circle().fill(DesignSystem.Rose.soft)
                        }
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            selection == index ? DesignSystem.Rose.primary : Color.clear,
                            lineWidth: 3
                        )
                    )
                    // 选中态不能只靠描边：色觉障碍或强光下都看不出差别。
                    .overlay(alignment: .bottomTrailing) {
                        if selection == index {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: size * 0.28))
                                .foregroundStyle(DesignSystem.Rose.primary, .white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("预设头像 \(index + 1)")
                .accessibilityAddTraits(selection == index ? [.isSelected] : [])
            }
        }
    }
}

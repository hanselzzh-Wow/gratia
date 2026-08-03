import SwiftUI

/// The only visual vocabulary for the native MVP.
/// Values are frozen in `docs/ios-design-freeze-v3.md`.
struct DesignSystem {
    // MARK: - Base tokens (rose-on-white, 2026-07-19 product-owner direction)
    // 旧 v3 暖白/暖蓝值已由产品负责人指示整体替换；
    // 沿用原 token 名，让全部页面一次性迁移到纯白底 + 玫粉点缀。

    static let accent = Rose.primary
    static let ink900 = Rose.ink
    static let ink700 = Rose.ink2
    static let ink500 = Rose.ink3
    static let canvasWarm = Rose.canvas
    static let canvas = Rose.canvas
    static let canvasSunk = Rose.tint
    static let hairline = Rose.line
    static let hairlineStrong = Rose.soft
    static let danger = Color(red: 179.0 / 255.0, green: 69.0 / 255.0, blue: 47.0 / 255.0) // #B3452F
    static let success = Color(red: 76.0 / 255.0, green: 122.0 / 255.0, blue: 82.0 / 255.0) // #4C7A52

    // Compatibility names deliberately map to v3 roles so untouched business pages
    // cannot reintroduce the old sky-blue, gold or navy palette.
    static let primaryBlue = accent
    static let textNavy = ink900
    static let textSecondary = ink700
    static let bgWarmWhite = canvasWarm
    static let cardBg = canvas
    static let highlightGold = ink900

    // MARK: - Rose palette (2026-07-18 product-owner direction)
    // 纯白画布 + 深玫红小面积点缀。首页/搜索/我的与 Dock 使用本组；
    // 其余页面在统一改版任务完成前继续使用上方 v3 token。
    enum Rose {
        static let primary = Color(red: 154.0 / 255.0, green: 83.0 / 255.0, blue: 109.0 / 255.0) // #9A536D
        static let deep = Color(red: 127.0 / 255.0, green: 64.0 / 255.0, blue: 88.0 / 255.0) // #7F4058
        static let soft = Color(red: 228.0 / 255.0, green: 198.0 / 255.0, blue: 208.0 / 255.0) // #E4C6D0
        static let tint = Color(red: 250.0 / 255.0, green: 244.0 / 255.0, blue: 246.0 / 255.0) // #FAF4F6
        static let canvas = Color.white
        static let ink = Color(red: 25.0 / 255.0, green: 23.0 / 255.0, blue: 25.0 / 255.0) // #191719
        static let ink2 = Color(red: 112.0 / 255.0, green: 106.0 / 255.0, blue: 109.0 / 255.0) // #706A6D
        static let ink3 = Color(red: 169.0 / 255.0, green: 162.0 / 255.0, blue: 165.0 / 255.0) // #A9A2A5
        static let line = Color(red: 236.0 / 255.0, green: 232.0 / 255.0, blue: 234.0 / 255.0) // #ECE8EA
    }

    // MARK: - Spacing

    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let spacing40: CGFloat = 40

    // MARK: - Radius

    static let radiusTiny: CGFloat = 6
    static let radiusSmall: CGFloat = 10
    static let radiusMedium: CGFloat = 14
    static let radiusLarge: CGFloat = 20
    static let radiusPill: CGFloat = 999

    // MARK: - Dynamic Type

    static let displayFont = Font.largeTitle.weight(.bold)
    static let titleFont = Font.title2.weight(.bold)
    static let headlineFont = Font.headline
    static let bodyFont = Font.subheadline
    static let metadataFont = Font.footnote
    static let captionFont = Font.caption2
}

struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.headlineFont)
            .foregroundStyle(.white)
            .padding(.vertical, DesignSystem.spacing12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(isDisabled ? DesignSystem.accent.opacity(0.45) : DesignSystem.accent)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.headlineFont)
            .foregroundStyle(DesignSystem.accent)
            .padding(.vertical, DesignSystem.spacing12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(DesignSystem.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .stroke(DesignSystem.accent, lineWidth: 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct WarmBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(DesignSystem.canvasWarm.ignoresSafeArea())
    }
}

extension View {
    func warmBackground() -> some View {
        modifier(WarmBackgroundModifier())
    }

    func v3Card(radius: CGFloat = DesignSystem.radiusMedium) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius)
                .fill(DesignSystem.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(DesignSystem.hairline, lineWidth: 1)
                )
        )
    }
}

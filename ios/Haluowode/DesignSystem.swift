import SwiftUI

/// The only visual vocabulary for the native MVP.
/// Values are frozen in `docs/ios-design-freeze-v3.md`.
struct DesignSystem {
    // MARK: - V3 colors

    static let accent = Color(red: 62.0 / 255.0, green: 107.0 / 255.0, blue: 146.0 / 255.0) // #3E6B92
    static let ink900 = Color(red: 23.0 / 255.0, green: 19.0 / 255.0, blue: 16.0 / 255.0) // #171310
    static let ink700 = Color(red: 74.0 / 255.0, green: 68.0 / 255.0, blue: 60.0 / 255.0) // #4A443C
    static let ink500 = Color(red: 132.0 / 255.0, green: 124.0 / 255.0, blue: 111.0 / 255.0) // #847C6F
    static let canvasWarm = Color(red: 251.0 / 255.0, green: 246.0 / 255.0, blue: 236.0 / 255.0) // #FBF6EC
    static let canvas = Color.white
    static let canvasSunk = Color(red: 243.0 / 255.0, green: 236.0 / 255.0, blue: 221.0 / 255.0) // #F3ECDD
    static let hairline = Color(red: 233.0 / 255.0, green: 225.0 / 255.0, blue: 210.0 / 255.0) // #E9E1D2
    static let hairlineStrong = Color(red: 216.0 / 255.0, green: 205.0 / 255.0, blue: 184.0 / 255.0) // #D8CDB8
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

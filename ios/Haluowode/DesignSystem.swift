import SwiftUI

struct DesignSystem {
    // Colors
    static let primaryBlue = Color(red: 0.365, green: 0.678, blue: 0.886) // 清透天空蓝
    static let highlightGold = Color(red: 0.98, green: 0.80, blue: 0.25) // 晨光金/暖黄
    static let textNavy = Color(red: 0.05, green: 0.12, blue: 0.25) // 深海军蓝
    static let textSecondary = Color(red: 0.35, green: 0.45, blue: 0.55) // 辅助灰蓝
    static let bgWarmWhite = Color(red: 0.98, green: 0.98, blue: 0.97) // 偏暖白背景
    static let cardBg = Color.white // 卡片纯白

    // Spacing
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing20: CGFloat = 20
    static let spacing24: CGFloat = 24

    // Corner Radius
    static let radiusLarge: CGFloat = 16
    static let radiusMedium: CGFloat = 12
    static let radiusSmall: CGFloat = 8
}

// Custom modifiers and styles
struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(isDisabled ? DesignSystem.primaryBlue.opacity(0.4) : DesignSystem.primaryBlue)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(DesignSystem.primaryBlue)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .stroke(DesignSystem.primaryBlue, lineWidth: 1.5)
                    .background(RoundedRectangle(cornerRadius: DesignSystem.radiusMedium).fill(Color.white))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// Background Modifier
struct WarmBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.bgWarmWhite.ignoresSafeArea())
    }
}

extension View {
    func warmBackground() -> some View {
        self.modifier(WarmBackgroundModifier())
    }
}

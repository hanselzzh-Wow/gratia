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
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .motion(DesignSystem.Motion.control, value: configuration.isPressed)
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
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .motion(DesignSystem.Motion.control, value: configuration.isPressed)
    }
}

struct WarmBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(DesignSystem.canvasWarm.ignoresSafeArea())
    }
}

// MARK: - Motion

extension DesignSystem {
    /// 动效语义层。全部使用弹簧而非时长曲线：系统动画是可中断的物理运动，
    /// 用户能在半路抓住它往回拖，`easeInOut` 做不到这件事。
    /// 各处一律引用这里的语义，不要散落手写数值。
    enum Motion {
        /// 层级与页面切换。
        static let navigation = Animation.snappy(duration: 0.42, extraBounce: 0.02)
        /// 内容出现、替换、列表变化。
        static let content = Animation.smooth(duration: 0.32)
        /// 控件的即时反馈，需要跟手。
        static let control = Animation.snappy(duration: 0.22)
        /// 仅用于成功时刻，是全 App 唯一允许"弹"的地方。
        static let celebrate = Animation.bouncy(duration: 0.5, extraBounce: 0.18)

        /// Reduce Motion 下退化为短促淡入，而不是取消动画——
        /// 直接取消会丢失"状态发生了变化"这一提示，反而更不可用。
        static func adaptive(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeOut(duration: 0.18) : animation
        }

        /// Reduce Motion 下一律交叉淡入，与系统自身的降级方式一致。
        static func transition(_ transition: AnyTransition, reduceMotion: Bool) -> AnyTransition {
            reduceMotion ? .opacity : transition
        }
    }
}

/// 按语义施加动画，并自动处理 Reduce Motion。
private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(DesignSystem.Motion.adaptive(animation, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// 用法：`.motion(.content, value: items)`
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }

    /// Reduce Motion 下自动降级为淡入的转场。
    func motionTransition(_ transition: AnyTransition) -> some View {
        modifier(MotionTransitionModifier(transition: transition))
    }
}

private struct MotionTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let transition: AnyTransition

    func body(content: Content) -> some View {
        content.transition(DesignSystem.Motion.transition(transition, reduceMotion: reduceMotion))
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

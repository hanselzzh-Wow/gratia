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

    // MARK: - CL-006 rose palette (product-owner approved Claude direction)
    // Scope: home / search / centre publish / help / profile and the dock only.
    // AG-007 progress & delivery pages keep the v3 accent above untouched.

    static let rose = Color(red: 154.0 / 255.0, green: 83.0 / 255.0, blue: 109.0 / 255.0) // #9A536D
    static let roseDeep = Color(red: 127.0 / 255.0, green: 64.0 / 255.0, blue: 88.0 / 255.0) // #7F4058
    static let roseSoft = Color(red: 228.0 / 255.0, green: 198.0 / 255.0, blue: 208.0 / 255.0) // #E4C6D0
    static let roseCanvas = Color(red: 250.0 / 255.0, green: 244.0 / 255.0, blue: 246.0 / 255.0) // #FAF4F6
    static let roseHairline = Color(red: 236.0 / 255.0, green: 217.0 / 255.0, blue: 225.0 / 255.0) // #ECD9E1
    static let inkPrimary = Color(red: 25.0 / 255.0, green: 23.0 / 255.0, blue: 25.0 / 255.0) // #191719
    static let inkMuted = Color(red: 109.0 / 255.0, green: 102.0 / 255.0, blue: 106.0 / 255.0) // #6D666A

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

/// Rose variants for CL-006 pages; the v3 accent styles above stay untouched
/// for the AG-007 progress/delivery pages.
struct RosePrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.headlineFont)
            .foregroundStyle(.white)
            .padding(.vertical, DesignSystem.spacing12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(isDisabled ? DesignSystem.rose.opacity(0.45) : DesignSystem.rose)
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct RoseSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.headlineFont)
            .foregroundStyle(DesignSystem.rose)
            .padding(.vertical, DesignSystem.spacing12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(DesignSystem.canvas)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                            .stroke(DesignSystem.rose, lineWidth: 1)
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

struct WhiteCanvasModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(DesignSystem.canvas.ignoresSafeArea())
    }
}

extension View {
    func warmBackground() -> some View {
        modifier(WarmBackgroundModifier())
    }

    func whiteCanvas() -> some View {
        modifier(WhiteCanvasModifier())
    }

    func roseCard(radius: CGFloat = DesignSystem.radiusLarge) -> some View {
        background(
            RoundedRectangle(cornerRadius: radius)
                .fill(DesignSystem.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(DesignSystem.roseHairline, lineWidth: 1)
                )
        )
    }
}

/// Original "two hands clasped" mark for the Help tab.
/// Hand-drawn bezier outline; deliberately not an SF Symbol so the dock
/// keeps the product's own vocabulary for mutual help.
struct HandsClaspedIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // Left forearm sweeping in from the lower left.
        p.move(to: CGPoint(x: 0.02 * w, y: 0.86 * h))
        p.addCurve(
            to: CGPoint(x: 0.34 * w, y: 0.44 * h),
            control1: CGPoint(x: 0.08 * w, y: 0.66 * h),
            control2: CGPoint(x: 0.18 * w, y: 0.50 * h)
        )
        // Left hand rises to grasp.
        p.addCurve(
            to: CGPoint(x: 0.52 * w, y: 0.40 * h),
            control1: CGPoint(x: 0.42 * w, y: 0.41 * h),
            control2: CGPoint(x: 0.47 * w, y: 0.38 * h)
        )
        // Clasp knuckles: gentle interlocked bumps across the centre.
        p.addCurve(
            to: CGPoint(x: 0.66 * w, y: 0.44 * h),
            control1: CGPoint(x: 0.57 * w, y: 0.42 * h),
            control2: CGPoint(x: 0.61 * w, y: 0.40 * h)
        )
        // Right hand and forearm sweeping out to the lower right.
        p.addCurve(
            to: CGPoint(x: 0.98 * w, y: 0.86 * h),
            control1: CGPoint(x: 0.82 * w, y: 0.50 * h),
            control2: CGPoint(x: 0.92 * w, y: 0.66 * h)
        )
        // Inner return line to suggest the wrist/thumb of the right hand.
        p.move(to: CGPoint(x: 0.80 * w, y: 0.70 * h))
        p.addCurve(
            to: CGPoint(x: 0.60 * w, y: 0.56 * h),
            control1: CGPoint(x: 0.74 * w, y: 0.61 * h),
            control2: CGPoint(x: 0.68 * w, y: 0.57 * h)
        )
        // Inner return line for the left thumb crossing over.
        p.move(to: CGPoint(x: 0.20 * w, y: 0.70 * h))
        p.addCurve(
            to: CGPoint(x: 0.44 * w, y: 0.54 * h),
            control1: CGPoint(x: 0.26 * w, y: 0.61 * h),
            control2: CGPoint(x: 0.34 * w, y: 0.55 * h)
        )
        // Small heart rising above the clasp, completing "help with heart".
        let hc = CGPoint(x: 0.50 * w, y: 0.20 * h)
        let r = 0.085 * w
        p.move(to: CGPoint(x: hc.x, y: hc.y + 1.35 * r))
        p.addCurve(
            to: CGPoint(x: hc.x - 1.5 * r, y: hc.y - 0.4 * r),
            control1: CGPoint(x: hc.x - 1.1 * r, y: hc.y + 0.7 * r),
            control2: CGPoint(x: hc.x - 1.5 * r, y: hc.y + 0.3 * r)
        )
        p.addArc(
            center: CGPoint(x: hc.x - 0.75 * r, y: hc.y - 0.4 * r),
            radius: 0.75 * r,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        p.addArc(
            center: CGPoint(x: hc.x + 0.75 * r, y: hc.y - 0.4 * r),
            radius: 0.75 * r,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        p.addCurve(
            to: CGPoint(x: hc.x, y: hc.y + 1.35 * r),
            control1: CGPoint(x: hc.x + 1.5 * r, y: hc.y + 0.3 * r),
            control2: CGPoint(x: hc.x + 1.1 * r, y: hc.y + 0.7 * r)
        )
        return p
    }
}

/// Renders the clasped-hands mark at SF-symbol-like stroke weight.
struct HandsClaspedGlyph: View {
    var lineWidth: CGFloat = 1.8

    var body: some View {
        HandsClaspedIcon()
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

extension View {
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

import SwiftUI

/// 演示故事的插画。**只有 DEBUG 的虚构示例会用到**（`StoryPost.illustration`
/// 在真实故事里恒为 nil），存在的意义是让商店截图里的交付位不是一块空占位。
///
/// 刻意画成矢量插画而不是使用照片素材：画面不空，但任何人一眼能看出这不是
/// 某个真实用户拍回来的东西。卡片上的「虚构示例内容」标签仍然保留。
struct StoryIllustrationView: View {
    let kind: StoryPost.Illustration
    var showsPlayButton = false

    var body: some View {
        Canvas { context, size in
            switch kind {
            case .nightRiver: drawNightRiver(&context, size)
            case .handwritten: drawHandwritten(&context, size)
            case .blossom: drawBlossom(&context, size)
            }
        }
        .overlay {
            if showsPlayButton {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
            }
        }
    }

    // MARK: 江边夜色

    private func drawNightRiver(_ context: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let horizon = h * 0.62

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.13, green: 0.16, blue: 0.32),
                                  Color(red: 0.36, green: 0.26, blue: 0.40)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)
            )
        )

        // 月亮
        let moon = CGRect(x: w * 0.76, y: h * 0.13, width: w * 0.10, height: w * 0.10)
        context.fill(Path(ellipseIn: moon), with: .color(.white.opacity(0.88)))

        // 对岸天际线：高矮不一的塔楼，只取剪影
        let towers: [(CGFloat, CGFloat, CGFloat)] = [
            (0.06, 0.20, 0.055), (0.14, 0.31, 0.045), (0.21, 0.15, 0.06),
            (0.32, 0.38, 0.05), (0.40, 0.24, 0.075), (0.52, 0.34, 0.045),
            (0.60, 0.19, 0.05), (0.69, 0.29, 0.06), (0.80, 0.22, 0.05),
            (0.89, 0.33, 0.055),
        ]
        let skyline = Color(red: 0.08, green: 0.09, blue: 0.20)
        for (x, top, tw) in towers {
            let rect = CGRect(x: w * x, y: horizon - h * (1 - top) * 0.52,
                              width: w * tw, height: h)
            context.fill(Path(rect), with: .color(skyline))
            // 零星窗灯
            for row in 0..<3 {
                let ly = rect.minY + CGFloat(row) * 14 + 10
                guard ly < horizon - 8 else { continue }
                context.fill(
                    Path(CGRect(x: rect.minX + rect.width * 0.28, y: ly, width: 3, height: 5)),
                    with: .color(Color(red: 1.0, green: 0.86, blue: 0.6).opacity(0.65))
                )
            }
        }

        // 江面
        context.fill(
            Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.10, green: 0.13, blue: 0.28),
                                  Color(red: 0.17, green: 0.20, blue: 0.36)]),
                startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)
            )
        )
        // 灯光在水面的碎反光
        for i in 0..<7 {
            let y = horizon + CGFloat(i) * (h - horizon) / 7 + 6
            let inset = w * (0.10 + CGFloat(i) * 0.03)
            context.stroke(
                Path { $0.move(to: CGPoint(x: inset, y: y)); $0.addLine(to: CGPoint(x: w - inset, y: y)) },
                with: .color(.white.opacity(0.10 - Double(i) * 0.012)),
                lineWidth: 2
            )
        }
        context.fill(
            Path(ellipseIn: CGRect(x: moon.midX - w * 0.035, y: horizon + h * 0.06,
                                   width: w * 0.07, height: h * 0.04)),
            with: .color(.white.opacity(0.18))
        )
    }

    // MARK: 手写卡片

    private func drawHandwritten(_ context: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(Color(red: 0.96, green: 0.93, blue: 0.90)))

        let card = CGRect(x: w * 0.13, y: h * 0.14, width: w * 0.74, height: h * 0.72)
        context.fill(Path(roundedRect: card, cornerRadius: 12),
                     with: .color(.white.opacity(0.97)))
        context.stroke(Path(roundedRect: card, cornerRadius: 12),
                       with: .color(Color(red: 0.85, green: 0.78, blue: 0.74)), lineWidth: 1)

        // 手写笔迹：起伏的曲线，长度不一，像写满又留白的一页
        let ink = Color(red: 0.29, green: 0.24, blue: 0.28).opacity(0.72)
        let lineCount = 5
        for i in 0..<lineCount {
            let y = card.minY + card.height * (0.20 + CGFloat(i) * 0.145)
            let endX = card.maxX - card.width * (i == lineCount - 1 ? 0.42 : 0.12)
            var path = Path()
            path.move(to: CGPoint(x: card.minX + card.width * 0.10, y: y))
            var x = card.minX + card.width * 0.10
            var up = true
            while x < endX {
                let step = card.width * 0.055
                path.addQuadCurve(
                    to: CGPoint(x: min(x + step, endX), y: y),
                    control: CGPoint(x: x + step / 2, y: y + (up ? -5 : 4))
                )
                x += step
                up.toggle()
            }
            context.stroke(path, with: .color(ink),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }

        // 角落那颗小爱心
        let cx = card.maxX - card.width * 0.16, cy = card.maxY - card.height * 0.13
        let r = card.width * 0.035
        var heart = Path()
        heart.move(to: CGPoint(x: cx, y: cy + r * 0.9))
        heart.addCurve(to: CGPoint(x: cx - r * 1.4, y: cy - r * 0.35),
                       control1: CGPoint(x: cx - r * 0.7, y: cy + r * 0.35),
                       control2: CGPoint(x: cx - r * 1.4, y: cy + r * 0.25))
        heart.addArc(center: CGPoint(x: cx - r * 0.7, y: cy - r * 0.35), radius: r * 0.7,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        heart.addArc(center: CGPoint(x: cx + r * 0.7, y: cy - r * 0.35), radius: r * 0.7,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        heart.addCurve(to: CGPoint(x: cx, y: cy + r * 0.9),
                       control1: CGPoint(x: cx + r * 1.4, y: cy + r * 0.25),
                       control2: CGPoint(x: cx + r * 0.7, y: cy + r * 0.35))
        context.fill(heart, with: .color(Color(red: 0.78, green: 0.36, blue: 0.48).opacity(0.85)))
    }

    // MARK: 树与花

    private func drawBlossom(_ context: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.99, green: 0.94, blue: 0.95),
                                  Color(red: 0.95, green: 0.88, blue: 0.90)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)
            )
        )
        var branch = Path()
        branch.move(to: CGPoint(x: w * 0.10, y: h * 0.95))
        branch.addCurve(to: CGPoint(x: w * 0.82, y: h * 0.18),
                        control1: CGPoint(x: w * 0.34, y: h * 0.80),
                        control2: CGPoint(x: w * 0.52, y: h * 0.30))
        context.stroke(branch, with: .color(Color(red: 0.42, green: 0.32, blue: 0.28).opacity(0.75)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))

        let petals: [(CGFloat, CGFloat, CGFloat)] = [
            (0.30, 0.72, 1.0), (0.40, 0.60, 0.8), (0.47, 0.52, 1.2),
            (0.56, 0.42, 0.9), (0.63, 0.36, 1.1), (0.72, 0.28, 0.85),
            (0.79, 0.21, 1.0), (0.36, 0.78, 0.7), (0.68, 0.44, 0.75),
        ]
        for (px, py, scale) in petals {
            let c = CGPoint(x: w * px, y: h * py)
            let r = w * 0.028 * scale
            for k in 0..<5 {
                let a = Double(k) * (2 * .pi / 5)
                let pc = CGPoint(x: c.x + cos(a) * r * 0.9, y: c.y + sin(a) * r * 0.9)
                context.fill(
                    Path(ellipseIn: CGRect(x: pc.x - r * 0.6, y: pc.y - r * 0.6,
                                           width: r * 1.2, height: r * 1.2)),
                    with: .color(Color(red: 0.95, green: 0.72, blue: 0.79).opacity(0.9))
                )
            }
            context.fill(
                Path(ellipseIn: CGRect(x: c.x - r * 0.34, y: c.y - r * 0.34,
                                       width: r * 0.68, height: r * 0.68)),
                with: .color(Color(red: 0.99, green: 0.90, blue: 0.72))
            )
        }
    }
}

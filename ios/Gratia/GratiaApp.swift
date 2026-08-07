import SwiftUI

@main
struct GratiaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // 全 App 锁定浅色。
                //
                // 1.0 的设计基线是「玫粉白」，DesignSystem 里的颜色全是写死的
                // 浅色值（`Color(red:green:blue:)`），没有任何暗色变体。而系统
                // 组件——Dock 背景、Sheet、弹窗、Sign in with Apple 按钮——会
                // 自己跟随系统外观。两者一叠加，暗色模式下就是「上面白、下面黑」，
                // 而且 Dock 选中态那个近黑图标落在黑底上几乎看不见。
                //
                // 在补齐整套暗色配色之前，锁定浅色是唯一自洽的状态；
                // 真要做暗色模式，得先给 DesignSystem 的每个颜色补暗色变体，
                // 再逐屏校对对比度，那时才应该去掉这一行。
                .preferredColorScheme(.light)
        }
    }
}

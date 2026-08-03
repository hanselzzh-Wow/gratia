import SwiftUI

#if !os(iOS)
// Compatibility definitions to allow macOS CLI compilation/typecheck
// of iOS-specific SwiftUI elements without code clutter.

public struct NavigationBarItem {
    public enum TitleDisplayMode {
        case inline
        case large
        case automatic
    }
}

public final class UIPasteboard {
    public static let general = UIPasteboard()
    public var string: String? {
        get { nil }
        set { }
    }
}

extension View {
    public func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> some View {
        self
    }

    public func fullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
    }
}

extension ToolbarItemPlacement {
    public static var navigationBarLeading: ToolbarItemPlacement {
        .navigation
    }

    public static var navigationBarTrailing: ToolbarItemPlacement {
        .primaryAction
    }
}
#endif

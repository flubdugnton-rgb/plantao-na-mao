import SwiftUI

enum AppTheme: String { case light, system, dark }

struct ThemeToggleButton: View {
    @AppStorage("plantao-na-mao.appearance") private var rawTheme = "system"
    var body: some View {
        PixelThemeToggle(theme: Binding(get: { AppTheme(rawValue: rawTheme) ?? .system }, set: {
            rawTheme = $0.rawValue
            WidgetBridge.refreshAppearance()
        }))
    }
}

extension View {
    @ViewBuilder func glassSurface(radius: CGFloat = 22, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: radius))
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }
}

struct AppBackdrop: View {
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [(ShiftColor(rawValue: theme) ?? .mint).value.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }.ignoresSafeArea()
    }
}

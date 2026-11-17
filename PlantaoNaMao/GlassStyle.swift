import SwiftUI

private struct GlassSurface: ViewModifier {
    var radius: CGFloat
    var interactive: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: radius))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: radius))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.35), lineWidth: 0.6) }
        }
    }
}

extension View {
    func glassSurface(radius: CGFloat = 22, interactive: Bool = false) -> some View {
        modifier(GlassSurface(radius: radius, interactive: interactive))
    }
}

struct AppBackdrop: View {
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(colors: [(ShiftColor(rawValue: theme) ?? .mint).value.opacity(0.10), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }.ignoresSafeArea()
    }
}

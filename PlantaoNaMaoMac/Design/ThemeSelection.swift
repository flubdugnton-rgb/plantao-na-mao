import Foundation

/// Ordem visual independente dos raw values já persistidos pelo app.
enum ThemeSelection {
    static let options: [AppTheme] = [.light, .system, .dark]
    static func position(for theme: AppTheme) -> Double {
        Double(options.firstIndex(of: theme) ?? 1)
    }
    static func theme(at position: Double) -> AppTheme {
        options[min(max(Int(position.rounded()), 0), 2)]
    }
    static func dragPosition(origin: Double, translation: Double, travel: Double) -> Double {
        guard travel > 0 else { return origin }
        return min(max(origin + translation / travel * 2, 0), 2)
    }
}

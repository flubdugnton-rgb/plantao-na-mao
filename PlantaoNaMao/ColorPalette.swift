import SwiftUI

extension ShiftColor {
    var value: Color {
        switch self {
        case .mint: return Color(red: 0.04, green: 0.57, blue: 0.43)
        case .sage: return Color(red: 0.38, green: 0.56, blue: 0.34)
        case .emerald: return Color(red: 0.03, green: 0.52, blue: 0.32)
        case .lime: return Color(red: 0.43, green: 0.58, blue: 0.08)
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return Color(red: 0.84, green: 0.32, blue: 0.08)
        case .amber: return Color(red: 0.65, green: 0.43, blue: 0.02)
        case .teal: return .teal
        case .yellow: return Color(red: 0.92, green: 0.72, blue: 0.02)
        case .brown: return .brown
        case .gray: return .gray
        case .monochrome: return .primary
        case .sky: return Color(red: 0.12, green: 0.65, blue: 0.91)
        case .cyan: return .cyan
        case .lavender: return Color(red: 0.57, green: 0.46, blue: 0.85)
        case .coral: return Color(red: 0.96, green: 0.37, blue: 0.31)
        case .rose: return Color(red: 0.72, green: 0.31, blue: 0.48)
        case .navy: return Color(red: 0.17, green: 0.29, blue: 0.57)
        case .forest: return Color(red: 0.13, green: 0.42, blue: 0.26)
        case .peach: return Color(red: 0.94, green: 0.62, blue: 0.42)
        }
    }
}

struct ColorChoices: View {
    @Binding var selection: ShiftColor
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<((ShiftColor.allCases.count + 3) / 4), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(Array(ShiftColor.allCases.dropFirst(row * 4).prefix(4))) { color in
                        colorButton(color)
                    }
                }
            }
        }.padding(.vertical, 8)
    }
    private func colorButton(_ color: ShiftColor) -> some View {
        Button { selection = color } label: {
            VStack(spacing: 6) {
                Circle().fill(color.value).frame(width: 38, height: 38)
                    .overlay {
                        if selection == color {
                            Image(systemName: "checkmark").font(.headline)
                                .foregroundStyle(color == .monochrome ? Color(.systemBackground) : color == .yellow || color == .peach ? Color.black : Color.white)
                        }
                    }
                Text(color.name).font(.caption2).foregroundStyle(.primary)
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain)
            .accessibilityLabel(color.name).accessibilityAddTraits(selection == color ? .isSelected : [])
    }
}

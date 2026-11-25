import SwiftUI

/// Um trilho, um botão e três posições. Inspirado no Swift e nas imagens fornecidos.
struct PixelThemeToggle: View {
    @Binding var theme: AppTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var drag: ThemeDrag?
    @State private var visible = false
    @State private var epoch = Date()

    private var position: Double { ThemeSelection.position(for: theme) }
    private let titles = ["Claro", "Sistema", "Escuro"]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width / 3.5
            let knob = height - 6
            let travel = width - knob - 6
            let preview = drag.map {
                ThemeSelection.dragPosition(origin: $0.origin, translation: $0.translation, travel: travel)
            } ?? position
            VStack(spacing: 8) {
                PixelThemeArtwork(position: preview, pressed: drag != nil, epoch: epoch,
                                  active: visible && scenePhase == .active && !reduceMotion && !AppLaunch.isUITest,
                                  reduceMotion: reduceMotion)
                    .frame(height: height)
                    .animation(drag == nil && !reduceMotion ? .spring(response: 0.42, dampingFraction: 0.86) : nil, value: preview)
                    .contentShape(Capsule())
                    .gesture(DragGesture(minimumDistance: 0)
                        .updating($drag) { value, state, _ in
                            guard enabled else { return }
                            state = ThemeDrag(origin: state?.origin ?? position, translation: value.translation.width)
                        }
                        .onEnded { value in
                            guard enabled else { return }
                            if abs(value.translation.width) < 3 && abs(value.translation.height) < 3 {
                                theme = ThemeSelection.theme(at: Double((value.location.x - 3 - knob / 2) / travel) * 2)
                            } else {
                                theme = ThemeSelection.theme(at: ThemeSelection.dragPosition(
                                    origin: drag?.origin ?? position, translation: value.translation.width, travel: travel))
                            }
                        })
                    .focusable(enabled)
                    .onKeyPress(.leftArrow) { move(-1); return .handled }
                    .onKeyPress(.rightArrow) { move(1); return .handled }
                    .onKeyPress(.space) { move(position == 2 ? -2 : 1); return .handled }
                    .accessibilityLabel("Tema")
                    .accessibilityValue(titles[Int(position)])
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: move(1)
                        case .decrement: move(-1)
                        @unknown default: break
                        }
                    }
                HStack(spacing: 0) {
                    ForEach(0..<3) { index in
                        Button {
                            theme = ThemeSelection.options[index]
                        } label: {
                            Text(titles[index])
                                .font(.system(size: 11, weight: Int(position) == index ? .semibold : .regular))
                                .foregroundStyle(Int(position) == index ? Color.primary : Color.secondary)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(Int(position) == index ? Color.accentColor.opacity(0.12) : .clear, in: Capsule())
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Tema \(titles[index])")
                        .accessibilityAddTraits(Int(position) == index ? .isSelected : [])
                    }
                }
            }
        }
        .frame(maxWidth: 216)
        .frame(height: 90)
        .opacity(enabled ? 1 : 0.45)
        .onAppear { epoch = .now; visible = true }
        .onDisappear { visible = false }
        .help("Escolha Claro, Sistema ou Escuro; arraste ou use as setas")
    }

    private func move(_ delta: Double) {
        guard enabled else { return }
        theme = ThemeSelection.theme(at: position + delta)
    }
}

private struct ThemeDrag {
    let origin: Double
    let translation: Double
}

/// A própria posição animável dirige materiais e pixels. Uma mudança interrompida
/// continua da apresentação atual, sem tarefas atrasadas que reiniciem os ícones.
private struct PixelThemeArtwork: View, Animatable {
    var position: Double
    let pressed: Bool
    let epoch: Date
    let active: Bool
    let reduceMotion: Bool
    nonisolated var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active)) { timeline in
            Canvas { context, size in
                draw(context: &context, size: size, time: active ? timeline.date.timeIntervalSince(epoch) : 0)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(context: inout GraphicsContext, size: CGSize, time: Double) {
        let p = min(max(position, 0), 2)
        let dark = p / 2
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)
        let track = Path(roundedRect: bounds, cornerRadius: size.height / 2)
        context.fill(track, with: .linearGradient(Gradient(colors: [mix((0.73,0.71,0.69),(0.035,0.04,0.07),dark),
            mix((0.94,0.92,0.89),(0.11,0.12,0.18),dark)]), startPoint: .zero, endPoint: CGPoint(x: 0,y: size.height)))
        context.stroke(track, with: .linearGradient(Gradient(colors: [.black.opacity(0.25),.white.opacity(0.5-dark*0.35)]),
                       startPoint: .zero, endPoint: CGPoint(x: 0,y: size.height)), lineWidth: 1.5)
        let side = size.height - 6
        let travel = size.width - side - 6
        let rect = CGRect(x: 3 + travel * p / 2, y: 3, width: side, height: side)
        let shape = Path(roundedRect: rect.insetBy(dx: pressed ? 0.8 : 0,dy: pressed ? 0.8 : 0), cornerRadius: side * 0.29)
        let glow = p < 1 ? mix((1,0.72,0.05),(0.85,0.74,1),p) : mix((0.85,0.74,1),(0.52,0.55,1),p-1)
        var shadow = context
        shadow.addFilter(.shadow(color: .black.opacity(0.22 + dark*0.2),radius: 5,x: 0,y: 3))
        shadow.fill(shape, with: .linearGradient(Gradient(colors: [mix((0.99,0.97,0.92),(0.29,0.30,0.39),dark),
            mix((0.88,0.85,0.79),(0.16,0.17,0.23),dark)]), startPoint: CGPoint(x: 0,y: 0),endPoint: CGPoint(x:0,y:size.height)))
        var tint = context
        tint.clip(to: shape)
        tint.fill(Path(ellipseIn: rect.offsetBy(dx:0,dy:side*0.45)),with:.radialGradient(Gradient(colors:[glow.opacity(0.6),.clear]),center:CGPoint(x:rect.midX,y:rect.maxY),startRadius:0,endRadius:side*0.8))
        context.stroke(shape, with:.color(.white.opacity(0.6)),lineWidth:0.8)
        let start = (p * 0.45 + time * 0.065).truncatingRemainder(dividingBy:1)
        for range in arcRanges(start: start, length: 0.36) {
            let arc = shape.trimmedPath(from: range.0,to: range.1)
            var halo = context
            halo.addFilter(.blur(radius: 4))
            halo.stroke(arc,with:.color(glow.opacity(0.75)),lineWidth:5)
            context.stroke(arc,with:.color(glow),style:StrokeStyle(lineWidth:1.8,lineCap:.round))
            context.stroke(arc,with:.color(.white.opacity(0.85)),lineWidth:0.55)
        }
        let low = min(Int(floor(p)), 2), high = min(low+1,2)
        let fraction = p - Double(low)
        let scatter = reduceMotion ? 0 : sin(fraction * .pi)
        let cell = side / 23
        for y in -9...9 {
            for x in -9...9 {
                let a = glyph(low,x,y), b = glyph(high,x,y)
                let alpha = a*(1-fraction)+b*fraction
                guard alpha > 0.015 else { continue }
                let seed = Double((x+10)*97 + (y+10)*53)
                let angle = seed * 2.399963
                let distance = scatter * side * 0.15 * (0.4 + (seed.truncatingRemainder(dividingBy:7)/10))
                let point = CGPoint(x:rect.midX+Double(x)*cell+cos(angle)*distance,
                                    y:rect.midY+Double(y)*cell+sin(angle)*distance)
                let square = cell*0.73*(1-scatter*0.25)
                let color = mix(glyphColor(low, x), glyphColor(high, x), fraction)
                context.fill(Path(CGRect(x:point.x-square/2,y:point.y-square/2,width:square,height:square)),with:.color(color.opacity(alpha)))
            }
        }
    }

    private func glyph(_ mode: Int, _ x: Int, _ y: Int) -> Double {
        switch mode {
        case 0:
            if x*x+y*y <= 12 { return 1 }
            return ((x == 0 && abs(y) >= 6 && abs(y) <= 8) || (y == 0 && abs(x) >= 6 && abs(x) <= 8) || (abs(x) == abs(y) && (abs(x) == 5 || abs(x) == 6))) ? 1 : 0
        case 1:
            if abs(x) <= 7 && y >= -5 && y <= 3 { return x < 0 ? 1 : 0.48 }
            return ((abs(x) <= 1 && y >= 4 && y <= 6) || (abs(x) <= 4 && y == 7)) ? 1 : 0
        default:
            let circle = (x+1)*(x+1)+(y-1)*(y-1) <= 38
            let cut = (x-2)*(x-2)+(y+2)*(y+2) < 29
            if circle { return cut ? 0.14 : 1 }
            return ((x == 6 && (-7 ... -5).contains(y)) || (y == -6 && (5...7).contains(x)) || (x == 8 && y == -1)) ? 1 : 0
        }
    }

    private func glyphColor(_ mode: Int, _ x: Int) -> (Double,Double,Double) {
        if mode == 0 { return (0.28,0.22,0.13) }
        if mode == 1 && x >= 0 { return (0.14,0.13,0.18) }
        return (0.98,0.98,1)
    }

    private func arcRanges(start: Double, length: Double) -> [(CGFloat,CGFloat)] {
        if start+length <= 1 { return [(start,start+length)] }
        return [(start,1),(0,start+length-1)]
    }
    private func mix(_ a:(Double,Double,Double),_ b:(Double,Double,Double),_ p:Double) -> Color {
        Color(red:a.0+(b.0-a.0)*p,green:a.1+(b.1-a.1)*p,blue:a.2+(b.2-a.2)*p)
    }
}

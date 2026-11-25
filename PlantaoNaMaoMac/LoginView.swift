import AppKit
import SwiftUI

enum LoginMood { case idle, stars, loading, success, sleepy, error }

/// Integra a referência enviada ao login real já existente; não simula autenticação.
struct LoginView: View {
    @EnvironmentObject private var auth: GoogleAuthStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var hover = false
    @State private var look = CGSize.zero
    @State private var lastActivity = Date()
    @State private var visible = false

    private var mood: LoginMood {
        if auth.isSignedIn { return .success }
        if auth.isLoading { return .loading }
        if auth.errorMessage != nil { return .error }
        return hover ? .stars : .idle
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.90, green: 0.89, blue: 0.87).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 24)
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable().scaledToFit()
                            .frame(width: 86, height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                            .accessibilityLabel("Plantão na Mão")
                        Text("Plantão na Mão")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.085))
                        VStack(spacing: 0) {
                            PipLoginRobot(mood: mood, look: look, lastActivity: lastActivity,
                                          active: visible && scenePhase == .active && !reduceMotion && !AppLaunch.isUITest)
                                .zIndex(1)
                                .padding(.bottom, -30)
                            VStack(spacing: 20) {
                                Text(auth.isSignedIn ? "Bom ter você aqui." : "Sua rotina de plantões.")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.54, green: 0.53, blue: 0.50))
                                Text(auth.isSignedIn ? "Bem-vindo de volta" : "Conecte sua conta")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.085))
                                Button(action: connect) {
                                    GoogleConnectGlyph()
                                        .frame(width: 25, height: 25)
                                        .frame(width: 56, height: 56)
                                        .background(.white, in: Circle())
                                        .overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                                }
                                .buttonStyle(.plain)
                                .disabled(auth.isLoading || auth.isSignedIn)
                                .onHover { value in hover = value; lastActivity = .now }
                                .help("Conectar conta Google")
                                .accessibilityLabel("Conectar conta Google")
                                if auth.isLoading {
                                    Text("Conectando com Google…")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .accessibilityAddTraits(.updatesFrequently)
                                }
                                if let error = auth.errorMessage, !error.isEmpty {
                                    Text(error).font(.caption).foregroundStyle(Color(red: 0.75, green: 0.16, blue: 0.2))
                                        .multilineTextAlignment(.center)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.top, 48)
                            .padding(.bottom, 30)
                            .frame(maxWidth: 380)
                            .background(Color(red: 0.985, green: 0.982, blue: 0.972), in: RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.08), radius: 24, y: 12)
                        }
                        Text("Plantão na Mão 1.6 · macOS")
                            .font(.caption).foregroundStyle(Color.black.opacity(0.45))
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    lastActivity = .now
                    let x = (point.x - geometry.size.width / 2) / max(geometry.size.width / 2, 1)
                    let y = (point.y - geometry.size.height / 2) / max(geometry.size.height / 2, 1)
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                        look = CGSize(width: min(max(x,-1),1), height: min(max(y,-1),1))
                    }
                case .ended: look = .zero
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear { visible = true; lastActivity = .now }
        .onDisappear { visible = false }
    }

    private func connect() {
        lastActivity = .now
        auth.signIn()
    }
}

/// Cabeça branca, tela LED, antena e mãos apoiadas no card, conforme o Swift enviado.
struct PipLoginRobot: View {
    let mood: LoginMood
    let look: CGSize
    let lastActivity: Date
    let active: Bool
    @State private var epoch = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active)) { timeline in
            let t = active ? timeline.date.timeIntervalSince(epoch) : 0
            let sleeping = mood == .idle && timeline.date.timeIntervalSince(lastActivity) > 5 && active
            let actualMood: LoginMood = sleeping ? .sleepy : mood
            let bob = active && !sleeping ? sin(t * .pi / 1.6) * 3 : (sleeping ? 8.0 : 0)
            let green = Color(red: 0.56, green: 0.94, blue: 0.76)
            let tint = actualMood == .error ? Color(red:0.85,green:0.25,blue:0.27) : green
            ZStack {
                VStack(spacing: 0) {
                    Circle().fill(actualMood == .idle || sleeping ? Color.gray : tint)
                        .frame(width: 12, height: 12)
                        .shadow(color: tint.opacity(actualMood == .idle ? 0 : 0.6), radius: 6)
                    Rectangle().fill(Color(white: 0.8)).frame(width: 3, height: 14)
                }.offset(y: -55)
                Capsule().fill(Color(white: 0.88)).frame(width: 148, height: 28)
                RoundedRectangle(cornerRadius: 28).fill(.white)
                    .frame(width: 130, height: 100)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                RoundedRectangle(cornerRadius: 18).fill(Color(red:0.04,green:0.04,blue:0.045))
                    .frame(width: 104, height: 70)
                    .overlay {
                        PipLEDs(mood: actualMood, look: look, time: t, active: active)
                            .frame(width: 92, height: 56)
                    }
                HStack(spacing: 30) {
                    Capsule().fill(.white).frame(width: 32, height: 20)
                    Capsule().fill(.white).frame(width: 32, height: 20)
                }
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                .offset(y: 57)
            }
            .offset(y: bob - (actualMood == .stars ? 5 : 0) - (actualMood == .success ? 12 : 0))
            .rotationEffect(.degrees(actualMood == .error && active ? sin(t*12)*3 : 0))
            .animation(active ? .spring(response:0.4,dampingFraction:0.75) : nil, value: actualMood)
        }
        .frame(width:160,height:150)
        .accessibilityHidden(true)
        .onAppear { epoch = .now }
    }
}

private struct PipLEDs: View {
    let mood: LoginMood
    let look: CGSize
    let time: Double
    let active: Bool
    var body: some View {
        Canvas { context, size in
            let green = Color(red:0.56,green:0.94,blue:0.76)
            let tint = mood == .error ? Color(red:0.85,green:0.25,blue:0.27) : green
            let blink = active && time.truncatingRemainder(dividingBy:3.1) > 2.96
            let step = 3.8
            for y in -5...5 {
                for x in -10...10 {
                    var lit = false
                    var alpha = 1.0
                    if mood == .loading {
                        let r = hypot(Double(x),Double(y))
                        if r >= 3.4 && r <= 4.7 {
                            lit = true
                            let angle = atan2(Double(y),Double(x)) + .pi
                            let chase = ((angle-time*5).truncatingRemainder(dividingBy:2 * .pi)+2 * .pi).truncatingRemainder(dividingBy:2 * .pi)
                            alpha = active ? 0.2+0.8*chase/(2 * .pi) : 0.8
                        }
                    } else {
                        let eyeX = x < 0 ? x+5 : x-5
                        switch mood {
                        case .stars:
                            lit = (eyeX == 0 && abs(y) <= 3) || (y == 0 && abs(eyeX) <= 3) || abs(eyeX)+abs(y) == 2
                        case .success:
                            let rows = ["0110110","1111111","1111111","0111110","0011100","0001000"]
                            let row = y+3, col = eyeX+3
                            if rows.indices.contains(row), (0..<7).contains(col) { lit = Array(rows[row])[col] == "1" }
                        case .sleepy: lit = abs(eyeX) <= 2 && y == 1
                        case .error: lit = abs(eyeX) <= 2 && abs(eyeX) == abs(y)
                        default: lit = eyeX*eyeX+y*y <= 5 && (!blink || y == 0)
                        }
                    }
                    guard lit else { continue }
                    let gaze = mood == .idle ? look : .zero
                    let point = CGPoint(x:size.width/2+Double(x)*step+gaze.width*6,y:size.height/2+Double(y)*step+gaze.height*4)
                    let square = Path(roundedRect:CGRect(x:point.x-1.4,y:point.y-1.4,width:2.8,height:2.8),cornerRadius:0.5)
                    var halo = context
                    halo.addFilter(.blur(radius:2))
                    halo.fill(square,with:.color(tint.opacity(alpha*0.65)))
                    context.fill(square,with:.color(tint.opacity(alpha)))
                }
            }
        }
    }
}

private struct GoogleConnectGlyph: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x:size.width/2,y:size.height/2)
            let radius = size.width*0.36
            let colors: [(Double,Double,Color)] = [(-40,45,Color(red:0.26,green:0.52,blue:0.96)),(45,130,Color(red:0.20,green:0.66,blue:0.33)),(130,205,Color(red:0.98,green:0.74,blue:0.02)),(205,315,Color(red:0.92,green:0.26,blue:0.21))]
            for (from,to,color) in colors {
                var path = Path()
                path.addArc(center:center,radius:radius,startAngle:.degrees(from),endAngle:.degrees(to),clockwise:false)
                context.stroke(path,with:.color(color),style:StrokeStyle(lineWidth:size.width*0.18,lineCap:.butt))
            }
            var crossbar = Path()
            crossbar.move(to:CGPoint(x:center.x,y:center.y))
            crossbar.addLine(to:CGPoint(x:center.x+radius+1,y:center.y))
            context.stroke(crossbar,with:.color(Color(red:0.26,green:0.52,blue:0.96)),lineWidth:size.width*0.18)
        }
        .accessibilityHidden(true)
    }
}

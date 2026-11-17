import SwiftUI
import GoogleSignIn

struct SettingsView: View {
    @EnvironmentObject private var cloud: GoogleSyncController
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @AppStorage("plantao-na-mao.appearance") private var appearance = "system"
    @AppStorage("plantao-na-mao.paymentDay") private var paymentDay = 5
    @AppStorage("plantao-na-mao.nextMonth") private var nextMonth = true
    @State private var showingReports = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let email = cloud.email {
                        Label(email, systemImage: "person.crop.circle.badge.checkmark")
                        Toggle("Sincronização automática", isOn: $cloud.automatic).disabled(!cloud.hasDriveAccess)
                        if cloud.isSyncing {
                            HStack { ProgressView(); Text("Sincronizando seus plantões…") }
                        } else {
                            Button { Task { await cloud.syncNow() } } label: {
                                Label("Sincronizar agora", systemImage: "arrow.triangle.2.circlepath")
                            }.disabled(!cloud.hasDriveAccess)
                        }
                        if let last = cloud.lastSync {
                            LabeledContent("Última sincronização", value: last.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                        }
                        if !cloud.hasDriveAccess { googleButton }
                        Button("Desconectar Google", role: .destructive) { cloud.disconnect() }.disabled(cloud.isConnecting)
                    } else { googleButton }
                    if let error = cloud.errorMessage {
                        Label(error, systemImage: "exclamationmark.icloud").font(.footnote).foregroundStyle(.orange)
                    }
                } header: { Text("Conta Google") } footer: {
                    Text("Seus plantões ficam na pasta privada do app no Google Drive. Após conectar, sincronizamos ao abrir, depois de alterações e periodicamente enquanto o app estiver ativo. Sem internet, tudo continua salvo neste aparelho. A futura versão para Mac poderá usar a mesma conta.")
                }
                Section("Seu estilo") {
                    Picker("Aparência", selection: $appearance) {
                        Text("Automática").tag("system"); Text("Clara").tag("light"); Text("Escura").tag("dark")
                    }
                    ColorChoices(selection: Binding(get: { ShiftColor(rawValue: theme) ?? .mint }, set: { theme = $0.rawValue }))
                }
                Section {
                    Stepper("Dia de pagamento: \(paymentDay)", value: $paymentDay, in: 1...31)
                    Toggle("Receber no mês seguinte", isOn: $nextMonth)
                } header: { Text("Padrão de pagamento") } footer: {
                    Text("Aplicado aos novos plantões. Cada plantão também permite escolher uma data personalizada ou ficar sem previsão. Em meses mais curtos, usamos o último dia do mês. Previsões já salvas são mantidas.")
                }
                Section("Relatórios") {
                    Button { showingReports = true } label: { Label("Exportar para PDF", systemImage: "doc.richtext") }
                    Text("Exporte a escala ou os pagamentos por mês ou por todo o período. Salve em Arquivos, imprima ou compartilhe pelo menu do iPhone.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Plantão na Mão") {
                    Label("Dados salvos neste dispositivo", systemImage: "lock.shield")
                    Text("Seus registros ficam disponíveis sem internet. Desinstalar o app pode apagar os dados locais.").font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("Versão", value: "1.1 · Liquid Glass")
                }
            }.navigationTitle("Ajustes")
                .sheet(isPresented: $showingReports) { ReportView(month: .now) }
        }
    }
    private var googleButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            NativeGoogleSignInButton(enabled: !cloud.isConnecting) { Task { await cloud.connect() } }.frame(height: 48)
            if cloud.isConnecting { ProgressView("Conectando ao Google…") }
        }.padding(.vertical, 4)
    }
}


private struct NativeGoogleSignInButton: UIViewRepresentable {
    let enabled: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.style = .standard
        button.isAccessibilityElement = true
        button.accessibilityLabel = "Entrar com Google"
        button.accessibilityTraits = .button
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }
    func updateUIView(_ button: GIDSignInButton, context: Context) {
        context.coordinator.action = action
        button.isEnabled = enabled
        let desired: GIDSignInButtonColorScheme = scheme == .dark ? .dark : .light
        if button.colorScheme != desired { button.colorScheme = desired }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: GIDSignInButton, context: Context) -> CGSize? {
        let width = proposal.width ?? 312
        return CGSize(width: width, height: 48)
    }
    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

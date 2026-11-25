import SwiftUI

struct MacSettingsView: View {
    @EnvironmentObject private var store: ShiftStore
    @EnvironmentObject private var auth: GoogleAuthStore
    @EnvironmentObject private var cloud: MacSyncController
    @EnvironmentObject private var reminders: ShiftNotifications
    @AppStorage("plantao-na-mao.paymentDay") private var paymentDay = 5
    @AppStorage("plantao-na-mao.nextMonth") private var nextMonth = true
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @State private var report = false
    var body: some View {
        Form {
            Section("Conta Google") {
                HStack(spacing: 16) {
                    MacAvatar(url: auth.photoURL).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(auth.displayName.isEmpty ? "Conecte sua conta" : auth.displayName).font(.headline)
                        if !auth.email.isEmpty { Text(auth.email).font(.caption).foregroundStyle(.secondary) }
                    }
                }.padding(.vertical, 8)
                if auth.isSignedIn {
                    Toggle("Sincronização automática", isOn: $cloud.automatic)
                    Button(cloud.isSyncing ? "Sincronizando…" : "Sincronizar agora") { Task { await cloud.syncNow() } }.disabled(cloud.isSyncing)
                    if let date = cloud.lastSync { LabeledContent("Última sincronização", value: date.formatted(date: .abbreviated, time: .shortened)) }
                    Button("Sair da conta", role: .destructive) { auth.signOut() }
                } else {
                    Button("Conectar conta Google") { auth.signIn() }.disabled(auth.isLoading)
                }
                if let message = cloud.errorMessage ?? auth.errorMessage { Text(message).foregroundStyle(.red).textSelection(.enabled) }
                if let notice = auth.credentialNotice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                    Button("Autorizar sessão salva") { auth.authorizeSessionStorage() }
                }
            }
            Section("Previsão de pagamento") {
                Stepper("Dia padrão: \(paymentDay)", value: $paymentDay, in: 1...31)
                Toggle("Prever para o mês seguinte", isOn: $nextMonth)
                Text("O dia padrão preenche novos plantões. Os pagamentos já cadastrados mantêm suas datas.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Lembretes") {
                Toggle("Avisar antes do plantão", isOn: Binding(get: { reminders.enabled }, set: { enabled in Task { await reminders.setEnabled(enabled) } }))
                    .disabled(reminders.requestingPermission)
                Picker("Antecedência", selection: Binding(get: { reminders.lead }, set: { reminders.setLead($0) })) {
                    ForEach(ReminderLead.allCases) { Text($0.label).tag($0) }
                }
                if reminders.denied { Text("Permita as notificações do Plantão na Mão nos Ajustes do Sistema.").font(.caption).foregroundStyle(.secondary) }
                if let message = reminders.errorMessage { Text(message).foregroundStyle(.red) }
            }
            Section("Widgets do Mac") {
                Text("Adicione Plantão na Mão em Editar Widgets na mesa ou na Central de Notificações. Toque em um dia para abrir o calendário nessa data.")
                Button("Atualizar widget agora") { WidgetBridge.publish(store.shifts) }
                Text(WidgetBridge.statusSummary).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Section("Cor do aplicativo") {
                ColorChoices(selection: Binding(get: { ShiftColor(rawValue: theme) ?? .mint }, set: { theme = $0.rawValue }))
            }
            Section("Relatórios") {
                Button("Exportar agenda ou pagamentos em PDF") { report = true }
                LabeledContent("Versão", value: "1.6 · macOS")
            }
        }.formStyle(.grouped).navigationTitle("Perfil e ajustes")
            .sheet(isPresented: $report) { ReportView(month: Date(), initialAllDates: true) }
    }
}

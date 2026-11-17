import SwiftUI

struct SettingsView: View {
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @AppStorage("plantao-na-mao.appearance") private var appearance = "system"
    @AppStorage("plantao-na-mao.paymentDay") private var paymentDay = 5
    @AppStorage("plantao-na-mao.nextMonth") private var nextMonth = true
    @State private var showingReports = false
    var body: some View {
        NavigationStack {
            Form {
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
                    LabeledContent("Versão", value: "1.0 · edição renovada")
                }
            }.navigationTitle("Ajustes")
                .sheet(isPresented: $showingReports) { ReportView(month: .now) }
        }
    }
}

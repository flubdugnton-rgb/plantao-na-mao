import SwiftUI
#if os(iOS)
import UIKit
typealias ReportColor = UIColor
#else
import AppKit
typealias ReportColor = NSColor
#endif
import UniformTypeIdentifiers

struct PDFFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SharePDF: Identifiable {
    let id = UUID()
    let url: URL
}

#if os(iOS)
struct ActivitySheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif

struct ReportView: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    private let singleShift: Shift?
    private let customShifts: [Shift]?
    private let customPeriod: String?
    private let financialSummary: [String]
    @State private var month: Date
    @State private var kind: ReportKind
    @State private var allDates: Bool
    @State private var filter: PaymentFilter
    @State private var includeNotes = true
    @State private var exporting = false
    @State private var pdf = PDFFile()
    @State private var shared: SharePDF?
    @State private var error: String?

    init(month: Date, singleShift: Shift? = nil, initialKind: ReportKind = .schedule,
         initialAllDates: Bool = false, initialFilter: PaymentFilter = .all, customShifts: [Shift]? = nil, customPeriod: String? = nil, financialSummary: [String] = []) {
        self.singleShift = singleShift
        self.customShifts = customShifts; self.customPeriod = customPeriod; self.financialSummary = financialSummary
        _month = State(initialValue: month); _kind = State(initialValue: initialKind)
        _allDates = State(initialValue: initialAllDates); _filter = State(initialValue: initialFilter)
    }
    private var items: [Shift] {
        if let customShifts { return customShifts }
        if let singleShift { return [singleShift] }
        return Reports.select(store.shifts, kind: kind, month: allDates ? nil : month, filter: kind == .schedule ? .all : filter)
    }
    private var period: String {
        if let customPeriod { return customPeriod }
        return singleShift != nil ? "Plantão individual" : allDates ? "Todo o período" : month.formatted(.dateTime.month(.wide).year()).capitalized
    }
    private var filename: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; f.locale = Locale(identifier: "en_US_POSIX")
        return "Plantao-na-Mao-\(singleShift != nil ? "individual" : kind == .schedule ? "escala" : "pagamentos")-\(allDates ? "completo" : f.string(from: month))"
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Sua rotina em PDF", systemImage: "doc.richtext").font(.title3.bold()).padding(.vertical, 6)
                    Text("Um relatório organizado para guardar, imprimir ou enviar.").foregroundStyle(.secondary)
                }
                if singleShift == nil && customShifts == nil {
                    Section("Conteúdo") {
                        Picker("Relatório", selection: $kind) { ForEach(ReportKind.allCases) { Text($0.rawValue).tag($0) } }
                        Toggle("Todo o período", isOn: $allDates)
                        if !allDates { DatePicker(kind == .schedule ? "Mês dos plantões" : "Mês dos pagamentos", selection: $month, displayedComponents: .date) }

                    }
                }
                Section {
                    Toggle("Incluir observações", isOn: $includeNotes)
                    LabeledContent("Período", value: period)
                    LabeledContent("Registros", value: "\(items.count)")
                    LabeledContent("Valor total", value: Money.format(items.reduce(0) { $0 + $1.amountCents }))
                } footer: {
                    if kind == .payments && !allDates && singleShift == nil { Text("São considerados os vencimentos no mês escolhido. Pagamentos sem previsão aparecem ao selecionar todo o período.") }
                }
                Section {
                    Button { pdf = PDFFile(data: generate()); exporting = true } label: { Label("Salvar PDF em Arquivos", systemImage: "folder") }.disabled(items.isEmpty)
                    Button {
                        do {
                            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PlantaoNaMao-\(UUID().uuidString)", isDirectory: true)
                            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                            let url = directory.appendingPathComponent(filename + ".pdf")
                            try generate().write(to: url, options: .atomic)
                            shared = SharePDF(url: url)
                        } catch { self.error = error.localizedDescription }
                    } label: { Label("Compartilhar ou imprimir PDF", systemImage: "square.and.arrow.up") }.disabled(items.isEmpty)
                } footer: { Text(items.isEmpty ? "Não há registros para exportar neste período." : "No menu de compartilhamento, escolha WhatsApp, Mail, AirDrop ou Imprimir.") }
            }
            .navigationTitle("Exportar PDF").inlineNavigationTitle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Concluir") { dismiss() } } }
            .fileExporter(isPresented: $exporting, document: pdf, contentType: .pdf, defaultFilename: filename) { result in
                if case .failure(let failure) = result { error = failure.localizedDescription }
            }
            .sheet(item: $shared, onDismiss: { shared = nil }) { ActivitySheet(url: $0.url) }
            .alert("Não foi possível exportar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }.editorWindowSize()
    }
    private func generate() -> Data {
        PDFReport.make(shifts: items, title: singleShift == nil ? kind.rawValue : "Detalhes do plantão", period: period,
                       includeNotes: includeNotes, color: ReportColor(ShiftColor.mint.value), summary: financialSummary)
    }
}

#if os(iOS)
enum PDFReport {
    // A4 in points. Text is drawn as selectable text, not as a screenshot.
    static func make(shifts: [Shift], title: String, period: String, includeNotes: Bool, color: UIColor, summary: [String] = []) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: "Plantão na Mão · \(title)", kCGPDFContextCreator as String: "Plantão na Mão"]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        let margin: CGFloat = 40
        let width = bounds.width - margin * 2
        let bottom = bounds.height - 56
        let body = UIFont.systemFont(ofSize: 10)
        let heading = UIFont.boldSystemFont(ofSize: 12)
        let dateFormat = DateFormatter(); dateFormat.locale = Locale(identifier: "pt_BR"); dateFormat.dateFormat = "dd/MM/yyyy"
        let timeFormat = DateFormatter(); timeFormat.locale = Locale(identifier: "pt_BR"); timeFormat.dateFormat = "HH:mm"
        return renderer.pdfData { context in
            var y: CGFloat = 0
            var page = 0
            func beginPage() {
                context.beginPage(); page += 1
                color.setFill(); context.cgContext.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 7))
                ("Plantão na Mão" as NSString).draw(at: CGPoint(x: margin, y: 26), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 21), .foregroundColor: color])
                ("\(title) · \(period)" as NSString).draw(in: CGRect(x: margin, y: 56, width: width, height: 32), withAttributes: [.font: body, .foregroundColor: UIColor.darkGray])
                ("Gerado em \(dateFormat.string(from: Date())) · Página \(page)" as NSString).draw(at: CGPoint(x: margin, y: bounds.height - 32), withAttributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.darkGray])
                y = 99
            }
            func ensure(_ height: CGFloat) { if y + height > bottom { beginPage() } }
            func paragraph(_ text: String, font selectedFont: UIFont? = nil, ink: UIColor = .black) {
                let font = selectedFont ?? body
                let lineHeight = ceil(font.lineHeight) + 3
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
                func drawLine(_ line: String) {
                    ensure(lineHeight)
                    (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attributes)
                    y += lineHeight
                }
                for part in text.components(separatedBy: .newlines) {
                    var line = ""
                    for word in part.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
                        let candidate = line.isEmpty ? word : line + " " + word
                        if (candidate as NSString).size(withAttributes: attributes).width <= width { line = candidate }
                        else {
                            if !line.isEmpty { drawLine(line); line = "" }
                            // Split an exceptionally long unbroken word without clipping.
                            for character in word {
                                let next = line + String(character)
                                if (next as NSString).size(withAttributes: attributes).width > width && !line.isEmpty { drawLine(line); line = "" }
                                line.append(character)
                            }
                        }
                    }
                    drawLine(line)
                }
            }
            beginPage()
            paragraph("\(shifts.count) plantões · \(shifts.reduce(0) { $0 + $1.minutes } / 60)h \(shifts.reduce(0) { $0 + $1.minutes } % 60)min · Total: \(Money.format(shifts.reduce(0) { $0 + $1.amountCents }))", font: heading)
            for line in summary { paragraph(line) }
            y += 14
            for (index, shift) in shifts.enumerated() {
                ensure(110)
                paragraph("\(index + 1). \(shift.title)", font: heading, ink: color)
                paragraph("Local: \(shift.location)")
                paragraph("Plantão: \(dateFormat.string(from: shift.interval.start)) às \(timeFormat.string(from: shift.interval.start)) até \(dateFormat.string(from: shift.interval.end)) às \(timeFormat.string(from: shift.interval.end)) · \(shift.duration)")
                paragraph("Valor: \(shift.amount) · \(shift.amountCents == 0 ? "Sem valor informado" : "Previsto")")
                paragraph("Previsão de pagamento: \(shift.paymentDate.map { dateFormat.string(from: $0) } ?? "Não informada")")
                if includeNotes && !shift.notes.isEmpty { paragraph("Observações: \(shift.notes)") }
                y += 8; ensure(8)
                UIColor(white: 0.88, alpha: 1).setFill(); context.cgContext.fill(CGRect(x: margin, y: y, width: width, height: 0.5)); y += 14
            }
        }
    }
}

#endif

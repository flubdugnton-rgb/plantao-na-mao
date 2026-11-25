import AppKit
import CoreText
import PDFKit
import SwiftUI

struct ActivitySheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.richtext").font(.system(size: 44)).foregroundStyle(.tint)
            Text("Seu relatório está pronto").font(.title2.bold())
            HStack {
                ShareLink(item: url) { Label("Compartilhar", systemImage: "square.and.arrow.up") }
                Button("Abrir PDF") { NSWorkspace.shared.open(url) }
                Button("Imprimir") {
                    PDFDocument(url: url)?.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleDownToFit, autoRotate: true)?.run()
                }
            }
            Button("Concluir") { dismiss() }.keyboardShortcut(.cancelAction)
        }.padding(36).frame(minWidth: 420, minHeight: 220)
    }
}

enum PDFReport {
    /// Core Text keeps reports searchable, paginated and independent of the screen size.
    static func make(shifts: [Shift], title: String, period: String, includeNotes: Bool, color: NSColor, summary: [String] = []) -> Data {
        let data = NSMutableData()
        var bounds = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard let consumer = CGDataConsumer(data: data), let context = CGContext(consumer: consumer, mediaBox: &bounds,
            [kCGPDFContextTitle as String: "Plantão na Mão · \(title)", kCGPDFContextCreator as String: "Plantão na Mão"] as CFDictionary) else { return Data() }
        let margin: CGFloat = 40, width = bounds.width - 80, bottom = bounds.height - 56
        let body = NSFont.systemFont(ofSize: 10), heading = NSFont.boldSystemFont(ofSize: 12)
        let dateFormat = DateFormatter(); dateFormat.locale = Locale(identifier: "pt_BR"); dateFormat.dateFormat = "dd/MM/yyyy"
        let timeFormat = DateFormatter(); timeFormat.locale = Locale(identifier: "pt_BR"); timeFormat.dateFormat = "HH:mm"
        var y: CGFloat = 0, page = 0
        func line(_ text: String, x: CGFloat, y: CGFloat, font: NSFont, ink: NSColor) {
            let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: ink])
            let textLine = CTLineCreateWithAttributedString(attributed)
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: x, y: bounds.height - y - font.ascender)
            CTLineDraw(textLine, context)
        }
        func beginPage() {
            if page > 0 { context.endPDFPage() }
            context.beginPDFPage(nil); page += 1
            context.setFillColor((color.usingColorSpace(.deviceRGB) ?? .systemGreen).cgColor)
            context.fill(CGRect(x: 0, y: bounds.height - 7, width: bounds.width, height: 7))
            line("Plantão na Mão", x: margin, y: 26, font: .boldSystemFont(ofSize: 21), ink: color)
            line("\(title) · \(period)", x: margin, y: 58, font: body, ink: .darkGray)
            line("Gerado em \(dateFormat.string(from: Date())) · Página \(page)", x: margin, y: bounds.height - 32, font: .systemFont(ofSize: 8), ink: .darkGray)
            y = 99
        }
        func ensure(_ height: CGFloat) { if y + height > bottom { beginPage() } }
        func paragraph(_ text: String, font: NSFont? = nil, ink: NSColor = .black) {
            let font = font ?? body
            let height = ceil(font.ascender - font.descender + font.leading) + 3
            func draw(_ text: String) { ensure(height); line(text, x: margin, y: y, font: font, ink: ink); y += height }
            func fits(_ text: String) -> Bool { (text as NSString).size(withAttributes: [.font: font]).width <= width }
            for part in text.components(separatedBy: .newlines) {
                var current = ""
                for word in part.split(whereSeparator: { $0.isWhitespace }).map(String.init) {
                    let candidate = current.isEmpty ? word : current + " " + word
                    if fits(candidate) { current = candidate } else {
                        if !current.isEmpty { draw(current); current = "" }
                        for character in word {
                            if !fits(current + String(character)) && !current.isEmpty { draw(current); current = "" }
                            current.append(character)
                        }
                    }
                }
                draw(current)
            }
        }
        beginPage()
        paragraph("\(shifts.count) plantões · \(shifts.reduce(0) { $0 + $1.minutes } / 60)h · Total: \(Money.format(shifts.reduce(0) { $0 + $1.amountCents }))", font: heading)
        for text in summary { paragraph(text) }
        y += 14
        for (index, shift) in shifts.enumerated() {
            ensure(110)
            paragraph("\(index + 1). \(shift.title)", font: heading, ink: color)
            paragraph("Local: \(shift.location)")
            paragraph("Plantão: \(dateFormat.string(from: shift.interval.start)) às \(timeFormat.string(from: shift.interval.start)) até \(dateFormat.string(from: shift.interval.end)) às \(timeFormat.string(from: shift.interval.end)) · \(shift.duration)")
            paragraph("Valor: \(shift.amount) · \(shift.isPaid ? "Pago" : "Previsto")")
            paragraph("Previsão de pagamento: \(shift.paymentDate.map { dateFormat.string(from: $0) } ?? "Não informada")")
            if includeNotes && !shift.notes.isEmpty { paragraph("Observações: \(shift.notes)") }
            y += 14
        }
        context.endPDFPage(); context.closePDF()
        return data as Data
    }
}

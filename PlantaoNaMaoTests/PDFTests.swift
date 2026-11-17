import XCTest
import PDFKit
@testable import PlantaoNaMao

@MainActor
final class PDFTests: XCTestCase {
    func testLongReportKeepsLastNotesAndUsesMultiplePages() throws {
        let shifts = (1...70).map { index in
            Shift(date: .now, title: "Plantão \(index)", location: "Hospital São José", start: .now, end: .now,
                  notes: String(repeating: "Observações importantes com acentuação. ", count: 15) + "FINAL-\(index)",
                  amountCents: 125050, paymentDate: .now)
        }
        let data = PDFReport.make(shifts: shifts, title: "Escala", period: "Todo o período", includeNotes: true, color: .systemTeal)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1)
        let text = try XCTUnwrap(document.string)
        XCTAssertTrue(text.contains("FINAL-70"))
        XCTAssertTrue(text.contains("Plantão na Mão"))
        XCTAssertTrue(text.contains("Hospital São José"))
        let page = try XCTUnwrap(document.page(at: 0))
        XCTAssertEqual(page.bounds(for: .mediaBox).width, 595.28, accuracy: 0.1)
    }

    func testPrivateNotesCanBeOmitted() throws {
        let shift = Shift(date: .now, title: "Diurno", location: "Clínica", start: .now, end: .now, notes: "NOTA-PRIVADA-123")
        let data = PDFReport.make(shifts: [shift], title: "Plantão", period: "Individual", includeNotes: false, color: .systemBlue)
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertFalse(try XCTUnwrap(document.string).contains("NOTA-PRIVADA-123"))
    }

    func testOldRecordsAndNewPaymentDetailsAreStoredUnderOriginalKey() throws {
        let suite = "PlantaoTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let oldJSON = "[{\"id\":\"A0000000-0000-0000-0000-000000000001\",\"date\":0,\"title\":\"Antigo\",\"location\":\"Hospital\",\"start\":0,\"end\":43200,\"color\":\"mint\",\"notes\":\"Preservar\"}]"
        defaults.set(Data(oldJSON.utf8), forKey: "plantao-na-mao.shifts")
        let store = ShiftStore(defaults: defaults)
        XCTAssertEqual(store.shifts.count, 1)
        var shift = try XCTUnwrap(store.shifts.first)
        shift.amountCents = 10050; shift.paymentDate = .now; shift.isPaid = true
        store.save(shift)
        let reloaded = ShiftStore(defaults: defaults)
        XCTAssertEqual(reloaded.shifts, [shift])
        XCTAssertTrue(reloaded.canWrite)
    }

    func testUnreadableStorageIsNeverOverwritten() throws {
        let suite = "PlantaoTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = Data("broken-data".utf8)
        defaults.set(original, forKey: "plantao-na-mao.shifts")
        let store = ShiftStore(defaults: defaults)
        XCTAssertFalse(store.canWrite)
        store.save(Shift(date: .now, title: "Novo", location: "Hospital", start: .now, end: .now))
        XCTAssertEqual(defaults.data(forKey: "plantao-na-mao.shifts"), original)
    }

    func testDeletionSurvivesRelaunchAndOfflineDeviceMerge() throws {
        let suite = "PlantaoTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ShiftStore(defaults: defaults)
        let shift = Shift(date: .now, title: "Excluir", location: "Hospital", start: .now, end: .now)
        store.save(shift)
        let offlineCopy = store.snapshot
        store.remove(shift)
        let reopened = ShiftStore(defaults: defaults)
        try reopened.mergeRemote(offlineCopy)
        XCTAssertTrue(reopened.shifts.isEmpty)
        XCTAssertEqual(reopened.snapshot.deletions.count, 1)
    }
}

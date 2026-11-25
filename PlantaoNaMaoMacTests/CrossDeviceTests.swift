import XCTest

@MainActor
final class CrossDeviceTests: XCTestCase {
    func testIOSAndMacEditsRoundTripWithoutLosingFinancialFields() throws {
        let iosDefaults = UserDefaults(suiteName: "ios-test-\(UUID())")!
        let macDefaults = UserDefaults(suiteName: "mac-test-\(UUID())")!
        let ios = ShiftStore(defaults: iosDefaults), mac = ShiftStore(defaults: macDefaults)
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        let start = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: day)!
        let end = Calendar.current.date(byAdding: .hour, value: 12, to: start)!
        var shift = Shift(date: day, title: "Plantão noturno", location: "Hospital", start: start, end: end,
                          color: .coral, notes: "Observação com acentuação", amountCents: 48000,
                          paymentDate: ShiftRules.paymentDate(for: day, day: 5, nextMonth: true),
                          pricingMode: .hour, rateCents: 4000)
        XCTAssertTrue(ios.save(shift))
        // Foundation's exact schema is the transport used by iOS and the native Mac target.
        let wire = try JSONEncoder().encode(ios.snapshot)
        try mac.mergeRemote(JSONDecoder().decode(SyncSnapshot.self, from: wire))
        XCTAssertEqual(mac.shifts, ios.shifts)
        XCTAssertEqual(mac.shifts.first?.pricingMode, .hour)
        shift.isPaid = true; shift.notes += " · Atualizado no Mac"
        XCTAssertTrue(mac.save(shift))
        try ios.mergeRemote(JSONDecoder().decode(SyncSnapshot.self, from: JSONEncoder().encode(mac.snapshot)))
        XCTAssertEqual(ios.shifts.first, shift)
        mac.remove(shift)
        try ios.mergeRemote(mac.snapshot)
        XCTAssertTrue(ios.shifts.isEmpty)
        try ios.mergeRemote(JSONDecoder().decode(SyncSnapshot.self, from: wire))
        XCTAssertTrue(ios.shifts.isEmpty, "Uma cópia antiga não pode recuperar um plantão excluído no Mac.")
    }

    func testConcurrentOfflineEditsFromBothDevicesArePreserved() throws {
        let now = Date()
        let first = Shift(date: now, title: "iPhone", location: "Hospital A", start: now, end: now, color: .blue)
        let second = Shift(date: now, title: "Mac", location: "Hospital B", start: now, end: now, color: .emerald)
        let ios = SyncSnapshot(records: [SyncRecord(shift: first, modifiedAt: now, writerID: "ios")])
        let mac = SyncSnapshot(records: [SyncRecord(shift: second, modifiedAt: now, writerID: "mac")])
        XCTAssertEqual(Set(SyncMerge.combine([ios, mac]).visibleShifts.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(SyncMerge.combine([ios, mac]), SyncMerge.combine([mac, ios]))
    }

    func testWidgetReadsTheSameUpdatedCalendarAndDeepLinksToTheDay() throws {
        let date = Calendar.current.startOfDay(for: Date())
        let shift = Shift(date: date, title: "Confidencial", location: "Hospital", start: date, end: date, color: .red, notes: "Privado", amountCents: 90000)
        let snapshot = WidgetSnapshot(shifts: [shift], appearance: "dark", updatedAt: date)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = WidgetSnapshotFile(url: directory.appendingPathComponent("calendar.json"))
        try file.save(snapshot)
        XCTAssertEqual(file.load(), snapshot)
        let payload = WidgetCalendarPayload(snapshot: snapshot)
        let data = try JSONEncoder().encode(payload)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Confidencial"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("Hospital"))
        XCTAssertEqual(payload.days.first?.colors, [.red])
        XCTAssertEqual(WidgetData.date(from: WidgetData.url(for: date)), date)
    }

    func testOAuthSharesTheGoogleProjectButNotTheKepleraeData() {
        XCTAssertTrue(GoogleCloudConfiguration.iOSClientID.hasPrefix(GoogleCloudConfiguration.projectNumber + "-"))
        XCTAssertTrue(CrossPlatformOAuth.nativeClientID.hasPrefix(GoogleCloudConfiguration.projectNumber + "-"))
        XCTAssertEqual(MacOAuthConfiguration.requestedScopes, ["openid", "profile", "email", "https://www.googleapis.com/auth/drive.appdata"])
        XCTAssertTrue(MacOAuthConfiguration.isCallback(MacOAuthConfiguration.redirectURL))
        XCTAssertFalse(MacOAuthConfiguration.isCallback(URL(string: "\(MacOAuthConfiguration.callbackScheme)://wrong/oauthredirect")!))
        XCTAssertEqual(GoogleCloudConfiguration.syncFilePrefix, "plantao-na-mao-sync-v1-")
        XCTAssertFalse(GoogleCloudConfiguration.syncFilePrefix.contains("keplerae"))
    }
}

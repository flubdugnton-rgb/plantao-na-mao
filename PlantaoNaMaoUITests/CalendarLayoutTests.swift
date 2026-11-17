import XCTest

final class CalendarLayoutTests: XCTestCase {
    @MainActor
    func testCalendarRemainsFixedWhileAgendaScrolls() throws {
        let app = XCUIApplication()
        executionTimeAllowance = 120
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        let calendar = app.otherElements["fixed-calendar"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["large-current-month"].exists)
        XCTAssertFalse(app.staticTexts["Tudo sob controle.\nUm plantão por vez."].exists)
        let currentRow = app.buttons["shift-row-17"].firstMatch
        XCTAssertTrue(currentRow.waitForExistence(timeout: 10))
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: currentRow)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed)
        let before = calendar.frame
        attach(name: "01-Escala-Liquid-Glass")
        let agenda = app.descendants(matching: .any)["scrolling-agenda"]
        XCTAssertTrue(agenda.exists)
        agenda.swipeUp()
        agenda.swipeUp()
        XCTAssertEqual(calendar.frame.minY, before.minY, accuracy: 1)
        XCTAssertEqual(calendar.frame.height, before.height, accuracy: 1)
        attach(name: "02-Calendario-fixo-apos-rolagem")
        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(app.buttons["Entrar com Google"].waitForExistence(timeout: 10))
        attach(name: "03-Ajustes-e-Google")
    }

    @MainActor
    func testPresetKeepsChosenDayAndSavesFromForm() throws {
        let app = XCUIApplication()
        executionTimeAllowance = 120
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        let day = app.buttons["calendar-day-20"]
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.tap()
        app.buttons["Adicionar plantão"].tap()
        let presets = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "reuse-"))
        XCTAssertTrue(presets.firstMatch.waitForExistence(timeout: 10))
        presets.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["shift-selected-date"].label.contains("20"))
        let save = app.buttons["save-shift"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["Adicionar plantão"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["shift-row-20"].waitForExistence(timeout: 10))
        app.buttons["shift-row-20"].tap()
        XCTAssertTrue(app.staticTexts["shift-selected-date"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["shift-selected-date"].label.contains("20"))
        attach(name: "04-Preset-salvo-no-dia-escolhido")
    }

    @MainActor
    private func attach(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}

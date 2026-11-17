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
        let before = calendar.frame
        attach(name: "01-Escala-Liquid-Glass")
        let agenda = app.scrollViews["scrolling-agenda"]
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
    private func attach(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}

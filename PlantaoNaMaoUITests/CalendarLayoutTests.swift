import XCTest

final class CalendarLayoutTests: XCTestCase {
    @MainActor
    func testCalendarRemainsFixedWhileAgendaScrolls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        let calendar = app.otherElements["fixed-calendar"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["large-current-month"].exists)
        XCTAssertFalse(app.staticTexts["Tudo sob controle.\nUm plantão por vez."].exists)
        let before = calendar.frame
        attach(app, name: "01-Escala-Liquid-Glass")
        let agenda = app.scrollViews["scrolling-agenda"]
        XCTAssertTrue(agenda.exists)
        agenda.swipeUp()
        agenda.swipeUp()
        XCTAssertEqual(calendar.frame.minY, before.minY, accuracy: 1)
        XCTAssertEqual(calendar.frame.height, before.height, accuracy: 1)
        attach(app, name: "02-Calendario-fixo-apos-rolagem")
        app.tabBars.buttons["Ajustes"].tap()
        attach(app, name: "03-Ajustes-e-Google")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
    }
}

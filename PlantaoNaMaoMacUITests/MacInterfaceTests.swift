import XCTest

final class MacInterfaceTests: XCTestCase {
    @MainActor
    func testLoginUsesPlantaoBrandAndGoogleButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        XCTAssertTrue(app.buttons["Conectar conta Google"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Plantão na Mão"].exists)
        XCTAssertFalse(app.textFields["Email"].exists)
        attach("01-Login-macOS")
    }
    @MainActor
    func testSidebarCalendarAndNativeEditor() {
        let app = signedInApp()
        let calendar = app.otherElements["fixed-calendar"]
        XCTAssertTrue(calendar.waitForExistence(timeout: 15))
        app.buttons["Próximo mês"].click()
        XCTAssertTrue(app.staticTexts["Dezembro"].waitForExistence(timeout: 5))
        app.buttons["Mês anterior"].click()
        app.buttons["calendar-day-20"].click()
        app.buttons["Adicionar plantão"].click()
        let title = app.textFields["shift-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.click(); title.typeText("Plantao criado no Mac")
        app.buttons["save-shift"].click()
        XCTAssertTrue(app.staticTexts["Plantao criado no Mac"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["sidebar-1"].click()
        XCTAssertTrue(app.datePickers["finance-start"].waitForExistence(timeout: 5))
        app.buttons["sidebar-2"].click()
        XCTAssertTrue(app.staticTexts["Competência do painel"].waitForExistence(timeout: 5))
        app.buttons["sidebar-3"].click()
        XCTAssertTrue(app.staticTexts["Clínica Central"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["sidebar-0"].click()
        attach("02-Calendario-e-barra-lateral-macOS")
    }
    @MainActor
    func testThemeAndProfileExposeWidgetsAndSync() {
        let app = signedInApp()
        XCTAssertTrue(app.buttons["Tema Escuro"].waitForExistence(timeout: 15))
        app.buttons["Tema Escuro"].click()
        app.buttons["mac-profile"].click()
        XCTAssertTrue(app.buttons["Atualizar widget agora"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sincronizar agora"].firstMatch.exists)
        attach("03-Perfil-widgets-e-sincronizacao-macOS")
    }
    @MainActor
    private func signedInApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-signed-in", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR"]
        app.launch()
        return app
    }
    @MainActor
    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

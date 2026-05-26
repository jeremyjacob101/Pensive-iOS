import XCTest

final class PensiveUITests: XCTestCase {
    func testLaunchShowsRootView() {
        let app = XCUIApplication()
        app.launchEnvironment["APP_ENV_NAME"] = "UITest"
        app.launchEnvironment["CONVEX_BASE_URL"] = "https://ui-test.convex.cloud"
        app.launchEnvironment["CONVEX_HTTP_ACTION_BASE_URL"] = "https://ui-test.convex.cloud"
        app.launchEnvironment["AUTH_CLIENT_ID"] = "ui-test-client"
        app.launchEnvironment["LOG_LEVEL"] = "debug"
        app.launchEnvironment["UI_TEST_AUTHENTICATED_USER_ID"] = "ui-test-user"
        app.launchEnvironment["UI_TEST_TRACKING_FIXTURE"] = "1"
        app.launchEnvironment["UI_TEST_NOTEPAD_FIXTURE"] = "1"
        app.launch()

        XCTAssertTrue(app.otherElements["root_view"].waitForExistence(timeout: 10))
    }

    func testTrackingRowPersistsStartMonthAndBufferWithinSession() {
        let app = XCUIApplication()
        app.launchEnvironment["APP_ENV_NAME"] = "UITest"
        app.launchEnvironment["CONVEX_BASE_URL"] = "https://ui-test.convex.cloud"
        app.launchEnvironment["CONVEX_HTTP_ACTION_BASE_URL"] = "https://ui-test.convex.cloud"
        app.launchEnvironment["AUTH_CLIENT_ID"] = "ui-test-client"
        app.launchEnvironment["LOG_LEVEL"] = "debug"
        app.launchEnvironment["UI_TEST_AUTHENTICATED_USER_ID"] = "ui-test-user"
        app.launchEnvironment["UI_TEST_TRACKING_FIXTURE"] = "1"
        app.launchEnvironment["UI_TEST_NOTEPAD_FIXTURE"] = "1"
        app.launch()

        openTab(named: "Tracking", app: app)
        let picker = app.buttons["tracking_start_month_housing"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        app.buttons["2026-03"].tap()

        let buffer = app.steppers["tracking_buffer_housing"]
        XCTAssertTrue(buffer.exists)
        let beforeLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Buffer Months:'")).firstMatch.label
        buffer.buttons["tracking_buffer_housing-Increment"].tap()
        let incremented = waitForBufferLabelChange(app: app, from: beforeLabel, timeout: 3)
        XCTAssertTrue(incremented, "Expected buffer label to change after increment.")
        let afterLabel = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Buffer Months:'")).firstMatch.label

        app.terminate()
        app.launch()
        openTab(named: "Tracking", app: app)
        XCTAssertTrue(app.buttons["tracking_start_month_housing"].exists)
        XCTAssertTrue(app.staticTexts[afterLabel].waitForExistence(timeout: 3))
    }

    func testNotepadNotesAndTablesWorkflow() {
        let app = XCUIApplication()
        app.launchEnvironment["APP_ENV_NAME"] = "UITest"
        app.launchEnvironment["CONVEX_BASE_URL"] = "https://ui-test.convex.cloud"
        app.launchEnvironment["CONVEX_HTTP_ACTION_BASE_URL"] = "https://ui-test.convex.cloud"
        app.launchEnvironment["AUTH_CLIENT_ID"] = "ui-test-client"
        app.launchEnvironment["LOG_LEVEL"] = "debug"
        app.launchEnvironment["UI_TEST_AUTHENTICATED_USER_ID"] = "ui-test-user"
        app.launchEnvironment["UI_TEST_NOTEPAD_FIXTURE"] = "1"
        app.launch()

        openTab(named: "Notepad", app: app)

        let noteTitle = app.textFields["notepad_note_title_note-1"]
        XCTAssertTrue(noteTitle.waitForExistence(timeout: 10))
        noteTitle.tap()

        app.segmentedControls.buttons["Tables"].tap()
        let tableTitle = app.textFields["notepad_table_title_table-1"]
        XCTAssertTrue(tableTitle.waitForExistence(timeout: 10))

        let cell = app.textFields["notepad_cell_table-1_1_1"]
        XCTAssertTrue(cell.exists)
        cell.tap()
    }

    private func waitForBufferLabelChange(app: XCUIApplication, from oldValue: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let label = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Buffer Months:'")).firstMatch.label
            if !label.isEmpty && label != oldValue { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func openTab(named tabName: String, app: XCUIApplication) {
        let direct = app.tabBars.buttons[tabName]
        if direct.waitForExistence(timeout: 1) {
            direct.tap()
            return
        }

        for _ in 0 ..< 3 {
            let more = app.tabBars.buttons["More"]
            if more.waitForExistence(timeout: 1) {
                more.tap()
            }
            let overflowItem = app.tables.staticTexts[tabName]
            if overflowItem.waitForExistence(timeout: 1) {
                overflowItem.tap()
                return
            }
        }

        XCTFail("Could not open tab named \(tabName)")
    }
}

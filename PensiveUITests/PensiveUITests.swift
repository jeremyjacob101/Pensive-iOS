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
        app.launch()

        if app.tabBars.buttons["Tracking"].exists {
            app.tabBars.buttons["Tracking"].tap()
        } else {
            app.tabBars.buttons["More"].tap()
            app.tables.staticTexts["Tracking"].tap()
        }
        let picker = app.buttons["tracking_start_month_housing"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        app.buttons["2026-03"].tap()

        let buffer = app.steppers["tracking_buffer_housing"]
        XCTAssertTrue(buffer.exists)
        buffer.buttons["tracking_buffer_housing-Increment"].tap()
        XCTAssertTrue(app.staticTexts["Buffer Months: 1"].waitForExistence(timeout: 3))

        app.terminate()
        app.launch()
        if app.tabBars.buttons["Tracking"].exists {
            app.tabBars.buttons["Tracking"].tap()
        } else {
            app.tabBars.buttons["More"].tap()
            app.tables.staticTexts["Tracking"].tap()
        }
        XCTAssertTrue(app.buttons["tracking_start_month_housing"].exists)
        XCTAssertTrue(app.staticTexts["Buffer Months: 1"].waitForExistence(timeout: 3))
    }
}

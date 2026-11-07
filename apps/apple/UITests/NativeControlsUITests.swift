import XCTest

final class NativeControlsUITests: XCTestCase {
    @MainActor func testNativeControlsFitBothOrientationsAndStayFolded() {
        let app = XCUIApplication()
        app.launchArguments = ["--native-controls-smoke"]
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let reveal = app.buttons["唤出原生控制条"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 30))
        reveal.tap()
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        let play = app.buttons["暂停"], next = app.buttons["下一首"], more = app.buttons["更多播放设置"]
        print("Native control geometry: window=\(app.frame), play=\(play.frame), next=\(next.frame), more=\(more.frame)")
        for control in [play, next, more] {
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.width, 43)
            XCTAssertTrue(app.frame.contains(control.frame), "Control must stay within the device window")
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "native-landscape-controls"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(app.staticTexts["原生控制条已收起"].waitForExistence(timeout: 10))
        // Regression: removing the bar must not reveal it again via onDisappear.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertFalse(app.buttons["暂停"].exists)
        XCUIDevice.shared.orientation = .portrait
        reveal.tap()
        XCTAssertTrue(app.buttons["暂停"].isHittable)
        app.buttons["暂停"].tap()
        XCTAssertTrue(app.buttons["播放"].waitForExistence(timeout: 3))
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "native-portrait-controls"; portrait.lifetime = .keepAlways; add(portrait)
    }
}

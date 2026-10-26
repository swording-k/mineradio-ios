import XCTest

final class OfficialLoginUITests: XCTestCase {
    @MainActor func verifyOfficialSheet(_ provider: String, title: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--apple-official-login-smoke", provider]
        app.launch()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 25))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 25))
        XCTAssertTrue(app.staticTexts["官方登录入口已打开"].waitForExistence(timeout: 45))
        // Third-party QR images have no stable accessibility label. Capture the
        // rendered panel for visual review; do not mistake an unlabeled image for
        // a missing QR, or treat this smoke test as successful authorization.
        if provider == "qq" { sleep(8) }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "official-\(provider)-login-page"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["取消"].tap()
        XCTAssertFalse(app.navigationBars[title].waitForExistence(timeout: 3))
        app.terminate()
    }
    @MainActor func testLocalAudioClockAndAnalysedSignal() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--apple-audio-smoke"]
        app.launch()
        let button = app.buttons["播放测试音"]
        XCTAssertTrue(button.waitForExistence(timeout: 45))
        button.tap()
        XCTAssertTrue(app.staticTexts["音频链路通过"].waitForExistence(timeout: 25))
        app.terminate()
    }
    @MainActor func testSpeedAudioClockAndAnalysedSignal() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--apple-audio-smoke"]
        app.launch()
        defer { app.terminate() }
        let button = app.buttons["播放1.5倍测试音"]
        XCTAssertTrue(button.waitForExistence(timeout: 45))
        button.tap()
        XCTAssertTrue(app.staticTexts["音频链路通过"].waitForExistence(timeout: 25))
    }
    @MainActor func testPausedSchedulerAndTouchWake() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--apple-power-smoke"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.buttons["检查暂停调度"].waitForExistence(timeout: 45))
        app.buttons["检查暂停调度"].tap()
        let passed = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "暂停调度通过：")).firstMatch
        XCTAssertTrue(passed.waitForExistence(timeout: 25))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "foreground-paused-frame-count"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["唤醒播放界面"].tap()
        XCTAssertTrue(app.staticTexts["触控唤醒通过"].waitForExistence(timeout: 5))
    }
    @MainActor func testQQOfficialLoginSheetAndCancel() throws { try verifyOfficialSheet("qq", title: "QQ 音乐官方登录") }
    @MainActor func testKugouOfficialLoginSheetAndCancel() throws { try verifyOfficialSheet("kugou", title: "酷狗音乐官方登录") }
}

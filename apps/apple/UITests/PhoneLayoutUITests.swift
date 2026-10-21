import XCTest

/// Runs the bundled original DOM/CSS in WebKit. Fixture-only launch state contains
/// no accounts or provider media; this is not a playback/authorization test.
final class PhoneLayoutUITests: XCTestCase {
    @MainActor func testPortraitLandscapeVolumeAndPanelClose() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--apple-layout-smoke"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let inspect = app.buttons["检查手机布局"]
        XCTAssertTrue(inspect.waitForExistence(timeout: 45))
        inspect.tap()
        XCTAssertTrue(app.staticTexts["布局检查通过"].waitForExistence(timeout: 10))
        app.webViews.firstMatch.pinch(withScale: 1.5, velocity: 1)
        XCTAssertTrue(app.staticTexts["双指缩放已触发"].waitForExistence(timeout: 5))
        let more = app.buttons["更多播放控制"]
        XCTAssertTrue(more.isHittable)
        XCTAssertEqual(more.frame.width, 44, accuracy: 1, "Scene pinch must not zoom the entire page")
        XCTAssertLessThan(app.buttons["播放/暂停"].frame.height, 70)
        more.tap()
        let volume = app.buttons["音量 / 静音"]
        XCTAssertTrue(volume.isHittable)
        volume.tap()
        XCTAssertTrue(app.sliders["音量"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["音量"].isHittable)
        inspect.tap()
        XCTAssertTrue(app.staticTexts["布局检查通过"].waitForExistence(timeout: 10))
        volume.tap()
        app.buttons["收起播放控制条"].tap()
        XCTAssertFalse(app.buttons["播放/暂停"].isHittable)
        app.buttons["展开播放器控制台"].tap()
        XCTAssertTrue(app.buttons["播放/暂停"].isHittable)
        let console = app.buttons["视觉控制台"]
        XCTAssertTrue(console.isHittable)
        console.tap()
        let close = app.buttons["关闭视觉控制台"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        inspect.tap()
        XCTAssertTrue(app.staticTexts["布局检查通过"].waitForExistence(timeout: 10))
        if !volume.isHittable { more.tap() }
        XCTAssertTrue(volume.isHittable)
        volume.tap()
        XCTAssertTrue(app.sliders["音量"].isHittable)
        inspect.tap()
        XCTAssertTrue(app.staticTexts["布局检查通过"].waitForExistence(timeout: 10))
        volume.tap()
        app.buttons["打开歌单与播放队列"].tap()
        XCTAssertTrue(app.buttons["当前队列"].exists) // Empty fixture queue is disabled upstream.
        XCTAssertTrue(app.buttons["我的歌单"].isHittable)
        XCTAssertTrue(app.buttons["我的播客"].isHittable)
        XCTAssertTrue(app.buttons["关闭歌单面板"].isHittable)
        app.buttons["关闭歌单面板"].tap()
        XCTAssertFalse(app.buttons["当前队列"].isHittable)
        app.buttons["打开歌单与播放队列"].tap()
        app.buttons["关闭歌单并返回播放器"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertFalse(app.buttons["当前队列"].isHittable)
        let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        evidence.name = "webkit-phone-landscape-fixture"
        evidence.lifetime = .keepAlways
        add(evidence)
    }
    @MainActor func testTouchControlsAutoHideAndRestore() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--apple-layout-smoke", "--apple-controls-auto-hide-smoke"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate() }
        let more = app.buttons["更多播放控制"]
        XCTAssertTrue(more.waitForExistence(timeout: 45))
        app.buttons["展开播放器控制台"].tap()
        // Measure the 1.5-second dwell and actual play-button hit test in the
        // WebKit clock, avoiding slow accessibility queries consuming idle time.
        XCTAssertTrue(app.staticTexts["控制条持续可用"].waitForExistence(timeout: 12))
        let hidden = NSPredicate(format: "hittable == false")
        expectation(for: hidden, evaluatedWith: more)
        waitForExpectations(timeout: 12)
        app.buttons["展开播放器控制台"].tap()
        XCTAssertTrue(more.isHittable)
    }
}

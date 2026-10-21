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
        let volume = app.buttons["音量 / 静音"]
        XCTAssertTrue(volume.isHittable)
        volume.tap()
        XCTAssertTrue(app.sliders["音量"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["音量"].isHittable)
        inspect.tap()
        XCTAssertTrue(app.staticTexts["布局检查通过"].waitForExistence(timeout: 10))
        volume.tap()
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
        XCTAssertTrue(volume.isHittable)
        volume.tap()
        XCTAssertTrue(app.sliders["音量"].isHittable)
        inspect.tap()
        XCTAssertTrue(app.staticTexts["布局检查通过"].waitForExistence(timeout: 10))
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = "webkit-phone-landscape-fixture"
        evidence.lifetime = .keepAlways
        add(evidence)
    }
}

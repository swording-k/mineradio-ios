import XCTest

final class GuideOverlayUITests: XCTestCase {
    @MainActor func testGuideRemainsTappableAcrossRotation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--apple-layout-smoke"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let launch = app.buttons["检查引导覆盖"]
        XCTAssertTrue(launch.waitForExistence(timeout: 45))
        launch.tap()
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            let next = app.buttons["下一步"]
            XCTAssertTrue(next.waitForExistence(timeout: 8))
            XCTAssertTrue(next.isHittable)
            XCTAssertGreaterThanOrEqual(next.frame.height, 43)
            next.tap()
            let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            evidence.name = "guide-overlay-\(orientation.rawValue)"
            evidence.lifetime = .keepAlways
            add(evidence)
        }
        let skip = app.buttons["跳过"]
        XCTAssertTrue(skip.isHittable)
        skip.tap()
        XCTAssertFalse(app.buttons["下一步"].isHittable)
    }
}

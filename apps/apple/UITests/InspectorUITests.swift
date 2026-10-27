import XCTest
/// 开发用：把 App 放到指定方向后保持运行，期间由 Documents/inspect.js 驱动界面、simctl 截图检查。
/// 方向由环境变量 MR_INSPECT_ORIENTATION（portrait / landscape）控制，时长由 MR_INSPECT_SECONDS 控制。
/// 不做断言，不访问账号；默认不在常规测试中长时间运行（未设置时长则立即结束）。
final class InspectorUITests: XCTestCase {
    @MainActor func testHoldForInspection() throws {
        let env = ProcessInfo.processInfo.environment
        let seconds = Double(env["MR_INSPECT_SECONDS"] ?? "") ?? 0
        guard seconds > 0 else { return }
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = env["MR_INSPECT_ORIENTATION"] == "landscape" ? .landscapeLeft : .portrait
        app.launch()
        Thread.sleep(forTimeInterval: seconds)
        XCUIDevice.shared.orientation = .portrait
    }
}

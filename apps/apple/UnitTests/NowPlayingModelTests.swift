import XCTest
@testable import Mineradio

@MainActor final class NowPlayingModelTests: XCTestCase {
    private func payload(_ changes: [String: Any] = [:]) -> [String: Any] {
        var state: [String: Any] = ["hasSong": true, "playing": true, "title": "Test", "autoHide": true]
        state.merge(changes) { _, new in new }
        return ["type": "state", "state": state]
    }
    func testEndingAbsentInteractionDoesNotResurrectHiddenBar() {
        let model = NowPlayingModel(systemIntegration: false)
        model.receive(payload()); model.barVisible = false
        model.setInteracting(false)
        XCTAssertFalse(model.barVisible)
    }
    func testDisablingAutoHideRevealsControls() {
        let model = NowPlayingModel(systemIntegration: false)
        model.receive(payload()); model.barVisible = false
        model.receive(payload(["autoHide": false]))
        XCTAssertTrue(model.barVisible)
    }
    func testClosingPanelRevealsControls() {
        let model = NowPlayingModel(systemIntegration: false)
        model.receive(payload(["panel": true])); model.barVisible = false
        model.receive(payload())
        XCTAssertTrue(model.barVisible)
    }
    func testProgressUpdatesDoNotUnhideControls() {
        let model = NowPlayingModel(systemIntegration: false)
        model.receive(payload()); model.barVisible = false
        model.receive(payload(["current": 10, "duration": 100]))
        XCTAssertFalse(model.barVisible)
    }
    func testClearingQueueHidesAndResetsControls() {
        let model = NowPlayingModel(systemIntegration: false)
        model.receive(payload()); model.setInteracting(true)
        model.receive(payload(["hasSong": false, "playing": false]))
        XCTAssertFalse(model.showsBar)
        XCTAssertNil(model.coverImage)
    }
}

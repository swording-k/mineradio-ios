import UIKit

/// 移动端专属设置（视觉控制台「手机 / 平板」）：播放时屏幕常亮、横竖屏锁定、按键震动反馈。
@MainActor final class AppleDeviceSettings {
    static let shared = AppleDeviceSettings()
    private(set) var haptics = true
    private(set) var mask: UIInterfaceOrientationMask = .all

    func apply(keepAwake: Bool, haptics: Bool, orientation: String) {
        UIApplication.shared.isIdleTimerDisabled = keepAwake
        self.haptics = haptics
        let next: UIInterfaceOrientationMask = orientation == "portrait" ? .portrait : (orientation == "landscape" ? .landscape : .all)
        guard next != mask else { return }
        mask = next
        for scene in UIApplication.shared.connectedScenes {
            guard let scene = scene as? UIWindowScene else { continue }
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: next)) { _ in }
        }
    }

    func tap() {
        guard haptics else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

/// 让横竖屏锁定对整个 App 生效。
final class AppleAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated { AppleDeviceSettings.shared.mask }
    }
}

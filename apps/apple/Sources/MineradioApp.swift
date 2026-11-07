import SwiftUI

@main struct MineradioApp: App {
    @UIApplicationDelegateAdaptor(AppleAppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                Color.black
            } else {
                #if targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains("--native-controls-smoke") {
                    NativeControlsSmoke().preferredColorScheme(.dark)
                } else {
                    PlayerHost().preferredColorScheme(.dark)
                }
                #else
                PlayerHost().preferredColorScheme(.dark)
                #endif
            }
            #else
            PlayerHost().preferredColorScheme(.dark)
            #endif
        }
    }
}

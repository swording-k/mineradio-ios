import SwiftUI

@main struct MineradioApp: App {
    @UIApplicationDelegateAdaptor(AppleAppDelegate.self) private var appDelegate
    var body: some Scene { WindowGroup { PlayerHost().preferredColorScheme(.dark) } }
}

import SwiftUI
import AVFAudio

@main struct MineradioApp: App {
    init() {
        // Enables playback while the app is foregrounded and the mute switch is on.
        // Background audio requires separate lifecycle verification and is not claimed here.
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default) }
        catch { NSLog("Mineradio audio session configuration failed: %@", error.localizedDescription) }
    }
    var body: some Scene { WindowGroup { PlayerHost().preferredColorScheme(.dark) } }
}

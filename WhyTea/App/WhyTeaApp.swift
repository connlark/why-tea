import AVFoundation
import OSLog
import SwiftUI

@main
struct WhyTeaApp: App {
    private static let logger = Logger(subsystem: "com.connor.whytea", category: "App")

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            Self.logger.error("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(.red)
        }
    }
}

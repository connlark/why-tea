import AVFoundation
import OSLog
import SwiftUI
import WhyTeaYouTube

@main
struct WhyTeaApp: App {
    private static let logger = Logger(subsystem: "com.connor.whytea", category: "App")

    private let service: any YouTubeService
    @State private var navigation: NavigationStore

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        } catch {
            Self.logger.error("Audio session setup failed: \(error.localizedDescription)")
        }

        let navigation = NavigationStore()
        #if DEBUG
        service = DebugLaunchArguments.usesFixtures ? FixtureYouTubeService() : YouTubeClient()
        // App.init runs once per process, which makes cold-launch handling
        // one-shot without any view lifecycle involved.
        navigation.applyLaunch(
            section: DebugLaunchArguments.section,
            searchQuery: DebugLaunchArguments.searchQuery,
            openURL: DebugLaunchArguments.openURL
        )
        #else
        service = YouTubeClient()
        #endif
        self.navigation = navigation
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(navigation)
                .environment(\.youTubeService, service)
                .tint(.red)
        }
        .commands {
            SectionCommands(navigation: navigation)
        }
    }
}

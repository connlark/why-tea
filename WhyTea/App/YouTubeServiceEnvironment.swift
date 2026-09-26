import SwiftUI
import WhyTeaYouTube

extension EnvironmentValues {
    /// The YouTube boundary screens hand to their models. `WhyTeaApp` sets it
    /// once at the root: the live client, or the fixture service in a DEBUG
    /// fixture launch. The DEBUG default is the fixture service, so a preview
    /// or hosted test that forgets to inject one never contacts YouTube.
    #if DEBUG
    @Entry var youTubeService: any YouTubeService = FixtureYouTubeService()
    #else
    @Entry var youTubeService: any YouTubeService = YouTubeClient()
    #endif
}

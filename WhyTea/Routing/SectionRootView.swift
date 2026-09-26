import SwiftUI
import WhyTeaYouTube

struct SectionRootView: View {
    let section: AppSection

    @Environment(\.youTubeService) private var service

    var body: some View {
        switch section {
        case .home:
            HomeScreen()
        case .following:
            FollowingScreen()
        case .search:
            SearchScreen(service: service)
        case .library:
            LibraryScreen()
        case .settings:
            SettingsScreen()
        }
    }
}

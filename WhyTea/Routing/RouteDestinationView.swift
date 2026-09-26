import SwiftUI
import WhyTeaYouTube

struct RouteDestinationView: View {
    let route: AppRoute

    @Environment(\.youTubeService) private var service

    var body: some View {
        switch route {
        case .video(let id):
            VideoScreen(id: id, service: service)
        }
    }
}

extension View {
    func withWhyTeaDestinations() -> some View {
        navigationDestination(for: AppRoute.self, destination: RouteDestinationView.init)
    }
}

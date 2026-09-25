import SwiftUI

struct RouteDestinationView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .video(let id):
            VideoScreen(id: id)
        }
    }
}

extension View {
    func withWhyTeaDestinations() -> some View {
        navigationDestination(for: AppRoute.self, destination: RouteDestinationView.init)
    }
}

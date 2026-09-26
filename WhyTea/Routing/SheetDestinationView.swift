import SwiftUI
import WhyTeaYouTube

struct SheetDestinationView: View {
    let destination: SheetDestination

    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        switch destination {
        case .openLink(let text):
            OpenLinkSheet(text: text, onOpen: open)
        }
    }

    private func open(_ id: VideoID) {
        navigation.open(.video(id))
    }
}

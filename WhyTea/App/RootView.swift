import SwiftUI
import WhyTeaYouTube

struct RootView: View {
    @State private var path: [AppRoute] = []
    @State private var isOpeningLink = false

    var body: some View {
        NavigationStack(path: $path) {
            SearchScreen()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Open Link", systemImage: "link", action: openLink)
                    }
                }
                .withWhyTeaDestinations()
        }
        .sheet(isPresented: $isOpeningLink) {
            OpenLinkSheet(onOpen: open)
        }
        .onOpenURL(perform: handleOpenURL)
        #if DEBUG
        .task {
            if let url = DebugLaunchArguments.openURL {
                handleOpenURL(url)
            }
        }
        #endif
    }

    private func openLink() {
        isOpeningLink = true
    }

    private func open(_ id: VideoID) {
        isOpeningLink = false
        path.append(.video(id))
    }

    /// `whytea://` followed by a video ID or any YouTube link minus its scheme,
    /// e.g. `whytea://youtu.be/dQw4w9WgXcQ`.
    private func handleOpenURL(_ url: URL) {
        let link = url.absoluteString.replacing(/^whytea:\/\//.ignoresCase(), with: "")
        if let id = VideoID(parsing: link) {
            open(id)
        }
    }
}

import SwiftUI

/// Home is a truthful placeholder until Continue Watching, saved videos, and
/// followed-channel uploads exist to fill it.
struct HomeScreen: View {
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        ContentUnavailableView {
            Label("Home Is on Its Way", systemImage: AppSection.home.systemImage)
        } description: {
            Text("Home will bring together what you're watching, what you've saved, and new videos from channels you follow. For now, start with Search or open a YouTube link.")
        } actions: {
            Button("Search YouTube", systemImage: AppSection.search.systemImage, action: search)
                .buttonStyle(.borderedProminent)
            Button("Open Link", systemImage: "link", action: openLink)
        }
        .readableWidth()
        .navigationTitle(Text(AppSection.home.title))
    }

    private func search() {
        navigation.select(.search)
    }

    private func openLink() {
        navigation.present(.openLink())
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
    .environment(NavigationStore())
}

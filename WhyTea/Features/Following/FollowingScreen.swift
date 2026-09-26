import SwiftUI

/// Following is a local feature: followed channels live on this device and
/// need no Google account. Until the Follow action exists, the section
/// explains how it will work and points to Search.
struct FollowingScreen: View {
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        ContentUnavailableView {
            Label("No Followed Channels", systemImage: AppSection.following.systemImage)
        } description: {
            Text("Follow a channel and its new videos collect here. Follows stay on this device and don't need a Google account. The Follow button is coming to channel pages and the watch page in an upcoming build.")
        } actions: {
            Button("Search YouTube", systemImage: AppSection.search.systemImage, action: search)
                .buttonStyle(.borderedProminent)
        }
        .readableWidth()
        .navigationTitle(Text(AppSection.following.title))
    }

    private func search() {
        navigation.select(.search)
    }
}

#Preview {
    NavigationStack {
        FollowingScreen()
    }
    .environment(NavigationStore())
}

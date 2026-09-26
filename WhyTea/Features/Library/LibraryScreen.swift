import SwiftUI

/// Library is a truthful placeholder until the queue, history, and saved
/// videos have a local store behind them.
struct LibraryScreen: View {
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        ContentUnavailableView {
            Label("Your Library Is Empty", systemImage: AppSection.library.systemImage)
        } description: {
            Text("Your queue, watch history, and saved videos will live here, kept on this device. Library arrives in an upcoming build.")
        } actions: {
            Button("Search YouTube", systemImage: AppSection.search.systemImage, action: search)
                .buttonStyle(.borderedProminent)
        }
        .readableWidth()
        .navigationTitle(Text(AppSection.library.title))
    }

    private func search() {
        navigation.select(.search)
    }
}

#Preview {
    NavigationStack {
        LibraryScreen()
    }
    .environment(NavigationStore())
}

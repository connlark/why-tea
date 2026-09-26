import SwiftUI
import WhyTeaYouTube

struct SearchScreen: View {
    @Environment(NavigationStore.self) private var navigation
    @State private var model: SearchModel
    @State private var submission = SearchSubmission()

    init(service: any YouTubeService) {
        model = SearchModel(client: service)
    }

    var body: some View {
        content
            .navigationTitle(Text(AppSection.search.title))
            // Always shown: in compact width the search tab otherwise tucks
            // the field under the large title until the list is pulled down.
            .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search YouTube")
            .searchSuggestions {
                ForEach(model.suggestions, id: \.self) { suggestion in
                    Text(suggestion).searchCompletion(suggestion)
                }
            }
            .onSubmit(of: .search, submit)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Open Link", systemImage: "link", action: openLink)
                }
            }
            .task(id: model.query) { await model.updateSuggestions() }
            .task(id: submission) { await model.search(submission) }
            .onChange(of: navigation.searchRequest, initial: true, runRequest)
    }

    @ViewBuilder
    private var content: some View {
        switch model.results {
        case nil:
            ContentUnavailableView(
                "Search YouTube",
                systemImage: "play.rectangle",
                description: Text("Search, details, comments, and playback all run on this device. No server in between.")
            )
        case .loading:
            ProgressView()
        case .failed(let message):
            ContentUnavailableView {
                Label("Search Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again", action: retrySearch)
            }
        case .loaded(let videos) where videos.isEmpty:
            ContentUnavailableView.search(text: submission.query)
        case .loaded(let videos):
            SearchResultsList(videos: videos, model: model)
        }
    }

    private func submit() {
        submission = submission.resubmitted(query: model.query)
    }

    private func retrySearch() {
        submission = submission.resubmitted(query: submission.query)
    }

    private func openLink() {
        navigation.present(.openLink())
    }

    private func runRequest(_: SearchRequest?, _ request: SearchRequest?) {
        guard let request else { return }
        navigation.consume(request)
        model.query = request.query
        submit()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SearchScreen(service: FixtureYouTubeService())
    }
    .environment(NavigationStore())
}
#endif

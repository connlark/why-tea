import SwiftUI

struct SearchScreen: View {
    @State private var model = SearchModel()
    @State private var submission = SearchSubmission()

    var body: some View {
        content
            .navigationTitle("why tea")
            .searchable(text: $model.query, prompt: "Search YouTube")
            .searchSuggestions {
                ForEach(model.suggestions, id: \.self) { suggestion in
                    Text(suggestion).searchCompletion(suggestion)
                }
            }
            .onSubmit(of: .search, submit)
            .task(id: model.query) { await model.updateSuggestions() }
            .task(id: submission) { await model.search(submission.query) }
            #if DEBUG
            .task {
                if let query = DebugLaunchArguments.searchQuery {
                    model.query = query
                    submit()
                }
            }
            #endif
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
}

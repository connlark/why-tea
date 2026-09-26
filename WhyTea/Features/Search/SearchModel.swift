import Foundation
import WhyTeaYouTube

@Observable
final class SearchModel {
    var query = ""
    private(set) var suggestions: [String] = []
    /// `nil` until the first search is submitted.
    private(set) var results: LoadState<[VideoSummary]>?
    private(set) var continuationToken: String?
    private(set) var loadMoreError: String?

    @ObservationIgnored private var isLoadingMore = false
    /// The last submission that finished, successfully or not.
    @ObservationIgnored private var settledSubmission: SearchSubmission?
    @ObservationIgnored private let client: any YouTubeService
    @ObservationIgnored private let suggestionDebounce: Duration

    init(client: any YouTubeService, suggestionDebounce: Duration = .milliseconds(250)) {
        self.client = client
        self.suggestionDebounce = suggestionDebounce
    }

    /// Runs `submission` unless it already settled. The screen's task restarts
    /// whenever Search reappears (a section switch or a pop back from a
    /// video), and that must not reload results the person is looking at.
    func search(_ submission: SearchSubmission) async {
        let term = submission.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, submission != settledSubmission else { return }
        results = .loading
        continuationToken = nil
        loadMoreError = nil
        do {
            let page = try await client.search(term)
            // The vendored request layer ignores cancellation, so a superseded
            // search can still finish; drop it instead of overwriting newer results.
            try Task.checkCancellation()
            results = .loaded(page.videos)
            continuationToken = page.continuationToken
            settledSubmission = submission
        } catch {
            guard !error.isCancellation else { return }
            results = .failed(error.localizedDescription)
            settledSubmission = submission
        }
    }

    func loadMore() async {
        guard let token = continuationToken, !isLoadingMore, case .loaded = results else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await client.moreSearchResults(token: token)
            try Task.checkCancellation()
            guard case .loaded(let current) = results else { return }
            results = .loaded(current.appendingUnique(page.videos))
            continuationToken = page.continuationToken
        } catch {
            guard !error.isCancellation else { return }
            loadMoreError = error.localizedDescription
        }
    }

    func retryLoadMore() {
        loadMoreError = nil
    }

    func updateSuggestions() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            suggestions = []
            return
        }
        do {
            try await Task.sleep(for: suggestionDebounce)
            let entries = try await client.suggestions(for: term)
            try Task.checkCancellation()
            suggestions = entries
        } catch {
            // Suggestions are ambient; a failed lookup keeps the previous list.
        }
    }
}

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
    @ObservationIgnored private let client: YouTubeClient

    init(client: YouTubeClient = YouTubeClient()) {
        self.client = client
    }

    func search(_ term: String) async {
        let term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
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
        } catch is CancellationError {
        } catch {
            results = .failed(error.localizedDescription)
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
        } catch is CancellationError {
        } catch {
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
            try await Task.sleep(for: .milliseconds(250))
            let entries = try await client.suggestions(for: term)
            try Task.checkCancellation()
            suggestions = entries
        } catch {
            // Suggestions are ambient; a failed lookup keeps the previous list.
        }
    }
}

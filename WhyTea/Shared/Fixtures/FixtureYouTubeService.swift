#if DEBUG
import Foundation
import WhyTeaYouTube

/// An in-process `YouTubeService` over `FixtureCatalog`, for SwiftUI previews,
/// `WhyTeaTests`, and the `-WhyTeaFixtures YES` simulator launch. It never
/// opens a socket and never reaches YouTube.
///
/// Latency and failures are scripted per operation. Like the vendored request
/// layers, a scripted delay ignores task cancellation, so a superseded request
/// still returns and models must recheck cancellation before writing state.
nonisolated struct FixtureYouTubeService: YouTubeService {
    enum Operation: Hashable, Sendable {
        case search
        case moreSearchResults
        case suggestions
        case home
        case details
        case comments
        case playbackSource
    }

    var catalog = FixtureCatalog.standard
    var latency: [Operation: Duration] = [:]
    /// Per-query search latency, overriding `latency[.search]`.
    var searchLatency: [String: Duration] = [:]
    var failures: [Operation: FixtureServiceError] = [:]
    /// Per-query suggestion failure, overriding `failures[.suggestions]`.
    var suggestionFailures: [String: FixtureServiceError] = [:]

    func search(_ query: String) async throws -> VideoPage {
        try await perform(.search, latency: searchLatency[query])
        return try catalog.searchPage(token: FixtureCatalog.searchToken(query: query, page: 0))
    }

    func moreSearchResults(token: String) async throws -> VideoPage {
        try await perform(.moreSearchResults)
        return try catalog.searchPage(token: token)
    }

    func suggestions(for query: String) async throws -> [String] {
        try await perform(.suggestions, failure: suggestionFailures[query])
        return catalog.suggestions(for: query)
    }

    func home() async throws -> VideoPage {
        try await perform(.home)
        return VideoPage(videos: catalog.home.compactMap { catalog.videos[$0]?.summary }, continuationToken: nil)
    }

    func details(for id: VideoID) async throws -> VideoDetails {
        try await perform(.details)
        return try catalog.details(for: id)
    }

    func comments(token: String) async throws -> CommentPage {
        try await perform(.comments)
        return try catalog.commentPage(token: token)
    }

    func playbackSource(for id: VideoID) async throws -> PlaybackSource {
        try await perform(.playbackSource)
        guard let source = catalog.playback[id] else { throw FixtureServiceError.playbackUnavailable }
        return source
    }

    private func perform(
        _ operation: Operation,
        latency latencyOverride: Duration? = nil,
        failure failureOverride: FixtureServiceError? = nil
    ) async throws {
        if let delay = latencyOverride ?? latency[operation] {
            await Task { try? await Task.sleep(for: delay) }.value
        }
        if let failure = failureOverride ?? failures[operation] {
            throw failure
        }
    }
}
#endif

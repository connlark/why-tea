import Foundation
import Testing
import WhyTeaYouTube
@testable import WhyTea

struct VideoModelTests {
    private let native = VideoID(rawValue: "wTeaMock00Q")!
    private let quiet = VideoID(rawValue: "wTeaMock01g")!

    private func isLoading(_ state: LoadState<VideoDetails>) -> Bool {
        if case .loading = state { true } else { false }
    }

    private func loadedDetails(_ state: LoadState<VideoDetails>) -> VideoDetails? {
        if case .loaded(let details) = state { details } else { nil }
    }

    private func failureMessage(_ state: LoadState<VideoDetails>) -> String? {
        if case .failed(let message) = state { message } else { nil }
    }

    private func isResolving(_ phase: PlaybackPhase) -> Bool {
        if case .resolving = phase { true } else { false }
    }

    private func playbackFailure(_ phase: PlaybackPhase) -> String? {
        if case .failed(let message) = phase { message } else { nil }
    }

    @Test func loadsDetailsAndSeedsTheCommentsToken() async throws {
        let model = VideoModel(id: native, client: FixtureYouTubeService())
        await model.load()

        let details = try #require(loadedDetails(model.details))
        #expect(details.title == "WhyTea: A Native YouTube Client")
        #expect(details.related.map(\.id.rawValue) == ["wTeaMock01g", "wTeaMock02o"])
        #expect(model.commentsToken == "wTeaMock00Q:comments:0")
        #expect(model.comments.isEmpty)
    }

    @Test func showsLoadingAndResolvingWhileRequestsAreInFlight() async {
        var service = FixtureYouTubeService()
        service.latency[.details] = .milliseconds(100)
        service.latency[.playbackSource] = .milliseconds(100)
        let model = VideoModel(id: native, client: service)

        let load = Task { await model.load() }
        await Task.yield()
        #expect(isLoading(model.details))
        #expect(isResolving(model.playback))

        await load.value
        #expect(loadedDetails(model.details) != nil)
    }

    @Test func fixturePlaybackFailsWithATypedMessage() async {
        let model = VideoModel(id: native, client: FixtureYouTubeService())
        await model.load()
        #expect(playbackFailure(model.playback) == FixtureServiceError.playbackUnavailable.localizedDescription)
    }

    @Test func resolvedSourceMakesPlaybackReady() async {
        var service = FixtureYouTubeService()
        service.catalog.playback[native] = PlaybackSource(url: URL(filePath: "/dev/null"), kind: .progressive(resolution: 360))
        let model = VideoModel(id: native, client: service)
        await model.load()

        guard case .ready(let player, let kind) = model.playback else {
            Issue.record("Expected a ready player, got \(model.playback)")
            return
        }
        player.pause()
        #expect(kind == .progressive(resolution: 360))
    }

    @Test func failedDetailsShowTheErrorAndRetryReopensThem() async {
        var service = FixtureYouTubeService()
        service.failures[.details] = .offline
        let model = VideoModel(id: native, client: service)

        await model.load()
        #expect(failureMessage(model.details) == FixtureServiceError.offline.localizedDescription)
        #expect(playbackFailure(model.playback) != nil)

        model.retry()
        #expect(model.loadAttempt == 1)
        #expect(isLoading(model.details))
        #expect(isResolving(model.playback))
    }

    @Test func failedWorkIsNotRepeatedByReappearance() async {
        var service = FixtureYouTubeService()
        service.failures[.details] = .offline
        service.latency[.details] = .milliseconds(100)
        service.latency[.playbackSource] = .milliseconds(100)
        let model = VideoModel(id: native, client: service)
        await model.load()

        let reappearance = Task { await model.load() }
        await Task.yield()
        #expect(failureMessage(model.details) == FixtureServiceError.offline.localizedDescription)
        #expect(playbackFailure(model.playback) == FixtureServiceError.playbackUnavailable.localizedDescription)
        await reappearance.value
    }

    @Test func retryLeavesLoadedDetailsAlone() async {
        let model = VideoModel(id: native, client: FixtureYouTubeService())
        await model.load()
        #expect(playbackFailure(model.playback) != nil)

        model.retry()
        #expect(loadedDetails(model.details) != nil)
        #expect(isResolving(model.playback))
    }

    @Test func unknownVideoIsAMissingDetailsFailure() async {
        let missing = VideoID(rawValue: "aaaaaaaaaaa")!
        let model = VideoModel(id: missing, client: FixtureYouTubeService())
        await model.load()
        #expect(failureMessage(model.details) == YouTubeClientError.missingDetails(missing).localizedDescription)
    }

    @Test func cancelledLoadWritesNothing() async {
        var service = FixtureYouTubeService()
        service.latency[.details] = .milliseconds(100)
        service.latency[.playbackSource] = .milliseconds(100)
        let model = VideoModel(id: native, client: service)

        let load = Task { await model.load() }
        await Task.yield()
        load.cancel()
        await load.value

        #expect(isLoading(model.details))
        #expect(isResolving(model.playback))
        #expect(model.commentsToken == nil)
    }

    @Test func loadIsIdempotentOnceDetailsArrive() async {
        var service = FixtureYouTubeService()
        service.latency[.details] = .milliseconds(100)
        let model = VideoModel(id: native, client: service)
        await model.load()

        let again = Task { await model.load() }
        await Task.yield()
        #expect(loadedDetails(model.details) != nil)
        await again.value
    }

    @Test func pagesThroughComments() async {
        let model = VideoModel(id: native, client: FixtureYouTubeService())
        await model.load()

        await model.loadMoreComments()
        #expect(model.comments.map(\.id) == ["comment-whytea-001", "comment-whytea-002"])
        #expect(model.commentsToken == "wTeaMock00Q:comments:1")

        await model.loadMoreComments()
        #expect(model.comments.map(\.id) == ["comment-whytea-001", "comment-whytea-002", "comment-whytea-003"])
        #expect(model.commentsToken == nil)
    }

    @Test func dropsCommentsRepeatedByTheNextPage() async throws {
        var service = FixtureYouTubeService()
        let comments = try #require(service.catalog.videos[native]?.comments)
        service.catalog.videos[native]?.comments = [comments[0], comments[1], comments[1], comments[2]]
        let model = VideoModel(id: native, client: service)
        await model.load()

        await model.loadMoreComments()
        await model.loadMoreComments()

        #expect(model.comments.map(\.id) == ["comment-whytea-001", "comment-whytea-002", "comment-whytea-003"])
    }

    @Test func videoWithoutCommentsEndsEmpty() async {
        let model = VideoModel(id: quiet, client: FixtureYouTubeService())
        await model.load()
        await model.loadMoreComments()

        #expect(model.comments.isEmpty)
        #expect(model.commentsToken == nil)
        #expect(model.commentsError == nil)
    }

    @Test func failedCommentsPageOffersRetry() async {
        var service = FixtureYouTubeService()
        service.failures[.comments] = .offline
        let model = VideoModel(id: native, client: service)
        await model.load()

        await model.loadMoreComments()
        #expect(model.commentsError == FixtureServiceError.offline.localizedDescription)
        #expect(model.commentsToken == "wTeaMock00Q:comments:0")

        model.retryComments()
        #expect(model.commentsError == nil)
    }
}

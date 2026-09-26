import Foundation
import Testing
import WhyTeaYouTube
@testable import WhyTea

struct SearchModelTests {
    private let fixtures = FixtureCatalog.standard

    private func submission(_ query: String, attempt: Int = 1) -> SearchSubmission {
        SearchSubmission(query: query, attempt: attempt)
    }

    private func summaries(_ ids: String...) -> [VideoSummary] {
        ids.compactMap { VideoID(rawValue: $0).flatMap { fixtures.videos[$0]?.summary } }
    }

    @Test func startsWithNoResults() {
        let model = SearchModel(client: FixtureYouTubeService())
        #expect(model.results == nil)
        #expect(model.continuationToken == nil)
    }

    @Test func showsLoadingUntilThePageArrives() async {
        var service = FixtureYouTubeService()
        service.latency[.search] = .milliseconds(100)
        let model = SearchModel(client: service)

        let search = Task { await model.search(submission("whytea")) }
        await Task.yield()
        #expect(model.results == .loading)

        await search.value
        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g")))
        #expect(model.continuationToken == "search:whytea:1")
    }

    @Test func unknownQueryLoadsAnEmptyPage() async {
        let model = SearchModel(client: FixtureYouTubeService())
        await model.search(submission("no such fixture"))
        #expect(model.results == .loaded([]))
        #expect(model.continuationToken == nil)
    }

    @Test func blankQueryDoesNothing() async {
        let model = SearchModel(client: FixtureYouTubeService())
        await model.search(submission("   "))
        #expect(model.results == nil)
    }

    @Test func loadsTheNextPageFromTheContinuation() async {
        let model = SearchModel(client: FixtureYouTubeService())
        await model.search(submission("whytea"))
        await model.loadMore()

        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g", "wTeaMock02o", "wTeaMock03w")))
        #expect(model.continuationToken == nil)

        await model.loadMore()
        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g", "wTeaMock02o", "wTeaMock03w")))
    }

    @Test func dropsVideosRepeatedByTheNextPage() async {
        var service = FixtureYouTubeService()
        let ids = ["wTeaMock00Q", "wTeaMock01g", "wTeaMock01g", "wTeaMock02o"].compactMap(VideoID.init(rawValue:))
        service.catalog.searches["repeat"] = ids
        let model = SearchModel(client: service)

        await model.search(submission("repeat"))
        await model.loadMore()

        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g", "wTeaMock02o")))
    }

    @Test func cancelledSearchWritesNothingAndCanRunAgain() async {
        var service = FixtureYouTubeService()
        service.latency[.search] = .milliseconds(100)
        let model = SearchModel(client: service)

        let search = Task { await model.search(submission("whytea")) }
        await Task.yield()
        search.cancel()
        await search.value

        #expect(model.results == .loading)
        #expect(model.continuationToken == nil)

        await model.search(submission("whytea"))
        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g")))
    }

    @Test func cancelledSearchThatFailsWritesNoError() async {
        var service = FixtureYouTubeService()
        service.latency[.search] = .milliseconds(100)
        service.failures[.search] = .offline
        let model = SearchModel(client: service)

        let search = Task { await model.search(submission("whytea")) }
        await Task.yield()
        search.cancel()
        await search.value

        #expect(model.results == .loading)
    }

    @Test func supersededSearchCannotOverwriteNewerResults() async {
        var service = FixtureYouTubeService()
        service.searchLatency["slow"] = .milliseconds(200)
        let model = SearchModel(client: service)

        let stale = Task { await model.search(submission("slow")) }
        await Task.yield()
        stale.cancel()
        await model.search(submission("whytea", attempt: 2))
        await stale.value

        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g")))
        #expect(model.continuationToken == "search:whytea:1")
    }

    @Test func settledSubmissionIsNotFetchedAgain() async {
        var service = FixtureYouTubeService()
        service.latency[.search] = .milliseconds(100)
        let model = SearchModel(client: service)
        let first = submission("whytea")
        await model.search(first)
        await model.loadMore()

        let repeated = Task { await model.search(first) }
        await Task.yield()
        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g", "wTeaMock02o", "wTeaMock03w")))
        await repeated.value

        let resubmitted = Task { await model.search(submission("whytea", attempt: 2)) }
        await Task.yield()
        #expect(model.results == .loading)
        await resubmitted.value
        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g")))
    }

    @Test func failedSearchShowsTheError() async {
        var service = FixtureYouTubeService()
        service.failures[.search] = .offline
        let model = SearchModel(client: service)

        await model.search(submission("whytea"))

        #expect(model.results == .failed(FixtureServiceError.offline.localizedDescription))
    }

    @Test func failedPageKeepsResultsAndOffersRetry() async {
        var service = FixtureYouTubeService()
        service.failures[.moreSearchResults] = .offline
        let model = SearchModel(client: service)
        await model.search(submission("whytea"))

        await model.loadMore()
        #expect(model.results == .loaded(summaries("wTeaMock00Q", "wTeaMock01g")))
        #expect(model.loadMoreError == FixtureServiceError.offline.localizedDescription)
        #expect(model.continuationToken == "search:whytea:1")

        model.retryLoadMore()
        #expect(model.loadMoreError == nil)
    }

    @Test func suggestionsFollowTheQueryAndSurviveFailures() async {
        var service = FixtureYouTubeService()
        service.suggestionFailures["youtube"] = .offline
        let model = SearchModel(client: service, suggestionDebounce: .zero)
        let swiftui = ["swiftui navigation split view", "swiftui liquid glass", "swift concurrency"]

        model.query = "swiftui"
        await model.updateSuggestions()
        #expect(model.suggestions == swiftui)

        model.query = "youtube"
        await model.updateSuggestions()
        #expect(model.suggestions == swiftui)

        model.query = ""
        await model.updateSuggestions()
        #expect(model.suggestions.isEmpty)
    }
}

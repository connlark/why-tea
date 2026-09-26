import Foundation
import Testing
import WhyTeaYouTube
@testable import WhyTea

struct FixtureCatalogTests {
    private let catalog = FixtureCatalog.standard

    @Test func standardCatalogIsTheBundledJSON() throws {
        #expect(catalog.videos.keys.map(\.rawValue).sorted() == ["wTeaMock00Q", "wTeaMock01g", "wTeaMock02o", "wTeaMock03w"])
        #expect(catalog.home.map(\.rawValue) == ["wTeaMock00Q", "wTeaMock01g", "wTeaMock02o"])
        #expect(catalog.searches["whytea"]?.map(\.rawValue) == ["wTeaMock00Q", "wTeaMock01g", "wTeaMock02o", "wTeaMock03w"])
        #expect(catalog.suggestions(for: "SwiftUI") == ["swiftui navigation split view", "swiftui liquid glass", "swift concurrency"])
        #expect(catalog.suggestions(for: "unknown") == ["swiftui", "native app", "apple design"])
        #expect(catalog.suggestions["default"] == nil)

        let native = try #require(catalog.videos[VideoID(rawValue: "wTeaMock00Q")!])
        #expect(native.summary.title == "WhyTea: A Native YouTube Client")
        #expect(native.summary.channelName == "WhyTea Labs")
        #expect(native.likeCountText == "98")
        #expect(native.related.map(\.rawValue) == ["wTeaMock01g", "wTeaMock02o"])
        #expect(native.comments.map(\.id) == ["comment-whytea-001", "comment-whytea-002", "comment-whytea-003"])
        #expect(native.comments.first?.authorName == "Fixture Viewer")
    }

    @Test(arguments: ["search:1", "search:", "nope", "whytea:1", "search:whytea:one"])
    func malformedSearchTokenIsAnInvalidTokenError(token: String) {
        #expect(throws: FixtureServiceError.invalidToken(token)) {
            try catalog.searchPage(token: token)
        }
    }

    @Test func searchTokenKeepsColonsInsideTheQuery() throws {
        var catalog = catalog
        catalog.searches["a:b"] = [VideoID(rawValue: "wTeaMock00Q")!]
        let page = try catalog.searchPage(token: FixtureCatalog.searchToken(query: "a:b", page: 0))
        #expect(page.videos.map(\.id.rawValue) == ["wTeaMock00Q"])
        #expect(page.continuationToken == nil)
    }
}

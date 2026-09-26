import Foundation
import Testing
@testable import WhyTeaYouTube

/// Exercises the local fixture contract. The suite is enabled only when the
/// loopback `Server/YouTubeMock` fixture is running and `WHYTEA_MOCK_BASE_URL`
/// is set, as `scripts/mock-youtube-test.sh` does.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["WHYTEA_MOCK_BASE_URL"] != nil), .serialized)
struct MockYouTubeClientTests {
    private var client: MockYouTubeClient {
        let origin = ProcessInfo.processInfo.environment["WHYTEA_MOCK_BASE_URL"]!
        return MockYouTubeClient(baseURL: URL(string: origin)!)
    }

    @Test func searchSuggestionsAndContinuation() async throws {
        let page = try await client.search("whytea")
        #expect(page.videos.count == 2)
        let more = try await client.moreSearchResults(token: try #require(page.continuationToken))
        #expect(more.videos.count == 2)
        #expect(try await client.suggestions(for: "swiftui").isEmpty == false)
    }

    @Test func homeDetailsCommentsAndPlayback() async throws {
        let home = try await client.home()
        let id = try #require(home.videos.first?.id)
        let details = try await client.details(for: id)
        #expect(details.id == id)
        let comments = try await client.comments(token: try #require(details.commentsToken))
        #expect(comments.comments.count == 2)
        let source = try await client.playbackSource(for: id)
        #expect(source.kind == .hls)
        #expect(source.url.path.hasSuffix("/master.m3u8"))
    }

    @Test func rejectsNonLoopbackOrigin() async {
        let client = MockYouTubeClient(baseURL: URL(string: "https://example.com")!)
        do {
            _ = try await client.home()
            Issue.record("MockYouTubeClient accepted a non-loopback origin")
        } catch MockYouTubeClientError.invalidBaseURL {
            // The fixture client must reject a remote origin before URLSession runs.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

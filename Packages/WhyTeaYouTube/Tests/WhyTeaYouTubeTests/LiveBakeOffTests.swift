import Foundation
import Testing
@testable import WhyTeaYouTube

/// Hits real YouTube from this machine; no relay server involved.
/// Run with `WHYTEA_LIVE=1 swift test --filter LiveBakeOff`.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["WHYTEA_LIVE"] == "1"), .serialized)
struct LiveBakeOffTests {
    let client = YouTubeClient()
    let knownVideo = VideoID(rawValue: "dQw4w9WgXcQ")!

    @Test func search() async throws {
        let page = try await client.search("rick astley never gonna give you up")
        #expect(!page.videos.isEmpty)
        #expect(page.continuationToken != nil)
        let more = try await client.moreSearchResults(token: try #require(page.continuationToken))
        #expect(!more.videos.isEmpty)
    }

    @Test func suggestions() async throws {
        #expect(try await !client.suggestions(for: "swiftui").isEmpty)
    }

    @Test func homeFeed() async throws {
        let page = try await client.home()
        print("[bake-off] logged-out home returned \(page.videos.count) videos")
    }

    @Test func detailsAndComments() async throws {
        let details = try await client.details(for: knownVideo)
        #expect(details.title.localizedStandardContains("Never Gonna Give You Up"))
        #expect(!details.related.isEmpty)
        let page = try await client.comments(token: try #require(details.commentsToken))
        #expect(!page.comments.isEmpty)
    }

    @Test func playbackSourceIsFetchable() async throws {
        let source = try await client.playbackSource(for: knownVideo)
        print("[bake-off] playback source kind: \(source.kind)")

        var request = URLRequest(url: source.url)
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = try #require(response as? HTTPURLResponse).statusCode
        #expect((200..<300).contains(status))
        #expect(!data.isEmpty)
        guard source.kind == .hls else { return }

        // Master → first variant → first segment: the same chain AVPlayer walks.
        let master = String(decoding: data, as: UTF8.self)
        #expect(master.hasPrefix("#EXTM3U"))
        let variantURL = try #require(firstURI(in: master, relativeTo: source.url))
        let (variantData, _) = try await URLSession.shared.data(from: variantURL)
        let segmentURL = try #require(firstURI(in: String(decoding: variantData, as: UTF8.self), relativeTo: variantURL))
        var segmentRequest = URLRequest(url: segmentURL)
        segmentRequest.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        let (segment, segmentResponse) = try await URLSession.shared.data(for: segmentRequest)
        let segmentStatus = try #require(segmentResponse as? HTTPURLResponse).statusCode
        print("[bake-off] first HLS segment status \(segmentStatus), \(segment.count) bytes")
        #expect((200..<300).contains(segmentStatus))
    }

    private func firstURI(in playlist: String, relativeTo base: URL) -> URL? {
        playlist.split(whereSeparator: \.isNewline)
            .first { !$0.hasPrefix("#") && !$0.isEmpty }
            .flatMap { URL(string: String($0), relativeTo: base)?.absoluteURL }
    }
}

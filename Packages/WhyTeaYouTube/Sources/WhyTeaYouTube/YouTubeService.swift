import Foundation

/// The app-facing YouTube capability boundary.
///
/// `YouTubeClient` is the live, on-device implementation. Test and preview
/// implementations can use the same contract without importing vendored
/// response types or touching YouTube.
public protocol YouTubeService: Sendable {
    func search(_ query: String) async throws -> VideoPage
    func moreSearchResults(token: String) async throws -> VideoPage
    func suggestions(for query: String) async throws -> [String]
    func home() async throws -> VideoPage
    func details(for id: VideoID) async throws -> VideoDetails
    func comments(token: String) async throws -> CommentPage
    func playbackSource(for id: VideoID) async throws -> PlaybackSource
}

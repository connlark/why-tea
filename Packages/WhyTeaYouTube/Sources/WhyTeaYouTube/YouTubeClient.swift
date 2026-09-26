import Foundation
import YouTubeAPI
import YouTubeStreams

/// Server-free YouTube access: browsing via `YouTubeAPI` (b5i), playback URLs via
/// `YouTubeStreams` (alexeichhorn). Every request goes from this device straight
/// to YouTube.
///
/// Each call builds its own `YouTubeModel`; neither vendored model type is
/// `Sendable`, so they never outlive the call that created them.
public struct YouTubeClient: YouTubeService, Sendable {
    public init() {}

    @concurrent
    public func search(_ query: String) async throws -> VideoPage {
        let response = try await SearchResponse.sendThrowingRequest(
            youtubeModel: YouTubeModel(),
            data: [.query: query]
        )
        return VideoPage(videos: response.results.videoSummaries, continuationToken: response.continuationToken)
    }

    @concurrent
    public func moreSearchResults(token: String) async throws -> VideoPage {
        let response = try await SearchResponse.Continuation.sendThrowingRequest(
            youtubeModel: YouTubeModel(),
            data: [.continuation: token]
        )
        return VideoPage(videos: response.results.videoSummaries, continuationToken: response.continuationToken)
    }

    @concurrent
    public func suggestions(for query: String) async throws -> [String] {
        try await AutoCompletionResponse.sendThrowingRequest(
            youtubeModel: YouTubeModel(),
            data: [.query: query]
        ).autoCompletionEntries
    }

    /// Logged-out home feed. YouTube often returns nothing here for a fresh
    /// visitor with no watch history.
    @concurrent
    public func home() async throws -> VideoPage {
        let response = try await HomeScreenResponse.sendThrowingRequest(youtubeModel: YouTubeModel(), data: [:])
        return VideoPage(videos: response.results.compactMap(\.videoSummary).uniqued, continuationToken: response.continuationToken)
    }

    @concurrent
    public func details(for id: VideoID) async throws -> VideoDetails {
        let response = try await MoreVideoInfosResponse.sendThrowingRequest(
            youtubeModel: YouTubeModel(),
            data: [.query: id.rawValue]
        )
        guard let title = response.videoTitle else { throw YouTubeClientError.missingDetails(id) }
        return VideoDetails(
            id: id,
            title: title,
            channelName: response.channel?.name,
            channelID: response.channel?.channelId,
            channelAvatarURL: response.channel?.thumbnails.largest?.url,
            subscriberCountText: response.channel?.subscriberCount,
            viewCountText: response.viewsCount.shortViewsCount ?? response.viewsCount.fullViewsCount,
            publishedText: response.timePosted.relativePostedDate ?? response.timePosted.postedDate,
            likeCountText: response.likesCount.defaultState,
            descriptionText: (response.videoDescription ?? []).compactMap(\.text).joined(),
            commentCountText: response.commentsCount,
            commentsToken: response.commentsContinuationToken,
            related: response.recommendedVideos.videoSummaries
        )
    }

    /// Pass `VideoDetails.commentsToken` for the first page, then each page's
    /// `continuationToken`.
    @concurrent
    public func comments(token: String) async throws -> CommentPage {
        let response = try await VideoCommentsResponse.sendThrowingRequest(
            youtubeModel: YouTubeModel(),
            data: [.continuation: token]
        )
        return CommentPage(comments: response.results.map(\.videoComment), continuationToken: response.continuationToken)
    }

    /// Prefers the adaptive HLS manifest; falls back to the best natively
    /// playable muxed stream. Signature solving runs JavaScriptCore, hence
    /// `@concurrent`.
    @concurrent
    public func playbackSource(for id: VideoID) async throws -> PlaybackSource {
        let video = YouTube(videoID: id.rawValue, methods: [.local])

        if let hls = try? await video.livestreams.first(where: { $0.streamType == .hls }) {
            return PlaybackSource(url: hls.url, kind: .hls)
        }

        let muxed = try await video.streams
            .filterVideoAndAudio()
            .filter(\.isNativelyPlayable)
            .highestResolutionStream()
        guard let muxed else { throw YouTubeClientError.noPlayableStream(id) }
        return PlaybackSource(url: muxed.url, kind: .progressive(resolution: muxed.videoResolution))
    }
}

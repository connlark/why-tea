import Foundation

/// A client for the local `Server/YouTubeMock` fixture service.
///
/// This type is for tests, previews, and simulator scenarios. It has no live
/// YouTube fallback. The service origin must be supplied explicitly so a
/// production client cannot silently start using fixtures.
public struct MockYouTubeClient: YouTubeService, Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    @concurrent
    public func search(_ query: String) async throws -> VideoPage {
        try await request(path: "/api/v1/search", queryItems: [URLQueryItem(name: "q", value: query)], as: MockPage.self).page
    }

    @concurrent
    public func moreSearchResults(token: String) async throws -> VideoPage {
        try await request(path: "/api/v1/search", queryItems: [URLQueryItem(name: "cursor", value: token)], as: MockPage.self).page
    }

    @concurrent
    public func suggestions(for query: String) async throws -> [String] {
        try await request(path: "/api/v1/suggestions", queryItems: [URLQueryItem(name: "q", value: query)], as: MockSuggestions.self).suggestions
    }

    @concurrent
    public func home() async throws -> VideoPage {
        try await request(path: "/api/v1/home", as: MockPage.self).page
    }

    @concurrent
    public func details(for id: VideoID) async throws -> VideoDetails {
        let payload = try await request(path: "/api/v1/videos/\(id.rawValue)", as: MockDetails.self)
        return try payload.details
    }

    @concurrent
    public func comments(token: String) async throws -> CommentPage {
        let components = token.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard components.count == 3, let id = VideoID(rawValue: String(components[0])) else {
            throw MockYouTubeClientError.invalidCommentToken(token)
        }
        let payload = try await request(
            path: "/api/v1/videos/\(id.rawValue)/comments",
            queryItems: [URLQueryItem(name: "cursor", value: token)],
            as: MockCommentPage.self
        )
        return payload.page
    }

    @concurrent
    public func playbackSource(for id: VideoID) async throws -> PlaybackSource {
        let payload = try await request(path: "/api/v1/videos/\(id.rawValue)/playback", as: MockPlayback.self)
        guard let url = URL(string: payload.source.url), payload.source.kind == "hls" else {
            throw MockYouTubeClientError.invalidPlayback(id)
        }
        return PlaybackSource(url: url, kind: .hls)
    }

    private func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        as type: Response.Type
    ) async throws -> Response {
        guard baseURL.scheme == "http", baseURL.host == "127.0.0.1", baseURL.port != nil else {
            throw MockYouTubeClientError.invalidBaseURL(baseURL)
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw MockYouTubeClientError.invalidBaseURL(baseURL) }
        var request = URLRequest(url: url)
        request.setValue("WhyTeaMock/1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw MockYouTubeClientError.invalidResponse(url)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw MockYouTubeClientError.http(status: response.statusCode, url: url)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw MockYouTubeClientError.decoding(url: url, underlying: String(describing: error))
        }
    }
}

public enum MockYouTubeClientError: LocalizedError, Sendable {
    case invalidBaseURL(URL)
    case invalidResponse(URL)
    case http(status: Int, url: URL)
    case decoding(url: URL, underlying: String)
    case invalidCommentToken(String)
    case invalidDetails(String)
    case invalidPlayback(VideoID)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL(let url): "Invalid mock server origin: \(url.absoluteString)"
        case .invalidResponse(let url): "Mock server returned a non-HTTP response for \(url.absoluteString)."
        case .http(let status, let url): "Mock server returned HTTP \(status) for \(url.path)."
        case .decoding(let url, let underlying): "Mock response at \(url.path) was invalid: \(underlying)"
        case .invalidCommentToken(let token): "Invalid mock comment token: \(token)"
        case .invalidDetails(let id): "Mock details for \(id) were invalid."
        case .invalidPlayback(let id): "Mock playback source for \(id) was invalid."
        }
    }
}

private struct MockPage: Decodable {
    let videos: [MockVideoSummary]
    let continuationToken: String?

    var page: VideoPage {
        VideoPage(videos: videos.compactMap(\.value), continuationToken: continuationToken)
    }
}

private struct MockVideoSummary: Decodable {
    let id: String
    let title: String
    let channelName: String?
    let channelID: String?
    let thumbnailURL: URL?
    let durationText: String?
    let viewCountText: String?
    let publishedText: String?

    var value: VideoSummary? {
        guard let id = VideoID(rawValue: id) else { return nil }
        return VideoSummary(
            id: id,
            title: title,
            channelName: channelName,
            channelID: channelID,
            thumbnailURL: thumbnailURL,
            durationText: durationText,
            viewCountText: viewCountText,
            publishedText: publishedText
        )
    }
}

private struct MockDetails: Decodable {
    let id: String
    let summary: MockVideoSummary
    let channelAvatarURL: URL?
    let subscriberCountText: String?
    let viewCountText: String?
    let publishedText: String?
    let likeCountText: String?
    let descriptionText: String
    let commentCountText: String?
    let commentsToken: String?
    let related: [MockVideoSummary]

    var details: VideoDetails {
        get throws {
            guard let id = VideoID(rawValue: id) else { throw MockYouTubeClientError.invalidDetails(self.id) }
            return VideoDetails(
                id: id,
                title: summary.title,
                channelName: summary.channelName,
                channelID: summary.channelID,
                channelAvatarURL: channelAvatarURL,
                subscriberCountText: subscriberCountText,
                viewCountText: viewCountText,
                publishedText: publishedText,
                likeCountText: likeCountText,
                descriptionText: descriptionText,
                commentCountText: commentCountText,
                commentsToken: commentsToken,
                related: related.compactMap(\.value)
            )
        }
    }
}

private struct MockCommentPage: Decodable {
    let comments: [MockComment]
    let continuationToken: String?

    var page: CommentPage {
        CommentPage(comments: comments.map(\.value), continuationToken: continuationToken)
    }
}

private struct MockComment: Decodable {
    let id: String
    let authorName: String?
    let authorAvatarURL: URL?
    let text: String
    let publishedText: String?
    let likeCountText: String?
    let replyCountText: String?

    var value: VideoComment {
        VideoComment(
            id: id,
            authorName: authorName,
            authorAvatarURL: authorAvatarURL,
            text: text,
            publishedText: publishedText,
            likeCountText: likeCountText,
            replyCountText: replyCountText
        )
    }
}

private struct MockSuggestions: Decodable {
    let suggestions: [String]
}

private struct MockPlayback: Decodable {
    let source: Source

    struct Source: Decodable {
        let url: String
        let kind: String
    }
}

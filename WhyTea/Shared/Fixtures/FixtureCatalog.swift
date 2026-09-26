#if DEBUG
import Foundation
import WhyTeaYouTube

/// The shared fixture catalog as in-process values, decoded from the bundled
/// `catalog.json` (schema 1) that the loopback fixture server also serves: the
/// same IDs, text, page size, and continuation tokens, without that server's
/// media URLs. Tests adjust a copy to script empty, repeated, or playable
/// cases.
nonisolated struct FixtureCatalog: Sendable {
    struct Video: Sendable {
        var summary: VideoSummary
        var subscriberCountText: String?
        var likeCountText: String?
        var descriptionText: String
        var commentCountText: String?
        var related: [VideoID]
        var comments: [VideoComment]
    }

    var videos: [VideoID: Video]
    var home: [VideoID]
    /// Keyed by lowercased query; served `pageSize` results at a time.
    var searches: [String: [VideoID]]
    var suggestions: [String: [String]]
    var defaultSuggestions: [String]
    /// Empty by default: fixture playback fails with a typed error rather
    /// than pointing AVPlayer at a URL that does not exist.
    var playback: [VideoID: PlaybackSource] = [:]
    var pageSize = 2

    static func searchToken(query: String, page: Int) -> String {
        "search:\(query):\(page)"
    }

    static func commentsToken(for id: VideoID, page: Int) -> String {
        "\(id.rawValue):comments:\(page)"
    }

    func searchPage(token: String) throws -> VideoPage {
        // `search:<query>:<page>`, where the query itself may contain colons.
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts[0] == "search", let number = Int(parts[parts.count - 1]) else {
            throw FixtureServiceError.invalidToken(token)
        }
        let query = parts[1..<(parts.count - 1)].joined(separator: ":")
        let ids = searches[query.trimmingCharacters(in: .whitespaces).lowercased()] ?? []
        let (slice, hasMore) = try slice(of: ids, page: number, token: token)
        return VideoPage(
            videos: slice.compactMap { videos[$0]?.summary },
            continuationToken: hasMore ? Self.searchToken(query: query, page: number + 1) : nil
        )
    }

    func suggestions(for query: String) -> [String] {
        suggestions[query.lowercased()] ?? defaultSuggestions
    }

    func details(for id: VideoID) throws -> VideoDetails {
        guard let video = videos[id] else { throw YouTubeClientError.missingDetails(id) }
        return VideoDetails(
            id: id,
            title: video.summary.title,
            channelName: video.summary.channelName,
            channelID: video.summary.channelID,
            subscriberCountText: video.subscriberCountText,
            viewCountText: video.summary.viewCountText,
            publishedText: video.summary.publishedText,
            likeCountText: video.likeCountText,
            descriptionText: video.descriptionText,
            commentCountText: video.commentCountText,
            commentsToken: Self.commentsToken(for: id, page: 0),
            related: video.related.compactMap { videos[$0]?.summary }
        )
    }

    func commentPage(token: String) throws -> CommentPage {
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[1] == "comments",
              let id = VideoID(rawValue: String(parts[0])), let number = Int(parts[2]),
              let video = videos[id] else {
            throw FixtureServiceError.invalidToken(token)
        }
        let (slice, hasMore) = try slice(of: video.comments, page: number, token: token)
        return CommentPage(
            comments: Array(slice),
            continuationToken: hasMore ? Self.commentsToken(for: id, page: number + 1) : nil
        )
    }

    private func slice<Element>(of elements: [Element], page: Int, token: String) throws -> (ArraySlice<Element>, Bool) {
        let start = page * pageSize
        guard page >= 0, start <= elements.count else { throw FixtureServiceError.invalidToken(token) }
        let end = min(start + pageSize, elements.count)
        return (elements[start..<end], end < elements.count)
    }
}

nonisolated extension FixtureCatalog {
    /// The bundled `catalog.json`. A missing or malformed resource is a build
    /// defect, not a runtime condition, so it stops the DEBUG process.
    static let standard: FixtureCatalog = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json") else {
            fatalError("catalog.json is not in the app bundle")
        }
        do {
            return try FixtureCatalog(file: JSONDecoder().decode(CatalogFile.self, from: Data(contentsOf: url)))
        } catch {
            fatalError("catalog.json could not be decoded: \(error)")
        }
    }()

    private init(file: CatalogFile) {
        precondition(file.schemaVersion == 1, "catalog.json schema \(file.schemaVersion) is not supported")
        var videos: [VideoID: Video] = [:]
        for (key, entry) in file.videos {
            let id = entry.summary.id
            precondition(id.rawValue == key, "catalog.json video \(key) does not match its summary id")
            videos[id] = Video(
                summary: VideoSummary(
                    id: id,
                    title: entry.summary.title,
                    channelName: entry.summary.channelName,
                    channelID: entry.summary.channelID,
                    durationText: entry.summary.durationText,
                    viewCountText: entry.summary.viewCountText,
                    publishedText: entry.summary.publishedText
                ),
                subscriberCountText: entry.details.subscriberCountText,
                likeCountText: entry.details.likeCountText,
                descriptionText: entry.details.descriptionText,
                commentCountText: entry.details.commentCountText,
                related: entry.details.related,
                comments: entry.comments.map {
                    VideoComment(
                        id: $0.id,
                        authorName: $0.authorName,
                        text: $0.text,
                        publishedText: $0.publishedText,
                        likeCountText: $0.likeCountText,
                        replyCountText: $0.replyCountText
                    )
                }
            )
        }
        var suggestions = file.suggestions
        let defaultSuggestions = suggestions.removeValue(forKey: "default") ?? []
        self.init(
            videos: videos,
            home: file.home,
            searches: file.search,
            suggestions: suggestions,
            defaultSuggestions: defaultSuggestions
        )
    }
}

/// The on-disk shape of `catalog.json`. The loopback server's media paths are
/// not decoded; in-process fixtures have no artwork.
nonisolated private struct CatalogFile: Decodable {
    struct Video: Decodable {
        struct Summary: Decodable {
            var id: VideoID
            var title: String
            var channelName: String?
            var channelID: String?
            var durationText: String?
            var viewCountText: String?
            var publishedText: String?
        }

        struct Details: Decodable {
            var subscriberCountText: String?
            var descriptionText: String
            var commentCountText: String?
            var likeCountText: String?
            var related: [VideoID]
        }

        struct Comment: Decodable {
            var id: String
            var authorName: String?
            var text: String
            var publishedText: String?
            var likeCountText: String?
            var replyCountText: String?
        }

        var summary: Summary
        var details: Details
        var comments: [Comment]
    }

    var schemaVersion: Int
    var home: [VideoID]
    var search: [String: [VideoID]]
    var suggestions: [String: [String]]
    var videos: [String: Video]
}
#endif

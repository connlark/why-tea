import Foundation

/// A video as it appears in a feed, search result, or related list.
public struct VideoSummary: Identifiable, Hashable, Sendable {
    public let id: VideoID
    public let title: String
    public let channelName: String?
    public let channelID: String?
    public let thumbnailURL: URL?
    public let durationText: String?
    public let viewCountText: String?
    public let publishedText: String?

    public init(
        id: VideoID,
        title: String,
        channelName: String? = nil,
        channelID: String? = nil,
        thumbnailURL: URL? = nil,
        durationText: String? = nil,
        viewCountText: String? = nil,
        publishedText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.channelName = channelName
        self.channelID = channelID
        self.thumbnailURL = thumbnailURL
        self.durationText = durationText
        self.viewCountText = viewCountText
        self.publishedText = publishedText
    }
}

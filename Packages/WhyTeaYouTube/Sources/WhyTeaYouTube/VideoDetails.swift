import Foundation

/// Watch-page details for one video.
public struct VideoDetails: Sendable {
    public let id: VideoID
    public let title: String
    public let channelName: String?
    public let channelID: String?
    public let channelAvatarURL: URL?
    public let subscriberCountText: String?
    public let viewCountText: String?
    public let publishedText: String?
    public let likeCountText: String?
    public let descriptionText: String
    public let commentCountText: String?
    public let commentsToken: String?
    public let related: [VideoSummary]

    public init(
        id: VideoID,
        title: String,
        channelName: String? = nil,
        channelID: String? = nil,
        channelAvatarURL: URL? = nil,
        subscriberCountText: String? = nil,
        viewCountText: String? = nil,
        publishedText: String? = nil,
        likeCountText: String? = nil,
        descriptionText: String = "",
        commentCountText: String? = nil,
        commentsToken: String? = nil,
        related: [VideoSummary] = []
    ) {
        self.id = id
        self.title = title
        self.channelName = channelName
        self.channelID = channelID
        self.channelAvatarURL = channelAvatarURL
        self.subscriberCountText = subscriberCountText
        self.viewCountText = viewCountText
        self.publishedText = publishedText
        self.likeCountText = likeCountText
        self.descriptionText = descriptionText
        self.commentCountText = commentCountText
        self.commentsToken = commentsToken
        self.related = related
    }
}

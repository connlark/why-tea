import Foundation

public struct VideoComment: Identifiable, Hashable, Sendable {
    public let id: String
    public let authorName: String?
    public let authorAvatarURL: URL?
    public let text: String
    public let publishedText: String?
    public let likeCountText: String?
    public let replyCountText: String?

    public init(
        id: String,
        authorName: String? = nil,
        authorAvatarURL: URL? = nil,
        text: String,
        publishedText: String? = nil,
        likeCountText: String? = nil,
        replyCountText: String? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.authorAvatarURL = authorAvatarURL
        self.text = text
        self.publishedText = publishedText
        self.likeCountText = likeCountText
        self.replyCountText = replyCountText
    }
}

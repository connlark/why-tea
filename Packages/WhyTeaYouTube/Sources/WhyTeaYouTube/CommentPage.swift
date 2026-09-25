/// One page of top-level comments plus the token for the next page, if any.
public struct CommentPage: Sendable {
    public let comments: [VideoComment]
    public let continuationToken: String?

    public init(comments: [VideoComment], continuationToken: String?) {
        self.comments = comments
        self.continuationToken = continuationToken
    }
}

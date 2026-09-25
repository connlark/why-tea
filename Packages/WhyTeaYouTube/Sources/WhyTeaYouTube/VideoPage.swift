/// One page of videos plus the token for the next page, if any.
public struct VideoPage: Sendable {
    public let videos: [VideoSummary]
    public let continuationToken: String?

    public init(videos: [VideoSummary], continuationToken: String?) {
        self.videos = videos
        self.continuationToken = continuationToken
    }
}

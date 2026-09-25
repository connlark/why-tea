import Foundation
import WhyTeaYouTube

extension VideoSummary {
    static let sample = VideoSummary(
        id: VideoID(rawValue: "dQw4w9WgXcQ")!,
        title: "Rick Astley - Never Gonna Give You Up (Official Video)",
        channelName: "Rick Astley",
        thumbnailURL: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"),
        durationText: "3:33",
        viewCountText: "1.7B views",
        publishedText: "16 years ago"
    )

    static let sampleLongTitle = VideoSummary(
        id: VideoID(rawValue: "jNQXAC9IVRw")!,
        title: "A deliberately long title that wraps across several lines so row layout can be checked at larger Dynamic Type sizes",
        channelName: "jawed",
        thumbnailURL: URL(string: "https://i.ytimg.com/vi/jNQXAC9IVRw/hqdefault.jpg"),
        durationText: "0:19",
        viewCountText: "380M views",
        publishedText: "21 years ago"
    )
}

extension VideoDetails {
    static let sample = VideoDetails(
        id: VideoSummary.sample.id,
        title: VideoSummary.sample.title,
        channelName: "Rick Astley",
        subscriberCountText: "4.3M subscribers",
        viewCountText: "1.7B views",
        publishedText: "16 years ago",
        likeCountText: "18M",
        descriptionText: "The official video for “Never Gonna Give You Up” by Rick Astley.\n\nNever: The Autobiography is out now.",
        commentCountText: "2.4M",
        related: [.sampleLongTitle]
    )
}

extension VideoComment {
    static let sample = VideoComment(
        id: "sample-comment",
        authorName: "@someone",
        text: "Still the best thing to find at the other end of a link.",
        publishedText: "2 days ago",
        likeCountText: "1.2K",
        replyCountText: "34"
    )
}

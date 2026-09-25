import YouTubeAPI

extension YTComment {
    var videoComment: VideoComment {
        VideoComment(
            id: commentIdentifier,
            authorName: sender?.name ?? sender?.handle,
            authorAvatarURL: sender?.thumbnails.largest?.url,
            text: text,
            publishedText: timePosted,
            likeCountText: likesCount,
            replyCountText: totalRepliesNumber
        )
    }
}

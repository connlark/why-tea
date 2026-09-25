import YouTubeAPI

extension YTVideo {
    var videoSummary: VideoSummary? {
        guard let id = VideoID(rawValue: videoId) else { return nil }
        return VideoSummary(
            id: id,
            title: title ?? "Untitled",
            channelName: channel?.name,
            channelID: channel?.channelId,
            thumbnailURL: thumbnails.largest?.url,
            durationText: timeLength,
            viewCountText: viewCount,
            publishedText: timePosted
        )
    }
}

extension [any YTSearchResult] {
    var videoSummaries: [VideoSummary] {
        compactMap { ($0 as? YTVideo)?.videoSummary }.uniqued
    }
}

extension [VideoSummary] {
    /// YouTube repeats a video when it appears in more than one shelf.
    var uniqued: [VideoSummary] {
        var seen = Set<VideoID>()
        return filter { seen.insert($0.id).inserted }
    }
}

extension [YTThumbnail] {
    var largest: YTThumbnail? {
        self.max { ($0.width ?? 0) < ($1.width ?? 0) }
    }
}

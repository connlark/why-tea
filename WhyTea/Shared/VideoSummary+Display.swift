import WhyTeaYouTube

extension VideoSummary {
    var metadataLine: String? {
        let parts = [viewCountText, publishedText].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

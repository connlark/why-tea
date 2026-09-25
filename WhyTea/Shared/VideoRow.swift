import SwiftUI
import WhyTeaYouTube

struct VideoRow: View {
    let video: VideoSummary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VideoThumbnail(url: video.thumbnailURL, durationText: video.durationText)
                .frame(width: 160)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .lineLimit(3)
                if let channelName = video.channelName {
                    Text(channelName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let metadataLine = video.metadataLine {
                    Text(metadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        VideoRow(video: .sample)
        VideoRow(video: .sampleLongTitle)
    }
    .listStyle(.plain)
}

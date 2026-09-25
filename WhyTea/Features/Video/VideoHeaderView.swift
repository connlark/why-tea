import SwiftUI
import WhyTeaYouTube

struct VideoHeaderView: View {
    let details: VideoDetails
    let playback: PlaybackPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(details.title)
                .font(.headline)
                .textSelection(.enabled)

            if let statsLine {
                Text(statsLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                AsyncImage(url: details.channelAvatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(.quaternary)
                }
                .frame(width: 36, height: 36)
                .clipShape(.circle)
                .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(details.channelName ?? "Unknown channel")
                        .font(.subheadline)
                    if let subscriberCountText = details.subscriberCountText {
                        Text(subscriberCountText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let likeCountText = details.likeCountText {
                    Label(likeCountText, systemImage: "hand.thumbsup")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let sourceDescription {
                Label(sourceDescription, systemImage: "iphone")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var statsLine: String? {
        let parts = [details.viewCountText, details.publishedText].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var sourceDescription: String? {
        guard case .ready(_, let kind) = playback else { return nil }
        return switch kind {
        case .hls: "Adaptive HLS, resolved on device"
        case .progressive(let resolution?): "Muxed \(resolution)p MP4, resolved on device"
        case .progressive(nil): "Muxed MP4, resolved on device"
        }
    }
}

#Preview {
    VideoHeaderView(details: .sample, playback: .resolving)
        .padding()
}

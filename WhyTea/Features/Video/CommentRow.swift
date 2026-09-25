import SwiftUI
import WhyTeaYouTube

struct CommentRow: View {
    let comment: VideoComment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: comment.authorAvatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(.quaternary)
            }
            .frame(width: 32, height: 32)
            .clipShape(.circle)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(headerLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(comment.text)
                    .font(.subheadline)
                    .textSelection(.enabled)
                HStack(spacing: 16) {
                    if let likeCountText = comment.likeCountText, !likeCountText.isEmpty {
                        Label(likeCountText, systemImage: "hand.thumbsup")
                    }
                    if let replyCountText = comment.replyCountText, !replyCountText.isEmpty {
                        Label(replyCountText, systemImage: "arrowshape.turn.up.left")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headerLine: String {
        [comment.authorName, comment.publishedText].compactMap(\.self).joined(separator: " · ")
    }
}

#Preview {
    CommentRow(comment: .sample)
        .padding()
}

import SwiftUI

struct VideoThumbnail: View {
    let url: URL?
    var durationText: String?

    var body: some View {
        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
            }
            .clipShape(.rect(cornerRadius: 8))
            .overlay(alignment: .bottomTrailing) {
                if let durationText {
                    Text(durationText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .background(.black.opacity(0.75), in: .rect(cornerRadius: 4))
                        .padding(4)
                }
            }
            .accessibilityHidden(true)
    }
}

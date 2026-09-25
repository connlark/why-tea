import SwiftUI
import WhyTeaYouTube

struct VideoDescriptionView: View {
    let text: String

    @State private var isExpanded = false

    var body: some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.footnote)
                    .lineLimit(isExpanded ? nil : 3)
                    .textSelection(.enabled)
                Button(isExpanded ? "Show Less" : "Show More", action: toggle)
                    .font(.footnote)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
        }
    }

    private func toggle() {
        withAnimation(.snappy) {
            isExpanded.toggle()
        }
    }
}

#Preview {
    VideoDescriptionView(text: VideoDetails.sample.descriptionText)
        .padding()
}

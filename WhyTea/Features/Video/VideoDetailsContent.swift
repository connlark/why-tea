import SwiftUI
import WhyTeaYouTube

struct VideoDetailsContent: View {
    let details: VideoDetails
    let model: VideoModel

    @State private var section: VideoScreenSection = .related

    var body: some View {
        VideoHeaderView(details: details, playback: model.playback)
        VideoDescriptionView(text: details.descriptionText)

        Picker("Section", selection: $section) {
            ForEach(VideoScreenSection.allCases) { section in
                Text(section.title).tag(section)
            }
        }
        .pickerStyle(.segmented)

        switch section {
        case .related:
            RelatedVideosList(videos: details.related)
        case .comments:
            CommentsList(model: model)
        }
    }
}

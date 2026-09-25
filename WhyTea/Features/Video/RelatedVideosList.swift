import SwiftUI
import WhyTeaYouTube

struct RelatedVideosList: View {
    let videos: [VideoSummary]

    var body: some View {
        if videos.isEmpty {
            ContentUnavailableView("No Related Videos", systemImage: "rectangle.stack")
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(videos) { video in
                    NavigationLink(value: AppRoute.video(video.id)) {
                        VideoRow(video: video)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

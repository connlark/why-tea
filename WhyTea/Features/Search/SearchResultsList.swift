import SwiftUI
import WhyTeaYouTube

struct SearchResultsList: View {
    let videos: [VideoSummary]
    let model: SearchModel

    var body: some View {
        List {
            ForEach(videos) { video in
                NavigationLink(value: AppRoute.video(video.id)) {
                    VideoRow(video: video)
                }
            }
            if model.continuationToken != nil {
                LoadMoreRow(
                    errorMessage: model.loadMoreError,
                    pageCount: videos.count,
                    load: model.loadMore,
                    retry: model.retryLoadMore
                )
            }
        }
        .listStyle(.plain)
    }
}

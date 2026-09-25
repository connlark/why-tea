import SwiftUI

struct CommentsList: View {
    let model: VideoModel

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(model.comments) { comment in
                CommentRow(comment: comment)
            }

            if model.commentsToken != nil {
                LoadMoreRow(
                    errorMessage: model.commentsError,
                    pageCount: model.comments.count,
                    load: model.loadMoreComments,
                    retry: model.retryComments
                )
            } else if model.comments.isEmpty {
                ContentUnavailableView("No Comments", systemImage: "text.bubble")
            }
        }
    }
}

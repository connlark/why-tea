import SwiftUI

/// Footer that loads the next page when it scrolls into view, or offers a
/// retry after a failure. Clearing the error re-shows the spinner, whose
/// `task` performs the retry.
struct LoadMoreRow: View {
    let errorMessage: String?
    let pageCount: Int
    let load: () async -> Void
    let retry: () -> Void

    var body: some View {
        if let errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Retry", systemImage: "arrow.clockwise", action: retry)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
                .task(id: pageCount) { await load() }
        }
    }
}

import SwiftUI
import WhyTeaYouTube

struct VideoScreen: View {
    @State private var model: VideoModel

    init(id: VideoID) {
        _model = State(initialValue: VideoModel(id: id))
    }

    var body: some View {
        VStack(spacing: 0) {
            VideoPlayerSurface(playback: model.playback, retry: model.retry)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch model.details {
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    case .failed(let message):
                        ContentUnavailableView {
                            Label("Couldn't Load Details", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Try Again", action: model.retry)
                        }
                    case .loaded(let details):
                        VideoDetailsContent(details: details, model: model)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: model.loadAttempt) { await model.load() }
        .onDisappear(perform: model.pause)
    }
}

import AVKit
import SwiftUI

struct VideoPlayerSurface: View {
    let playback: PlaybackPhase
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color.black
            switch playback {
            case .resolving:
                ProgressView()
                    .tint(.white)
            case .ready(let player, _):
                VideoPlayer(player: player)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Can't Play", systemImage: "play.slash")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again", action: retry)
                }
                .environment(\.colorScheme, .dark)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }
}

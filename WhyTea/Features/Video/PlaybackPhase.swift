import AVFoundation
import WhyTeaYouTube

enum PlaybackPhase {
    case resolving
    case ready(AVPlayer, PlaybackSource.Kind)
    case failed(String)
}

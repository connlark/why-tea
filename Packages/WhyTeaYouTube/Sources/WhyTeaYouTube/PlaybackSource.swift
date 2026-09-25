import Foundation

/// A URL AVPlayer can open directly.
public struct PlaybackSource: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Adaptive HLS manifest from the iOS InnerTube client. Preferred.
        case hls
        /// Single muxed audio+video file. Usually capped at 360p.
        case progressive(resolution: Int?)
    }

    public let url: URL
    public let kind: Kind

    public init(url: URL, kind: Kind) {
        self.url = url
        self.kind = kind
    }
}

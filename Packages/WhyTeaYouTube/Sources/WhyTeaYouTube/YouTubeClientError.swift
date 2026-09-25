import Foundation

public enum YouTubeClientError: LocalizedError, Sendable {
    case noPlayableStream(VideoID)
    case missingDetails(VideoID)

    public var errorDescription: String? {
        switch self {
        case .noPlayableStream(let id): "No stream for \(id) that this device can play."
        case .missingDetails(let id): "YouTube returned no details for \(id)."
        }
    }
}

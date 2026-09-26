#if DEBUG
import Foundation

nonisolated enum FixtureServiceError: LocalizedError, Hashable, Sendable {
    case offline
    case invalidToken(String)
    case playbackUnavailable

    var errorDescription: String? {
        switch self {
        case .offline: "The fixture service is simulating a connection failure."
        case .invalidToken(let token): "The fixture catalog has no page for \(token)."
        case .playbackUnavailable: "Fixture data has no playable stream for this video."
        }
    }
}
#endif

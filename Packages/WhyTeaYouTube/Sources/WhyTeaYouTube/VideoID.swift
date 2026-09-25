import Foundation

/// An 11-character YouTube video identifier.
public struct VideoID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard Self.isValid(rawValue) else { return nil }
        self.rawValue = rawValue
    }

    /// Accepts a bare ID or any common YouTube link: `watch?v=`, `youtu.be/`,
    /// `/shorts/`, `/embed/`, `/live/`, and `/v/`.
    public init?(parsing input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id = VideoID(rawValue: trimmed) {
            self = id
            return
        }

        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: withScheme), let host = components.host?.lowercased() else {
            return nil
        }

        let pathSegments = components.path.split(separator: "/").map(String.init)
        let candidate: String? = if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            pathSegments.first
        } else if host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtube-nocookie.com" || host.hasSuffix(".youtube-nocookie.com") {
            if let value = components.queryItems?.first(where: { $0.name == "v" })?.value {
                value
            } else if pathSegments.count >= 2, Self.pathPrefixes.contains(pathSegments[0]) {
                pathSegments[1]
            } else {
                nil
            }
        } else {
            nil
        }

        guard let candidate, let id = VideoID(rawValue: candidate) else { return nil }
        self = id
    }

    public var description: String { rawValue }

    private static let pathPrefixes: Set<String> = ["shorts", "embed", "live", "v"]

    private static func isValid(_ value: String) -> Bool {
        value.count == 11 && value.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == "_")
        }
    }
}

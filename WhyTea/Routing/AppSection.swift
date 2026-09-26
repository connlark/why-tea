import Foundation
import SwiftUI

/// The shell's top-level sections, in sidebar and tab-bar order. Every section
/// works logged out, so none depends on account state.
enum AppSection: String, CaseIterable, Identifiable {
    case home
    case following
    case search
    case library
    case settings

    var id: Self { self }

    /// The visible label, which is also the VoiceOver label.
    var title: LocalizedStringResource {
        switch self {
        case .home: "Home"
        case .following: "Following"
        case .search: "Search"
        case .library: "Library"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .following: "person.2"
        case .search: "magnifyingglass"
        case .library: "rectangle.stack"
        case .settings: "gear"
        }
    }

    var accessibilityHint: LocalizedStringResource {
        switch self {
        case .home: "Your starting point for watching."
        case .following: "New videos from channels you follow on this device."
        case .search: "Search YouTube or open a link."
        case .library: "Your queue, history, and saved videos."
        case .settings: "About why tea and how it works."
        }
    }

    /// Stable identifier for UI automation and hierarchy evidence.
    var accessibilityIdentifier: String { "section.\(rawValue)" }

    var tabRole: TabRole? { self == .search ? .search : nil }

    /// Search is the discovery entry point at every width and Settings holds
    /// recovery, so neither can be hidden. That guarantees a visible section
    /// to fall back to when another one hides.
    var isHideable: Bool {
        switch self {
        case .home, .following, .library: true
        case .search, .settings: false
        }
    }
}

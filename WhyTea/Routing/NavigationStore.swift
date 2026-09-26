import Foundation
import Observation
import WhyTeaYouTube

/// The app's single navigation owner: the selected section, one route path per
/// section, the presented sheet, and pending external requests. Views render
/// it and call its named actions; it never starts I/O or creates players.
///
/// Each section keeps its own path, so a pushed route survives a section
/// switch, a width change, and a sidebar collapse.
@Observable
final class NavigationStore {
    private(set) var selectedSection: AppSection = .search
    private(set) var hiddenSections: Set<AppSection> = []
    private(set) var searchRequest: SearchRequest?
    var sheet: SheetDestination?

    private let paths = Dictionary(uniqueKeysWithValues: AppSection.allCases.map { ($0, SectionPath()) })
    @ObservationIgnored private var lastSearchRequestID = 0

    /// The `TabView` selection. Writes go through `select(_:)`, so a hidden
    /// section can never become selected.
    var selection: AppSection {
        get { selectedSection }
        set { select(newValue) }
    }

    /// One section's route path, bound to that section's `NavigationStack`.
    subscript(path section: AppSection) -> [AppRoute] {
        get { paths[section]!.routes }
        set { paths[section]!.routes = newValue }
    }

    func select(_ section: AppSection) {
        guard !hiddenSections.contains(section) else { return }
        selectedSection = section
    }

    /// Opens a route from outside the current stack: selects the section that
    /// owns it, then pushes it there unless it is already on top.
    func open(_ route: AppRoute) {
        sheet = nil
        let section = route.owningSection
        select(section)
        if self[path: section].last != route {
            self[path: section].append(route)
        }
    }

    func popToRoot(_ section: AppSection) {
        self[path: section] = []
    }

    func present(_ destination: SheetDestination) {
        sheet = destination
    }

    /// Selects Search, returns it to its results, and asks it to run `query`.
    func search(_ query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        select(.search)
        popToRoot(.search)
        lastSearchRequestID += 1
        searchRequest = SearchRequest(query: query, id: lastSearchRequestID)
    }

    /// Called by Search once it has taken `request`; a newer request survives.
    func consume(_ request: SearchRequest) {
        if searchRequest == request {
            searchRequest = nil
        }
    }

    /// Handles a `whytea:` URL: a video ID or any YouTube link minus its
    /// scheme, such as `whytea://youtu.be/dQw4w9WgXcQ`. A link that does not
    /// name a video opens the Open Link sheet with the text filled in, so the
    /// person sees why nothing played. Returns `false` for other schemes.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "whytea" else { return false }
        let link = URLComponents(url: url, resolvingAgainstBaseURL: false).map(Self.link(from:)) ?? url.absoluteString
        if let id = VideoID(parsing: link) {
            open(.video(id))
        } else {
            present(.openLink(text: link.removingPercentEncoding ?? link))
        }
        return true
    }

    /// Everything after the scheme as `host/path?query#fragment`, whether the
    /// URL was written with `//`, `///`, or no slashes at all.
    private static func link(from components: URLComponents) -> String {
        var link = (components.percentEncodedHost ?? "") + components.percentEncodedPath
        if let query = components.percentEncodedQuery {
            link += "?\(query)"
        }
        if let fragment = components.percentEncodedFragment {
            link += "#\(fragment)"
        }
        return String(link.drop { $0 == "/" })
    }

    /// Applies the requests present at cold launch, once, in an order that
    /// leaves each visible: the section, then a search, then a link on top.
    func applyLaunch(section: AppSection?, searchQuery: String?, openURL: URL?) {
        if let section {
            select(section)
        }
        if let searchQuery {
            search(searchQuery)
        }
        if let openURL {
            handle(openURL)
        }
    }

    func isHidden(_ section: AppSection) -> Bool {
        hiddenSections.contains(section)
    }

    /// Hides or shows a section. Selection moves to the first visible section
    /// before the hidden one leaves the tab view, because a `TabView` must
    /// never be left selecting a tab it no longer shows. The hidden section's
    /// path is kept for when it returns.
    func setHidden(_ hidden: Bool, for section: AppSection) {
        guard hidden else {
            hiddenSections.remove(section)
            return
        }
        guard section.isHideable else { return }
        if selectedSection == section {
            selectedSection = AppSection.allCases.first { $0 != section && !hiddenSections.contains($0) } ?? .search
        }
        hiddenSections.insert(section)
    }
}

/// One section's path as its own observable, so a push in one section
/// invalidates only that section's `NavigationStack`.
@Observable
private final class SectionPath {
    var routes: [AppRoute] = []
}

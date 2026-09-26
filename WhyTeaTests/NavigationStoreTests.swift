import Foundation
import Testing
import WhyTeaYouTube
@testable import WhyTea

struct NavigationStoreTests {
    private let rick = VideoID(rawValue: "dQw4w9WgXcQ")!
    private let zoo = VideoID(rawValue: "jNQXAC9IVRw")!

    @Test func startsOnSearchWithEmptyPathsAndNoSheet() {
        let store = NavigationStore()
        #expect(store.selection == .search)
        #expect(AppSection.allCases.allSatisfy { store[path: $0].isEmpty })
        #expect(store.sheet == nil)
        #expect(store.searchRequest == nil)
    }

    @Test func sectionsAreInSidebarOrder() {
        #expect(AppSection.allCases == [.home, .following, .search, .library, .settings])
        #expect(AppSection.search.tabRole == .search)
        #expect(AppSection.allCases.filter { $0.tabRole != nil } == [.search])
    }

    @Test func eachSectionKeepsItsOwnPathAcrossSelection() {
        let store = NavigationStore()
        store[path: .search].append(.video(rick))
        store.selection = .library
        store[path: .library].append(.video(zoo))

        store.selection = .search
        #expect(store[path: .search] == [.video(rick)])
        #expect(store[path: .library] == [.video(zoo)])
        #expect(store[path: .home].isEmpty)
    }

    @Test func backAndForwardRestoreTheRoute() {
        let store = NavigationStore()
        store[path: .search] = [.video(rick), .video(zoo)]
        store[path: .search].removeLast()
        #expect(store[path: .search] == [.video(rick)])
        store[path: .search].append(.video(zoo))
        #expect(store[path: .search] == [.video(rick), .video(zoo)])
        store.popToRoot(.search)
        #expect(store[path: .search].isEmpty)
    }

    @Test func openingAVideoSelectsItsSectionAndPushesOnce() {
        let store = NavigationStore()
        store.selection = .library
        store[path: .library].append(.video(zoo))
        store.present(.openLink())

        store.open(.video(rick))
        store.open(.video(rick))

        #expect(store.selection == .search)
        #expect(store[path: .search] == [.video(rick)])
        #expect(store[path: .library] == [.video(zoo)])
        #expect(store.sheet == nil)
    }

    @Test(arguments: [
        "whytea://dQw4w9WgXcQ",
        "whytea:dQw4w9WgXcQ",
        "whytea:///youtu.be/dQw4w9WgXcQ",
        "whytea://youtu.be/dQw4w9WgXcQ",
        "WHYTEA://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "whytea://m.youtube.com/shorts/dQw4w9WgXcQ"
    ])
    func whyteaURLsOpenTheVideo(link: String) throws {
        let store = NavigationStore()
        store.selection = .home
        let url = try #require(URL(string: link))

        #expect(store.handle(url))
        #expect(store.selection == .search)
        #expect(store[path: .search] == [.video(rick)])
    }

    @Test func unparseableLinkShowsItInOpenLink() throws {
        let store = NavigationStore()
        let url = try #require(URL(string: "whytea://example.com/not-a-video"))

        #expect(store.handle(url))
        #expect(store.sheet == .openLink(text: "example.com/not-a-video"))
        #expect(store[path: .search].isEmpty)
    }

    @Test func otherSchemesAreNotHandled() throws {
        let store = NavigationStore()
        #expect(!store.handle(try #require(URL(string: "https://youtu.be/dQw4w9WgXcQ"))))
        #expect(store[path: .search].isEmpty)
    }

    @Test func searchSelectsSearchPopsToResultsAndIsConsumedOnce() {
        let store = NavigationStore()
        store.selection = .following
        store[path: .search].append(.video(rick))

        store.search("  swiftui ")
        let first = store.searchRequest
        #expect(store.selection == .search)
        #expect(store[path: .search].isEmpty)
        #expect(first?.query == "swiftui")

        store.search("swiftui")
        let second = store.searchRequest
        #expect(second != first)

        if let first {
            store.consume(first)
        }
        #expect(store.searchRequest == second)
        if let second {
            store.consume(second)
        }
        #expect(store.searchRequest == nil)

        store.search("   ")
        #expect(store.searchRequest == nil)
    }

    @Test func coldLaunchLeavesTheLinkOnTopOfTheSearch() throws {
        let store = NavigationStore()
        store.applyLaunch(
            section: .library,
            searchQuery: "whytea",
            openURL: try #require(URL(string: "whytea://youtu.be/dQw4w9WgXcQ"))
        )

        #expect(store.selection == .search)
        #expect(store.searchRequest?.query == "whytea")
        #expect(store[path: .search] == [.video(rick)])
    }

    @Test func coldLaunchCanSelectASectionAlone() {
        let store = NavigationStore()
        store.applyLaunch(section: .settings, searchQuery: nil, openURL: nil)
        #expect(store.selection == .settings)
        #expect(store.searchRequest == nil)
    }

    @Test func hidingTheSelectedSectionMovesSelectionFirst() {
        let store = NavigationStore()
        store.selection = .library
        store[path: .library].append(.video(zoo))

        store.setHidden(true, for: .library)
        #expect(store.selection == .home)
        #expect(store.isHidden(.library))

        store.selection = .library
        #expect(store.selection == .home)

        store.setHidden(true, for: .home)
        #expect(store.selection == .following)

        store.setHidden(false, for: .library)
        store.selection = .library
        #expect(store.selection == .library)
        #expect(store[path: .library] == [.video(zoo)])
    }

    @Test func searchAndSettingsCannotBeHidden() {
        let store = NavigationStore()
        store.setHidden(true, for: .search)
        store.setHidden(true, for: .settings)
        #expect(!store.isHidden(.search))
        #expect(!store.isHidden(.settings))
        #expect(store.selection == .search)
    }
}

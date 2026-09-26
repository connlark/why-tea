import SwiftUI

/// The WhyTea shell: one `TabView` with the sidebar-adaptable style, a sidebar
/// on iPad that the person can collapse into the floating tab bar, and a tab
/// bar on iPhone. Each tab wraps its section's own `NavigationStack`, so the
/// hierarchy is never rebuilt when the width changes.
///
/// Followed channels get a sidebar-only `TabSection` directly beneath
/// Following once local follows exist; until then there is nothing to list,
/// and an empty section header would be a placeholder, so none is shown.
struct RootView: View {
    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selection) {
            ForEach(AppSection.allCases) { section in
                Tab(section.title, systemImage: section.systemImage, value: section, role: section.tabRole) {
                    SectionNavigationStack(section: section)
                }
                .accessibilityHint(Text(section.accessibilityHint))
                .accessibilityIdentifier(section.accessibilityIdentifier)
                .hidden(navigation.isHidden(section))
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .sheet(item: $navigation.sheet, content: SheetDestinationView.init)
        .onOpenURL(perform: handleOpenURL)
    }

    private func handleOpenURL(_ url: URL) {
        navigation.handle(url)
    }
}

#if DEBUG
#Preview {
    RootView()
        .environment(NavigationStore())
        .environment(\.youTubeService, FixtureYouTubeService())
}
#endif

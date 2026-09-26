import SwiftUI

/// One section's `NavigationStack`, bound to that section's path in the
/// navigation store, with the app's single destination registration.
struct SectionNavigationStack: View {
    let section: AppSection

    @Environment(NavigationStore.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation[path: section]) {
            SectionRootView(section: section)
                .withWhyTeaDestinations()
        }
    }
}

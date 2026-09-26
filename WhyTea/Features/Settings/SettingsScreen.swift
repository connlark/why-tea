import SwiftUI

/// Settings has no preferences yet. It states what the build is and how the
/// app reaches YouTube.
struct SettingsScreen: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: "\(version) (\(build))")
            } footer: {
                Text("Playback, library, and caption settings arrive with the features they control.")
            }

            Section("How It Works") {
                Label("Search, video details, comments, and playback go straight from this device to YouTube. There's no server in between.", systemImage: "iphone")
                Label("There's no sign-in. Search and playback work without a Google account.", systemImage: "person.crop.circle.badge.xmark")
            }
        }
        .navigationTitle(Text(AppSection.settings.title))
    }
}

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}

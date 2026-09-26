import SwiftUI

/// Keyboard commands for the shell: Command-1 to Command-5 select a section and
/// Command-L opens a link. They also appear in the iPad menu bar.
struct SectionCommands: Commands {
    let navigation: NavigationStore

    var body: some Commands {
        CommandMenu("Go") {
            ForEach(Array(AppSection.allCases.enumerated()), id: \.element) { index, section in
                Button(section.title, systemImage: section.systemImage) {
                    navigation.select(section)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .disabled(navigation.isHidden(section))
            }
            Divider()
            Button("Open Link…", systemImage: "link", action: openLink)
                .keyboardShortcut("l", modifiers: .command)
        }
    }

    private func openLink() {
        navigation.present(.openLink())
    }
}

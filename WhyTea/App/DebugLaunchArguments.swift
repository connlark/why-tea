#if DEBUG
import Foundation

/// Launch-argument hooks for driving the app without UI input. Values arrive
/// through the `UserDefaults` argument domain:
///
/// - `-WhyTeaOpenURL whytea://youtu.be/dQw4w9WgXcQ`
/// - `-WhyTeaSearch "swiftui"`
/// - `-WhyTeaSection library` (any `AppSection` raw value)
/// - `-WhyTeaFixtures YES` serves the in-process fixture catalog instead of
///   YouTube, so simulator checks and screenshots never contact YouTube.
enum DebugLaunchArguments {
    static var openURL: URL? {
        UserDefaults.standard.string(forKey: "WhyTeaOpenURL").flatMap(URL.init(string:))
    }

    static var searchQuery: String? {
        UserDefaults.standard.string(forKey: "WhyTeaSearch")
    }

    static var section: AppSection? {
        UserDefaults.standard.string(forKey: "WhyTeaSection").flatMap(AppSection.init(rawValue:))
    }

    static var usesFixtures: Bool {
        UserDefaults.standard.bool(forKey: "WhyTeaFixtures")
    }
}
#endif

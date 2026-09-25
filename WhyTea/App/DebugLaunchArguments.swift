#if DEBUG
import Foundation

/// Launch-argument hooks for driving the app without UI input, e.g.
/// `-WhyTeaOpenURL whytea://youtu.be/dQw4w9WgXcQ` or `-WhyTeaSearch "swiftui"`.
/// Values arrive through the `UserDefaults` argument domain.
enum DebugLaunchArguments {
    static var openURL: URL? {
        UserDefaults.standard.string(forKey: "WhyTeaOpenURL").flatMap(URL.init(string:))
    }

    static var searchQuery: String? {
        UserDefaults.standard.string(forKey: "WhyTeaSearch")
    }
}
#endif

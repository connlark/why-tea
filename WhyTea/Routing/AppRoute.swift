import WhyTeaYouTube

enum AppRoute: Hashable {
    case video(VideoID)

    /// The section an external entry point (a link, URL, or launch argument)
    /// opens this route in. Links can name anything on YouTube, so they open
    /// in Search and leave every other section's stack as the person left it.
    var owningSection: AppSection {
        switch self {
        case .video: .search
        }
    }
}

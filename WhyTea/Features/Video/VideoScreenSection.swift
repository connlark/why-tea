enum VideoScreenSection: String, CaseIterable, Identifiable {
    case related
    case comments

    var id: Self { self }

    var title: String {
        switch self {
        case .related: "Related"
        case .comments: "Comments"
        }
    }
}

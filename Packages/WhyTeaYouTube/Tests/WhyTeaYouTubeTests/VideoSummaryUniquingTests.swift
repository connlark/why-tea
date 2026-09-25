import Testing
@testable import WhyTeaYouTube

struct VideoSummaryUniquingTests {
    @Test func keepsFirstOccurrenceInOrder() {
        let a = VideoSummary(id: VideoID(rawValue: "aaaaaaaaaaa")!, title: "A")
        let b = VideoSummary(id: VideoID(rawValue: "bbbbbbbbbbb")!, title: "B")
        let aAgain = VideoSummary(id: a.id, title: "A from another shelf")

        #expect([a, b, aAgain, b].uniqued.map(\.title) == ["A", "B"])
    }
}

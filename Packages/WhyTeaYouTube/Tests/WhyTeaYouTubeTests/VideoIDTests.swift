import Testing
@testable import WhyTeaYouTube

struct VideoIDTests {
    @Test(arguments: [
        "dQw4w9WgXcQ",
        "  dQw4w9WgXcQ\n",
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://www.youtube.com/watch?feature=share&v=dQw4w9WgXcQ&t=42",
        "youtube.com/watch?v=dQw4w9WgXcQ",
        "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://music.youtube.com/watch?v=dQw4w9WgXcQ&list=RD",
        "https://youtu.be/dQw4w9WgXcQ?si=abc",
        "https://www.youtube.com/shorts/dQw4w9WgXcQ",
        "https://www.youtube.com/embed/dQw4w9WgXcQ",
        "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
        "https://www.youtube.com/live/dQw4w9WgXcQ?feature=shared"
    ])
    func parsesSupportedForms(input: String) {
        #expect(VideoID(parsing: input)?.rawValue == "dQw4w9WgXcQ")
    }

    @Test(arguments: [
        "",
        "dQw4w9WgXc",
        "dQw4w9WgXcQQ",
        "dQw4w9WgX!Q",
        "https://example.com/watch?v=dQw4w9WgXcQ",
        "https://www.youtube.com/@channel",
        "https://www.youtube.com/playlist?list=PL123"
    ])
    func rejectsOtherInput(input: String) {
        #expect(VideoID(parsing: input) == nil)
    }
}

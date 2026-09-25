import AVFoundation
import WhyTeaYouTube

@Observable
final class VideoModel {
    let id: VideoID
    private(set) var details: LoadState<VideoDetails> = .loading
    private(set) var playback: PlaybackPhase = .resolving
    private(set) var comments: [VideoComment] = []
    /// Next comments page; seeded from `VideoDetails.commentsToken`.
    private(set) var commentsToken: String?
    private(set) var commentsError: String?
    /// Bumped by `retry()` to restart the screen's load task.
    private(set) var loadAttempt = 0

    @ObservationIgnored private var isLoadingComments = false
    @ObservationIgnored private let client: YouTubeClient

    init(id: VideoID, client: YouTubeClient = YouTubeClient()) {
        self.id = id
        self.client = client
    }

    /// Idempotent: the screen's `.task` re-runs on every appearance (e.g. after
    /// popping back from a related video), so only unfinished work restarts.
    func load() async {
        async let details: Void = loadDetailsIfNeeded()
        async let playback: Void = preparePlaybackIfNeeded()
        _ = await (details, playback)
    }

    func retry() {
        loadAttempt += 1
    }

    func pause() {
        if case .ready(let player, _) = playback {
            player.pause()
        }
    }

    func loadMoreComments() async {
        guard let token = commentsToken, !isLoadingComments else { return }
        isLoadingComments = true
        defer { isLoadingComments = false }
        do {
            let page = try await client.comments(token: token)
            try Task.checkCancellation()
            comments = comments.appendingUnique(page.comments)
            commentsToken = page.continuationToken
        } catch is CancellationError {
        } catch {
            commentsError = error.localizedDescription
        }
    }

    func retryComments() {
        commentsError = nil
    }

    private func loadDetailsIfNeeded() async {
        if case .loaded = details { return }
        details = .loading
        do {
            let loaded = try await client.details(for: id)
            try Task.checkCancellation()
            details = .loaded(loaded)
            commentsToken = loaded.commentsToken
        } catch is CancellationError {
        } catch {
            details = .failed(error.localizedDescription)
        }
    }

    private func preparePlaybackIfNeeded() async {
        if case .ready = playback { return }
        playback = .resolving
        do {
            let source = try await client.playbackSource(for: id)
            try Task.checkCancellation()
            let player = AVPlayer(url: source.url)
            playback = .ready(player, source.kind)
            player.play()
        } catch is CancellationError {
        } catch {
            playback = .failed(error.localizedDescription)
        }
    }
}

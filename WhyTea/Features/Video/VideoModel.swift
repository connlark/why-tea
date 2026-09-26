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
    @ObservationIgnored private let client: any YouTubeService

    init(id: VideoID, client: any YouTubeService) {
        self.id = id
        self.client = client
    }

    /// Idempotent: the screen's `.task` re-runs on every appearance (e.g. after
    /// popping back from a related video), so only unfinished work restarts.
    /// Failed work stays failed until `retry()` reopens it.
    func load() async {
        async let details: Void = loadDetailsIfNeeded()
        async let playback: Void = preparePlaybackIfNeeded()
        _ = await (details, playback)
    }

    /// Reopens whatever failed, then restarts the screen's load task.
    func retry() {
        if case .failed = details {
            details = .loading
        }
        if case .failed = playback {
            playback = .resolving
        }
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
        } catch {
            guard !error.isCancellation else { return }
            commentsError = error.localizedDescription
        }
    }

    func retryComments() {
        commentsError = nil
    }

    private func loadDetailsIfNeeded() async {
        guard case .loading = details else { return }
        do {
            let loaded = try await client.details(for: id)
            try Task.checkCancellation()
            details = .loaded(loaded)
            commentsToken = loaded.commentsToken
        } catch {
            guard !error.isCancellation else { return }
            details = .failed(error.localizedDescription)
        }
    }

    private func preparePlaybackIfNeeded() async {
        guard case .resolving = playback else { return }
        do {
            let source = try await client.playbackSource(for: id)
            try Task.checkCancellation()
            let player = AVPlayer(url: source.url)
            playback = .ready(player, source.kind)
            player.play()
        } catch {
            guard !error.isCancellation else { return }
            playback = .failed(error.localizedDescription)
        }
    }
}

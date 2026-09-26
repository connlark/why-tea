import Foundation
import Testing
import YouTubeAPI
import YouTubeStreams
@testable import WhyTeaYouTube

/// The upstream capability baseline behind the playback design (HLS first, a
/// muxed fallback, captions from HLS subtitle renditions). It samples videos
/// of mixed age and length and records whether HLS resolves, whether the HLS
/// master carries subtitle renditions, the muxed fallback, the caption tracks
/// the watch page lists, and every 403 or token-gated response.
///
/// Contacts real YouTube. Run it once per extractor revision:
/// `WHYTEA_LIVE=1 swift test --filter LiveCapabilityBaseline`. The JSON Lines
/// log goes to `WHYTEA_BASELINE_LOG` or `/private/tmp`; stream and caption
/// URLs are reduced to their host before logging.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["WHYTEA_LIVE"] == "1"), .serialized)
struct LiveCapabilityBaselineTests {
    /// Fixed IDs spanning 2005 to 2022, 19 seconds to six hours, music,
    /// talks, open films, 4K, and a 24/7 live stream. A search adds recent
    /// uploads at run time.
    private static let sample: [(id: String, note: String)] = [
        ("jNQXAC9IVRw", "2005, 0:19, first upload"),
        ("iG9CE55wbtY", "2006, 20 min talk"),
        ("fJ9rUzIMcZQ", "2008, 6 min music"),
        ("UF8uR6Z6KLc", "2008, 15 min talk"),
        ("dQw4w9WgXcQ", "2009, 3:33 music"),
        ("hTWKbfoikeg", "2009, 5 min music"),
        ("eRsGyueVLvQ", "2010, 15 min open film"),
        ("9bZkp7q19f0", "2012, 4 min music"),
        ("R6MlUcmOul8", "2013, 12 min open film"),
        ("CevxZvSJLk8", "2013, 4 min music"),
        ("aqz-KE-bpKQ", "2014, 10 min 4K60 open film"),
        ("OPf0YbXqDm0", "2014, 4 min music"),
        ("YQHsXMglC9A", "2015, 6 min music"),
        ("RgKAFK5djSk", "2015, 4 min music"),
        ("60ItHLz5WEA", "2015, 3 min music"),
        ("LXb3EKWsInQ", "2016, 5 min 4K HDR"),
        ("arj7oStGLkU", "2016, 14 min talk"),
        ("kJQP7kiw5Fk", "2017, 5 min music"),
        ("JGwWNGJdvx8", "2017, 4 min music"),
        ("rfscVS0vtbw", "2018, 4.5 h course"),
        ("PkZNo7MFNFg", "2018, 3.5 h course"),
        ("_uQrJ0TkZlc", "2019, 6 h course"),
        ("WhWc3b3KhnY", "2019, 8 min open film"),
        ("jfKfPfyJRdk", "2022, 24/7 live stream")
    ]

    private static let recentQuery = "iPadOS 27"
    private static let recentCount = 4

    @Test(.timeLimit(.minutes(20)))
    func capabilityBaseline() async throws {
        var entries = Self.sample
        entries += try await recentUploads(excluding: Set(entries.map(\.id)))

        var probes: [VideoProbe] = []
        for entry in entries {
            probes.append(await probe(id: entry.id, note: entry.note))
            try await Task.sleep(for: .milliseconds(750))
        }

        let summary = BaselineSummary(probes: probes)
        let logURL = try writeLog(probes: probes, summary: summary)
        print("[baseline] log: \(logURL.path)")
        print("[baseline] \(summary.line)")

        #expect(probes.count >= 20)
        #expect(summary.playable > 0, "No sampled video resolved any playable source")
    }

    // MARK: - Sampling

    private func recentUploads(excluding existing: Set<String>) async throws -> [(id: String, note: String)] {
        let page = try await YouTubeClient().search(Self.recentQuery)
        return page.videos
            .filter { !existing.contains($0.id.rawValue) }
            .prefix(Self.recentCount)
            .map { video in
                let detail = [video.publishedText, video.durationText].compactMap(\.self).joined(separator: ", ")
                return (video.id.rawValue, "recent search result: \(detail)")
            }
    }

    /// `@concurrent` like the facade: the vendored `YouTube` is not `Sendable`
    /// and its async members run off the caller's actor.
    @concurrent
    private func probe(id: String, note: String) async -> VideoProbe {
        let video = YouTube(videoID: id, methods: [.local])
        var probe = VideoProbe(id: id, note: note)
        probe.hls = await probeHLS(video)
        probe.streams = await probeStreams(video)
        probe.captions = await probeCaptions(id)
        return probe
    }

    @concurrent
    private func probeHLS(_ video: YouTube) async -> HLSProbe {
        var probe = HLSProbe()
        let masterURL: URL
        do {
            guard let url = try await video.livestreams.first(where: { $0.streamType == .hls })?.url else {
                return probe
            }
            masterURL = url
        } catch {
            probe.error = describe(error)
            return probe
        }
        probe.present = true
        probe.host = masterURL.host()

        let master = await fetch(masterURL)
        probe.masterStatus = master.status
        probe.masterError = master.error
        guard let body = master.text, body.hasPrefix("#EXTM3U") else { return probe }

        let lines = body.split(whereSeparator: \.isNewline).map(String.init)
        let variants = lines.filter { $0.hasPrefix("#EXT-X-STREAM-INF") }
        let media = lines.filter { $0.hasPrefix("#EXT-X-MEDIA") }
        probe.variantCount = variants.count
        probe.subtitleRenditions = media.count(where: { $0.contains("TYPE=SUBTITLES") })
        probe.closedCaptionRenditions = media.count(where: { $0.contains("TYPE=CLOSED-CAPTIONS") })
        probe.audioRenditions = media.count(where: { $0.contains("TYPE=AUDIO") })
        probe.maxHeight = variants.compactMap(Self.height(inStreamInfo:)).max()
        probe.codecs = Set(variants.flatMap(Self.codecFamilies(inStreamInfo:))).sorted()

        if let subtitle = media.first(where: { $0.contains("TYPE=SUBTITLES") }),
           let uri = subtitle.firstMatch(of: /URI="([^"]+)"/).map({ String($0.1) }),
           let subtitleURL = URL(string: uri, relativeTo: masterURL)?.absoluteURL {
            let playlist = await fetch(subtitleURL)
            probe.subtitlePlaylistStatus = playlist.status
            if let playlistBody = playlist.text, let cueURL = firstURI(in: playlistBody, relativeTo: subtitleURL) {
                probe.subtitleSegmentIsWebVTT = await fetch(cueURL).text?.hasPrefix("WEBVTT")
            }
        }

        guard let variantURL = firstURI(in: body, relativeTo: masterURL) else { return probe }
        let variant = await fetch(variantURL)
        probe.variantStatus = variant.status
        guard let variantBody = variant.text, let segmentURL = firstURI(in: variantBody, relativeTo: variantURL) else {
            return probe
        }
        probe.segmentStatus = await fetch(segmentURL, range: true).status
        return probe
    }

    @concurrent
    private func probeStreams(_ video: YouTube) async -> StreamProbe {
        var probe = StreamProbe()
        let streams: [YouTubeStreams.Stream]
        do {
            streams = try await video.streams
        } catch {
            probe.error = describe(error)
            return probe
        }
        let muxed = streams.filterVideoAndAudio().filter(\.isNativelyPlayable)
        let videoOnly = streams.filterVideoOnly()
        probe.muxedCount = muxed.count
        probe.adaptiveVideoMaxResolution = videoOnly.compactMap(\.videoResolution).max()
        probe.adaptiveNativeVideoMaxResolution = videoOnly.filter(\.isNativelyPlayable).compactMap(\.videoResolution).max()
        guard let best = muxed.highestResolutionStream() else { return probe }
        probe.muxedResolution = best.videoResolution
        probe.muxedHost = best.url.host()
        probe.muxedStatus = await fetch(best.url, range: true).status
        return probe
    }

    /// Caption tracks come from the web watch page's player response, the only
    /// vendored surface that lists them today.
    private func probeCaptions(_ id: String) async -> CaptionProbe {
        var probe = CaptionProbe()
        let response: VideoInfosResponse
        do {
            response = try await VideoInfosResponse.sendThrowingRequest(youtubeModel: YouTubeModel(), data: [.query: id])
        } catch {
            probe.error = describe(error)
            return probe
        }
        let sources = response.captions.filter { !$0.isTranslated }
        probe.title = response.title
        probe.isLive = response.isLive
        probe.webHLS = response.streamingURL != nil
        probe.serverABR = response.serverAbrStreamingURL != nil
        probe.sourceTracks = sources.count
        probe.autoGeneratedTracks = sources.count(where: \.isAutoGenerated)
        probe.languages = Array(sources.map(\.languageCode).prefix(6))

        guard let track = sources.first(where: { !$0.isAutoGenerated }) ?? sources.first else { return probe }
        probe.fetchedTrackIsAutoGenerated = track.isAutoGenerated
        probe.tokenExperimentFlag = track.url.query()?.contains("exp=xpe") ?? false
        guard var components = URLComponents(url: track.url, resolvingAgainstBaseURL: false) else { return probe }
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "fmt" } + [URLQueryItem(name: "fmt", value: "vtt")]
        guard let vttURL = components.url else { return probe }
        let vtt = await fetch(vttURL)
        probe.vttStatus = vtt.status
        probe.vttBytes = vtt.body?.count
        probe.vttIsWebVTT = vtt.text?.hasPrefix("WEBVTT") ?? false
        probe.vttCues = vtt.text?.components(separatedBy: "-->").count.advanced(by: -1) ?? 0
        return probe
    }

    // MARK: - HTTP

    private func fetch(_ url: URL, range: Bool = false) async -> Fetched {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if range {
            request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return Fetched(status: (response as? HTTPURLResponse)?.statusCode, body: data)
        } catch {
            return Fetched(error: describe(error))
        }
    }

    private func firstURI(in playlist: String, relativeTo base: URL) -> URL? {
        playlist.split(whereSeparator: \.isNewline)
            .first { !$0.hasPrefix("#") && !$0.isEmpty }
            .flatMap { URL(string: String($0), relativeTo: base)?.absoluteURL }
    }

    /// Error text without URLs: a `URLError` description embeds the signed
    /// request URL.
    private func describe(_ error: any Error) -> String {
        if let error = error as? URLError {
            return "URLError(\(error.code.rawValue))"
        }
        if let error = error as? YouTubeKitError {
            return "YouTubeKitError.\(error.rawValue)"
        }
        return "\(type(of: error)): \(String(error.localizedDescription.prefix(160)))"
    }

    private static func height(inStreamInfo line: String) -> Int? {
        guard let match = line.firstMatch(of: /RESOLUTION=(\d+)x(\d+)/),
              let width = Int(match.1), let height = Int(match.2) else { return nil }
        return min(width, height)
    }

    private static func codecFamilies(inStreamInfo line: String) -> [String] {
        guard let match = line.firstMatch(of: /CODECS="([^"]+)"/) else { return [] }
        return match.1.split(separator: ",").compactMap { $0.split(separator: ".").first.map(String.init) }
    }

    // MARK: - Log

    private func writeLog(probes: [VideoProbe], summary: BaselineSummary) throws -> URL {
        let environment = ProcessInfo.processInfo.environment["WHYTEA_BASELINE_LOG"]
        let url = environment.map { URL(filePath: $0) }
            ?? URL(filePath: "/private/tmp/whytea-capability-baseline-\(summary.date).jsonl")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var lines = try probes.map { try String(decoding: encoder.encode($0), as: UTF8.self) }
        lines.append(try String(decoding: encoder.encode(summary), as: UTF8.self))
        try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Records

private struct Fetched {
    var status: Int?
    var body: Data?
    var error: String?

    var text: String? { body.map { String(decoding: $0, as: UTF8.self) } }
}

private struct VideoProbe: Codable {
    let id: String
    let note: String
    var hls = HLSProbe()
    var streams = StreamProbe()
    var captions = CaptionProbe()

    var statuses: [Int] {
        [hls.masterStatus, hls.subtitlePlaylistStatus, hls.variantStatus, hls.segmentStatus, streams.muxedStatus, captions.vttStatus]
            .compactMap(\.self)
    }

    var isPlayable: Bool {
        hls.masterStatus.map { (200..<300).contains($0) } == true
            || streams.muxedStatus.map { (200..<300).contains($0) } == true
    }
}

private struct HLSProbe: Codable {
    var present = false
    var host: String?
    var masterStatus: Int?
    var masterError: String?
    var variantCount = 0
    var maxHeight: Int?
    var codecs: [String] = []
    var subtitleRenditions = 0
    var closedCaptionRenditions = 0
    var audioRenditions = 0
    /// First subtitle rendition's playlist and segment. Added after the
    /// 2026-09-25 run, whose log does not contain these fields.
    var subtitlePlaylistStatus: Int?
    var subtitleSegmentIsWebVTT: Bool?
    var variantStatus: Int?
    var segmentStatus: Int?
    var error: String?
}

private struct StreamProbe: Codable {
    var muxedCount = 0
    var muxedResolution: Int?
    var muxedHost: String?
    var muxedStatus: Int?
    var adaptiveVideoMaxResolution: Int?
    var adaptiveNativeVideoMaxResolution: Int?
    var error: String?
}

private struct CaptionProbe: Codable {
    var title: String?
    var isLive: Bool?
    var webHLS = false
    var serverABR = false
    var sourceTracks = 0
    var autoGeneratedTracks = 0
    var languages: [String] = []
    var fetchedTrackIsAutoGenerated: Bool?
    var tokenExperimentFlag = false
    var vttStatus: Int?
    var vttBytes: Int?
    var vttIsWebVTT = false
    var vttCues = 0
    var error: String?
}

private struct BaselineSummary: Codable {
    let date: String
    let sampled: Int
    let playable: Int
    let hlsPresent: Int
    let hlsMasterOK: Int
    let hlsSegmentOK: Int
    let hlsWithSubtitleRenditions: Int
    let hlsWithClosedCaptionRenditions: Int
    let hlsSubtitleWebVTTFetched: Int
    let hlsMaxHeights: [String: Int]
    let muxedResolved: Int
    let muxedResolutions: [String: Int]
    let muxedOnly: Int
    let adaptiveNativeAboveHLS: Int
    let with403: [String]
    let otherNon2xx: [String]
    let extractionErrors: [String]
    let captionListed: Int
    let captionAutoOnly: Int
    let captionVTTFetched: Int
    let captionEmptyBody: Int
    let captionTokenFlag: Int

    init(probes: [VideoProbe]) {
        date = Date.now.formatted(.iso8601.year().month().day())
        sampled = probes.count
        playable = probes.count(where: \.isPlayable)
        hlsPresent = probes.count(where: \.hls.present)
        hlsMasterOK = probes.count { $0.hls.masterStatus.map { (200..<300).contains($0) } == true }
        hlsSegmentOK = probes.count { $0.hls.segmentStatus.map { (200..<300).contains($0) } == true }
        hlsWithSubtitleRenditions = probes.count { $0.hls.subtitleRenditions > 0 }
        hlsWithClosedCaptionRenditions = probes.count { $0.hls.closedCaptionRenditions > 0 }
        hlsSubtitleWebVTTFetched = probes.count { $0.hls.subtitleSegmentIsWebVTT == true }
        hlsMaxHeights = Self.histogram(probes.compactMap(\.hls.maxHeight))
        muxedResolved = probes.count { $0.streams.muxedResolution != nil }
        muxedResolutions = Self.histogram(probes.compactMap(\.streams.muxedResolution))
        muxedOnly = probes.count { !$0.hls.present && $0.streams.muxedResolution != nil }
        adaptiveNativeAboveHLS = probes.count { probe in
            guard let adaptive = probe.streams.adaptiveNativeVideoMaxResolution else { return false }
            return adaptive > (probe.hls.maxHeight ?? probe.streams.muxedResolution ?? 0)
        }
        with403 = probes.filter { $0.statuses.contains(403) }.map(\.id)
        otherNon2xx = probes.filter { probe in
            probe.statuses.contains { !(200..<300).contains($0) && $0 != 403 }
        }.map(\.id)
        extractionErrors = probes.compactMap { probe in
            let errors = [probe.hls.error, probe.streams.error, probe.captions.error].compactMap(\.self)
            return errors.isEmpty ? nil : "\(probe.id): \(errors.joined(separator: " | "))"
        }
        captionListed = probes.count { $0.captions.sourceTracks > 0 }
        captionAutoOnly = probes.count { $0.captions.sourceTracks > 0 && $0.captions.fetchedTrackIsAutoGenerated == true }
        captionVTTFetched = probes.count { $0.captions.vttIsWebVTT && $0.captions.vttCues > 0 }
        captionEmptyBody = probes.count { $0.captions.vttStatus == 200 && ($0.captions.vttBytes ?? 0) == 0 }
        captionTokenFlag = probes.count(where: \.captions.tokenExperimentFlag)
    }

    var line: String {
        "sampled \(sampled), playable \(playable), HLS \(hlsPresent) (master 2xx \(hlsMasterOK), segment 2xx \(hlsSegmentOK), "
            + "SUBTITLES \(hlsWithSubtitleRenditions) (WebVTT fetched \(hlsSubtitleWebVTTFetched)), CLOSED-CAPTIONS \(hlsWithClosedCaptionRenditions), heights \(hlsMaxHeights)), "
            + "muxed \(muxedResolved) \(muxedResolutions), muxed-only \(muxedOnly), adaptive above HLS \(adaptiveNativeAboveHLS), "
            + "403 \(with403), other non-2xx \(otherNon2xx), caption tracks \(captionListed) (auto-only \(captionAutoOnly), "
            + "VTT fetched \(captionVTTFetched), empty body \(captionEmptyBody), exp=xpe \(captionTokenFlag)), "
            + "errors \(extractionErrors.count)"
    }

    private static func histogram(_ values: [Int]) -> [String: Int] {
        Dictionary(grouping: values, by: { "\($0)p" }).mapValues(\.count)
    }
}

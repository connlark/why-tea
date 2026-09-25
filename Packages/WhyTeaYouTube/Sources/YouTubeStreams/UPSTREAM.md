# YouTubeStreams Upstream

- Upstream project: [alexeichhorn/YouTubeKit](https://github.com/alexeichhorn/YouTubeKit) (MIT)
- Upstream revision: `e5b7d0396ce12bf3444f0d209e8436c83373b7af` (2026-08-18, PR #140 `fix/youtube-august-26`)
- Upstream source: `Sources/YouTubeKit/` copied verbatim; `LICENSE` copied from the repository root.
- Role: on-device stream URL extraction (InnerTube player request, signature and n-parameter solving in JavaScriptCore, HLS manifest lookup) and minimal metadata.
- Not vendored: upstream `Tests/` (mostly live-network) and `Scripts/update_resources.sh`.

## Local modifications

- Module renamed from `YouTubeKit` to `YouTubeStreams` so it can coexist with `YouTubeAPI` (b5i's package is also named `YouTubeKit`). No source changes were needed.
- Built in Swift 5 language mode (`Package.swift`), matching upstream's `swift-tools-version:5.9`.

## Remote fallback

Upstream can fall back to a hosted `youtube-dl` relay (`ExtractionMethod.remote`, `remote-production.youtubekit.dev`). WhyTea never enables it: `WhyTeaYouTube` always passes `methods: [.local]`. The `Remote/` sources stay only so the vendored copy is unmodified.

## Re-sync

`scripts/update-vendored-youtube.sh streams <revision>` replaces this directory's Swift and resource files and keeps `UPSTREAM.md`. Update the revision above in the same change.

# YouTubeAPI Upstream

- Upstream project: [b5i/YouTubeKit](https://github.com/b5i/YouTubeKit) (MIT)
- Upstream revision: `6532af39da4c1612b0a1af603792419d8fb0e67f` (2026-08-02)
- Upstream source: `Sources/YouTubeKit/` copied; `LICENSE` copied from the repository root.
- Role: key-less InnerTube client for browsing (search, autocomplete, home, trending, channels, playlists, video details, comments) and cookie-authenticated account actions (like/dislike, comment, subscribe, history, playlists).
- Not vendored: upstream `Tests/`, `Examples/`.

## Local modifications

- Module renamed from `YouTubeKit` to `YouTubeAPI` so it can coexist with `YouTubeStreams` (alexeichhorn's package is also named `YouTubeKit`).
- `YouTubeResponseTypes/VideoInfos/VideoInfosWithDownloadFormatsResponse.swift`: four `YouTubeKit.` module qualifiers rewritten to `YouTubeAPI.`. Re-apply after every re-sync (the update script does this).
- Resources declared as `.copy("JavaScript")` instead of upstream's equivalent `.copy("JavaScript/.")`.
- Built in Swift 5 language mode (`Package.swift`), matching upstream's `swift-tools-version: 5.7`.

## Re-sync

`scripts/update-vendored-youtube.sh api <revision>` replaces this directory's Swift and resource files, re-applies the module qualifier rewrite, and keeps `UPSTREAM.md`. Update the revision above in the same change.

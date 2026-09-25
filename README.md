# why tea

**why tea** is an iPhone and iPad YouTube client that talks to YouTube directly from the device. There is no relay server, no API key, and no account. It is a research spike that asks one question: can a Yattee-style app run with no server of its own?

[![Apple CI](https://img.shields.io/github/actions/workflow/status/connlark/why-tea/apple-ci.yml?branch=main&label=Apple%20CI&logo=apple)](https://github.com/connlark/why-tea/actions/workflows/apple-ci.yml)

> [!IMPORTANT]
> why tea uses YouTube's private InnerTube API. YouTube's terms of service do not allow third-party apps to use it, and YouTube changes it without notice. This project is not affiliated with or endorsed by YouTube or Google. It is published for research and education.

## What works

- Search with autocomplete suggestions and infinite scroll.
- A watch screen with an AVKit player, title, channel, views, likes, an expandable description, related videos, and paged comments.
- Open any YouTube link or video ID from a sheet (with a paste button) or through `whytea://<link-or-id>`.

Everything runs on device. Playback prefers the adaptive HLS manifest from the iOS InnerTube client and falls back to the best natively playable muxed stream.

Not built yet: sign-in and the account features that depend on it, background audio and Picture in Picture, and composing 1080p+ DASH video with separate audio when no HLS manifest is available. The logged-out home feed is empty, because YouTube shows nothing to a visitor with no history.

## The two YouTubeKits

Two unrelated Swift packages are both named `YouTubeKit`. Each covers half of what the app needs, so both are vendored under renamed modules:

| Module | Upstream | Provides |
| --- | --- | --- |
| `YouTubeStreams` | [alexeichhorn/YouTubeKit](https://github.com/alexeichhorn/YouTubeKit) | Playable stream URLs: signature and n-parameter solving in JavaScriptCore, HLS manifests, muxed and adaptive streams |
| `YouTubeAPI` | [b5i/YouTubeKit](https://github.com/b5i/YouTubeKit) | Search, autocomplete, home, channels, playlists, video details, and comments |

`WhyTeaYouTube` wraps both behind one `YouTubeClient` with `Sendable` value types, and it is the only module the app imports. Both upstreams are MIT-licensed. Each vendored target keeps its `LICENSE` and an `UPSTREAM.md` recording the pinned revision and local changes.

Both libraries scrape private endpoints, and YouTube breaks extraction every few weeks. `scripts/update-vendored-youtube.sh` re-syncs a vendored library at a pinned revision.

## Build from source

You will need macOS, Xcode 27 or later, Swift 6.4, and an iOS 27 simulator.

```zsh
git clone https://github.com/connlark/why-tea.git
cd why-tea

# Package tests (offline)
swift test --package-path Packages/WhyTeaYouTube

# Live check against real YouTube: search, details, comments, and stream extraction
WHYTEA_LIVE=1 swift test --package-path Packages/WhyTeaYouTube --filter LiveBakeOff

open WhyTea.xcodeproj
```

Select the `WhyTea` scheme, choose an iPhone or iPad simulator running iOS 27, and press Run.

<details>
<summary><strong>Running on a physical device</strong></summary>

Set your own Apple development team on the `WhyTea` target, and change the bundle identifier (`com.connor.whytea`) to one your team owns.

</details>

## Project map

| Area | What lives there |
| --- | --- |
| [`WhyTea/`](WhyTea/) | SwiftUI app: `App/`, `Routing/`, `Shared/`, and `Features/` (Search, Video, OpenLink) |
| [`Packages/WhyTeaYouTube/`](Packages/WhyTeaYouTube/) | The `WhyTeaYouTube` facade, the two vendored libraries, and tests |
| [`scripts/`](scripts/) | Vendoring helper |

The app uses SwiftUI, Observation, AVKit, and Swift Testing, with Swift 6 strict concurrency. It has no dependencies beyond the two vendored libraries.

## Contributing

Issues and pull requests are welcome. When extraction breaks, check upstream first: a re-sync usually fixes it.

## License

why tea is available under the [MIT License](LICENSE). _Vendored components retain their own attribution and license files._

// swift-tools-version: 6.4

import PackageDescription

let swift63Settings: [SwiftSetting] = [
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

// Vendored sources build exactly as upstream ships them (Swift 5 mode) so a
// re-sync never needs concurrency fixups. See each target's UPSTREAM.md.
let vendoredSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v5)
]

let package = Package(
    name: "WhyTeaYouTube",
    platforms: [
        .iOS(.v27),
        .macOS(.v15)
    ],
    products: [
        .library(name: "WhyTeaYouTube", targets: ["WhyTeaYouTube"])
    ],
    targets: [
        .target(
            name: "YouTubeStreams",
            exclude: [
                "LICENSE",
                "UPSTREAM.md"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: vendoredSettings
        ),
        .target(
            name: "YouTubeAPI",
            exclude: [
                "LICENSE",
                "UPSTREAM.md"
            ],
            resources: [
                .copy("JavaScript")
            ],
            swiftSettings: vendoredSettings
        ),
        .target(
            name: "WhyTeaYouTube",
            dependencies: [
                "YouTubeStreams",
                "YouTubeAPI"
            ],
            swiftSettings: swift63Settings
        ),
        .testTarget(
            name: "WhyTeaYouTubeTests",
            dependencies: ["WhyTeaYouTube"],
            swiftSettings: swift63Settings
        )
    ],
    swiftLanguageModes: [.v6]
)

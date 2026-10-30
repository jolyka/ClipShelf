// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClipShelf",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClipShelf",
            path: "Sources/ClipShelf",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "Downtime",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Downtime",
            path: "Sources/Downtime"
        )
    ],
    // Pinned so a newer toolchain defaulting to Swift 6 strict concurrency
    // doesn't turn AppKit's main-actor warnings into build errors.
    swiftLanguageVersions: [.v5]
)

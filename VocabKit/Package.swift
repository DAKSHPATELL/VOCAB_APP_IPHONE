// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VocabKit",
    defaultLocalization: "en",
    // macOS is listed so the shared logic can be unit-tested natively on a CI
    // runner without booting a simulator. Everything UIKit-only is behind
    // `#if canImport(UIKit)`; the app and widget themselves are iOS-only.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VocabKit", targets: ["VocabKit"])
    ],
    targets: [
        .target(
            name: "VocabKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "VocabKitTests",
            dependencies: ["VocabKit"]
        )
    ]
)

// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VocabKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
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

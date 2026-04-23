// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlankVoice",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PlankVoice", targets: ["PlankVoice"]),
    ],
    dependencies: [
        .package(path: "../PlankEngine"),
    ],
    targets: [
        .target(
            name: "PlankVoice",
            dependencies: ["PlankEngine"]
        ),
        .testTarget(
            name: "PlankVoiceTests",
            dependencies: ["PlankVoice"]
        ),
    ]
)

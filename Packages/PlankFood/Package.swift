// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlankFood",
    // macOS pinned to 14 for SwiftData @Model availability (introduced
    // macOS 14 / iOS 17). Higher than posthog-ios's 10.15 minimum.
    // PlankFood ships iOS-only; the macOS pin is purely to keep
    // SwiftPM resolution + macOS test runs happy.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlankFood", targets: ["PlankFood"]),
    ],
    dependencies: [
        // posthog-ios — feature flag layer in FoodFlags + future food rail
        // events per W5-T3 spec. Match the main project's pin
        // (plankAI.xcodeproj: upToNextMajor from 3.58.3).
        .package(url: "https://github.com/PostHog/posthog-ios", from: "3.58.3"),
    ],
    targets: [
        .target(
            name: "PlankFood",
            dependencies: [
                .product(name: "PostHog", package: "posthog-ios"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PlankFoodTests",
            dependencies: ["PlankFood"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlankFood",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PlankFood", targets: ["PlankFood"]),
    ],
    targets: [
        .target(
            name: "PlankFood",
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

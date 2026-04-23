// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlankEngine",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PlankEngine", targets: ["PlankEngine"]),
    ],
    targets: [
        .target(
            name: "PlankEngine",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PlankEngineTests",
            dependencies: ["PlankEngine"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)

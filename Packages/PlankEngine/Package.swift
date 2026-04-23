// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlankEngine",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "PlankEngine", targets: ["PlankEngine"]),
    ],
    targets: [
        .target(name: "PlankEngine"),
        .testTarget(
            name: "PlankEngineTests",
            dependencies: ["PlankEngine"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)

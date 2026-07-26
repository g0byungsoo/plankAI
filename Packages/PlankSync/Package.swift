// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlankSync",
    // macOS platform exists solely so `swift test` runs standalone on a
    // dev machine (SwiftData needs macOS 14+); the app only ships iOS.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PlankSync", targets: ["PlankSync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "PlankSync",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "PlankSyncTests",
            dependencies: ["PlankSync"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)

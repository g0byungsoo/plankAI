// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlankSync",
    platforms: [.iOS(.v17)],
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
            ]
        ),
        .testTarget(
            name: "PlankSyncTests",
            dependencies: ["PlankSync"]
        ),
    ]
)

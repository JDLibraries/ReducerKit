// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReducerKit",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .visionOS(.v1), .watchOS(.v10)],
    products: [
        .library(
            name: "ReducerKit",
            targets: ["ReducerKit"]
        ),
    ],
    targets: [
        .target(
            name: "ReducerKit"
        ),
        .testTarget(
            name: "ReducerKitTests",
            dependencies: ["ReducerKit"]
        ),
    ]
)

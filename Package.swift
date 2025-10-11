// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ReducerKit",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .visionOS(.v1), .watchOS(.v10)],
    products: [
        .library(
            name: "ReducerKit",
            targets: ["ReducerKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "510.0.0"),
    ],
    targets: [
        // 매크로 구현 타겟
        .macro(
            name: "ReducerKitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // 메인 라이브러리 타겟
        .target(
            name: "ReducerKit",
            dependencies: ["ReducerKitMacros"]
        ),

        // 테스트 타겟
        .testTarget(
            name: "ReducerKitTests",
            dependencies: ["ReducerKit"]
        ),
        .testTarget(
            name: "ReducerKitMacrosTests",
            dependencies: [
                "ReducerKitMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)

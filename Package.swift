// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Snake",
    products: [
        .library(
            name: "Snake",
            targets: ["Snake"]
        ),
        .executable(
            name: "Example",
            targets: ["Example"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.19.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.8.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.12.3"),
    ],
    targets: [
        .target(
            name: "Snake",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
            ]
        ),
        .testTarget(
            name: "SnakeTests",
            dependencies: ["Snake"]
        ),

        // Examples
        .target(
            name: "Example",
            dependencies: ["Snake"]
        ),
    ]
)

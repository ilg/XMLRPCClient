// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "XMLRPCClient",
    products: [
        .library(name: "XMLRPCClient", targets: ["XMLRPCClient"]),
        .library(name: "ResultAssertions", targets: ["ResultAssertions"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ilg/XMLRPCCoder.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/nicklockwood/SwiftFormat",
            from: "0.53.5"
        ),
    ],
    targets: [
        .target(
            name: "XMLRPCClient",
            dependencies: [
                .byName(name: "XMLRPCCoder"),
            ]
        ),
        .testTarget(
            name: "XMLRPCClientTests",
            dependencies: [
                .target(name: "XMLRPCClient"),
                .product(name: "XMLAssertions", package: "XMLRPCCoder"),
                .target(name: "ResultAssertions"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "ResultAssertions",
            dependencies: [.target(name: "XMLRPCClient")]
        ),
    ]
)

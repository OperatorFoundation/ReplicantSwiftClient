// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(iOS) || os(macOS) || os(watchOS) || os(tvOS)
let package = Package(
    name: "ReplicantSwiftClient",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "Replicant", targets: ["Replicant"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.8.6"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.5"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "0.1.3"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.4"),
    ],
    targets: [
        .target(name: "Replicant", dependencies: [
            "Transport",
            "ReplicantSwift",
            "SwiftQueue",
            "Datable",
            "Flower",
            .product(name: "Logging", package: "swift-log"),
        ]),

        .testTarget(name: "ReplicantTests", dependencies: ["Replicant", "ReplicantSwift", .product(name: "Logging", package: "swift-log"), "Datable"]),
    ],
    swiftLanguageVersions: [.v5]
)
#elseif os(Linux)
let package = Package(
    name: "ReplicantSwiftClient",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "Replicant", targets: ["Replicant"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.8.6"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.5"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "0.1.3"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.4"),
        .package(url: "https://github.com/OperatorFoundation/NetworkLinux.git", from: "0.2.0"),
    ],
    targets: [
        .target(name: "Replicant", dependencies: [
            "Transport",
            "ReplicantSwift",
            "SwiftQueue",
            "Datable",
            "Flower",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux"),
        ]),

        .testTarget(name: "ReplicantTests", dependencies: ["Replicant", "ReplicantSwift", .product(name: "Logging", package: "swift-log"), "Datable"]),
    ],
    swiftLanguageVersions: [.v5]
)
#endif

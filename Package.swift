// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReplicantSwiftClient",
    platforms: [.macOS(.v10_15)],
    products: [.library(name: "ReplicantSwiftClient", targets: ["ReplicantSwiftClient"])],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.1.1"),
        .package(url: "https://github.com/OperatorFoundation/Monolith.git", from: "1.0.3"),
        .package(url: "https://github.com/OperatorFoundation/Keychain.git", from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.13.0"),
        .package(url: "https://github.com/OperatorFoundation/Song.git", from: "0.2.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.1.1"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", from: "1.0.1"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTransport.git", from: "0.3.0"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.8"),
        .package(url: "git@github.com:apple/swift-crypto.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "ReplicantSwiftClient",
            dependencies: [
                "Datable",
                "Monolith",
                "ReplicantSwift",
                "Song",
                "SwiftQueue",
                "Transmission",
                "Transport",
                "TransmissionTransport",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Keychain", package: "Keychain"),
            ]
        ),
        .testTarget(
            name: "ReplicantSwiftClientTests",
            dependencies: ["ReplicantSwiftClient"]),
    ],
    swiftLanguageVersions: [.v5]
)

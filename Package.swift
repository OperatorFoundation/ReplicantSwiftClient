// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(iOS) || os(macOS) || os(watchOS) || os(tvOS)
let package = Package(
    name: "ReplicantSwiftClient",
    platforms: [.macOS(.v11)],
    products: [.library(name: "ReplicantSwiftClient", targets: ["ReplicantSwiftClient"])],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Monolith.git", from: "1.0.2"),
        .package(url: "https://github.com/OperatorFoundation/Keychain.git", from: "0.1.2"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.10.3"),
        .package(url: "https://github.com/OperatorFoundation/Song.git", from: "0.1.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", from: "0.3.0"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.7"),
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
#elseif os(Linux)
let package = Package(
    name: "ReplicantSwiftClient",
    products: [.library(name: "ReplicantSwiftClient", targets: ["ReplicantSwiftClient"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git",
                 from: "1.1.2"),
        .package(url: "https://github.com/OperatorFoundation/KeychainLinux.git",
                 from: "0.1.1"),
        .package(url: "https://github.com/OperatorFoundation/Song.git",
                 from: "0.1.1"),
        .package(url: "https://github.com/apple/swift-log.git",
                 from: "1.4.0"),
        .package(url: "https://github.com/OperatorFoundation/Monolith.git",
                 from: "1.0.2"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git",
                 from: "3.1.0"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionLinux.git", from: "0.3.5"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git",
                 from: "2.3.7"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git",
                 from: "0.1.0")],
    targets: [
        .target(
            name: "ReplicantSwiftClient",
            dependencies: [
                "Datable",
                "Monolith",
                "Song",
                "SwiftQueue",
                "TransmissionLinux",
                "Transport",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "KeychainLinux", package: "KeychainLinux"),
                .product(name: "Crypto", package: "swift-crypto")
            ]),
        .testTarget(
            name: "ReplicantSwiftClientTests",
            dependencies: ["ReplicantSwiftClient"]),
    ],
    swiftLanguageVersions: [.v5])
#endif

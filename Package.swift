// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ReplicantSwiftClient",
    platforms: [.macOS(.v12),
                        .iOS(.v15)
                       ],
    products: [.library(name: "ReplicantSwiftClient", targets: ["ReplicantSwiftClient"])],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Datable.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Monolith.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Keychain.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Song.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionTransport.git", branch: "main"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
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
                "Keychain",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "ReplicantSwiftClientTests",
            dependencies: ["ReplicantSwiftClient"]),
    ],
    swiftLanguageVersions: [.v5]
)

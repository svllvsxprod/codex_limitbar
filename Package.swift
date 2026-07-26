// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "CodexLimitBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexLimitBar", targets: ["CodexLimitBar"])
    ],
    targets: [
        .executableTarget(
            name: "CodexLimitBar",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CodexLimitBarTests",
            dependencies: ["CodexLimitBar"]
        )
    ]
)

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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "CodexLimitBar",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            resources: [.process("Resources")],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "CodexLimitBarTests",
            dependencies: ["CodexLimitBar"]
        )
    ]
)

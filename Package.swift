// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "camview",
    platforms: [
        // Floor is set by the Protect dependency, which requires macOS 15.
        .macOS(.v15)
    ],
    products: [
        .executable(name: "camview", targets: ["camview"]),
        .executable(name: "StreamdeckLauncher", targets: ["StreamdeckLauncher"]),
        // Consumed by the camgui Xcode project as a local package dependency.
        .library(name: "CamviewCore", targets: ["CamviewCore"]),
    ],
    dependencies: [
        // Pinned to tags rather than `branch: "main"`. Both of these repos have moved
        // ahead of what camview was building via Package.resolved, so a branch pin would
        // silently change behaviour on the next resolve.
        .package(url: "https://github.com/PeteRichardson/Protect", .upToNextMinor(from: "1.0.0")),
        .package(url: "https://github.com/PeteRichardson/SimpleConfig", .upToNextMinor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.5.1")),
    ],
    targets: [
        // Shared by the camview CLI and the camgui app. Deliberately free of any
        // ArgumentParser dependency so a GUI with no command line doesn't link it.
        .target(
            name: "CamviewCore",
            dependencies: [
                .product(name: "SimpleConfig", package: "SimpleConfig")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "camview",
            dependencies: [
                "CamviewCore",
                .product(name: "Protect", package: "Protect"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // One binary, copied to 15 names by Scripts/build-launchers.sh. It derives its
        // liveview from its own executable name, so there is no per-app source variant.
        .executableTarget(
            name: "StreamdeckLauncher",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "CamviewCoreTests",
            dependencies: ["CamviewCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Depends on the executable target so `@testable import camview` can reach the
        // CLI's own types. SwiftPM links an executable target into a test bundle fine on
        // macOS; `@main` is not an obstacle.
        .testTarget(
            name: "CamviewCLITests",
            dependencies: ["camview"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)

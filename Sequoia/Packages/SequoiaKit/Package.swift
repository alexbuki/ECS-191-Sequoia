// swift-tools-version: 6.0
import PackageDescription

/// `SEQUOIA_DEV` gates every line of developer-mode code. It is only defined for
/// Debug builds, so Release builds contain no dev-mode code or UI.
let devSettings: [SwiftSetting] = [
    .define("SEQUOIA_DEV", .when(configuration: .debug)),
]

let package = Package(
    name: "SequoiaKit",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "SequoiaCore", targets: ["SequoiaCore"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        .target(
            name: "SequoiaCore",
            resources: [.process("Resources")],
            swiftSettings: devSettings
        ),
        .target(
            name: "DesignSystem",
            dependencies: ["SequoiaCore"],
            resources: [.process("Resources")],
            swiftSettings: devSettings
        ),
        .testTarget(name: "SequoiaCoreTests", dependencies: ["SequoiaCore"], swiftSettings: devSettings),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"], swiftSettings: devSettings),
    ]
)

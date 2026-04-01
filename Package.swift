// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftSynapseHarness",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "SwiftSynapseHarness",
            targets: ["SwiftSynapseHarness"]
        ),
        .library(
            name: "SwiftSynapseUI",
            targets: ["SwiftSynapseUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
        .package(url: "https://github.com/RichNasz/SwiftOpenSkills", branch: "main"),
    ],
    targets: [
        .target(
            name: "SwiftSynapseHarness",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
                .product(name: "SwiftOpenSkills", package: "SwiftOpenSkills"),
                .product(name: "SwiftOpenSkillsResponses", package: "SwiftOpenSkills"),
            ]
        ),
        .target(
            name: "SwiftSynapseUI",
            dependencies: ["SwiftSynapseHarness"],
            path: "Sources/SwiftSynapseUI"
        ),
        .testTarget(
            name: "SwiftSynapseHarnessTests",
            dependencies: ["SwiftSynapseHarness"],
            path: "Tests/SwiftSynapseHarnessTests"
        ),
    ]
)

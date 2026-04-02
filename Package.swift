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
    traits: [
        // Leaf traits — each enables a specific subsystem
        .trait(name: "Core",
               description: "Tool system, LLM client, config, runtime, and core infrastructure"),
        .trait(name: "Hooks",
               description: "AgentHookPipeline with 16 event types and closure hooks"),
        .trait(name: "Safety",
               description: "Permissions, guardrails, denial tracking, and tool list policies"),
        .trait(name: "Resilience",
               description: "Recovery strategies, error classification, rate limiting, and context compression"),
        .trait(name: "Observability",
               description: "Telemetry sinks, cost tracking, and token usage monitoring"),
        .trait(name: "MultiAgent",
               description: "Multi-agent coordination runner and subagent spawning"),
        .trait(name: "Persistence",
               description: "Session persistence, session lifecycle, and agent memory"),
        .trait(name: "MCP",
               description: "Model Context Protocol manager and external tool servers"),
        .trait(name: "Plugins",
               description: "AgentPlugin system with activation lifecycle"),

        // Composite traits — opinionated bundles
        .trait(name: "Production",
               description: "Core + Hooks + Safety + Resilience + Observability — recommended for most agents",
               enabledTraits: ["Core", "Hooks", "Safety", "Resilience", "Observability"]),
        .trait(name: "Advanced",
               description: "Production + MultiAgent + Persistence + MCP + Plugins — full feature set",
               enabledTraits: ["Production", "MultiAgent", "Persistence", "MCP", "Plugins"]),
        .trait(name: "Full",
               description: "All traits enabled — equivalent to Advanced",
               enabledTraits: ["Advanced"]),

        // Default trait set — what users get without specifying traits
        .default(enabledTraits: ["Production"]),
    ],
    dependencies: [
        .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
        .package(url: "https://github.com/RichNasz/SwiftOpenSkills", branch: "main"),
        .package(url: "https://github.com/RichNasz/SwiftLLMToolMacros", branch: "main"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "SwiftSynapseHarness",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
                .product(name: "SwiftOpenSkills", package: "SwiftOpenSkills"),
                .product(name: "SwiftOpenSkillsResponses", package: "SwiftOpenSkills"),
                .product(name: "SwiftLLMToolMacros", package: "SwiftLLMToolMacros"),
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

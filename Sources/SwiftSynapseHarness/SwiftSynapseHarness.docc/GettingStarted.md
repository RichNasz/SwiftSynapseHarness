# Getting Started with SwiftSynapseHarness

From zero to a working agent with tools, in five steps.

## Overview

SwiftSynapseHarness is the production-grade agent harness for the SwiftSynapse ecosystem. This guide walks you through adding the package, defining your first agent, registering a tool, and running it.

## Step 1: Add the Package

Add `SwiftSynapseHarness` to your `Package.swift`:

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/RichNasz/SwiftSynapseHarness",
        branch: "main"
    )
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness")
        ]
    )
]
```

One import gives you the full harness, macros, and core types:

```swift
import SwiftSynapseHarness
```

## Step 2: Define Your First Tool

Tools conform to ``AgentToolProtocol`` with typed `Input` and `Output`:

```swift
struct GetWeatherTool: AgentToolProtocol {
    struct Input: Codable, Sendable {
        let city: String
    }
    struct Output: Codable, Sendable {
        let temperature: Double
        let condition: String
    }

    static let name = "get_weather"
    static let description = "Gets current weather for a city."
    static let inputSchema: FunctionToolParam = .init(
        name: name,
        description: description,
        parameters: .init(
            properties: ["city": .init(type: "string", description: "The city name")],
            required: ["city"]
        )
    )

    func execute(input: Input) async throws -> Output {
        // Your actual implementation here
        return Output(temperature: 22.5, condition: "Sunny")
    }
}
```

## Step 3: Configure the Agent

Create an ``AgentConfiguration`` and register your tool in a ``ToolRegistry``:

```swift
// Read config from SWIFTSYNAPSE_* environment variables
let config = try AgentConfiguration.fromEnvironment()

// Or configure explicitly:
// let config = AgentConfiguration(executionMode: .cloud, model: "claude-opus-4-6")

let tools = ToolRegistry()
tools.register(GetWeatherTool())
```

`AgentConfiguration.fromEnvironment()` reads `SWIFTSYNAPSE_API_KEY`, `SWIFTSYNAPSE_MODEL`, and other `SWIFTSYNAPSE_*` environment variables.

## Step 4: Write and Run Your Agent

Define an agent using the `@SpecDrivenAgent` macro and call ``AgentToolLoop`` inside `execute(goal:)`:

```swift
@SpecDrivenAgent
actor WeatherAgent {
    let config: AgentConfiguration
    let tools: ToolRegistry

    init(config: AgentConfiguration, tools: ToolRegistry) {
        self.config = config
        self.tools = tools
    }

    func execute(goal: String) async throws -> String {
        let client = config.buildClient()
        return try await AgentToolLoop.run(
            client: client,
            config: config,
            goal: goal,
            tools: tools,
            transcript: _transcript,
            systemPrompt: "You are a helpful weather assistant."
        )
    }
}
```

Run the agent — `run(goal:)` is macro-generated and handles the full lifecycle:

```swift
let agent = WeatherAgent(config: config, tools: tools)
let result = try await agent.run(goal: "What's the weather like in Tokyo?")
print(result)
```

## Step 5: Add a SwiftUI Interface (Optional)

Import `SwiftSynapseUI` and drop in ``AgentChatView`` for a complete chat interface:

```swift
import SwiftSynapseUI

struct ContentView: View {
    @State var agent = WeatherAgent(config: config, tools: tools)

    var body: some View {
        AgentChatView(agent: agent)
    }
}
```

`AgentChatView` observes `agent.status` and `agent.transcript` automatically — no additional wiring required.

## What Happens Under the Hood

`run(goal:)` (macro-generated) manages the agent lifecycle:

1. Validates the goal is non-empty
2. Sets `status` to `.running` and resets the transcript
3. Fires the `.agentStarted` hook
4. Calls your `execute(goal:)` with cancellation support
5. On success: sets `status` to `.completed(result)`, fires `.agentCompleted`
6. On error: sets `status` to `.error(error)`, fires `.agentFailed`
7. On cancellation: sets `status` to `.paused`, fires `.agentCancelled`
8. Auto-saves the session if a `SessionStore` is provided

## Next Steps

- <doc:AgentHarnessGuide> — typed tools, hooks, permissions, streaming, subagents
- <doc:ProductionGuide> — session persistence, guardrails, MCP, cost tracking
- <doc:HowToAddTools> — step-by-step tool building with progress reporting

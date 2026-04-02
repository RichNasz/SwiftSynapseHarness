# Doc-GettingStarted

## Purpose

Specifies the Getting Started article for SwiftSynapseHarness. This is the first article a new developer reads — it takes them from package installation to a working agent with one tool in five steps.

## Generates

- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/GettingStarted.md`

---

## Article Structure

### Title & Intro

Title: `Getting Started with SwiftSynapseHarness`

Tagline: From zero to a working agent with tools, in five steps.

Overview: SwiftSynapseHarness is the production-grade agent harness for the SwiftSynapse ecosystem. This guide walks you through adding the package, defining your first agent, registering a tool, and running the agent.

---

### Step 1: Add the Package

Show a `Package.swift` snippet adding SwiftSynapseHarness:

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

---

### Step 2: Define Your First Tool

Explain `AgentToolProtocol`: typed Input/Output, a name, description, and `execute(input:)`.

Show a minimal weather tool:

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

---

### Step 3: Create and Configure Your Agent

Show creating an `AgentConfiguration` and registering the tool in a `ToolRegistry`:

```swift
// Configure the agent
let config = try AgentConfiguration.fromEnvironment()
// Or configure explicitly:
// let config = AgentConfiguration(executionMode: .cloud, model: "claude-opus-4-6")

// Register tools
let tools = ToolRegistry()
tools.register(GetWeatherTool())
```

Explain `AgentConfiguration.fromEnvironment()` reads `SWIFTSYNAPSE_*` environment variables for the API key and model.

---

### Step 4: Define and Run Your Agent

Show using `@SpecDrivenAgent` macro and calling `AgentToolLoop.run()`:

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

Run the agent:

```swift
let agent = WeatherAgent(config: config, tools: tools)
let result = try await agent.run(goal: "What's the weather like in Tokyo?")
print(result)
```

---

### Step 5: Observe the Result

Explain that `run(goal:)` is macro-generated and manages the full lifecycle:
- Sets `status` from `.idle` → `.running` → `.completed` or `.error`
- Records all LLM turns and tool calls in `transcript`
- Returns the final text result

Show observing from SwiftUI using `AgentChatView` from SwiftSynapseUI:

```swift
import SwiftSynapseUI

struct ContentView: View {
    let agent = WeatherAgent(config: config, tools: tools)

    var body: some View {
        AgentChatView(agent: agent)
    }
}
```

---

### Next Steps

Point to:
- `<doc:AgentHarnessGuide>` — complete tool system, hooks, permissions, streaming
- `<doc:ProductionGuide>` — session persistence, guardrails, MCP, cost tracking
- `<doc:HowToAddTools>` — step-by-step tool building guide

---

## Implementation Notes for Generator

- Wrap all code examples in ` ```swift ``` ` blocks
- Use `<doc:ArticleName>` link syntax for cross-references to other articles
- Use `` ``TypeName`` `` syntax for links to types
- Keep prose short and scannable — developers read this while setting up their project

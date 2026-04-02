<!-- Generated from CodeGenSpecs/README-Generation.md — Do not edit manually. Update spec and re-generate. -->

# SwiftSynapseHarness

Production-grade agent harness for Swift. Tools, hooks, permissions, streaming, recovery, MCP, multi-agent coordination — everything between your `execute(goal:)` and a deployed agent.

## Overview

SwiftSynapseHarness is the orchestration layer for the [SwiftSynapse](https://github.com/RichNasz/SwiftSynapse) ecosystem. It re-exports [SwiftSynapseMacros](https://github.com/RichNasz/SwiftSynapseMacros), so importing `SwiftSynapseHarness` gives you macros, core types, and the full harness in one import.

- **Agent runtime** with `agentRun()` lifecycle management, hooks, telemetry, and session persistence
- **Typed tool system** with `ToolRegistry`, `AgentToolLoop`, batch dispatch, and streaming
- **Hook system** with 16 event types for audit logging, approval gates, and custom handling
- **Permission system** with policy-driven tool access control and human-in-the-loop approval
- **Recovery strategies** for context window exhaustion, output truncation, and error retry
- **Production capabilities** including guardrails, MCP integration, multi-agent coordination, caching, plugins, cost tracking, rate limiting, and more

Designed for **business agents** — customer support, data processing, workflow automation — but general-purpose enough for any AI agent.

## Documentation

The full documentation is available as DocC via two paths:

**GitHub Pages** — no Xcode required. Both deployed automatically on push to `main`.

- **[SwiftSynapseHarness](https://richnasz.github.io/SwiftSynapseHarness/documentation/swiftsynapseharness/)** — core harness, tools, hooks, permissions, recovery, MCP, coordination, plugins, and all production capabilities
- **[SwiftSynapseUI](https://richnasz.github.io/SwiftSynapseHarness/documentation/swiftsynapseui/)** — drop-in SwiftUI views and App Intents for any `ObservableAgent`

**Xcode Developer Documentation** — richest experience during development:

1. Open this project (or any project that depends on it) in Xcode.
2. Choose **Product > Build Documentation** (or open the Documentation window).
3. Navigate to **SwiftSynapseHarness** or **SwiftSynapseUI** in the documentation navigator.

Both paths cover all guides and API reference. The README covers installation and orientation only.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main"),
]
```

Add `"SwiftSynapseHarness"` to your target's dependencies. This re-exports `SwiftSynapseMacrosClient`, so you get macros and core types automatically.

## Package Traits

SwiftSynapseHarness uses SwiftPM Package Traits for modular feature selection. The default `Production` trait includes everything most agents need. Pick exactly the subsystems you want:

| Trait | What it enables | Default? |
|-------|----------------|----------|
| `Core` | AgentToolProtocol, ToolRegistry, AgentToolLoop, streaming, config, LLM client | No |
| `Hooks` | HookPipeline + 16 event types + closure hooks | No |
| `Safety` | Permissions + Guardrails + Denial tracking | No |
| `Resilience` | RecoveryChain + strategies + compaction + rate limiting | No |
| `Observability` | Telemetry sinks, CostTracker, error classification | No |
| `MultiAgent` | CoordinationRunner + phases + subagent spawning | No |
| `Persistence` | FileSessionStore + session lifecycle + agent memory | No |
| `MCP` | MCPManager + external tool servers | No |
| `Plugins` | AgentPlugin system + lifecycle | No |
| `Production` | Core + Hooks + Safety + Resilience + Observability | **Yes** |
| `Advanced` | Production + MultiAgent + Persistence + MCP + Plugins | No |
| `Full` | Everything | No |

```swift
// Minimal agent (smallest binary):
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main", traits: ["Core"])

// Default — zero config (most users):
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main")

// Production + specific extras:
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main", traits: ["Production", "MCP", "Persistence"])

// Everything:
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main", traits: ["Full"])
```

## Quick Start

```swift
import SwiftSynapseHarness

@SpecDrivenAgent
actor CustomerSupportAgent {
    private let config: AgentConfiguration

    init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    func execute(goal: String) async throws -> String {
        let client = try config.buildClient()
        let tools = ToolRegistry()
        tools.register(LookupOrderTool())
        tools.register(RefundTool())

        return try await AgentToolLoop.run(
            client: client, config: config, goal: goal,
            tools: tools, transcript: _transcript
        )
    }
}
```

## Agent Harness

### Typed Tool System

```swift
struct CalculateTool: AgentToolProtocol {
    struct Input: Codable, Sendable { let expression: String }
    typealias Output = String

    static let name = "calculate"
    static let description = "Evaluates a math expression"
    static let isConcurrencySafe = true

    static var inputSchema: FunctionToolParam { /* ... */ }

    func execute(input: Input) async throws -> String {
        // Tool logic
    }
}

let tools = ToolRegistry()
tools.register(CalculateTool())
let result = try await tools.dispatch(name: "calculate", callId: "1", arguments: json)
```

### Hook System

```swift
let auditHook = ClosureHook(on: [.preToolUse, .postToolUse]) { event in
    switch event {
    case .preToolUse(let calls):
        AuditLog.record("Tools invoked: \(calls.map(\.name))")
    default: break
    }
    return .proceed
}

let pipeline = AgentHookPipeline()
await pipeline.add(auditHook)
```

### Permission System

```swift
let gate = PermissionGate()
await gate.addPolicy(ToolListPolicy(rules: [
    .requireApproval(["chargeCard", "sendEmail"]),
    .deny(["deleteAccount"])
]))
```

### Recovery Strategies

- **ReactiveCompactionStrategy** — compresses transcript when context window exceeded
- **OutputTokenEscalationStrategy** — increases max tokens on truncation
- **ContinuationStrategy** — sends continuation prompt
- **RecoveryChain** — ordered chain, first success wins

### Streaming

`AgentToolLoop.runStreaming()` dispatches concurrency-safe tools as their definitions complete in the LLM stream.

### LLM Backend Abstraction

- `CloudLLMClient` — wraps SwiftOpenResponsesDSL
- `HybridLLMClient` — Foundation Models on-device with cloud fallback
- `AgentConfiguration.buildClient()` selects based on `executionMode`

## Production Capabilities

### Session Persistence

```swift
let store = FileSessionStore()
try await agentRun(agent: myAgent, goal: "...", sessionStore: store)
```

### Guardrails

```swift
let guardrails = GuardrailPipeline()
await guardrails.add(ContentFilter.default)

try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    guardrails: guardrails
)
```

### MCP Integration

```swift
let manager = MCPManager()
try await manager.addServer(MCPServerConfig(
    name: "database",
    command: "/usr/local/bin/mcp-postgres",
    arguments: ["--connection", connectionString]
))
try await manager.registerAll(in: tools)
```

### Multi-Agent Coordination

```swift
let phases = [
    CoordinationPhase(name: "research", goal: "Research the topic",
                      agentFactory: { try ResearchAgent(configuration: $0) }),
    CoordinationPhase(name: "synthesize", goal: "Synthesize findings",
                      dependencies: ["research"],
                      agentFactory: { try SynthesisAgent(configuration: $0) }),
]
let result = try await CoordinationRunner.run(phases: phases, config: config)
```

### Cost Tracking

```swift
let tracker = CostTracker()
await tracker.setPricing(for: "claude-sonnet-4-20250514", pricing: ModelPricing(
    inputCostPerMillionTokens: 3, outputCostPerMillionTokens: 15
))
let sink = CostTrackingTelemetrySink(tracker: tracker)
```

### Rate Limiting

```swift
let rateLimitState = RateLimitState()
try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    rateLimitState: rateLimitState
)
```

### Plugin System

```swift
struct AuditPlugin: AgentPlugin {
    let name = "audit"
    let version = "1.0.0"

    func activate(context: PluginContext) async throws {
        await context.hookPipeline.add(AuditLoggingHook())
    }
    func deactivate() async {}
}
```

### Also Included

- **Advanced Compression** — MicroCompactor, ImportanceCompressor, AutoCompactCompressor, CompositeCompressor
- **Configuration Hierarchy** — 7-level priority (CLI > local > project > user > MDM > remote > environment)
- **Caching** — LRU/FIFO eviction with TTL for tool results
- **Denial Tracking** — Adaptive permission behavior based on consecutive denials
- **Error Classification** — Semantic API and tool error categorization
- **Tool Result Truncation** — Automatic oversized result handling
- **System Prompt Composition** — Prioritized, cacheable sections
- **VCR Testing** — Deterministic record/replay for agent tests
- **Graceful Shutdown** — LIFO handler execution with signal handling
- **Agent Memory** — Persistent cross-session categorized memory
- **Conversation Recovery** — Transcript integrity checking and repair

## Telemetry

```swift
let telemetry = CompositeTelemetrySink([
    OSLogTelemetrySink(),
    CostTrackingTelemetrySink(tracker: costTracker),
])
```

12 event types: agent lifecycle, LLM calls, tool calls, retries, budget exhaustion, guardrail triggers, context compaction, API error classification, plugin lifecycle.

## Dependencies

| Package | Purpose |
|---------|---------|
| [SwiftSynapseMacros](https://github.com/RichNasz/SwiftSynapseMacros) | Macros and core types (re-exported) |
| [SwiftOpenSkills](https://github.com/RichNasz/SwiftOpenSkills) | Skills framework integration |

## Spec-Driven Development

All `.swift` files are generated from specs in `CodeGenSpecs/`. To change behavior: edit the spec, regenerate, never edit generated files directly. See [CodeGenSpecs/Overview.md](CodeGenSpecs/Overview.md).

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the spec-first workflow, commit conventions, and PR standards.

## License

SwiftSynapseHarness is available under the Apache License 2.0.

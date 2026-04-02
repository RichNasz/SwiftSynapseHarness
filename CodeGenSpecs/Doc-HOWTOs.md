# Doc-HOWTOs

## Purpose

Specifies five task-focused HOWTO articles for SwiftSynapseHarness. Each article is a standalone, step-by-step guide for a specific developer task. Articles are concise (300–500 words), actionable, and include complete code examples.

## Generates

- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/HowToAddTools.md`
- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/HowToConfigurePermissions.md`
- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/HowToGoToProduction.md`
- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/HowToMultiAgent.md`
- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/HowToTestAgents.md`

---

## HowToAddTools.md

### Title & Tagline

Title: `How to Add Tools to an Agent`

Tagline: Define a typed tool, register it, and wire it into the tool loop.

### Steps

#### Step 1: Conform to AgentToolProtocol

Every tool has a typed `Input`, typed `Output`, a `name`, a `description`, an `inputSchema`, and an `execute(input:)` method:

```swift
struct SearchDocsTool: AgentToolProtocol {
    struct Input: Codable, Sendable {
        let query: String
        let maxResults: Int
    }
    struct Output: Codable, Sendable {
        let results: [String]
    }

    static let name = "search_docs"
    static let description = "Searches documentation for a query."
    static let inputSchema: FunctionToolParam = .init(
        name: name,
        description: description,
        parameters: .init(
            properties: [
                "query": .init(type: "string", description: "The search query"),
                "maxResults": .init(type: "integer", description: "Maximum number of results")
            ],
            required: ["query"]
        )
    )

    func execute(input: Input) async throws -> Output {
        let results = try await DocumentationIndex.search(input.query, limit: input.maxResults)
        return Output(results: results)
    }
}
```

#### Step 2: Mark Concurrency Safety

If your tool has no shared mutable state, mark it concurrency-safe. This enables parallel execution with other safe tools during streaming:

```swift
static let isConcurrencySafe = true
```

#### Step 3: Register the Tool

Register tools in a `ToolRegistry` before passing it to `AgentToolLoop`:

```swift
let tools = ToolRegistry()
tools.register(SearchDocsTool())
tools.register(CalculateTool())
tools.register(ConvertUnitTool())
```

#### Step 4: Report Progress (Optional)

For long-running tools, conform to `ProgressReportingTool` instead of `AgentToolProtocol` to emit intermediate progress:

```swift
struct IndexingTool: ProgressReportingTool {
    func execute(input: Input, callId: String, progress: any ToolProgressDelegate) async throws -> Output {
        let files = try listFiles()
        for (i, file) in files.enumerated() {
            await progress.reportProgress(ToolProgressUpdate(
                callId: callId,
                toolName: Self.name,
                message: "Indexing \(file.name) (\(i+1)/\(files.count))",
                fractionComplete: Double(i+1) / Double(files.count)
            ))
            try await index(file)
        }
        return .success
    }
}
```

Progress updates appear in `ObservableTranscript.toolProgress` for real-time SwiftUI display.

### See Also

- `<doc:AgentHarnessGuide>` — typed tool system, batch dispatch, StreamingToolExecutor
- `<doc:HowToConfigurePermissions>` — restrict which tools an agent can call

---

## HowToConfigurePermissions.md

### Title & Tagline

Title: `How to Configure Tool Permissions`

Tagline: Control which tools run automatically, which require human approval, and which are always blocked.

### Steps

#### Step 1: Create a ToolListPolicy

`ToolListPolicy` takes an ordered list of rules. Rules are evaluated top-to-bottom:

```swift
let policy = ToolListPolicy(rules: [
    .allow(["search_docs", "calculate"]),       // Always allowed
    .requireApproval(["send_email", "charge"]), // Ask human first
    .deny(["delete_account"])                   // Always blocked
])
```

Rule precedence: the first matching rule wins. Tools not matching any rule fall through to a configurable default (`.deny` by default).

#### Step 2: Wire Into a PermissionGate

```swift
let gate = PermissionGate()
await gate.addPolicy(policy)
await gate.setApprovalDelegate(UIApprovalDelegate())

tools.permissionGate = gate
```

Implement `ApprovalDelegate` to show approval UI (alerts, Slack, etc.):

```swift
struct UIApprovalDelegate: ApprovalDelegate {
    func requestApproval(for tool: String, input: String) async -> Bool {
        // Show UI and return user's decision
        return await showApprovalAlert(tool: tool, input: input)
    }
}
```

#### Step 3: Add Adaptive Behavior (Optional)

`AdaptivePermissionGate` switches modes automatically after repeated denials:

```swift
let adaptiveGate = AdaptivePermissionGate(
    gate: gate,
    mode: .default,
    denialThreshold: 3  // Switch to .planOnly after 3 consecutive denials
)
```

Use `.autoApprove` for trusted CI environments. Use `.planOnly` to let the LLM describe what it _would_ do without executing.

### See Also

- `<doc:AgentHarnessGuide>` — permission system, adaptive gate, denial tracking
- `<doc:ProductionGuide>` — guardrails for content safety alongside permissions

---

## HowToGoToProduction.md

### Title & Tagline

Title: `How to Deploy an Agent to Production`

Tagline: Add guardrails, cost tracking, rate limiting, and graceful shutdown for a production-ready deployment.

### Steps

#### Step 1: Add Content Guardrails

Guardrails screen tool arguments and LLM outputs for sensitive content:

```swift
let guardrails = GuardrailPipeline()
await guardrails.add(ContentFilter.default)         // Built-in: CC#, SSN, API keys
await guardrails.add(ComplianceFilter())            // Your custom policy

try await AgentToolLoop.run(
    ..., guardrails: guardrails
)
```

#### Step 2: Track Costs

Wire `CostTrackingTelemetrySink` into the telemetry pipeline. Costs accumulate automatically from every LLM call:

```swift
let costTracker = CostTracker()
await costTracker.setPricing(for: "claude-opus-4-6", pricing: ModelPricing(
    inputCostPerMillionTokens: 3.0,
    outputCostPerMillionTokens: 15.0
))

let telemetry = CompositeTelemetrySink([
    OSLogTelemetrySink(),
    CostTrackingTelemetrySink(tracker: costTracker)
])
```

Query costs after the session:

```swift
let total = await costTracker.totalCost()
let byModel = await costTracker.usageByModel()
```

#### Step 3: Handle Rate Limits

Pass a `RateLimitState` to `AgentToolLoop`. It automatically parses Retry-After headers, enters cooldown on 429/529 responses, and uses jittered backoff:

```swift
let rateLimitState = RateLimitState()
try await AgentToolLoop.run(..., rateLimitState: rateLimitState)
```

#### Step 4: Register Graceful Shutdown

Register cleanup handlers in reverse-priority order. `SignalHandler.install()` catches SIGINT and SIGTERM:

```swift
let shutdown = ShutdownRegistry()
await shutdown.register(name: "sessions") { await sessionStore.flush() }
await shutdown.register(name: "mcp")      { await mcpManager.disconnectAll() }
await shutdown.register(name: "plugins")  { await pluginManager.deactivateAll() }
SignalHandler.install(registry: shutdown)
```

Handlers run in LIFO order (last registered runs first).

### See Also

- `<doc:ProductionGuide>` — full details on each capability
- `<doc:HowToMultiAgent>` — coordinating multiple agents in production

---

## HowToMultiAgent.md

### Title & Tagline

Title: `How to Coordinate Multiple Agents`

Tagline: Run child agents, build dependency-aware pipelines, and share state between agents.

### Steps

#### Step 1: Run a Child Agent

`SubagentRunner.run()` spawns a single child agent with inherited configuration:

```swift
let summary = try await SubagentRunner.run(
    agentFactory: { config in try SummaryAgent(configuration: config) },
    goal: "Summarize this document: \(documentText)",
    context: SubagentContext(config: parentConfig, lifecycleMode: .shared)
)
```

With `.shared` lifecycle, cancelling the parent also cancels the child. Use `.independent` for fire-and-forget children.

#### Step 2: Run Agents in Parallel

`SubagentRunner.runParallel()` runs multiple children concurrently:

```swift
let results = try await SubagentRunner.runParallel(
    agents: [
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research Swift concurrency"),
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research async/await"),
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research actors"),
    ],
    context: SubagentContext(config: config, lifecycleMode: .shared)
)
```

#### Step 3: Build a DAG Workflow

Use `CoordinationRunner` for dependency-ordered execution. Phases with satisfied dependencies run in parallel:

```swift
let phases = [
    CoordinationPhase(
        name: "research",
        goal: "Research the market opportunity",
        agentFactory: { try ResearchAgent(configuration: $0) }
    ),
    CoordinationPhase(
        name: "draft",
        goal: "Draft a business proposal",
        dependencies: ["research"],
        agentFactory: { try WritingAgent(configuration: $0) }
    ),
    CoordinationPhase(
        name: "review",
        goal: "Review and refine the proposal",
        dependencies: ["draft"],
        agentFactory: { try ReviewAgent(configuration: $0) }
    ),
]

let result = try await CoordinationRunner.run(phases: phases, config: config)
```

`TeamMemory` automatically stores each phase's output. Downstream phases can read upstream results via the context.

#### Step 4: Pass Messages Between Agents

`SharedMailbox` enables async message passing between concurrently running agents:

```swift
let mailbox = SharedMailbox(name: "research-channel")

// Producer agent
await mailbox.send("Found key insight: \(insight)")

// Consumer agent
for await message in mailbox.messages {
    process(message)
}
```

### See Also

- `<doc:AgentHarnessGuide>` — `SubagentRunner`, `SubagentContext`
- `<doc:ProductionGuide>` — `CoordinationRunner`, `TeamMemory`, `SharedMailbox`

---

## HowToTestAgents.md

### Title & Tagline

Title: `How to Test Agents`

Tagline: Deterministic, fast agent tests using VCR recording/replay, in-memory telemetry, and fixture stores.

### Steps

#### Step 1: Record Agent Interactions with VCR

`VCRClient` records real LLM responses to fixture files on first run, then replays them in subsequent runs:

```swift
// Record mode — makes real API calls and saves responses
let store = FileFixtureStore(directoryPath: "Tests/Fixtures/AgentTests")
let vcr = VCRClient(client: realClient, store: store, mode: .record)

let agent = MyAgent(client: vcr, config: config, tools: tools)
let result = try await agent.run(goal: "Summarize this document")
// Fixture saved to Tests/Fixtures/AgentTests/<hash>.json
```

#### Step 2: Replay in CI (No Network Calls)

Switch to `.replay` mode for deterministic test execution:

```swift
let vcr = VCRClient(client: realClient, store: store, mode: .replay)
// No API calls made — responses come from fixture files
let result = try await agent.run(goal: "Summarize this document")
XCTAssertTrue(result.contains("key finding"))
```

Use `.passthrough` to always make real calls without recording.

#### Step 3: Assert Telemetry Events

`InMemoryTelemetrySink` collects events for inspection in tests:

```swift
let sink = InMemoryTelemetrySink()
let agent = MyAgent(telemetry: sink, ...)
_ = try await agent.run(goal: "...")

let events = await sink.events
XCTAssertTrue(events.contains { $0.kind == .toolCalled(name: "search_docs", ...) })
XCTAssertFalse(events.contains { $0.kind == .retryAttempted })
```

#### Step 4: Test Hook Behavior

Use `ClosureHook` to assert hooks fire with the expected events:

```swift
var capturedEvents: [AgentHookEvent] = []
let hook = ClosureHook(on: [.preToolUse, .postToolUse]) { event in
    capturedEvents.append(event)
    return .proceed
}
await agent.hooks.add(hook)
_ = try await agent.run(goal: "...")

XCTAssertEqual(capturedEvents.count, 2) // pre + post
```

#### Step 5: Test Guardrail Decisions

Test that guardrails block the expected content:

```swift
let pipeline = GuardrailPipeline()
await pipeline.add(ContentFilter.default)

let sensitiveInput = GuardrailInput.toolArguments("api_key=sk-abc123")
let decision = await pipeline.evaluate(sensitiveInput)

if case .block = decision { /* pass */ } else { XCTFail("Should have blocked API key") }
```

### See Also

- `<doc:ProductionGuide>` — `VCRClient`, `FileFixtureStore`, `FixtureMode`
- `<doc:AgentHarnessGuide>` — telemetry sinks, hook system

---

## Implementation Notes for Generator

- Each HOWTO is an independent article — no shared state or cross-article dependencies
- Keep steps numbered and scannable — developers read these while coding
- Every step must have a working code example
- "See Also" links use `<doc:ArticleName>` syntax
- Type names in prose use `` ``TypeName`` `` syntax

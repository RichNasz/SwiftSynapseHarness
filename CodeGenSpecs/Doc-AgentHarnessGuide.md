# Doc-AgentHarnessGuide

## Purpose

Specifies the complete Agent Harness Guide — the authoritative reference for core harness runtime capabilities. This replaces the existing `AgentHarnessGuide.md`, filling in gaps: all 16 hook events, adaptive permissions, skills integration, and `StreamingToolExecutor`.

## Generates

- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/AgentHarnessGuide.md`

---

## Article Structure

### Title & Overview

Title: `Agent Harness Guide`

Tagline: The runtime infrastructure between your `execute(goal:)` and a working agent — typed tools, hooks, permissions, streaming, recovery, and subagents.

Overview prose: The agent harness provides everything an agent needs at runtime. Each component is opt-in and composes naturally through function parameters — no subclassing, no protocol witnesses, no configuration objects.

Note: Each section below indicates which Package Trait is required. All sections here are included in the default `Production` trait except Subagent Composition (requires `MultiAgent`). See `<doc:GettingStarted>` for how to select traits.

---

### Section: Typed Tool System — *Requires: Core trait (included in Production)*

Introduce `AgentToolProtocol` with typed `Input`/`Output`:

```swift
public protocol AgentToolProtocol: Sendable {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable
    static var name: String { get }
    static var description: String { get }
    static var inputSchema: FunctionToolParam { get }
    static var isConcurrencySafe: Bool { get }  // default: false
    func execute(input: Input) async throws -> Output
}
```

Show registering and dispatching tools via `ToolRegistry`:

```swift
let tools = ToolRegistry()
tools.register(CalculateTool())
tools.register(ConvertUnitTool())

// Single dispatch
let result = try await tools.dispatch(name: "calculate", callId: "1", arguments: json)

// Batch dispatch — concurrency-safe tools run in parallel via TaskGroup
let results = try await tools.dispatchBatch(calls)
```

Explain: `AnyAgentTool` handles type erasure internally. String outputs bypass JSON encoding to avoid double-quoting.

Mark `isConcurrencySafe = true` on tools with no shared mutable state to enable parallel execution.

---

### Section: Declarative Tools with @LLMTool

Subsection under "Typed Tool System". Show `AgentLLMTool` bridge protocol:

```swift
/// Searches documentation for a query.
@LLMTool
struct SearchDocsTool: AgentLLMTool {
    @LLMToolArguments
    struct Arguments {
        @LLMToolGuide(description: "The search query")
        var query: String

        @LLMToolGuide(description: "Max results", .range(1...50))
        var maxResults: Int
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        ToolOutput(content: try await search(arguments.query, limit: arguments.maxResults))
    }
}

tools.register(SearchDocsTool())  // same registration path as AgentToolProtocol
```

Explain: `@LLMTool` synthesizes `name` (snake_cased), `description` (doc comment), `toolDefinition`. `AgentLLMTool` provides `inputSchema`, `isConcurrencySafe` (default `false`), and `execute(input:)` as defaults — bridging `ToolDefinition` → `FunctionToolParam` via `FunctionToolParam.init(from:)`. Inherits `AgentToolProtocol`, so declarative tools work everywhere existing tools do.

---

### Section: AgentToolLoop

The reusable tool dispatch loop handles the complete LLM conversation cycle:

```swift
let result = try await AgentToolLoop.run(
    client: client,
    config: config,
    goal: goal,
    tools: tools,
    transcript: _transcript,
    systemPrompt: "You are a helpful assistant.",
    maxIterations: 10,
    hooks: hooks,
    telemetry: telemetry,
    budget: &budget,
    compressor: compressor,
    recovery: recovery,
    guardrails: guardrails,
    progressDelegate: delegate,
    compactionTrigger: .threshold(0.75)
)
```

Each iteration: check cancellation → compact if needed → build request → fire hooks → send to LLM → track tokens → dispatch tools → record results → check budget.

#### Streaming Variant

`AgentToolLoop.runStreaming()` dispatches concurrency-safe tools as their definitions complete in the LLM stream. Text deltas are forwarded to `ObservableTranscript` for real-time SwiftUI updates.

---

### Section: StreamingToolExecutor

`StreamingToolExecutor` manages concurrent tool execution during streaming responses:

- Concurrency-safe tools (`isConcurrencySafe == true`) start immediately as calls arrive
- Unsafe tools are queued and dispatched sequentially after all safe tools finish
- Used internally by `AgentToolLoop.runStreaming()`, but also available standalone

```swift
let executor = StreamingToolExecutor(tools: registry, hooks: hooks, telemetry: telemetry)

// As tool call events arrive from the stream:
executor.enqueue(toolCall)

// After the stream ends — await all results:
let results = try await executor.awaitAll()
```

Properties:
- `hasTools: Bool` — whether any tools have been enqueued

---

### Section: Hook System — *Requires: Hooks trait (included in Production)*

Intercept all 16 event types without modifying agent code.

Show table of all 16 events:

| Event | When it fires |
|-------|---------------|
| `agentStarted` | Agent begins execution |
| `agentCompleted` | Agent finishes successfully |
| `agentFailed` | Agent encounters an error |
| `agentCancelled` | Agent task is cancelled |
| `preToolUse` | Before tool dispatch (can block) |
| `postToolUse` | After tool dispatch |
| `llmRequestSent` | Before LLM call (can modify) |
| `llmResponseReceived` | After LLM response |
| `transcriptUpdated` | Transcript entry added |
| `sessionSaved` | Session persisted |
| `sessionRestored` | Session restored |
| `guardrailTriggered` | Guardrail policy activated |
| `coordinationPhaseStarted` | Coordination phase begins |
| `coordinationPhaseCompleted` | Coordination phase ends |
| `memoryUpdated` | A memory entry was saved or updated |
| `transcriptRepaired` | Transcript integrity violations were repaired |

#### Hook Actions

- `.proceed` — continue normally
- `.modify(String)` — replace input/output
- `.block(reason:)` — abort the operation

#### Quick Setup

```swift
let hooks = AgentHookPipeline()

let auditHook = ClosureHook(on: [.preToolUse, .postToolUse]) { event in
    if case .preToolUse(let calls) = event {
        for call in calls { AuditLog.record("Tool: \(call.name)") }
    }
    return .proceed
}
await hooks.add(auditHook)
```

The pipeline uses first-block-wins semantics — if any hook returns `.block`, the operation is aborted.

---

### Section: Permission System — *Requires: Safety trait (included in Production)*

Policy-driven tool access control with human-in-the-loop approval:

```swift
let gate = PermissionGate()
await gate.addPolicy(ToolListPolicy(rules: [
    .allow(["calculate", "convertUnit"]),
    .requireApproval(["chargeCard", "sendEmail"]),
    .deny(["deleteAccount"])
]))
await gate.setApprovalDelegate(myDelegate)

tools.permissionGate = gate
```

Policies evaluate in order with most-restrictive-wins semantics. For `.requiresApproval`, the gate calls your `ApprovalDelegate` for a human decision.

#### Adaptive Permission Gate

`AdaptivePermissionGate` wraps a base `PermissionGate` and tracks consecutive denials. When the denial threshold is reached, it can switch permission modes automatically:

```swift
let adaptiveGate = AdaptivePermissionGate(
    gate: baseGate,
    mode: .default,
    denialThreshold: 3
)
```

| Mode | Behavior |
|------|----------|
| `.default` | Policy-driven, tracks denials, switches at threshold |
| `.autoApprove` | Always allow (trusted environments) |
| `.alwaysPrompt` | Force approval for every tool call |
| `.planOnly` | Block all tools, explain what would have been called |

`DenialTracker` is the underlying actor tracking consecutive denials per session. Access it via `adaptiveGate.denialTracker` to read the denial count or reset it.

---

### Section: Recovery Strategies — *Requires: Resilience trait (included in Production)*

Self-healing from context window exhaustion and output truncation:

| Strategy | Recovers from |
|----------|--------------|
| `ReactiveCompactionStrategy` | Context window exceeded — compresses transcript |
| `OutputTokenEscalationStrategy` | Output truncated — increases max tokens |
| `ContinuationStrategy` | Output truncated — sends continuation prompt |

Chain them with `RecoveryChain`:

```swift
let recovery = RecoveryChain.default
// Tries: Compaction → Escalation → Continuation (first success wins)
```

---

### Section: Context Budget — *Requires: Core trait (included in Production)*

Track token usage and trigger compaction:

```swift
var budget = ContextBudget(maxTokens: 128_000)
// AgentToolLoop records tokens automatically
// When budget.utilizationPercentage exceeds threshold, compaction fires
```

#### Transcript Compression

`TranscriptCompressor` protocol with built-in strategies. `SlidingWindowCompressor` keeps the last N entries plus a summary. See `<doc:ProductionGuide>` for advanced compressors.

---

### Section: LLM Backend Abstraction — *Requires: Core trait (included in Production)*

Three backends behind one protocol:

```swift
public protocol AgentLLMClient: Sendable {
    func send(_ request: AgentRequest) async throws -> AgentResponse
    func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<AgentStreamEvent, Error>
}
```

| Backend | Implementation |
|---------|---------------|
| `CloudLLMClient` | Wraps SwiftOpenResponsesDSL for any OpenAI-compatible endpoint |
| `HybridLLMClient` | Foundation Models on-device first, cloud fallback |

`AgentConfiguration.buildClient()` selects the backend based on `executionMode`.

---

### Section: Subagent Composition — *Requires: MultiAgent trait*

Run child agents with shared or independent lifecycles:

```swift
let result = try await SubagentRunner.run(
    agentFactory: { try SummaryAgent(configuration: $0) },
    goal: "Summarize this document",
    context: SubagentContext(config: parentConfig, lifecycleMode: .shared)
)
```

- `.shared` — parent cancellation propagates to the child
- `.independent` — child runs in its own task

Run multiple children in parallel:

```swift
let results = try await SubagentRunner.runParallel(
    agents: [
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research topic A"),
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research topic B"),
    ],
    context: SubagentContext(config: config, lifecycleMode: .shared)
)
```

---

### Section: Telemetry — *Requires: Observability trait (included in Production)*

Structured event emission to any backend:

```swift
let telemetry = CompositeTelemetrySink([
    OSLogTelemetrySink(),       // Unified logging
    InMemoryTelemetrySink(),    // Testing assertions
])
```

12 event types emitted automatically: agent lifecycle, LLM calls (model, tokens, duration), tool calls (name, duration, success), retries, budget exhaustion, guardrail triggers, context compaction, plugin lifecycle.

---

### Section: Retry — *Requires: Core trait (included in Production)*

Exponential backoff for transient failures:

```swift
let result = try await retryWithBackoff(maxAttempts: 3) {
    try await client.send(request)
}
```

Base delay 500ms, doubles per attempt. `isTransportRetryable()` provides a default predicate for network errors.

---

### Section: Skills Integration — *Requires: Core trait (included in Production)*

SwiftSynapseHarness re-exports SwiftOpenSkills types so skills are available with one import:

```swift
import SwiftSynapseHarness

// Skills types available directly:
// SkillStore, SkillSearchPath, Skill
// SkillsAgent, Skills (when SwiftOpenSkillsResponses is available)
```

`SkillStore` manages a collection of skills. `SkillSearchPath` configures where skills are discovered on disk. Use `SkillsAgent` (from SwiftOpenSkillsResponses) to run agents with skill awareness.

---

## Implementation Notes for Generator

- All 16 hook events must appear in the table — no omissions
- `StreamingToolExecutor` section is new — was not in previous guide
- `AdaptivePermissionGate` + `DenialTracker` section is new
- Skills section is new
- Use `` ``TypeName`` `` for all type cross-references
- Use `<doc:ProductionGuide>` when referencing production guide content

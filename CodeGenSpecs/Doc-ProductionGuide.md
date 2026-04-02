# Doc-ProductionGuide

## Purpose

Specifies the complete Production Guide — the authoritative reference for deploying agents in production. Replaces the existing `ProductionGuide.md` with an expanded Conversation Recovery section and updated accuracy throughout.

## Generates

- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/ProductionGuide.md`

---

## Article Structure

### Title & Overview

Title: `Production Guide`

Tagline: Capabilities that close the gap between a working agent and a deployed one — session persistence, guardrails, MCP, compression, configuration, caching, coordination, and plugins.

Overview: Every capability in this guide is modular and opt-in. They integrate through established extension points (function parameters, hook events, telemetry) rather than requiring changes to your agent's `execute(goal:)`.

---

### Section: Session Persistence

Pause and resume agent workflows across app launches:

```swift
let store = FileSessionStore()

// agentRun() auto-saves on completion, error, or cancellation
try await agentRun(agent: myAgent, goal: "...", sessionStore: store)

// Resume later
if let session = try await store.load(sessionId: savedId) {
    myAgent._transcript.restore(from: session.transcriptEntries)
}
```

| Type | Purpose |
|------|---------|
| `SessionStore` | Protocol — `save`, `load`, `list`, `delete` |
| `SessionMetadata` | Lightweight summary (id, agentType, goal, timestamps, status) |
| `SessionStatus` | `.active`, `.paused`, `.completed`, `.failed` |
| `FileSessionStore` | Actor — JSON file-per-session in `~/.swiftsynapse/sessions/` |

Hook events: `.sessionSaved(sessionId:)`, `.sessionRestored(sessionId:)`.

---

### Section: Guardrails

Input/output safety checks for content filtering and compliance:

```swift
let guardrails = GuardrailPipeline()
await guardrails.add(ContentFilter.default)

try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    guardrails: guardrails
)
```

`ContentFilter.default` detects credit card numbers, SSNs, API keys, and bearer tokens via regex patterns.

#### Guardrail Decisions

- `.allow` — content passes
- `.sanitize(replacement:)` — replace sensitive content
- `.block(reason:)` — reject entirely (throws `GuardrailError`)
- `.warn(reason:)` — log but allow

The pipeline evaluates policies in order with most-restrictive-wins semantics. Checks run before tool dispatch (on arguments) and after LLM response (on output text).

#### Custom Policies

```swift
struct ComplianceFilter: GuardrailPolicy {
    let name = "compliance"
    func evaluate(input: GuardrailInput) async -> GuardrailDecision {
        // Your compliance logic
        return .allow
    }
}
```

---

### Section: Tool Progress Streaming

Real-time feedback during long-running tool execution:

```swift
struct DataImportTool: ProgressReportingTool {
    func execute(input: Input, callId: String, progress: any ToolProgressDelegate) async throws -> Output {
        for (i, batch) in batches.enumerated() {
            await progress.reportProgress(ToolProgressUpdate(
                callId: callId, toolName: Self.name,
                message: "Importing batch \(i+1)/\(batches.count)",
                fractionComplete: Double(i+1) / Double(batches.count)
            ))
            try await processBatch(batch)
        }
        return .success
    }
}
```

Progress updates flow to `ObservableTranscript.toolProgress` for SwiftUI binding.

---

### Section: MCP Integration

Connect agents to external systems via the Model Context Protocol (JSON-RPC 2.0):

```swift
let manager = MCPManager()
try await manager.addServer(MCPServerConfig(
    name: "database",
    command: "/usr/local/bin/mcp-postgres",
    arguments: ["--connection", connectionString]
))
try await manager.registerAll(in: tools) // MCP tools appear as native AgentToolProtocol tools
```

| Type | Purpose |
|------|---------|
| `MCPTransport` | Protocol — `send`, `receive`, `close` |
| `StdioMCPTransport` | Actor — stdio via child `Process` with Content-Length framing |
| `MCPServerConnection` | Actor — connect, handshake, discover tools, call tools |
| `MCPToolBridge` | Wraps MCP tool as `AgentToolProtocol` (JSON pass-through) |
| `MCPManager` | Actor — manages multiple servers, registers tools |

No external dependencies — Foundation covers stdio (`Process`), SSE (`URLSession`), and WebSocket.

---

### Section: Advanced Context Compression

Multiple compression strategies beyond the basic `SlidingWindowCompressor`:

| Compressor | Strategy |
|------------|----------|
| `MicroCompactor` | Truncates individual tool results exceeding a length threshold |
| `ImportanceCompressor` | Scores entries by type (user > error > assistant > toolCall), drops lowest first |
| `AutoCompactCompressor` | Aggressive — keeps first entry + last N entries + summary |
| `CompositeCompressor` | Chains compressors in order |

```swift
let compressor = CompositeCompressor.default
// Chain: MicroCompactor → ImportanceCompressor → SlidingWindowCompressor

try await AgentToolLoop.run(
    ..., compressor: compressor,
    compactionTrigger: .threshold(0.75)
)
```

#### Compaction Triggers

- `.threshold(Double)` — compress when budget utilization exceeds percentage (default 0.8)
- `.tokenCount(Int)` — compress when used tokens exceed count
- `.entryCount(Int)` — compress when transcript entry count exceeds limit
- `.manual` — never auto-compact

---

### Section: Configuration Hierarchy

7-level priority configuration for enterprise deployments:

```
CLI arguments (7)  >  local file (6)  >  project file (5)  >
user file (4)  >  MDM policy (3)  >  remote config (2)  >  environment (1)
```

```swift
let resolver = ConfigurationResolver()
await resolver.addSource(EnvironmentConfigSource())
await resolver.addSource(FileConfigSource.userDefault)   // ~/.swiftsynapse/config.json
await resolver.addSource(MDMConfigSource())              // macOS managed domain
let config = try await resolver.resolveConfiguration()
```

| Source | What it reads |
|--------|--------------|
| `EnvironmentConfigSource` | `SWIFTSYNAPSE_*` env vars, strips prefix, lowercases keys |
| `FileConfigSource` | JSON file at configurable path |
| `MDMConfigSource` | macOS UserDefaults managed domain (enterprise MDM profiles) |

---

### Section: Caching

Generic caching with LRU eviction and TTL for tool results:

```swift
let cache = ToolResultCache(policy: CachePolicy(maxEntries: 50, ttl: .seconds(300)))
// Identical tool calls return cached results instantly
```

The underlying `Cache<Key, Value>` actor supports both `.lru` and `.fifo` eviction strategies. Thread-safe via actor isolation.

---

### Section: Denial Tracking

Adaptive permission behavior based on consecutive denials:

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

`DenialTracker` records consecutive denials and exposes the count for observation. Access via `adaptiveGate.denialTracker`.

---

### Section: Multi-Agent Coordination

Dependency-aware multi-agent workflow execution:

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

Phases with satisfied dependencies run in parallel. Results are stored in `TeamMemory` for downstream phases. `SharedMailbox` enables cross-agent async message passing.

The runner validates the dependency graph — `CoordinationError.unknownDependency` for missing references, `CoordinationError.cyclicDependency` for cycles.

---

### Section: Plugin System

Modular extension mechanism — plugins register hooks, tools, and guardrails at activation:

```swift
struct AuditPlugin: AgentPlugin {
    let name = "audit"
    let version = "1.0.0"

    func activate(context: PluginContext) async throws {
        await context.hookPipeline.add(AuditLoggingHook())
        await context.guardrailPipeline?.add(ComplianceFilter())
    }
    func deactivate() async {}
}

let plugins = PluginManager()
await plugins.register(AuditPlugin())
await plugins.activateAll(context: pluginContext)
```

`PluginContext` provides access to `toolRegistry`, `hookPipeline`, `guardrailPipeline`, and `configResolver`. Plugins activate in registration order and deactivate in reverse (LIFO).

Telemetry: `.pluginActivated(name:)`, `.pluginError(name:error:)`.

---

### Section: Cost Tracking

Track per-session costs with per-model pricing:

```swift
let tracker = CostTracker()
await tracker.setPricing(for: "claude-opus-4-6", pricing: ModelPricing(
    inputCostPerMillionTokens: 3,
    outputCostPerMillionTokens: 15
))

let sink = CostTrackingTelemetrySink(tracker: tracker)
// Wire into telemetry — costs accumulate automatically from .llmCallMade events
```

`CostTracker` provides `totalCost()`, `totalAPIDuration()`, `usageByModel()`, and `allRecords()`.

---

### Section: Rate Limiting

Rate-limit-aware retry with cooldown tracking, separate from general retry logic:

```swift
let rateLimitState = RateLimitState()

try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    rateLimitState: rateLimitState
)
```

Checks cooldown before sending, parses Retry-After headers, enters cooldown on 429/529 errors, uses jittered exponential backoff.

---

### Section: Semantic Error Classification

Classify API and tool errors into semantic categories for structured handling:

```swift
let classified = classifyAPIError(error, model: "claude-opus-4-6")
switch classified.category {
case .auth:              // Invalid API key
case .rateLimit(let retryAfter):  // Rate limited with optional retry-after
case .quota:             // Quota exhausted
case .connectivity:      // Network issue
case .serverError:       // Transient server error (5xx)
case .badRequest:        // Malformed request
default: break
}
```

`classifyRecoverableError()` in the recovery system delegates to `classifyAPIError()` for consistent classification.

---

### Section: System Prompt Composition

Build system prompts from composable, prioritized sections:

```swift
let builder = SystemPromptBuilder()
await builder.addSection(SystemPromptSection(
    id: "role", content: "You are a support agent.", priority: 0
))
await builder.addDynamicSection(id: "context", priority: 100) {
    "Current time: \(Date())"
}
let systemPrompt = try await builder.build()
```

Tools can co-locate prompt instructions via `SystemPromptProvider` conformance. `buildWithCacheBoundaries()` returns sections grouped by cacheability for prompt-caching backends.

---

### Section: Tool Result Truncation

Oversized tool results are automatically truncated before entering the transcript:

```swift
let policy = TruncationPolicy(maxCharacters: 8192)
let truncated = ResultTruncator.truncate(longOutput, policy: policy)
```

Applied automatically in `AgentToolLoop.run()` using `config.toolResultBudgetTokens * 4` as the default limit (16384 chars). The truncator preserves the last 200 characters so output endings are not lost.

---

### Section: Agent Memory

Persistent cross-session memory distinct from session persistence and team memory:

```swift
let memory = FileMemoryStore()
try await memory.save(MemoryEntry(
    category: .feedback,
    content: "User prefers terse responses",
    tags: ["style"]
))
let entries = try await memory.retrieve(category: .user, limit: 10)
let results = try await memory.search(query: "preferences", limit: 5)
```

Categories: `.user`, `.feedback`, `.project`, `.reference`, `.custom(String)`. Stored as JSON files in `~/.swiftsynapse/memory/`.

Hook event: `.memoryUpdated(entry:)` fires when a memory entry is saved or updated.

---

### Section: Conversation Recovery

Validate and repair transcript integrity after interruptions or network failures:

```swift
let (repaired, violations) = recoverTranscript(entries)
if !violations.isEmpty {
    print("Repaired \(violations.count) transcript violations")
}
```

#### Integrity Violations

`TranscriptIntegrityCheck` detects three violation types:

| Violation | Description |
|-----------|-------------|
| `.orphanedToolCall(name:index:)` | A tool call at index has no matching tool result |
| `.orphanedToolResult(name:index:)` | A tool result at index has no preceding tool call |
| `.invalidSequence(expected:found:index:)` | An unexpected entry type at index |

#### Recovery Strategies

`ConversationRecoveryStrategy` is a protocol for custom repair logic. The built-in `DefaultConversationRecoveryStrategy`:

- For orphaned tool calls: appends a synthetic error result (`[Error: Tool call interrupted — no result received]`)
- For orphaned tool results: removes them

Pass a custom strategy to `recoverTranscript(_:strategy:)`:

```swift
let (repaired, violations) = recoverTranscript(entries, strategy: MyCustomStrategy())
```

Hook event: `.transcriptRepaired(violations:)` fires when repairs are applied.

---

### Section: VCR Testing

Deterministic agent testing via request/response recording and replay:

```swift
let store = FileFixtureStore(directoryPath: "Tests/Fixtures")
let vcr = VCRClient(client: realClient, store: store, mode: .record)

// Later, in CI:
let vcr = VCRClient(client: realClient, store: store, mode: .replay)
// No network calls — deterministic responses from fixtures
```

`VCRClient` conforms to `AgentLLMClient` and drops in anywhere a client is used. Fixtures are keyed by SHA-256 of the request content for deterministic matching.

---

### Section: Graceful Shutdown

Coordinated resource cleanup on application termination:

```swift
let registry = ShutdownRegistry()
await registry.register(name: "mcp") { await mcpManager.disconnectAll() }
await registry.register(name: "plugins") { await pluginManager.deactivateAll() }
SignalHandler.install(registry: registry)
```

Handlers run in reverse registration order (LIFO). Signal handlers for SIGINT and SIGTERM are installed via `DispatchSource`.

---

## Implementation Notes for Generator

- Conversation Recovery section must include all three violation types, both the protocol and default strategy, and the hook event
- All sections use the same DocC format: prose + code + table (where applicable)
- Cross-reference `<doc:AgentHarnessGuide>` when mentioning hooks or streaming
- Denial Tracking is a full section (not just part of Permissions) — it was missing from the previous version

# Spec: Core Trait

**Trait guard:** `#if Core` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/AgentRuntime.swift`
- `Sources/SwiftSynapseHarness/ObservableTranscript+Harness.swift`
- `Sources/SwiftSynapseHarness/AgentToolProtocol.swift`
- `Sources/SwiftSynapseHarness/ToolRegistry.swift`
- `Sources/SwiftSynapseHarness/AgentToolLoop.swift`
- `Sources/SwiftSynapseHarness/StreamingToolExecutor.swift`
- `Sources/SwiftSynapseHarness/AgentLLMClient.swift`
- `Sources/SwiftSynapseHarness/AgentConfiguration.swift`
- `Sources/SwiftSynapseHarness/ContextBudget.swift`
- `Sources/SwiftSynapseHarness/RetryWithBackoff.swift`
- `Sources/SwiftSynapseHarness/ToolProgress.swift`
- `Sources/SwiftSynapseHarness/ConfigurationHierarchy.swift`
- `Sources/SwiftSynapseHarness/Caching.swift`
- `Sources/SwiftSynapseHarness/ResultTruncation.swift`
- `Sources/SwiftSynapseHarness/SystemPromptBuilder.swift`
- `Sources/SwiftSynapseHarness/TestFixtures.swift`
- `Sources/SwiftSynapseHarness/GracefulShutdown.swift`

## Overview

The Core trait is the foundation every other trait builds on. It provides the complete tool dispatch loop, LLM client abstraction, configuration, context budget tracking, and all operational utilities needed to run a working agent. All other traits add optional subsystems on top of Core.

Core files that reference cross-trait types (AgentToolLoop, StreamingToolExecutor, ToolRegistry, AgentRuntime) use `#if TraitName` blocks inside method bodies where possible. Parameter-level cross-trait types are handled by stubs in `TraitStubs.swift`. See `Traits.md` for the full stub inventory.

---

## AgentRuntime

Runtime bridge between macro-generated `run(goal:)` and user-implemented `execute(goal:)`.

### AgentLifecycleError
- `.emptyGoal` — goal string was empty
- `.blockedByHook(reason:)` — a hook blocked agent startup

### AgentExecutable Protocol
Protocol that `@SpecDrivenAgent` actors implicitly conform to:
- `var _status: AgentStatus { get set }`
- `var _transcript: ObservableTranscript { get set }`
- `func execute(goal: String) async throws -> String`

### agentRun() Function
`public func agentRun<A: AgentExecutable>(agent:goal:hooks:telemetry:sessionStore:sessionAgentType:)`

**Parameters:** `agent: isolated A`, `goal: String`, `hooks: AgentHookPipeline? = nil`, `telemetry: (any TelemetrySink)? = nil`, `sessionStore: (any SessionStore)? = nil`, `sessionAgentType: String? = nil`

**Lifecycle:**
1. Validate — empty goal throws `.emptyGoal`
2. Start — set status to `.running`, reset transcript, fire `.agentStarted` hook, emit telemetry
3. Execute — call `agent.execute(goal:)` with cancellation handler
4. Complete — set status to `.completed`, fire `.agentCompleted` hook, emit telemetry
5. Error paths — `.paused` on cancellation, `.error` on failure, auto-save session on both

### ObservableTranscript+Harness Extension
- `restore(from codableEntries: [CodableTranscriptEntry])` — restores transcript from session entries

---

## AgentToolProtocol

Typed, self-describing tool interface.

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

**Internal — `AnyAgentTool`:** Type-erased wrapper for heterogeneous storage. Handles JSON decode of input, execution, JSON encode of output. String outputs bypass JSON encoding to avoid double-quoting. Detects `ProgressReportingTool` conformance and forwards delegate.

**Types:** `ToolResult` (callId, name, output, duration, success), `ToolDispatchError` (unknownTool, loopExceeded, decodingFailed, encodingFailed, blockedByHook, permissionDenied)

---

## ToolRegistry

Thread-safe registry using `NSLock`. Register at init, dispatch by name at runtime.

- `register<T: AgentToolProtocol>(_:)` — stores as `AnyAgentTool`
- `dispatch(name:callId:arguments:progressDelegate:)` — single tool execution with permission check
- `dispatchBatch(_:progressDelegate:)` — concurrency-safe tools run in `TaskGroup`; unsafe run sequentially
- `definitions() -> [FunctionToolParam]` — returns definitions for LLM request
- `permissionGate` — optional `PermissionGate` checked before each dispatch

---

## AgentToolLoop

The reusable tool dispatch loop. Two variants:

### `run()` (non-streaming)
Parameters: client, config, goal, tools, transcript, systemPrompt, maxIterations, hooks, telemetry, budget (inout), compressor, recovery, guardrails, progressDelegate, compactionTrigger, rateLimitState.

Flow per iteration:
1. Check cancellation
2. Check compaction trigger → compress if needed
3. Build `AgentRequest`
4. Fire `.llmRequestSent` hook (can block/modify)
5. Send with `retryWithBackoff`; on failure attempt recovery
6. Track tokens in budget
7. Fire `.llmResponseReceived` hook
8. If no tool calls → check output guardrails → return result
9. Fire `.preToolUse` hook (can block)
10. Check argument guardrails per tool call
11. Dispatch tools via registry (with progress delegate)
12. Emit per-tool telemetry
13. Record results in transcript
14. Fire `.postToolUse` hook
15. Check budget exhaustion

### `runStreaming()` (stream-aware)
Same loop but uses `StreamingToolExecutor` to dispatch concurrency-safe tools as definitions complete in the LLM stream. Text deltas forwarded to transcript streaming state.

---

## StreamingToolExecutor

Manages concurrent tool execution during streaming responses.

- Concurrency-safe tools start immediately as call definitions arrive in the stream
- Unsafe tools queued and dispatched sequentially after all safe tools finish
- `enqueue(_ toolCall:)` — submit a tool call as it arrives
- `awaitAll() -> [ToolResult]` — wait for all enqueued tools to complete
- `hasTools: Bool` — whether any tools have been enqueued

---

## AgentLLMClient

Backend-agnostic LLM abstraction:

- `AgentLLMClient` protocol: `send(_:)`, `stream(_:)`, `streamEvents(_:)`
- `AgentRequest`: model, userPrompt, systemPrompt, tools, timeoutSeconds, previousResponseId, maxTokens
- `AgentResponse`: text, toolCalls, responseId, inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens
- `AgentStreamEvent`: `.textDelta(String)`, `.toolCall(AgentToolCall)`, `.responseComplete(id, inputTokens, outputTokens)`
- `CloudLLMClient` actor: wraps SwiftOpenResponsesDSL
- `HybridLLMClient` actor: Foundation Models on-device first, cloud fallback
- `AgentConfiguration.buildClient()` / `buildLLMClient()` extensions

---

## AgentConfiguration

Centralized configuration with environment resolution:

```swift
public struct AgentConfiguration: Codable, Sendable {
    executionMode: ExecutionMode  // .onDevice, .cloud, .hybrid
    serverURL: String?
    modelName: String
    apiKey: String?
    timeoutSeconds: Int           // default: 300
    maxRetries: Int               // default: 3
    toolResultBudgetTokens: Int   // default: 4096
}
```

- `fromEnvironment(overrides:)` — resolves from `SWIFTSYNAPSE_*` env vars
- `Overrides` struct for caller-supplied values
- `AgentConfigurationError`: `.invalidServerURL`, `.emptyModelName`, `.invalidTimeout`, `.invalidMaxRetries`
- Validation: URL format, non-empty model, positive timeout, retries 1–10

---

## ContextBudget

Token budget tracking with compaction trigger support:

- `ContextBudget`: maxTokens, usedTokens, remaining, isExhausted, utilizationPercentage, `record()`, `reset()`
- `TranscriptCompressor` protocol: `compress(entries:budget:) -> [TranscriptEntry]`
- `SlidingWindowCompressor`: keeps last N entries + one-line summary of dropped entries
- `CompactionTrigger` enum: `.threshold(Double)`, `.tokenCount(Int)`, `.entryCount(Int)`, `.manual`. Method: `shouldCompact(budget:entryCount:) -> Bool`

---

## RetryWithBackoff

Exponential backoff for transient failures:

- `retryWithBackoff(maxAttempts:isRetryable:onRetry:operation:)` — base delay 500ms, doubles per attempt, jitter applied
- `isTransportRetryable(_ error:)` — default predicate for URLError network failures

---

## ToolProgress

Real-time feedback during long-running tool execution:

- `ToolProgressDelegate` protocol: `reportProgress(_: ToolProgressUpdate) async`
- `ProgressReportingTool` protocol: refines `AgentToolProtocol` with `execute(input:callId:progress:)`. Default bridges to standard `execute(input:)`.
- **Integration:** `AnyAgentTool` detects conformance and forwards delegate. `ToolRegistry.dispatch()` and `dispatchBatch()` accept optional `progressDelegate`. `AgentToolLoop.run()` threads delegate through.
- **UI binding:** `ObservableTranscript.toolProgress: [String: ToolProgressUpdate]` — active progress keyed by callId, with `updateToolProgress(_:)` and `clearToolProgress(callId:)`.

---

## ConfigurationHierarchy

7-level priority configuration for enterprise deployments:

- `ConfigurationPriority` enum: `.environment(1)` < `.remoteConfig(2)` < `.mdmPolicy(3)` < `.userFile(4)` < `.projectFile(5)` < `.localFile(6)` < `.cliArguments(7)`
- `ConfigurationSource` protocol: `priority`, `load() async throws -> [String: String]`
- **Built-in sources:** `EnvironmentConfigSource` (reads `SWIFTSYNAPSE_*` env vars), `FileConfigSource` (JSON files; statics `.userDefault`, `.projectDefault`), `MDMConfigSource` (macOS managed domain)
- `ConfigurationResolver` actor: merges sources by priority, `resolve()`, `resolveConfiguration(overrides:)`, cached with `invalidate()`

---

## Caching

Generic LRU/FIFO cache with TTL for tool results:

- `CachePolicy`: maxEntries (default 100), TTL (default 5 min), eviction strategy
- `EvictionStrategy` enum: `.lru`, `.fifo`
- `Cache<Key: Hashable & Sendable, Value: Sendable>` actor: `get()` checks TTL, `set()` evicts at capacity
- `ToolResultCache` actor: wraps `Cache<String, String>`, keyed by `toolName:argsHash`. Methods: `get(toolName:arguments:)`, `set(...)`, `invalidate(...)`, `clear()`

---

## ResultTruncation

Graceful handling of oversized tool results:

- `TruncationPolicy`: `maxCharacters` (default 16384), `preserveLastCharacters` (default 200). `fromConfig(_:)` uses `toolResultBudgetTokens * 4`.
- `ResultTruncator` enum: static `truncate(_:policy:)` — returns original if under limit, otherwise `[Truncated: N chars total, showing last M]\n...\nsuffix`. `truncatePath(_:maxLength:)` for path display.
- **Integration:** applied in `AgentToolLoop.run()` after tool dispatch, before appending to transcript.

---

## SystemPromptBuilder

Composable, prioritized system prompt construction:

- `SystemPromptSection`: id, content, priority (ordering), cacheable flag
- `SystemPromptProvider` protocol: `systemPromptSections() -> [SystemPromptSection]`
- `SystemPromptBuilder` actor: `addSection()`, `addDynamicSection(resolver:)`, `addProvider()`, `removeSection(id:)`, `build() -> String`, `buildWithCacheBoundaries() -> [(content, cacheable)]`, `clear()`

---

## VCR Testing Utilities (TestFixtures)

Deterministic agent testing via request/response recording and replay:

- `FixtureMode` enum: `.record`, `.replay`, `.passthrough`
- `FixtureStore` protocol: `save(key:response:)`, `load(key:) -> Data?`
- `FileFixtureStore` actor: JSON fixtures in configurable directory
- `VCRClient` actor: conforms to `AgentLLMClient`. Records/replays by SHA-256 hash of (model + prompt + tools). In `.record` mode, forwards to real client and saves. In `.replay` mode, loads from store.
- `VCRError` enum: `.fixtureNotFound(key:)`

---

## GracefulShutdown

Coordinated resource cleanup on application termination:

- `ShutdownHandler` protocol: `cleanup() async`
- `ShutdownRegistry` actor: `register(_:name:)`, `register(name:cleanup:)` (closure), `shutdownAll()` (LIFO, idempotent), `isShuttingDown`, `handlerCount`
- `SignalHandler` class: `install(signals:registry:)` — installs POSIX signal handlers (SIGINT, SIGTERM) via `DispatchSource`

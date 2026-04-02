# Spec: Observability Trait

**Trait guard:** `#if Observability` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/Telemetry.swift`
- `Sources/SwiftSynapseHarness/TelemetrySinks.swift`
- `Sources/SwiftSynapseHarness/CostTracking.swift`

## Overview

The Observability trait provides structured event emission, pluggable telemetry sinks, and per-session cost accumulation. Included in the default `Production` trait.

Stubs in `TraitStubs.swift` provide a no-op `TelemetrySink` protocol (nobody conforms) when this trait is disabled, allowing Core files that accept `(any TelemetrySink)?` parameters to compile.

---

## Telemetry

### TelemetryEvent
- `timestamp: Date`, `kind: TelemetryEventKind`, `agentType: String`, `sessionId: String?`

### TelemetryEventKind (12 kinds)
| Kind | Payload |
|------|---------|
| `agentStarted` | goal |
| `agentCompleted` | duration |
| `agentFailed` | error description |
| `llmCallMade` | model, inputTokens, outputTokens, cacheCreationTokens, cacheReadTokens, duration |
| `toolCalled` | name, duration, success |
| `retryAttempted` | attempt number, error |
| `tokenBudgetExhausted` | usedTokens, maxTokens |
| `guardrailTriggered` | policy name, risk level |
| `contextCompacted` | entriesBefore, entriesAfter |
| `pluginActivated` | plugin name |
| `pluginError` | plugin name, error |
| `apiErrorClassified` | category, model |

### TelemetrySink Protocol
```swift
public protocol TelemetrySink: Sendable {
    func emit(_ event: TelemetryEvent) async
}
```

### TokenUsageTracker
`actor TokenUsageTracker`: cumulative token tracking across calls. `record(inputTokens:outputTokens:)`, `totalInputTokens`, `totalOutputTokens`, `reset()`.

---

## TelemetrySinks

### OSLogTelemetrySink
Emits events to unified logging (os.Logger). Category: `"SwiftSynapseHarness"`.

### InMemoryTelemetrySink
`actor InMemoryTelemetrySink`: accumulates events in memory for test assertions.
- `events: [TelemetryEvent]` — all emitted events
- `reset()` — clears accumulated events

### CompositeTelemetrySink
Fans out to multiple sinks:
```swift
let telemetry = CompositeTelemetrySink([
    OSLogTelemetrySink(),
    InMemoryTelemetrySink()
])
```

---

## CostTracking

Per-session cost accumulation across all LLM calls with per-model pricing:

- `ModelPricing`: inputCostPerMillionTokens, outputCostPerMillionTokens, cacheCreationCostPerMillionTokens, cacheReadCostPerMillionTokens. Method: `cost(inputTokens:outputTokens:cacheCreationTokens:cacheReadTokens:) -> Decimal`
- `CostRecord`: single LLM call (model, tokens, cost, apiDuration, timestamp)
- `ModelUsage`: aggregated per-model summary (total tokens, cost, call count)
- `CostTracker` actor: `setPricing(for:pricing:)`, `record(model:inputTokens:outputTokens:...)`, `totalCost()`, `totalAPIDuration()`, `usageByModel()`, `allRecords()`, `reset()`
- `CostTrackingTelemetrySink`: conforms to `TelemetrySink`, listens for `.llmCallMade` events and delegates to `CostTracker`. Zero changes to `AgentToolLoop`.

# Spec: Observability Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/ObservabilityTests.swift`

**Sources under test:** `Telemetry.swift`, `TelemetrySinks.swift`, `CostTracking.swift`

## Generation Rules

Same as `CoreTests.md`: Swift Testing, top-level `@Test` functions, `#expect()`, `async throws`.

## Test Functions

### InMemoryTelemetrySink

| Test | Verifies |
|------|---------|
| `inMemorySinkAccumulatesEvents` | After emitting 3 events, `sink.events.count == 3` |
| `inMemorySinkResetClearsEvents` | `reset()` empties accumulated events |
| `inMemorySinkContainsExpectedKind` | Emitting `.agentStarted` → `events.contains { $0.kind == .agentStarted }` |

### CompositeTelemetrySink

| Test | Verifies |
|------|---------|
| `compositeSinkFansOutToAll` | `CompositeTelemetrySink([sinkA, sinkB])` → both receive the emitted event |

### CostTracker

| Test | Verifies |
|------|---------|
| `costTrackerAccumulatesCost` | After `record(model:inputTokens:100:outputTokens:50:...)` with pricing set, `totalCost() > 0` |
| `costTrackerUsageByModel` | Two records for same model → `usageByModel()` returns 1 entry with combined tokens |
| `costTrackerResetClearsAll` | `reset()` → `totalCost() == 0` and `allRecords().isEmpty` |

### CostTrackingTelemetrySink

| Test | Verifies |
|------|---------|
| `costTrackingSinkRecordsOnLLMCallMade` | Emitting `.llmCallMade(model:inputTokens:outputTokens:...)` → `CostTracker.allRecords().count == 1` |
| `costTrackingSinkIgnoresOtherEvents` | Emitting `.agentStarted` → `CostTracker.allRecords().isEmpty` |

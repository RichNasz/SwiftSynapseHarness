# Spec: Persistence Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/PersistenceTests.swift`

**Sources under test:** `AgentSession.swift`, `SessionPersistence.swift`, `AgentMemory.swift`, `ObservableTranscript+Harness.swift`

## Generation Rules

Same as `CoreTests.md`: Swift Testing, top-level `@Test` functions, `#expect()`, `async throws`.

## Test Functions

### CodableTranscriptEntry / AgentSession

| Test | Verifies |
|------|---------|
| `codableTranscriptEntryUserMessageRoundTrips` | `CodableTranscriptEntry.userMessage("Hello")` encodes/decodes back to `.userMessage("Hello")` |
| `codableTranscriptEntryAssistantMessageRoundTrips` | `.assistantMessage("Reply")` Codable round-trip |
| `codableTranscriptEntryToolCallRoundTrips` | `.toolCall(name: "echo", arguments: "{}")` Codable round-trip |
| `codableTranscriptEntryToolResultRoundTrips` | `.toolResult(name: "echo", result: "hi")` Codable round-trip |
| `codableTranscriptEntryErrorRoundTrips` | `.error("Something failed")` Codable round-trip |
| `codableTranscriptEntryToTranscriptEntry` | `.userMessage("hi").toTranscriptEntry()` returns `.userMessage("hi")` |
| `agentSessionEncodesAndDecodes` | `AgentSession` with known fields encodes to JSON and decodes with matching fields |
| `agentSessionPreservesTranscriptEntries` | Session with 3 entries → decoded session has 3 entries |

### ObservableTranscript+Harness

| Test | Verifies |
|------|---------|
| `observableTranscriptRestoreFromCodable` | `restore(from: [.userMessage("A"), .assistantMessage("B")])` → `entries.count == 2` |

### MemoryEntry

| Test | Verifies |
|------|---------|
| `memoryEntryEncodesAndDecodes` | `MemoryEntry` with known fields Codable round-trips with matching fields |
| `memoryEntryCategoryCustomRoundTrips` | `.custom("myCategory")` Codable round-trip preserves the custom string |

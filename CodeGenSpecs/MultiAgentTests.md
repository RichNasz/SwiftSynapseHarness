# Spec: MultiAgent Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/MultiAgentTests.swift`

**Sources under test:** `SubagentContext.swift`, `AgentCoordination.swift`

## Generation Rules

Same as `CoreTests.md`: Swift Testing, top-level `@Test` functions, `#expect()`, `async throws`.

## Test Functions

### TeamMemory

| Test | Verifies |
|------|---------|
| `teamMemorySetAndGet` | `set("key", "value")` → `get("key") == "value"` |
| `teamMemoryGetMissingReturnsNil` | `get("nonexistent")` returns `nil` |
| `teamMemoryRemoveDeletesKey` | `set("k", "v")` then `remove("k")` → `get("k")` returns `nil` |
| `teamMemoryAllReturnsAllEntries` | After setting 3 keys, `all().count == 3` |
| `teamMemoryClearRemovesAll` | `clear()` → `all().isEmpty` |

### SharedMailbox

| Test | Verifies |
|------|---------|
| `sharedMailboxSendAndReceive` | `send(to: "agent", message: "hello")` → `receive(for: "agent")` first value is `"hello"` |

### CoordinationRunner

| Test | Verifies |
|------|---------|
| `coordinationRunnerDetectsUnknownDependency` | Phase with `dependencies: ["nonexistent"]` → `CoordinationError.unknownDependency` |
| `coordinationRunnerDetectsCyclicDependency` | Phase A depends on B, phase B depends on A → `CoordinationError.cyclicDependency` |

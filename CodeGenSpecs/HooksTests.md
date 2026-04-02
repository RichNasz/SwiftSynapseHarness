# Spec: Hooks Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/HooksTests.swift`

**Sources under test:** `AgentHook.swift`, `AgentHookPipeline.swift`

## Generation Rules

Same as `CoreTests.md`: Swift Testing, top-level `@Test` functions, `#expect()`, `async throws`.

## Test Functions

| Test | Verifies |
|------|---------|
| `hookPipelineFiresSubscribedHook` | `ClosureHook(on: [.agentStarted])` receives `.agentStarted` event |
| `hookPipelineSkipsUnsubscribedHook` | Hook subscribed to `.agentCompleted` not called when `.agentStarted` fires |
| `hookPipelineBlockActionReturned` | Hook returning `.block(reason:)` → `fire()` returns `.block` |
| `hookPipelineFirstBlockWins` | Two hooks: first returns `.block`, second never called (call counter stays 0) |
| `hookPipelineProceedContinuesToNextHook` | Two subscribed hooks, both `.proceed` → both called (call counter == 2) |
| `hookPipelineModifyActionPropagates` | Hook returning `.modify("replacement")` → `fire()` returns `.modify("replacement")` |
| `hookPipelineEmptyPipelineProceed` | `AgentHookPipeline` with no hooks → `fire(.agentStarted)` returns `.proceed` |
| `closureHookSubscribedToMultipleEvents` | `ClosureHook(on: [.preToolUse, .postToolUse])` called for both event kinds |

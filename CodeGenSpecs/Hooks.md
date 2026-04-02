# Spec: Hooks Trait

**Trait guard:** `#if Hooks` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/AgentHook.swift`
- `Sources/SwiftSynapseHarness/AgentHookPipeline.swift`

## Overview

The Hooks trait provides an event interception system covering all 16 agent lifecycle events. Hooks can observe, modify, or block operations without modifying agent code. Included in the default `Production` trait.

Stubs in `TraitStubs.swift` provide no-op `AgentHookPipeline.fire() → .proceed` and no-op `add()` when this trait is disabled, allowing Core files (AgentToolLoop, AgentRuntime) to compile without Hooks.

---

## AgentHook Protocol

```swift
public protocol AgentHook: Sendable {
    var subscribedEvents: Set<AgentHookEventKind> { get }
    func handle(_ event: AgentHookEvent) async -> HookAction
}
```

### AgentHookEvent (16 kinds)

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

### HookAction
- `.proceed` — continue normally
- `.modify(String)` — replace input/output with provided string
- `.block(reason: String)` — abort the operation with a reason

### ClosureHook
Convenience closure-based hook for quick setup:
```swift
ClosureHook(on: [.preToolUse, .postToolUse]) { event in
    return .proceed
}
```

---

## AgentHookPipeline

`actor AgentHookPipeline`:

- `add(_ hook: any AgentHook)` — appends hook to pipeline
- `fire(_ event: AgentHookEvent) async -> HookAction` — evaluates all subscribed hooks in registration order; returns on first `.block` (first-block-wins semantics)

When no hooks are registered, `fire()` returns `.proceed` immediately.

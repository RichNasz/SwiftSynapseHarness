# Spec: Agent Runtime

**Generates:**
- `Sources/SwiftSynapseHarness/AgentRuntime.swift`
- `Sources/SwiftSynapseHarness/ObservableTranscript+Harness.swift`

## Overview

The runtime bridge between macro-generated `run(goal:)` and user-implemented `execute(goal:)`. Handles lifecycle status transitions, transcript management, hook firing, telemetry emission, session persistence, and cancellation.

## Trait Guard

All generated files are wrapped in `#if Core` / `#endif`. Internal references to cross-trait types (Hooks, Observability, Persistence) use `#if TraitName` blocks inside method bodies where possible. Parameter-level cross-trait types are handled by stubs in `TraitStubs.swift`.

---

## AgentLifecycleError

Error enum for agent lifecycle failures:
- `.emptyGoal` — goal string was empty
- `.blockedByHook(reason:)` — a hook blocked agent startup

---

## AgentExecutable Protocol

Protocol that `@SpecDrivenAgent` actors implicitly conform to:
- `var _status: AgentStatus { get set }` — mutable status backing store
- `var _transcript: ObservableTranscript { get set }` — mutable transcript backing store
- `func execute(goal: String) async throws -> String` — user-implemented domain logic

---

## agentRun() Function

Public generic function `agentRun<A: AgentExecutable>`:

**Parameters:**
- `agent: isolated A` — the agent actor
- `goal: String` — the goal to execute
- `hooks: AgentHookPipeline? = nil` — optional hook pipeline
- `telemetry: (any TelemetrySink)? = nil` — optional telemetry sink
- `sessionStore: (any SessionStore)? = nil` — optional session persistence
- `sessionAgentType: String? = nil` — agent type identifier for sessions

**Lifecycle:**
1. Validate — empty goal throws `.emptyGoal`
2. Start — set status to `.running`, reset transcript, fire `.agentStarted` hook, emit telemetry
3. Execute — call `agent.execute(goal:)` with cancellation handler
4. Complete — set status to `.completed`, fire `.agentCompleted` hook, emit telemetry
5. Error paths — `.paused` on cancellation, `.error` on failure, auto-save session on both

---

## ObservableTranscript+Harness Extension

Extension on `ObservableTranscript` providing:
- `restore(from codableEntries: [CodableTranscriptEntry])` — restores transcript from codable session entries

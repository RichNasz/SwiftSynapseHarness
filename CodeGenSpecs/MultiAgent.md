# Spec: MultiAgent Trait

**Trait guard:** `#if MultiAgent` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/AgentCoordination.swift`
- `Sources/SwiftSynapseHarness/SubagentContext.swift`

## Overview

The MultiAgent trait provides dependency-aware multi-agent workflow execution and subagent spawning. Not included in the default `Production` trait — requires explicit opt-in via `traits: ["Production", "MultiAgent"]` or `traits: ["Advanced"]`.

---

## SubagentContext

Subagent spawning with lifecycle control:

- `SubagentContext`: inherited config, tools, hooks, telemetry, lifecycle mode, system prompt, max iterations
- `SubagentLifecycleMode` enum: `.independent` (own task, not cancelled with parent), `.shared` (parent cancellation propagates)
- `SubagentResult`: output, transcript, duration, success

### SubagentRunner
- `SubagentRunner.run(agentFactory:goal:context:)` — spawns a single child agent
- `SubagentRunner.runParallel(agents:context:)` — spawns multiple children in `TaskGroup`, results returned in input order

```swift
// Single child
let summary = try await SubagentRunner.run(
    agentFactory: { config in try SummaryAgent(configuration: config) },
    goal: "Summarize this document",
    context: SubagentContext(config: parentConfig, lifecycleMode: .shared)
)

// Parallel children
let results = try await SubagentRunner.runParallel(
    agents: [
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research topic A"),
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research topic B"),
    ],
    context: SubagentContext(config: config, lifecycleMode: .shared)
)
```

---

## AgentCoordination

Dependency-aware multi-agent workflow execution with shared state:

### SharedMailbox
`actor SharedMailbox`: cross-agent async message passing.
- `send(to:message:)` — queue message for a named agent
- `receive(for:) -> AsyncStream<String>` — stream messages for a named agent
- `closeAll()` — terminates all streams

### TeamMemory
`actor TeamMemory`: shared key-value store visible to all agents in a coordination.
- `set(_ key:value:)`, `get(_ key:) -> String?`, `remove(_ key:)`, `all() -> [String: String]`, `clear()`

### CoordinationPhase
```swift
CoordinationPhase(
    name: "research",
    goal: "Research the market opportunity",
    dependencies: [],  // phases whose results must be available before this one runs
    agentFactory: { try ResearchAgent(configuration: $0) }
)
```

### CoordinationRunner
`CoordinationRunner.run(phases:config:)` — executes phases in dependency-ordered waves. Phases with all dependencies satisfied run in parallel. Phase results stored in `TeamMemory` for downstream access.

- `CoordinationResult`: phaseResults (keyed by name), total duration
- `CoordinationError`: `.unknownDependency(phase:dependency:)`, `.cyclicDependency(phases:)`
- **Hook events:** `.coordinationPhaseStarted(phase:)`, `.coordinationPhaseCompleted(phase:)`

### DAG Example
```swift
let phases = [
    CoordinationPhase(name: "research", goal: "Research market", agentFactory: { try ResearchAgent(configuration: $0) }),
    CoordinationPhase(name: "draft", goal: "Draft proposal", dependencies: ["research"], agentFactory: { try WritingAgent(configuration: $0) }),
    CoordinationPhase(name: "review", goal: "Review proposal", dependencies: ["draft"], agentFactory: { try ReviewAgent(configuration: $0) }),
]
let result = try await CoordinationRunner.run(phases: phases, config: config)
```

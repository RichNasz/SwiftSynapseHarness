# How to Coordinate Multiple Agents

Run child agents, build dependency-aware pipelines, and share state between agents.

## Overview

SwiftSynapseHarness provides three levels of multi-agent coordination: single child agents via ``SubagentRunner``, parallel fan-out via `runParallel`, and dependency-ordered DAG execution via ``CoordinationRunner``. Agents communicate through ``SharedMailbox`` for async messaging and ``TeamMemory`` for shared results.

## Step 1: Run a Single Child Agent

``SubagentRunner/run(agentFactory:goal:context:)`` spawns a child agent with inherited configuration. The factory receives the parent's `AgentConfiguration`, so the child uses the same model and settings:

```swift
let summary = try await SubagentRunner.run(
    agentFactory: { config in try SummaryAgent(configuration: config) },
    goal: "Summarize this document: \(documentText)",
    context: SubagentContext(config: parentConfig, lifecycleMode: .shared)
)
```

**Lifecycle modes:**
- `.shared` — parent cancellation propagates to the child. Use this for tightly coupled work.
- `.independent` — child runs in its own `Task`. Use this for fire-and-forget work that should survive parent cancellation.

## Step 2: Run Agents in Parallel

`SubagentRunner.runParallel()` fans out to multiple child agents concurrently and collects all results:

```swift
let results = try await SubagentRunner.runParallel(
    agents: [
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research Swift concurrency"),
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research async/await"),
        (factory: { try ResearchAgent(configuration: $0) }, goal: "Research Swift actors"),
    ],
    context: SubagentContext(config: config, lifecycleMode: .shared)
)

// results[0] = Swift concurrency research
// results[1] = async/await research
// results[2] = actors research
```

All agents run concurrently via `TaskGroup`. The call returns when all agents complete (or throws if any fails).

## Step 3: Build a DAG Workflow with CoordinationRunner

``CoordinationRunner`` executes phases in dependency order. Phases with no unmet dependencies run in parallel; phases with dependencies wait for their prerequisites:

```swift
let phases = [
    CoordinationPhase(
        name: "research",
        goal: "Research the target market",
        agentFactory: { try ResearchAgent(configuration: $0) }
    ),
    CoordinationPhase(
        name: "financial",
        goal: "Analyze financial projections",
        agentFactory: { try FinancialAgent(configuration: $0) }
    ),
    CoordinationPhase(
        name: "draft",
        goal: "Draft a business proposal incorporating research and financials",
        dependencies: ["research", "financial"],  // Waits for both
        agentFactory: { try WritingAgent(configuration: $0) }
    ),
    CoordinationPhase(
        name: "review",
        goal: "Review and refine the proposal",
        dependencies: ["draft"],
        agentFactory: { try ReviewAgent(configuration: $0) }
    ),
]

let result = try await CoordinationRunner.run(phases: phases, config: config)
```

In this example, `research` and `financial` run in parallel. `draft` starts when both complete. `review` starts when `draft` completes.

The runner validates the graph before execution — `CoordinationError.unknownDependency` for missing phase names, `CoordinationError.cyclicDependency` for circular references.

## Step 4: Access Phase Results via TeamMemory

``TeamMemory`` stores each completed phase's output as a key-value pair. Downstream phases can read upstream results via the ``PluginContext`` or by passing `TeamMemory` explicitly:

```swift
// Within a downstream phase's agent:
let researchResult = await teamMemory.get(key: "research")
let financialResult = await teamMemory.get(key: "financial")
```

All phase results are automatically stored in `TeamMemory` by `CoordinationRunner` after each phase completes.

## Step 5: Pass Messages Between Concurrent Agents

``SharedMailbox`` enables async message passing between agents that run concurrently (e.g., in `runParallel`):

```swift
let mailbox = SharedMailbox(name: "insights-channel")

// In agent A (producer):
await mailbox.send("Discovered insight: \(insight)")

// In agent B (consumer):
for await message in mailbox.messages {
    print("Received: \(message)")
}
```

`SharedMailbox` is an actor — safe to use from multiple concurrent agents. Close the mailbox when the producer is done to signal completion to consumers.

## See Also

- <doc:AgentHarnessGuide> — ``SubagentRunner``, ``SubagentContext``
- <doc:ProductionGuide> — ``CoordinationRunner``, ``TeamMemory``, ``SharedMailbox``
- <doc:HowToGoToProduction> — production deployment for multi-agent workflows

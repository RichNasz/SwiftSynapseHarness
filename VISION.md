# SwiftSynapseHarness Vision

## Overview

SwiftSynapseHarness is the production-grade agent runtime for the SwiftSynapse ecosystem. It provides everything that sits between `@SpecDrivenAgent`'s `execute(goal:)` and a deployed agent: tool loop, hooks, permissions, streaming, recovery strategies, and a full suite of production capabilities. SwiftSynapseHarness depends on SwiftSynapseMacros and re-exports it, so a single `import SwiftSynapseHarness` provides macros, core types, and the full runtime.

## Core Goals

1. **Typed Tool Execution** — `ToolRegistry` and `AgentToolProtocol` provide a compile-time-safe, actor-isolated tool system with batch dispatch, streaming, and result caching.
2. **Hook-Driven Observability** — `AgentHookPipeline` with 16 event types makes every agent action auditable, interceptable, and extensible without modifying core logic.
3. **Permission & Safety** — `PermissionGate` and `ToolListPolicy` enforce policy-driven access control, with human-in-the-loop approval and denial tracking built in.
4. **Production Readiness** — Session persistence, guardrails, MCP integration, multi-agent coordination, cost tracking, rate limiting, graceful shutdown, and VCR testing make agents deployable in real business environments.

## Non-Negotiables

- **Swift 6.2+** — Uses modern Swift concurrency, actors, and structured concurrency throughout.
- **Spec-Driven** — All `.swift` files are generated from specs in `CodeGenSpecs/`. Generated files are never manually edited.
- **No Manual Edits** — Every generated file carries a header comment pointing to its source spec.
- **Actor Isolation** — All mutable agent state is actor-isolated; the runtime is designed for safe concurrent use.

## Dependencies

| Package | Purpose |
|---------|---------|
| `SwiftSynapseMacros` (branch: main) | Macros (`@SpecDrivenAgent`, etc.) and core types (`AgentStatus`, `ObservableTranscript`, etc.) — re-exported |
| `SwiftOpenSkills` (branch: main) | Skills framework integration |

## Platforms

- macOS 26+
- iOS 26+
- visionOS 2+

## Package Structure

```
SwiftSynapseHarness/     # Main target: runtime, tools, hooks, permissions, LLM, production features
SwiftSynapseUI/          # UI target: SwiftUI views and protocols for agent status binding
Tests/                   # Swift Testing test suite
CodeGenSpecs/            # Spec files (source of truth for all generated .swift files)
```

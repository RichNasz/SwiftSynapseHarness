# SwiftSynapseHarness

## Project Overview

SwiftSynapseHarness is the production-grade agent harness for the SwiftSynapse ecosystem. It provides the full orchestration layer between `execute(goal:)` and a deployed agent: tool system, hooks, permissions, streaming, recovery, MCP, multi-agent coordination, and production capabilities.

Re-exports `SwiftSynapseMacrosClient` so users only need `import SwiftSynapseHarness`.

## Commands

- **Build**: `swift build`
- **Clean**: `swift package clean`

## Architecture

### Two Products, Two Targets

- **SwiftSynapseHarness** — core harness library (no SwiftUI dependency)
- **SwiftSynapseUI** — SwiftUI + AppIntents views for any `ObservableAgent` (separate product/target)

### File Categories

| Category | Files | Purpose |
|----------|-------|---------|
| Runtime | `AgentRuntime.swift`, `ObservableTranscript+Harness.swift` | `agentRun()` lifecycle, transcript extension |
| Tool System | `AgentToolProtocol.swift`, `ToolRegistry.swift`, `AgentToolLoop.swift`, `StreamingToolExecutor.swift`, `ToolProgress.swift` | Typed tools, dispatch, streaming, progress |
| Hooks | `AgentHook.swift`, `AgentHookPipeline.swift` | 16 event types, closure/protocol hooks |
| Permissions | `Permission.swift`, `ToolListPolicy.swift`, `DenialTracking.swift` | Policy-driven access, adaptive denial |
| LLM | `AgentLLMClient.swift`, `AgentConfiguration.swift` | Client protocol, configuration, execution modes |
| Session | `AgentSession.swift`, `SessionPersistence.swift` | Session snapshots, file-based persistence |
| Recovery | `RecoveryStrategy.swift`, `RetryWithBackoff.swift`, `ContextBudget.swift` | Compaction, escalation, retry |
| Telemetry | `Telemetry.swift`, `TelemetrySinks.swift` | Event emission, OSLog/InMemory/Cost sinks |
| Subagents | `SubagentContext.swift` | Subagent spawning with lifecycle modes |
| Production | `Guardrails.swift`, `MCP.swift`, `ContextCompression.swift`, `ConfigurationHierarchy.swift`, `Caching.swift`, `AgentCoordination.swift`, `PluginSystem.swift` | Full production capabilities |
| Polish | `CostTracking.swift`, `ErrorClassification.swift`, `ResultTruncation.swift`, `RateLimiting.swift`, `SystemPromptBuilder.swift`, `TestFixtures.swift`, `GracefulShutdown.swift`, `AgentMemory.swift`, `ConversationRecovery.swift` | Operational polish |
| Skills | `SkillsSupport.swift` | SwiftOpenSkills integration |
| LLM Tool Macros | `LLMToolSupport.swift` | `@LLMTool` / `AgentLLMTool` bridge to `AgentToolProtocol` |
| Exports | `Exports.swift` | `@_exported import SwiftSynapseMacrosClient` |

### SwiftSynapseUI Files (`Sources/SwiftSynapseUI/`)

| File | Purpose |
|------|---------|
| `ObservableAgent.swift` | Protocol for `@SpecDrivenAgent` actors |
| `AgentAppIntent.swift` | Base protocol for App Intents |
| `AgentStatusView.swift` | Status icon + label view |
| `AgentChatView.swift` | Complete drop-in chat UI |
| `TranscriptView.swift` | Chat-style transcript list |
| `StreamingTextView.swift` | Animated streaming text with cursor |
| `ToolCallDetailView.swift` | Expandable tool call details |

### Package Traits

SwiftSynapseHarness uses SwiftPM Package Traits (SE-0450) for modular feature selection. Trait names declared in `Package.swift` are natively available as compilation conditions — each source file is wrapped in `#if TraitName` / `#endif` (e.g., `#if Core`, `#if Hooks`). No `.define()` or `swiftSettings` are needed.

| Trait | Files | Default? |
|-------|-------|----------|
| `Core` | Tool system, LLM client, config, runtime, exports, skills, budgets, caching, shutdown, test fixtures | No |
| `Hooks` | AgentHook, AgentHookPipeline | No |
| `Safety` | Permission, Guardrails, DenialTracking, ToolListPolicy | No |
| `Resilience` | RecoveryStrategy, ErrorClassification, RateLimiting, ConversationRecovery, ContextCompression | No |
| `Observability` | Telemetry, TelemetrySinks, CostTracking | No |
| `MultiAgent` | AgentCoordination, SubagentContext | No |
| `Persistence` | AgentSession, SessionPersistence, AgentMemory | No |
| `MCP` | MCP.swift | No |
| `Plugins` | PluginSystem | No |
| `Production` | Core + Hooks + Safety + Resilience + Observability | **Yes** |
| `Advanced` | Production + MultiAgent + Persistence + MCP + Plugins | No |
| `Full` | Everything | No |

`TraitStubs.swift` provides no-op stubs (`#if !TraitName`) for cross-trait type references so Core files compile regardless of which traits are enabled. See `CodeGenSpecs/Traits.md` for full details.

### Key Design Decisions

- **Re-exports core types**: `@_exported import SwiftSynapseMacrosClient` — users import one package
- **`agentRun()` lives here**: The macro-generated `run(goal:)` calls `agentRun()` which uses harness types (hooks, telemetry, sessions)
- **`AgentExecutable` lives in SwiftSynapseMacrosClient**: The protocol is needed by the macro declaration
- **`ToolProgressUpdate` lives in SwiftSynapseMacrosClient**: The struct is needed by `ObservableTranscript`
- **Tool progress protocols live here**: `ToolProgressDelegate`, `ProgressReportingTool` depend on `AgentToolProtocol`

## Spec-Driven Workflow

All `.swift` files are generated from specs in `CodeGenSpecs/`. Specs are the single source of truth.

1. Edit the relevant spec in `CodeGenSpecs/`
2. Re-generate the corresponding `.swift` file(s)
3. Run `swift build` to verify
4. Commit both spec and generated files together

**Never edit generated `.swift` files directly.**

## Dependencies

- [SwiftSynapseMacros](https://github.com/RichNasz/SwiftSynapseMacros) (branch: main) — macros + core types
- [SwiftOpenSkills](https://github.com/RichNasz/SwiftOpenSkills) (branch: main) — skills framework
- [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) (branch: main) — `@LLMTool`, `@LLMToolArguments`, `@LLMToolGuide` macros

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+ / visionOS 2+

## Claude Code Files

Only `CLAUDE.md` is tracked. The `.claude/` directory is gitignored.

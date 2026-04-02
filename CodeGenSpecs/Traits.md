# Spec: Package Traits

**Generates:**
- `Sources/SwiftSynapseHarness/TraitStubs.swift`

## Overview

SwiftSynapseHarness uses SwiftPM Package Traits (SE-0450) for modular feature selection. Users opt into exactly the subsystems they need via `traits:` on their `.package()` dependency declaration.

### How Package Traits Work

Package Traits are a SwiftPM feature (SE-0450, Swift 6.1+) that allow packages to offer optional functionality that consumers can selectively enable. Key concepts:

- **Trait declarations** live in `Package.swift` under the `traits:` parameter. Each trait has a name, optional description, and optional `enabledTraits` for composing traits together.
- **Default traits** are specified via `.default(enabledTraits:)`. Consumers who don't specify `traits:` get the defaults.
- **Conditional compilation**: Trait names are directly available as compilation conditions. A trait named `"Core"` can be checked with `#if Core` / `#if !Core` — no `.define()` or `swiftSettings` mapping is needed.
- **Consumer opt-in**: Consumers specify traits on their `.package()` dependency: `.package(url: "...", branch: "main", traits: ["Core"])`. Omitting `traits:` uses the package's defaults.

### Why We Use Traits

Traits give SwiftSynapseHarness three benefits:

1. **Smaller binaries** — Users who only need the core tool loop don't link against hooks, guardrails, MCP, plugins, multi-agent coordination, etc.
2. **Explicit dependency surfaces** — Each feature's code compiles only when its trait is enabled, making the feature boundary explicit in the source.
3. **Backward compatibility** — The default trait set (`Production`) includes everything most agents need, so existing users require zero changes.

## Trait Definitions

| Trait | What it enables | Default? |
|-------|----------------|----------|
| `Core` | AgentToolProtocol, ToolRegistry, AgentToolLoop, StreamingToolExecutor, ToolProgress, AgentLLMClient, AgentConfiguration, AgentRuntime, Exports, SkillsSupport, SystemPromptBuilder, ResultTruncation, LLMToolSupport, ObservableTranscript+Harness, ContextBudget, RetryWithBackoff, ConfigurationHierarchy, Caching, GracefulShutdown, TestFixtures | No |
| `Hooks` | AgentHook, AgentHookPipeline (16 event types, closure hooks) | No |
| `Safety` | Permission, Guardrails, DenialTracking, ToolListPolicy | No |
| `Resilience` | RecoveryStrategy, ErrorClassification, RateLimiting, ConversationRecovery, ContextCompression | No |
| `Observability` | Telemetry, TelemetrySinks, CostTracking | No |
| `MultiAgent` | AgentCoordination, SubagentContext | No |
| `Persistence` | AgentSession, SessionPersistence, AgentMemory | No |
| `MCP` | MCP (MCPManager, MCPServerConnection, MCPToolBridge, etc.) | No |
| `Plugins` | PluginSystem (AgentPlugin, PluginManager, PluginContext) | No |
| `Production` | Core + Hooks + Safety + Resilience + Observability | **Yes** (default) |
| `Advanced` | Production + MultiAgent + Persistence + MCP + Plugins | No |
| `Full` | Everything | No |

## File-to-Trait Mapping

### Core (`#if Core`)
AgentToolProtocol.swift, ToolRegistry.swift, AgentToolLoop.swift, StreamingToolExecutor.swift, ToolProgress.swift, AgentLLMClient.swift, AgentConfiguration.swift, AgentRuntime.swift, Exports.swift, SkillsSupport.swift, SystemPromptBuilder.swift, ResultTruncation.swift, LLMToolSupport.swift, ObservableTranscript+Harness.swift, ContextBudget.swift, RetryWithBackoff.swift, ConfigurationHierarchy.swift, Caching.swift, GracefulShutdown.swift, TestFixtures.swift

### Hooks (`#if Hooks`)
AgentHook.swift, AgentHookPipeline.swift

### Safety (`#if Safety`)
Permission.swift, Guardrails.swift, DenialTracking.swift, ToolListPolicy.swift

### Resilience (`#if Resilience`)
RecoveryStrategy.swift, ErrorClassification.swift, RateLimiting.swift, ConversationRecovery.swift, ContextCompression.swift

### Observability (`#if Observability`)
Telemetry.swift, TelemetrySinks.swift, CostTracking.swift

### MultiAgent (`#if MultiAgent`)
AgentCoordination.swift, SubagentContext.swift

### Persistence (`#if Persistence`)
AgentSession.swift, SessionPersistence.swift, AgentMemory.swift

### MCP (`#if MCP`)
MCP.swift

### Plugins (`#if Plugins`)
PluginSystem.swift

### No trait guard
TraitStubs.swift (uses `#if !TraitName` internally)

## Cross-Trait Dependencies and Stubs

Core files (AgentToolLoop, AgentRuntime, StreamingToolExecutor, ToolRegistry) reference types from Hooks, Safety, Resilience, Observability, and Persistence in their function signatures. Since Swift does not support `#if` inside function parameter lists, these types must always exist at compile time.

`TraitStubs.swift` provides `#if !TraitName` stub blocks for every cross-referenced type. When a trait is disabled, the stub provides the same API surface but does nothing:

- Hooks stubs: `AgentHookPipeline.fire()` → `.proceed`, `add()` is no-op
- Safety stubs: `GuardrailPipeline.evaluate()` → `.allow`, `PermissionGate.check()` is no-op
- Observability stubs: `TelemetrySink.emit()` protocol exists but nobody conforms
- Resilience stubs: `RecoveryChain.default` is inert, `classifyRecoverableError()` → nil, `retryWithRateLimit()` → passthrough, `CompactionTrigger.default` → `.manual` (never fires)
- Persistence stubs: `SessionStore` protocol exists but nobody conforms, `AgentSession`/`CodableTranscriptEntry`/`MemoryEntry` exist as minimal types

### Why this works

All cross-trait parameters in AgentToolLoop and AgentRuntime default to `nil`. The stubs make the _types_ available for compilation. Users without a trait never construct real instances of those types, so the stubs are never meaningfully invoked.

## Package.swift Structure

```swift
traits: [
    .trait(name: "Core",
           description: "Tool system, LLM client, config, runtime, and core infrastructure"),
    .trait(name: "Hooks",
           description: "AgentHookPipeline with 16 event types and closure hooks"),
    .trait(name: "Safety",
           description: "Permissions, guardrails, denial tracking, and tool list policies"),
    .trait(name: "Resilience",
           description: "Recovery strategies, error classification, rate limiting, and context compression"),
    .trait(name: "Observability",
           description: "Telemetry sinks, cost tracking, and token usage monitoring"),
    .trait(name: "MultiAgent",
           description: "Multi-agent coordination runner and subagent spawning"),
    .trait(name: "Persistence",
           description: "Session persistence, session lifecycle, and agent memory"),
    .trait(name: "MCP",
           description: "Model Context Protocol manager and external tool servers"),
    .trait(name: "Plugins",
           description: "AgentPlugin system with activation lifecycle"),
    .trait(name: "Production",
           description: "Core + Hooks + Safety + Resilience + Observability — recommended for most agents",
           enabledTraits: ["Core", "Hooks", "Safety", "Resilience", "Observability"]),
    .trait(name: "Advanced",
           description: "Production + MultiAgent + Persistence + MCP + Plugins — full feature set",
           enabledTraits: ["Production", "MultiAgent", "Persistence", "MCP", "Plugins"]),
    .trait(name: "Full",
           description: "All traits enabled — equivalent to Advanced",
           enabledTraits: ["Advanced"]),
    .default(enabledTraits: ["Production"]),
]
```

Trait names are natively available as compilation conditions — no `swiftSettings` or `.define()` needed. `#if Core` compiles when the `Core` trait is enabled. `#if !Core` compiles when it is disabled.

## Source File Structure

Every source file guarded by a trait follows this pattern:

```swift
// Generated from CodeGenSpecs/<SpecName>.md — Do not edit manually. Update spec and re-generate.

#if Core  // or Hooks, Safety, etc.

import Foundation
// ... file contents ...

#endif
```

## User-Facing Examples

```swift
// Minimal agent (smallest binary):
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main", traits: ["Core"])

// Default (most users — zero config):
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main")

// Production + extras:
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main", traits: ["Production", "MCP", "Persistence"])

// Everything:
.package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main", traits: ["Full"])
```

# CodeGenSpecs Overview

## Purpose

This directory contains the specifications that serve as the single source of truth for all generated `.swift` files in SwiftSynapseHarness. Every `.swift` file in `Sources/` and `Tests/` is a generated artifact — to change behavior, update the relevant spec and re-generate.

Specs are organized by **Package Trait**. The spec name matches the trait name directly (e.g., `Resilience.md` → all `#if Resilience` files). This makes the mapping self-evident: to modify a trait, find the spec with that name.

## Trait Source Specs

| Spec | Trait Guard | Generates |
|------|------------|-----------|
| [Core.md](Core.md) | `#if Core` | `AgentRuntime.swift`, `ObservableTranscript+Harness.swift`, `AgentToolProtocol.swift`, `ToolRegistry.swift`, `AgentToolLoop.swift`, `StreamingToolExecutor.swift`, `AgentLLMClient.swift`, `AgentConfiguration.swift`, `ContextBudget.swift`, `RetryWithBackoff.swift`, `ToolProgress.swift`, `ConfigurationHierarchy.swift`, `Caching.swift`, `ResultTruncation.swift`, `SystemPromptBuilder.swift`, `TestFixtures.swift`, `GracefulShutdown.swift` |
| [Hooks.md](Hooks.md) | `#if Hooks` | `AgentHook.swift`, `AgentHookPipeline.swift` |
| [Safety.md](Safety.md) | `#if Safety` | `Permission.swift`, `ToolListPolicy.swift`, `Guardrails.swift`, `DenialTracking.swift` |
| [Resilience.md](Resilience.md) | `#if Resilience` | `RecoveryStrategy.swift`, `ErrorClassification.swift`, `RateLimiting.swift`, `ConversationRecovery.swift`, `ContextCompression.swift` |
| [Observability.md](Observability.md) | `#if Observability` | `Telemetry.swift`, `TelemetrySinks.swift`, `CostTracking.swift` |
| [MultiAgent.md](MultiAgent.md) | `#if MultiAgent` | `AgentCoordination.swift`, `SubagentContext.swift` |
| [Persistence.md](Persistence.md) | `#if Persistence` | `AgentSession.swift`, `SessionPersistence.swift`, `AgentMemory.swift` |
| [MCP.md](MCP.md) | `#if MCP` | `MCP.swift` |
| [Plugins.md](Plugins.md) | `#if Plugins` | `PluginSystem.swift` |

## Shared Integration Specs

These specs generate files that bridge external packages into the trait system. Named with a `Shared-` prefix to distinguish them from native trait specs.

| Spec | Generates |
|------|-----------|
| [Shared-LLMToolMacros.md](Shared-LLMToolMacros.md) | `LLMToolSupport.swift` (`#if Core`) |
| [Shared-Skills.md](Shared-Skills.md) | `SkillsSupport.swift` (`#if Core`) |

## Infrastructure Specs

| Spec | Generates |
|------|-----------|
| [Traits.md](Traits.md) | `TraitStubs.swift` (no-op stubs via `#if !TraitName`), `Package.swift` trait declarations |

## Test Specs

One test spec per trait. Each generates one test file covering that trait's types.

| Spec | Generates |
|------|-----------|
| [CoreTests.md](CoreTests.md) | `Tests/SwiftSynapseHarnessTests/CoreTests.swift` |
| [HooksTests.md](HooksTests.md) | `Tests/SwiftSynapseHarnessTests/HooksTests.swift` |
| [SafetyTests.md](SafetyTests.md) | `Tests/SwiftSynapseHarnessTests/SafetyTests.swift` |
| [ResilienceTests.md](ResilienceTests.md) | `Tests/SwiftSynapseHarnessTests/ResilienceTests.swift` |
| [ObservabilityTests.md](ObservabilityTests.md) | `Tests/SwiftSynapseHarnessTests/ObservabilityTests.swift` |
| [PersistenceTests.md](PersistenceTests.md) | `Tests/SwiftSynapseHarnessTests/PersistenceTests.swift` |
| [MultiAgentTests.md](MultiAgentTests.md) | `Tests/SwiftSynapseHarnessTests/MultiAgentTests.swift` |
| [MCPTests.md](MCPTests.md) | `Tests/SwiftSynapseHarnessTests/MCPTests.swift` |
| [PluginsTests.md](PluginsTests.md) | `Tests/SwiftSynapseHarnessTests/PluginsTests.swift` |

## UI Spec

| Spec | Generates |
|------|-----------|
| [UI.md](UI.md) | `Sources/SwiftSynapseUI/ObservableAgent.swift`, `AgentAppIntent.swift`, `AgentStatusView.swift`, `AgentChatView.swift`, `TranscriptView.swift`, `StreamingTextView.swift`, `ToolCallDetailView.swift` |

## Documentation Specs

| Spec | Generates |
|------|-----------|
| [Doc-HarnessCatalog.md](Doc-HarnessCatalog.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/SwiftSynapseHarness.md` |
| [Doc-GettingStarted.md](Doc-GettingStarted.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/GettingStarted.md` |
| [Doc-AgentHarnessGuide.md](Doc-AgentHarnessGuide.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/AgentHarnessGuide.md` |
| [Doc-ProductionGuide.md](Doc-ProductionGuide.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/ProductionGuide.md` |
| [Doc-HOWTOs.md](Doc-HOWTOs.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/HowToAddTools.md`, `HowToConfigurePermissions.md`, `HowToGoToProduction.md`, `HowToMultiAgent.md`, `HowToTestAgents.md` |
| [Doc-SwiftSynapseUI.md](Doc-SwiftSynapseUI.md) | `Sources/SwiftSynapseUI/SwiftSynapseUI.docc/SwiftSynapseUI.md`, `UIGuide.md` |

## Generation Rules

1. Every generated `.swift` file starts with:
   ```
   // Generated from CodeGenSpecs/<SpecName>.md — Do not edit manually. Update spec and re-generate.
   ```

2. Specs are the authority — if code and spec disagree, the spec wins.

3. Edit spec → regenerate files → `swift build` → commit both together.

## Workflow

1. Identify which trait the change belongs to
2. Edit the corresponding `<TraitName>.md` spec (and `<TraitName>Tests.md` if behavior changes)
3. Re-generate the corresponding `.swift` file(s)
4. Run `swift build` to verify
5. Commit spec(s) and generated file(s) together

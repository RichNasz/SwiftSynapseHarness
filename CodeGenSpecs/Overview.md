# CodeGenSpecs Overview

## Purpose

This directory contains the specifications that serve as the single source of truth for all generated `.swift` files in SwiftSynapseHarness. Every `.swift` file in `Sources/` is a generated artifact — to change behavior, update the relevant spec and re-generate.

## Spec Files

| Spec | Generates |
|------|-----------|
| [Client-Runtime.md](Client-Runtime.md) | `AgentRuntime.swift`, `ObservableTranscript+Harness.swift` |
| [Client-AgentHarness.md](Client-AgentHarness.md) | `AgentToolProtocol.swift`, `ToolRegistry.swift`, `AgentToolLoop.swift`, `StreamingToolExecutor.swift`, `AgentHook.swift`, `AgentHookPipeline.swift`, `Permission.swift`, `ToolListPolicy.swift`, `AgentLLMClient.swift`, `AgentConfiguration.swift`, `AgentSession.swift`, `RetryWithBackoff.swift`, `RecoveryStrategy.swift`, `ContextBudget.swift`, `Telemetry.swift`, `TelemetrySinks.swift`, `SubagentContext.swift`, `ToolProgress.swift`, `SkillsSupport.swift` |
| [Client-Production.md](Client-Production.md) | `SessionPersistence.swift`, `Guardrails.swift`, `MCP.swift`, `ContextCompression.swift`, `ConfigurationHierarchy.swift`, `Caching.swift`, `DenialTracking.swift`, `AgentCoordination.swift`, `PluginSystem.swift` |
| [Client-ProductionPolish.md](Client-ProductionPolish.md) | `CostTracking.swift`, `ErrorClassification.swift`, `ResultTruncation.swift`, `RateLimiting.swift`, `SystemPromptBuilder.swift`, `TestFixtures.swift`, `GracefulShutdown.swift`, `AgentMemory.swift`, `ConversationRecovery.swift` |
| [UI.md](UI.md) | `Sources/SwiftSynapseUI/ObservableAgent.swift`, `AgentAppIntent.swift`, `AgentStatusView.swift`, `AgentChatView.swift`, `TranscriptView.swift`, `StreamingTextView.swift`, `ToolCallDetailView.swift` |
| [Tests.md](Tests.md) | `Tests/SwiftSynapseHarnessTests/AgentConfigurationTests.swift`, `RetryAndContextTests.swift`, `ToolSystemTests.swift`, `SessionAndTranscriptTests.swift`, `HooksAndGuardrailsTests.swift`, `ProductionPolishTests.swift`, `AgentRuntimeTests.swift` |
| [Shared-Skills.md](Shared-Skills.md) | `Sources/SwiftSynapseHarness/SkillsSupport.swift` |

## Documentation Spec Files

| Spec | Generates |
|------|-----------|
| [Doc-HarnessCatalog.md](Doc-HarnessCatalog.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/SwiftSynapseHarness.md` |
| [Doc-GettingStarted.md](Doc-GettingStarted.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/GettingStarted.md` |
| [Doc-AgentHarnessGuide.md](Doc-AgentHarnessGuide.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/AgentHarnessGuide.md` |
| [Doc-ProductionGuide.md](Doc-ProductionGuide.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/ProductionGuide.md` |
| [Doc-HOWTOs.md](Doc-HOWTOs.md) | `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/HowToAddTools.md`, `HowToConfigurePermissions.md`, `HowToGoToProduction.md`, `HowToMultiAgent.md`, `HowToTestAgents.md` |
| [Doc-SwiftSynapseUI.md](Doc-SwiftSynapseUI.md) | `Sources/SwiftSynapseUI/SwiftSynapseUI.docc/SwiftSynapseUI.md`, `UIGuide.md` |

## Infrastructure Files

| File | Purpose |
|------|---------|
| `Exports.swift` | Re-exports `SwiftSynapseMacrosClient` so users only need one import |

## Generation Rules

1. Every generated `.swift` file starts with a header comment:
   ```
   // Generated from CodeGenSpecs/<SpecName>.md — Do not edit manually. Update spec and re-generate.
   ```

2. Specs are the authority — if code and spec disagree, the spec wins.

## Workflow

1. Edit the relevant spec in `CodeGenSpecs/`
2. Re-generate the corresponding `.swift` file(s)
3. Run `swift build` to verify
4. Commit both spec and generated files together

## Dependency

SwiftSynapseHarness depends on `SwiftSynapseMacrosClient` (from `SwiftSynapseMacros`) for core types: `AgentStatus`, `ObservableTranscript`, `TextFormat`, `AgentGoalMetadata`, `ToolProgressUpdate`, and macro declarations.

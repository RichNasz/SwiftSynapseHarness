# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `agentRun()` lifecycle function with status transitions, error handling, and cancellation
- `AgentToolLoop` with typed tool dispatch, batch dispatch, and streaming via `runStreaming()`
- `ToolRegistry` with `AgentToolProtocol` for typed tool registration and dispatch
- Hook system: `AgentHookPipeline`, 16 event types, `ClosureHook` for inline hook definitions
- Permission system: `PermissionGate`, `ToolListPolicy` for policy-driven tool access control
- Recovery strategies: `ReactiveCompactionStrategy`, `OutputTokenEscalationStrategy`, `ContinuationStrategy`, and `RecoveryChain` for ordered first-success recovery
- LLM backends: `CloudLLMClient` (wraps SwiftOpenResponsesDSL), `HybridLLMClient` (on-device with cloud fallback), `AgentConfiguration.buildClient()` for mode-based selection
- Session persistence via `FileSessionStore` and `agentRun(sessionStore:)`
- Guardrails pipeline with `GuardrailPipeline` and `ContentFilter`
- MCP integration via `MCPManager` and `MCPServerConfig` for external tool server registration
- Multi-agent coordination via `CoordinationRunner` and `CoordinationPhase` with dependency ordering
- Cost tracking via `CostTracker` and `CostTrackingTelemetrySink` with per-model pricing
- Rate limiting via `RateLimitState` integrated into `AgentToolLoop`
- Plugin system with `AgentPlugin` protocol and `PluginContext`
- Advanced compression: `MicroCompactor`, `ImportanceCompressor`, `AutoCompactCompressor`, `CompositeCompressor`
- Configuration hierarchy with 7-level priority (CLI > local > project > user > MDM > remote > environment)
- LRU/FIFO caching with TTL for tool results
- Denial tracking for adaptive permission behavior on consecutive denials
- Semantic error classification for API and tool errors
- Tool result truncation for oversized outputs
- Prioritized, cacheable system prompt composition
- VCR testing support for deterministic record/replay in agent tests
- Graceful shutdown with LIFO handler execution and signal handling
- Agent memory for persistent cross-session categorized storage
- Conversation recovery with transcript integrity checking and repair
- Telemetry system: `CompositeTelemetrySink`, `OSLogTelemetrySink`, `CostTrackingTelemetrySink`, 12 event types covering agent lifecycle, LLM calls, tool calls, retries, budget exhaustion, guardrail triggers, context compaction, API error classification, and plugin lifecycle
- `SwiftSynapseUI` target with SwiftUI views and protocols for agent status binding
- Spec-driven development structure with `CodeGenSpecs/` as source of truth
- Re-export of `SwiftSynapseMacrosClient` and `SwiftOpenSkills`

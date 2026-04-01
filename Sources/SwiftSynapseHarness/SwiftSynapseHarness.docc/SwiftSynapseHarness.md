# ``SwiftSynapseHarness``

Production-grade agent harness for Swift — typed tools, hooks, permissions, streaming, recovery, MCP, multi-agent coordination, and everything between `execute(goal:)` and a deployed agent.

## Overview

SwiftSynapseHarness provides the orchestration layer for Swift AI agents. It re-exports `SwiftSynapseMacrosClient`, so importing `SwiftSynapseHarness` gives you macros, core types, and the full harness in one import.

## Topics

### Essentials

- <doc:AgentHarnessGuide>
- <doc:ProductionGuide>

### Agent Runtime

- ``agentRun(agent:goal:hooks:telemetry:sessionStore:sessionAgentType:)``
- ``AgentExecutable``

### Tool System

- ``AgentToolProtocol``
- ``ToolRegistry``
- ``AgentToolLoop``

### Hooks & Permissions

- ``AgentHook``
- ``AgentHookPipeline``
- ``PermissionGate``

### LLM Backend

- ``AgentLLMClient``
- ``AgentConfiguration``

### Recovery & Resilience

- ``RecoveryChain``
- ``retryWithBackoff(maxAttempts:baseDelay:isRetryable:onRetry:operation:)``

### Telemetry

- ``TelemetrySink``
- ``TelemetryEvent``

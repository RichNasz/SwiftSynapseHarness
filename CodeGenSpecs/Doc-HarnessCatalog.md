# Doc-HarnessCatalog

## Purpose

Specifies the main DocC catalog for the `SwiftSynapseHarness` product. This file is the documentation entry point — it groups every public type into organized topic sections and links all guide articles.

## Generates

- `Sources/SwiftSynapseHarness/SwiftSynapseHarness.docc/SwiftSynapseHarness.md`

---

## Catalog Structure

### Title & Overview

- Title: ` ``SwiftSynapseHarness`` `
- Tagline: Production-grade agent harness for Swift — typed tools, hooks, permissions, streaming, recovery, MCP, multi-agent coordination, and everything between `execute(goal:)` and a deployed agent.
- Overview prose: SwiftSynapseHarness provides the orchestration layer for Swift AI agents. It re-exports `SwiftSynapseMacrosClient`, so importing `SwiftSynapseHarness` gives you macros, core types, and the full harness in one import.

---

### Topics

#### Essentials

Links to all guide articles and HOWTOs:

- `<doc:GettingStarted>`
- `<doc:AgentHarnessGuide>`
- `<doc:ProductionGuide>`
- `<doc:HowToAddTools>`
- `<doc:HowToConfigurePermissions>`
- `<doc:HowToGoToProduction>`
- `<doc:HowToMultiAgent>`
- `<doc:HowToTestAgents>`

#### Agent Runtime

- `` ``agentRun(agent:goal:hooks:telemetry:sessionStore:sessionAgentType:)`` ``
- `` ``AgentExecutable`` ``
- `` ``AgentSession`` ``
- `` ``AgentConfiguration`` ``
- `` ``ExecutionMode`` ``

#### Tool System

- `` ``AgentToolProtocol`` ``
- `` ``AnyAgentTool`` ``
- `` ``ToolRegistry`` ``
- `` ``AgentToolLoop`` ``
- `` ``StreamingToolExecutor`` ``
- `` ``AgentStreamEvent`` ``
- `` ``ProgressReportingTool`` ``
- `` ``ToolProgressDelegate`` ``
- `` ``ResultTruncator`` ``
- `` ``TruncationPolicy`` ``

#### Hooks

- `` ``AgentHook`` ``
- `` ``AgentHookPipeline`` ``
- `` ``AgentHookEvent`` ``
- `` ``AgentHookEventKind`` ``
- `` ``HookAction`` ``
- `` ``ClosureHook`` ``

#### Permissions

- `` ``PermissionGate`` ``
- `` ``PermissionPolicy`` ``
- `` ``ToolListPolicy`` ``
- `` ``ApprovalDelegate`` ``
- `` ``AdaptivePermissionGate`` ``
- `` ``DenialTracker`` ``
- `` ``PermissionMode`` ``

#### Guardrails

- `` ``GuardrailPolicy`` ``
- `` ``GuardrailPipeline`` ``
- `` ``GuardrailInput`` ``
- `` ``GuardrailDecision`` ``
- `` ``ContentFilter`` ``

#### LLM Backend

- `` ``AgentLLMClient`` ``
- `` ``AgentRequest`` ``
- `` ``AgentResponse`` ``
- `` ``AgentToolCall`` ``
- `` ``ToolResult`` ``
- `` ``CloudLLMClient`` ``
- `` ``HybridLLMClient`` ``

#### Recovery & Resilience

- `` ``RecoveryChain`` ``
- `` ``RecoveryStrategy`` ``
- `` ``ReactiveCompactionStrategy`` ``
- `` ``OutputTokenEscalationStrategy`` ``
- `` ``ContinuationStrategy`` ``
- `` ``retryWithBackoff(maxAttempts:baseDelay:isRetryable:onRetry:operation:)`` ``
- `` ``retryWithRateLimit(state:policy:operation:)`` ``
- `` ``RateLimitState`` ``
- `` ``classifyAPIError(_:model:)`` ``
- `` ``classifyToolError(_:)`` ``
- `` ``APIErrorCategory`` ``
- `` ``ToolErrorCategory`` ``

#### Context Management

- `` ``ContextBudget`` ``
- `` ``CompactionTrigger`` ``
- `` ``TranscriptCompressor`` ``
- `` ``SlidingWindowCompressor`` ``
- `` ``ImportanceCompressor`` ``
- `` ``MicroCompactor`` ``
- `` ``AutoCompactCompressor`` ``
- `` ``CompositeCompressor`` ``

#### Session & Memory

- `` ``SessionStore`` ``
- `` ``FileSessionStore`` ``
- `` ``SessionMetadata`` ``
- `` ``SessionStatus`` ``
- `` ``MemoryStore`` ``
- `` ``FileMemoryStore`` ``
- `` ``MemoryEntry`` ``
- `` ``MemoryCategory`` ``

#### Telemetry

- `` ``TelemetrySink`` ``
- `` ``TelemetryEvent`` ``
- `` ``TelemetryEventKind`` ``
- `` ``OSLogTelemetrySink`` ``
- `` ``InMemoryTelemetrySink`` ``
- `` ``CompositeTelemetrySink`` ``
- `` ``TokenUsageTracker`` ``

#### Cost Tracking

- `` ``CostTracker`` ``
- `` ``CostRecord`` ``
- `` ``ModelPricing`` ``
- `` ``ModelUsage`` ``
- `` ``CostTrackingTelemetrySink`` ``

#### MCP Integration

- `` ``MCPManager`` ``
- `` ``MCPServerConfig`` ``
- `` ``MCPServerConnection`` ``
- `` ``MCPToolBridge`` ``
- `` ``MCPTransport`` ``
- `` ``StdioMCPTransport`` ``
- `` ``MCPMessage`` ``
- `` ``MCPToolDefinition`` ``

#### Multi-Agent Coordination

- `` ``SubagentRunner`` ``
- `` ``SubagentContext`` ``
- `` ``CoordinationRunner`` ``
- `` ``CoordinationPhase`` ``
- `` ``SharedMailbox`` ``
- `` ``TeamMemory`` ``

#### Plugins

- `` ``AgentPlugin`` ``
- `` ``PluginManager`` ``
- `` ``PluginContext`` ``

#### Configuration

- `` ``ConfigurationResolver`` ``
- `` ``ConfigurationSource`` ``
- `` ``EnvironmentConfigSource`` ``
- `` ``FileConfigSource`` ``
- `` ``MDMConfigSource`` ``

#### System Prompt

- `` ``SystemPromptBuilder`` ``
- `` ``SystemPromptSection`` ``
- `` ``SystemPromptProvider`` ``

#### Caching

- `` ``ToolResultCache`` ``
- `` ``Cache`` ``
- `` ``CachePolicy`` ``

#### Testing

- `` ``VCRClient`` ``
- `` ``VCRError`` ``
- `` ``FixtureStore`` ``
- `` ``FileFixtureStore`` ``
- `` ``FixtureMode`` ``

#### Production Utilities

- `` ``ShutdownRegistry`` ``
- `` ``SignalHandler`` ``
- `` ``TranscriptIntegrityCheck`` ``
- `` ``IntegrityViolation`` ``
- `` ``ConversationRecoveryStrategy`` ``
- `` ``DefaultConversationRecoveryStrategy`` ``
- `` ``recoverTranscript(_:strategy:)`` ``

#### Skills

- `` ``SkillStore`` ``
- `` ``SkillSearchPath`` ``
- `` ``Skill`` ``

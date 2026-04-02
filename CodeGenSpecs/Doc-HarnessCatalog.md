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

#### Package Traits

SwiftSynapseHarness uses SwiftPM Package Traits for modular feature selection. Each topic section below indicates which trait enables it. The default `Production` trait includes Core, Hooks, Safety, Resilience, and Observability. For multi-agent coordination, persistence, MCP, or plugins, add `traits: ["Full"]` or `traits: ["Advanced"]` to your `.package()` declaration, or add individual traits like `traits: ["Production", "MCP"]`.

#### Agent Runtime — *Core trait*

- `` ``agentRun(agent:goal:hooks:telemetry:sessionStore:sessionAgentType:)`` ``
- `` ``AgentExecutable`` ``
- `` ``AgentSession`` ``
- `` ``AgentConfiguration`` ``
- `` ``ExecutionMode`` ``

#### Tool System — *Core trait*

- `` ``AgentToolProtocol`` ``
- `` ``AgentLLMTool`` ``
- `` ``LLMTool`` ``
- `` ``LLMToolArguments`` ``
- `` ``ToolOutput`` ``
- `` ``AnyAgentTool`` ``
- `` ``ToolRegistry`` ``
- `` ``AgentToolLoop`` ``
- `` ``StreamingToolExecutor`` ``
- `` ``AgentStreamEvent`` ``
- `` ``ProgressReportingTool`` ``
- `` ``ToolProgressDelegate`` ``
- `` ``ResultTruncator`` ``
- `` ``TruncationPolicy`` ``

#### Hooks — *Hooks trait*

- `` ``AgentHook`` ``
- `` ``AgentHookPipeline`` ``
- `` ``AgentHookEvent`` ``
- `` ``AgentHookEventKind`` ``
- `` ``HookAction`` ``
- `` ``ClosureHook`` ``

#### Permissions — *Safety trait*

- `` ``PermissionGate`` ``
- `` ``PermissionPolicy`` ``
- `` ``ToolListPolicy`` ``
- `` ``ApprovalDelegate`` ``
- `` ``AdaptivePermissionGate`` ``
- `` ``DenialTracker`` ``
- `` ``PermissionMode`` ``

#### Guardrails — *Safety trait*

- `` ``GuardrailPolicy`` ``
- `` ``GuardrailPipeline`` ``
- `` ``GuardrailInput`` ``
- `` ``GuardrailDecision`` ``
- `` ``ContentFilter`` ``

#### LLM Backend — *Core trait*

- `` ``AgentLLMClient`` ``
- `` ``AgentRequest`` ``
- `` ``AgentResponse`` ``
- `` ``AgentToolCall`` ``
- `` ``ToolResult`` ``
- `` ``CloudLLMClient`` ``
- `` ``HybridLLMClient`` ``

#### Recovery & Resilience — *Resilience trait*

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

#### Context Management — *Core trait (ContextBudget), Resilience trait (compressors)*

- `` ``ContextBudget`` ``
- `` ``CompactionTrigger`` ``
- `` ``TranscriptCompressor`` ``
- `` ``SlidingWindowCompressor`` ``
- `` ``ImportanceCompressor`` ``
- `` ``MicroCompactor`` ``
- `` ``AutoCompactCompressor`` ``
- `` ``CompositeCompressor`` ``

#### Session & Memory — *Persistence trait*

- `` ``SessionStore`` ``
- `` ``FileSessionStore`` ``
- `` ``SessionMetadata`` ``
- `` ``SessionStatus`` ``
- `` ``MemoryStore`` ``
- `` ``FileMemoryStore`` ``
- `` ``MemoryEntry`` ``
- `` ``MemoryCategory`` ``

#### Telemetry — *Observability trait*

- `` ``TelemetrySink`` ``
- `` ``TelemetryEvent`` ``
- `` ``TelemetryEventKind`` ``
- `` ``OSLogTelemetrySink`` ``
- `` ``InMemoryTelemetrySink`` ``
- `` ``CompositeTelemetrySink`` ``
- `` ``TokenUsageTracker`` ``

#### Cost Tracking — *Observability trait*

- `` ``CostTracker`` ``
- `` ``CostRecord`` ``
- `` ``ModelPricing`` ``
- `` ``ModelUsage`` ``
- `` ``CostTrackingTelemetrySink`` ``

#### MCP Integration — *MCP trait*

- `` ``MCPManager`` ``
- `` ``MCPServerConfig`` ``
- `` ``MCPServerConnection`` ``
- `` ``MCPToolBridge`` ``
- `` ``MCPTransport`` ``
- `` ``StdioMCPTransport`` ``
- `` ``MCPMessage`` ``
- `` ``MCPToolDefinition`` ``

#### Multi-Agent Coordination — *MultiAgent trait*

- `` ``SubagentRunner`` ``
- `` ``SubagentContext`` ``
- `` ``CoordinationRunner`` ``
- `` ``CoordinationPhase`` ``
- `` ``SharedMailbox`` ``
- `` ``TeamMemory`` ``

#### Plugins — *Plugins trait*

- `` ``AgentPlugin`` ``
- `` ``PluginManager`` ``
- `` ``PluginContext`` ``

#### Configuration — *Core trait*

- `` ``ConfigurationResolver`` ``
- `` ``ConfigurationSource`` ``
- `` ``EnvironmentConfigSource`` ``
- `` ``FileConfigSource`` ``
- `` ``MDMConfigSource`` ``

#### System Prompt — *Core trait*

- `` ``SystemPromptBuilder`` ``
- `` ``SystemPromptSection`` ``
- `` ``SystemPromptProvider`` ``

#### Caching — *Core trait*

- `` ``ToolResultCache`` ``
- `` ``Cache`` ``
- `` ``CachePolicy`` ``

#### Testing — *Core trait*

- `` ``VCRClient`` ``
- `` ``VCRError`` ``
- `` ``FixtureStore`` ``
- `` ``FileFixtureStore`` ``
- `` ``FixtureMode`` ``

#### Production Utilities — *Core trait (shutdown), Resilience trait (recovery)*

- `` ``ShutdownRegistry`` ``
- `` ``SignalHandler`` ``
- `` ``TranscriptIntegrityCheck`` ``
- `` ``IntegrityViolation`` ``
- `` ``ConversationRecoveryStrategy`` ``
- `` ``DefaultConversationRecoveryStrategy`` ``
- `` ``recoverTranscript(_:strategy:)`` ``

#### Skills — *Core trait*

- `` ``SkillStore`` ``
- `` ``SkillSearchPath`` ``
- `` ``Skill`` ``

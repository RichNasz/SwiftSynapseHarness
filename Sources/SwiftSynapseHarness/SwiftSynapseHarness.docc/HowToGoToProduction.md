# How to Deploy an Agent to Production

Add guardrails, cost tracking, rate limiting, and graceful shutdown for a production-ready deployment.

## Overview

Running an agent in production requires four additional capabilities beyond development: content guardrails to prevent sensitive data leakage, cost tracking to control spend, rate limit handling to survive API throttling, and graceful shutdown to avoid data loss when the process ends.

## Step 1: Add Content Guardrails

Guardrails screen tool arguments and LLM outputs for sensitive content before they enter the transcript or reach external systems:

```swift
let guardrails = GuardrailPipeline()
await guardrails.add(ContentFilter.default)    // Built-in: CC#, SSN, API keys, bearer tokens
await guardrails.add(ComplianceFilter())       // Your custom compliance policy

try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    guardrails: guardrails
)
```

Write a custom policy by conforming to ``GuardrailPolicy``:

```swift
struct PIIFilter: GuardrailPolicy {
    let name = "pii"
    func evaluate(input: GuardrailInput) async -> GuardrailDecision {
        guard case .llmOutput(let text) = input else { return .allow }
        return text.containsPII ? .sanitize(replacement: "[REDACTED]") : .allow
    }
}
```

The hook event `.guardrailTriggered(policy:decision:input:)` fires on every non-`.allow` decision.

## Step 2: Track Costs

Wire ``CostTrackingTelemetrySink`` into the telemetry pipeline. Costs accumulate automatically from every `.llmCallMade` telemetry event:

```swift
let costTracker = CostTracker()
await costTracker.setPricing(for: "claude-opus-4-6", pricing: ModelPricing(
    inputCostPerMillionTokens: 3.0,
    outputCostPerMillionTokens: 15.0,
    cacheCreationCostPerMillionTokens: 3.75,
    cacheReadCostPerMillionTokens: 0.30
))

let telemetry = CompositeTelemetrySink([
    OSLogTelemetrySink(),
    CostTrackingTelemetrySink(tracker: costTracker)
])
```

Query costs after the session:

```swift
let total = await costTracker.totalCost()          // Total USD
let duration = await costTracker.totalAPIDuration() // Total API wall-clock time
let byModel = await costTracker.usageByModel()      // Per-model stats
let records = await costTracker.allRecords()        // Full record per LLM call
```

## Step 3: Handle Rate Limits

Pass a ``RateLimitState`` to ``AgentToolLoop``. It automatically parses Retry-After headers, enters cooldown on 429/529 responses, and uses jittered exponential backoff — no extra configuration needed:

```swift
let rateLimitState = RateLimitState()

try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    rateLimitState: rateLimitState
)
```

`RateLimitState` checks the cooldown window before sending each request, avoiding wasted calls that will immediately be rejected. The default policy: max 5 retries, 1s initial backoff, 60s max backoff, 25% jitter.

## Step 4: Register Graceful Shutdown

Register cleanup handlers and install signal handlers. Handlers run in LIFO order on SIGINT or SIGTERM:

```swift
let shutdown = ShutdownRegistry()

// Register in order of importance (last registered runs first)
await shutdown.register(name: "sessions")  { try? await sessionStore.flush() }
await shutdown.register(name: "mcp")       { await mcpManager.disconnectAll() }
await shutdown.register(name: "plugins")   { await pluginManager.deactivateAll() }

SignalHandler.install(registry: shutdown)
```

This ensures agents finish their current work, sessions are persisted, MCP connections are cleanly closed, and plugins are deactivated before the process exits.

## Putting It All Together

A minimal production-ready agent run:

```swift
let costTracker = CostTracker()
let guardrails = GuardrailPipeline()
let shutdown = ShutdownRegistry()
let rateLimitState = RateLimitState()

await guardrails.add(ContentFilter.default)
await costTracker.setPricing(for: config.model, pricing: myPricing)

let telemetry = CompositeTelemetrySink([
    OSLogTelemetrySink(),
    CostTrackingTelemetrySink(tracker: costTracker)
])

await shutdown.register(name: "sessions") { await sessionStore.flush() }
SignalHandler.install(registry: shutdown)

let result = try await AgentToolLoop.run(
    client: client, config: config, goal: goal,
    tools: tools, transcript: transcript,
    telemetry: telemetry,
    guardrails: guardrails,
    rateLimitState: rateLimitState,
    sessionStore: sessionStore
)

print("Cost: \(await costTracker.totalCost())")
```

## See Also

- <doc:ProductionGuide> — full details on each capability
- <doc:HowToMultiAgent> — coordinating multiple agents in production
- <doc:HowToTestAgents> — VCR testing for deterministic CI runs

# Spec: SwiftSynapseHarness Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/AgentConfigurationTests.swift`, `RetryAndContextTests.swift`, `ToolSystemTests.swift`, `SessionAndTranscriptTests.swift`, `HooksAndGuardrailsTests.swift`, `ProductionPolishTests.swift`, `AgentRuntimeTests.swift`

## Overview

Unit tests for the SwiftSynapseHarness package. Covers all testable harness types without requiring an external LLM server. Integration/live tests are gated by `SWIFTSYNAPSE_LIVE_TESTS` environment variable.

## Test Target

- **Name:** `SwiftSynapseHarnessTests`
- **Path:** `Tests/SwiftSynapseHarnessTests/`
- **Dependencies:** `SwiftSynapseHarness`
- **Framework:** Swift Testing (`import Testing`) — NOT XCTest

## Generation Rules

- Every generated test file starts with: `// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.`
- Top-level `@Test` functions (no `@Suite` wrappers) — consistent with SwiftSynapse showcase tests
- `async throws` test functions for async assertions
- `#expect()` macro for all assertions
- Pattern-match failures use `Issue.record()` to report rather than crash
- Live/integration tests gated with `@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))`

## Mock Types

Defined once at file scope in each test file that needs them:

```swift
// Mock AgentLLMTool for ToolSystemTests — conforms manually (no macros needed in tests)
struct MockLLMTool: AgentLLMTool {
    struct Arguments: LLMToolArguments {
        let message: String
        static var jsonSchema: JSONSchemaValue {
            .object(properties: [("message", .string(description: "A test message"))], required: ["message"])
        }
    }
    static var name: String { "mock_llm_tool" }
    static var description: String { "A mock tool for testing AgentLLMTool." }
    static var toolDefinition: ToolDefinition {
        ToolDefinition(name: name, description: description, parameters: Arguments.jsonSchema)
    }
    func call(arguments: Arguments) async throws -> ToolOutput {
        ToolOutput(content: "echo:\(arguments.message)")
    }
}

struct ConcurrentMockLLMTool: AgentLLMTool {
    struct Arguments: LLMToolArguments {
        let value: String
        static var jsonSchema: JSONSchemaValue {
            .object(properties: [("value", .string(description: "A value"))], required: ["value"])
        }
    }
    static var name: String { "concurrent_mock_llm_tool" }
    static var description: String { "A concurrent-safe mock LLM tool." }
    static var isConcurrencySafe: Bool { true }
    static var toolDefinition: ToolDefinition {
        ToolDefinition(name: name, description: description, parameters: Arguments.jsonSchema)
    }
    func call(arguments: Arguments) async throws -> ToolOutput {
        ToolOutput(content: arguments.value)
    }
}

// Mock agent for AgentRuntimeTests
actor MockAgent: AgentExecutable {
    var _status: AgentStatus = .idle
    var _transcript: ObservableTranscript = ObservableTranscript()
    var shouldThrow = false
    func execute(goal: String) async throws -> String {
        if shouldThrow { throw AgentLifecycleError.emptyGoal }
        return "mock result"
    }
}
```

## Test Groups

### AgentConfigurationTests.swift (sources: AgentConfiguration.swift)

| Test Function | What it verifies |
|---------------|-----------------|
| `cloudConfigValidURLSucceeds` | `AgentConfiguration(.cloud, serverURL: "http://127.0.0.1:1234", modelName: "m")` does not throw |
| `cloudConfigInvalidURLThrows` | `serverURL: ":::bad-url"` throws `AgentConfigurationError.invalidServerURL` |
| `cloudConfigNilURLThrows` | `serverURL: nil` with `.cloud` throws `AgentConfigurationError.invalidServerURL` |
| `cloudConfigEmptyURLThrows` | `serverURL: ""` throws `AgentConfigurationError.invalidServerURL` |
| `cloudConfigEmptyModelNameThrows` | `modelName: ""` with valid URL throws `AgentConfigurationError.emptyModelName` |
| `cloudConfigZeroTimeoutThrows` | `timeoutSeconds: 0` throws `AgentConfigurationError.invalidTimeout` |
| `cloudConfigNegativeTimeoutThrows` | `timeoutSeconds: -1` throws `AgentConfigurationError.invalidTimeout` |
| `cloudConfigZeroRetriesThrows` | `maxRetries: 0` throws `AgentConfigurationError.invalidMaxRetries` |
| `cloudConfigElevenRetriesThrows` | `maxRetries: 11` throws `AgentConfigurationError.invalidMaxRetries` |
| `onDeviceConfigNoURLRequired` | `executionMode: .onDevice` with nil serverURL and empty modelName does not throw |
| `overridesSupersedEnvVars` | `fromEnvironment(overrides: Overrides(modelName: "override"))` returns config with overridden modelName |

### RetryAndContextTests.swift (sources: RetryWithBackoff.swift, ContextBudget.swift, ContextCompression.swift)

| Test Function | What it verifies |
|---------------|-----------------|
| `isTransportRetryableTimedOut` | `isTransportRetryable(URLError(.timedOut))` returns `true` |
| `isTransportRetryableNetworkConnectionLost` | `isTransportRetryable(URLError(.networkConnectionLost))` returns `true` |
| `isTransportRetryableNotConnectedToInternet` | `isTransportRetryable(URLError(.notConnectedToInternet))` returns `true` |
| `isTransportRetryableNonURLError` | Generic `NSError` returns `false` |
| `retryWithBackoffSucceedsFirstAttempt` | Returns value without retry when operation succeeds immediately |
| `retryWithBackoffRetriesRetryableError` | Retries once on retryable error, succeeds on second attempt |
| `retryWithBackoffExhaustesRetries` | Throws after `maxAttempts` all fail with retryable error |
| `retryWithBackoffNonRetryableRethrowsImmediately` | Non-retryable error is rethrown without retry |
| `retryWithBackoffCallsOnRetryCallback` | `onRetry` callback is called for each failed attempt |
| `contextBudgetTracksTokens` | `record(inputTokens:outputTokens:)` updates `usedTokens` and `remainingTokens` |
| `contextBudgetIsExhausted` | `isExhausted` true when `usedTokens >= maxTokens` |
| `contextBudgetUtilizationPercentage` | `utilizationPercentage` returns correct ratio |
| `contextBudgetReset` | `reset()` sets `usedTokens` back to 0 |
| `slidingWindowCompressorKeepsLastN` | A 10-entry transcript compressed with `keepLast: 3` yields 4 entries (1 summary + 3) |
| `microCompactorTruncatesLongResults` | Tool result > `maxResultLength` gets a `[Truncated:]` suffix |
| `microCompactorPreservesShortResults` | Tool result ≤ `maxResultLength` passes through unchanged |

### ToolSystemTests.swift (sources: AgentToolProtocol.swift, ToolRegistry.swift, LLMToolSupport.swift, ToolListPolicy.swift, DenialTracking.swift, Permission.swift)

| Test Function | What it verifies |
|---------------|-----------------|
| `toolRegistryRegistersAndListsDefinitions` | After `register(MockLLMTool())`, `definitions()` returns 1 item and `toolNames` contains "mock_llm_tool" |
| `toolRegistryIsNotEmptyAfterRegister` | `isEmpty` is `false` after registration |
| `toolRegistryDispatchUnknownToolThrows` | `dispatch(name: "nonexistent", ...)` throws `ToolDispatchError.unknownTool` |
| `toolRegistryIsConcurrencySafeDefault` | `MockLLMTool` registered → `isConcurrencySafe(toolName: "mock_llm_tool")` returns `false` |
| `toolRegistryIsConcurrencySafeTrue` | `ConcurrentMockLLMTool` registered → `isConcurrencySafe(toolName: "concurrent_mock_llm_tool")` returns `true` |
| `agentLLMToolSchemaDerivesFromToolDefinition` | `MockLLMTool.inputSchema.name == "mock_llm_tool"` and `.description` matches |
| `agentLLMToolDispatchReturnsContent` | `dispatch(name: "mock_llm_tool", arguments: "{\"message\":\"hello\"}")` returns `output == "echo:hello"` |
| `agentLLMToolOutputNotDoubleQuoted` | Dispatched output is `"echo:world"`, does not start with `"\""`  — verifies `Output==String` fast path |
| `agentLLMToolConcurrencySafeDefaultsFalse` | `MockLLMTool.isConcurrencySafe == false`; registry confirms same |
| `agentLLMToolConcurrencySafeOverridable` | `ConcurrentMockLLMTool.isConcurrencySafe == true`; registry confirms same |
| `agentLLMToolMultipleToolsInRegistry` | `register(MockLLMTool())` + `register(ConcurrentMockLLMTool())` → `toolNames.count == 2`, both names present |
| `toolListPolicyAllowRule` | `.allow(["goodTool"])` → `evaluate("goodTool")` returns `.allowed` |
| `toolListPolicyDenyRule` | `.deny(["badTool"])` → `evaluate("badTool")` returns `.denied` |
| `toolListPolicyRequireApprovalRule` | `.requireApproval(["gatedTool"])` → returns `.requiresApproval` |
| `toolListPolicyFirstRuleWins` | Rule [.deny(["t"]), .allow(["t"])] → evaluate("t") returns `.denied` |
| `toolListPolicyDefaultAllowsUnknown` | Tool not listed in any rule → `.allowed` by default |
| `denialTrackerIncrementsCount` | After 2 `recordDenial(toolName:)` calls, `denialCount(for:)` returns 2 |
| `denialTrackerThresholdExceeded` | `threshold: 3`, 3 denials → `isThresholdExceeded` returns `true` |
| `denialTrackerNotExceededBelowThreshold` | `threshold: 3`, 2 denials → `isThresholdExceeded` returns `false` |
| `denialTrackerResetOnSuccess` | After 3 denials, `recordSuccess(toolName:)` resets count to 0 |
| `permissionGateAllowsAllowedTool` | Gate with `allow(["goodTool"])` policy → `check("goodTool")` does not throw |
| `permissionGateDeniedToolThrows` | Gate with `deny(["badTool"])` policy → `check("badTool")` throws `PermissionError` |
| `permissionGateRequiresApprovalNoDelegate` | Gate with `requireApproval(["gated"])`, no delegate → throws `PermissionError.noApprovalDelegate` |

### SessionAndTranscriptTests.swift (sources: AgentSession.swift, ObservableTranscript+Harness.swift)

| Test Function | What it verifies |
|---------------|-----------------|
| `codableTranscriptEntryUserMessageRoundTrips` | `CodableTranscriptEntry.userMessage("Hello")` encodes/decodes back to `.userMessage("Hello")` |
| `codableTranscriptEntryAssistantMessageRoundTrips` | `.assistantMessage("Reply")` Codable round-trip |
| `codableTranscriptEntryToolCallRoundTrips` | `.toolCall(name: "echo", arguments: "{}")` Codable round-trip |
| `codableTranscriptEntryToolResultRoundTrips` | `.toolResult(name: "echo", result: "hi")` Codable round-trip |
| `codableTranscriptEntryErrorRoundTrips` | `.error("Something failed")` Codable round-trip |
| `agentSessionEncodesAndDecodes` | `AgentSession` with known fields encodes to JSON and decodes with matching fields |
| `agentSessionPreservesTranscriptEntries` | Session with 3 entries → decoded session has 3 entries |
| `codableTranscriptEntryToTranscriptEntry` | `.userMessage("hi").toTranscriptEntry()` returns `.userMessage("hi")` |
| `observableTranscriptRestoreFromCodable` | `restore(from: [.userMessage("A"), .assistantMessage("B")])` → `entries.count == 2` |

### HooksAndGuardrailsTests.swift (sources: AgentHook.swift, AgentHookPipeline.swift, Guardrails.swift)

| Test Function | What it verifies |
|---------------|-----------------|
| `hookPipelineFiresSubscribedHook` | `ClosureHook(on: [.agentStarted])` receives `.agentStarted` event |
| `hookPipelineSkipsUnsubscribedHook` | Hook subscribed to `.agentCompleted` not called when `.agentStarted` fires |
| `hookPipelineBlockActionReturned` | Hook returning `.block(reason:)` → `fire()` returns `.block` |
| `hookPipelineFirstBlockWins` | Two hooks: first returns `.block`, second never called (counter stays 0) |
| `hookPipelineProceedContinuesToNextHook` | Two subscribed hooks, both `.proceed` → both called |
| `contentFilterDefaultDetectsCreditCard` | `"Card: 4111111111111111"` → `.block` decision |
| `contentFilterDefaultDetectsSSN` | `"SSN: 123-45-6789"` → `.block` decision |
| `contentFilterDefaultDetectsAPIKey` | `"api_key: abcdefghijklmnopqrstuvwx"` (20+ chars) → `.block` decision |
| `contentFilterDefaultDetectsBearerToken` | `"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abcdefghijklmno"` → `.block` decision |
| `contentFilterAllowsCleanText` | `"Hello, how are you?"` → `.allow` decision |
| `contentFilterCustomPatternDetects` | Custom regex pattern detects configured keyword |
| `guardrailPipelineAllowPassesThrough` | Empty pipeline → `.allow` for any input |
| `guardrailPipelineBlockWinsMostRestrictive` | One allow policy + one block policy → result is `.block` |

### ProductionPolishTests.swift (sources: ErrorClassification.swift, ResultTruncation.swift, RateLimiting.swift, SystemPromptBuilder.swift, Caching.swift, ConversationRecovery.swift)

| Test Function | What it verifies |
|---------------|-----------------|
| `classifyAPIErrorAuth` | Error description containing "401" → `APIErrorCategory.auth`, `isRetryable: false` |
| `classifyAPIErrorUnauthorized` | Error description containing "unauthorized" → `.auth` |
| `classifyAPIErrorQuota` | Error description containing "quota" → `.quota`, not retryable |
| `classifyAPIErrorRateLimit` | Error description containing "429" → `.rateLimit`, retryable |
| `classifyAPIErrorServerError` | Error description containing "500" → `.serverError`, retryable |
| `classifyAPIErrorUnknown` | Unrelated error → `.unknown` |
| `resultTruncatorPassesThroughShortText` | String under `maxCharacters` returned unchanged |
| `resultTruncatorTruncatesLongText` | String over `maxCharacters` → contains `[Truncated:]` header |
| `resultTruncatorPreservesLastChars` | Truncated result ends with last `preserveLastCharacters` chars of original |
| `rateLimitStateInitiallyNotInCooldown` | Freshly created `RateLimitState.isInCooldown` is `false` |
| `rateLimitStateEnterCooldown` | After `enterCooldown(duration: .seconds(60))` → `isInCooldown == true` |
| `rateLimitStateConsecutiveHits` | Each `enterCooldown` increments `consecutiveHits` |
| `rateLimitStateRecordSuccessResets` | `recordSuccess()` after cooldown → `isInCooldown == false`, `consecutiveHits == 0` |
| `systemPromptBuilderOrdersByPriority` | Section with `priority: 10` appears before section with `priority: 200` in `build()` output |
| `systemPromptBuilderConcatenatesWithDoubleNewline` | Two sections joined with `\n\n` separator |
| `cacheGetReturnsNilForMissingKey` | `Cache<String, String>` fresh → `get("x")` returns `nil` |
| `cacheSetAndGetReturnsValue` | `set("k", "v")` then `get("k")` returns `"v"` |
| `cacheLRUEvictsLeastRecentlyAccessed` | Capacity 2: after accessing "a", inserting "c" evicts "b" (LRU) |
| `cacheFIFOEvictsFirst` | Capacity 2: insert "a", "b", "c" → "a" evicted (FIFO) |
| `transcriptIntegrityCheckDetectsOrphanedResult` | `[.userMessage, .toolResult]` (no preceding toolCall) → 1 orphanedToolResult violation |
| `transcriptIntegrityCheckDetectsOrphanedCall` | `[.userMessage, .toolCall]` (no following toolResult) → 1 orphanedToolCall violation |
| `transcriptIntegrityCheckPassesValid` | `[.userMessage, .toolCall, .toolResult]` paired correctly → 0 violations |
| `conversationRecoveryRemovesOrphanedResult` | Strategy removes orphaned toolResult from transcript |
| `conversationRecoveryAppendsSyntheticForOrphanedCall` | Strategy appends synthetic error toolResult for orphaned toolCall |
| `recoverTranscriptConvenienceFunction` | `recoverTranscript([.userMessage, .toolResult])` returns 1 violation and repaired transcript |

### AgentRuntimeTests.swift (sources: AgentRuntime.swift)

Mock type defined at file scope:
```swift
actor MockAgent: AgentExecutable {
    var _status: AgentStatus = .idle
    var _transcript: ObservableTranscript = ObservableTranscript()
    var shouldThrow = false
    func execute(goal: String) async throws -> String {
        if shouldThrow { throw AgentLifecycleError.emptyGoal }
        return "mock result"
    }
}
```

| Test Function | What it verifies |
|---------------|-----------------|
| `agentRunThrowsOnEmptyGoal` | `agentRun(agent: mock, goal: "")` throws `AgentLifecycleError.emptyGoal` |
| `agentRunSetsErrorStatusOnEmptyGoal` | After throwing on empty goal, `mock._status` is `.error` |
| `agentRunCompletesSuccessfully` | `agentRun(agent: mock, goal: "hello")` returns `"mock result"` |
| `agentRunSetsCompletedStatus` | After success, `mock._status` case is `.completed` |
| `agentRunSetsErrorStatusOnExecuteFailure` | When `mock.shouldThrow = true`, `mock._status` is `.error` after throw |
| `agentRunWithHooksFiresStartedEvent` | `AgentHookPipeline` receives `.agentStarted` event when `agentRun` called |
| `agentRunWithHooksBlocksWhenHookBlocks` | Hook returning `.block` on `.agentStarted` causes `agentRun` to throw `AgentLifecycleError.blockedByHook` |

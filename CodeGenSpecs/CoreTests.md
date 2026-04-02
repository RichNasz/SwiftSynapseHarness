# Spec: Core Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/CoreTests.swift`

**Sources under test:** `AgentConfiguration.swift`, `AgentToolProtocol.swift`, `ToolRegistry.swift`, `LLMToolSupport.swift`, `AgentRuntime.swift`, `ObservableTranscript+Harness.swift`, `ContextBudget.swift`, `RetryWithBackoff.swift`, `ResultTruncation.swift`, `SystemPromptBuilder.swift`, `Caching.swift`

## Generation Rules

- File header: `// Generated from CodeGenSpecs/CoreTests.md — Do not edit manually. Update spec and re-generate.`
- Framework: Swift Testing (`import Testing`) — NOT XCTest
- Top-level `@Test` functions (no `@Suite` wrappers)
- `async throws` for async assertions; `#expect()` for all assertions
- Pattern-match failures use `Issue.record()`
- Live tests gated with `@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))`

## Mock Types (file scope)

```swift
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

## Test Functions

### AgentConfiguration

| Test | Verifies |
|------|---------|
| `cloudConfigValidURLSucceeds` | `AgentConfiguration(.cloud, serverURL: "http://127.0.0.1:1234", modelName: "m")` does not throw |
| `cloudConfigInvalidURLThrows` | `serverURL: ":::bad-url"` throws `AgentConfigurationError.invalidServerURL` |
| `cloudConfigNilURLThrows` | `serverURL: nil` with `.cloud` throws `AgentConfigurationError.invalidServerURL` |
| `cloudConfigEmptyURLThrows` | `serverURL: ""` throws `AgentConfigurationError.invalidServerURL` |
| `cloudConfigEmptyModelNameThrows` | `modelName: ""` with valid URL throws `AgentConfigurationError.emptyModelName` |
| `cloudConfigZeroTimeoutThrows` | `timeoutSeconds: 0` throws `AgentConfigurationError.invalidTimeout` |
| `cloudConfigNegativeTimeoutThrows` | `timeoutSeconds: -1` throws `AgentConfigurationError.invalidTimeout` |
| `cloudConfigZeroRetriesThrows` | `maxRetries: 0` throws `AgentConfigurationError.invalidMaxRetries` |
| `cloudConfigElevenRetriesThrows` | `maxRetries: 11` throws `AgentConfigurationError.invalidMaxRetries` |
| `onDeviceConfigNoURLRequired` | `.onDevice` with nil serverURL and empty modelName does not throw |
| `overridesSupersedEnvVars` | `fromEnvironment(overrides: Overrides(modelName: "override"))` returns config with overridden modelName |

### ToolRegistry / AgentToolProtocol / AgentLLMTool

| Test | Verifies |
|------|---------|
| `toolRegistryRegistersAndListsDefinitions` | After `register(MockLLMTool())`, `definitions()` returns 1 item and `toolNames` contains `"mock_llm_tool"` |
| `toolRegistryIsNotEmptyAfterRegister` | `isEmpty` is `false` after registration |
| `toolRegistryDispatchUnknownToolThrows` | `dispatch(name: "nonexistent", ...)` throws `ToolDispatchError.unknownTool` |
| `toolRegistryIsConcurrencySafeDefault` | `MockLLMTool` → `isConcurrencySafe(toolName: "mock_llm_tool")` returns `false` |
| `toolRegistryIsConcurrencySafeTrue` | `ConcurrentMockLLMTool` → `isConcurrencySafe(toolName: "concurrent_mock_llm_tool")` returns `true` |
| `agentLLMToolSchemaDerivesFromToolDefinition` | `MockLLMTool.inputSchema.name == "mock_llm_tool"` and `.description` matches |
| `agentLLMToolDispatchReturnsContent` | `dispatch(name: "mock_llm_tool", arguments: "{\"message\":\"hello\"}")` returns `"echo:hello"` |
| `agentLLMToolOutputNotDoubleQuoted` | Dispatched output is `"echo:world"`, does not start with `"\""` — verifies `Output==String` fast path |
| `agentLLMToolConcurrencySafeDefaultsFalse` | `MockLLMTool.isConcurrencySafe == false` |
| `agentLLMToolConcurrencySafeOverridable` | `ConcurrentMockLLMTool.isConcurrencySafe == true` |
| `agentLLMToolMultipleToolsInRegistry` | Register both mocks → `toolNames.count == 2`, both names present |

### AgentRuntime

| Test | Verifies |
|------|---------|
| `agentRunThrowsOnEmptyGoal` | `agentRun(agent: mock, goal: "")` throws `AgentLifecycleError.emptyGoal` |
| `agentRunSetsErrorStatusOnEmptyGoal` | After empty goal, `mock._status` is `.error` |
| `agentRunCompletesSuccessfully` | `agentRun(agent: mock, goal: "hello")` returns `"mock result"` |
| `agentRunSetsCompletedStatus` | After success, `mock._status` case is `.completed` |
| `agentRunSetsErrorStatusOnExecuteFailure` | `mock.shouldThrow = true` → `mock._status` is `.error` after throw |
| `agentRunWithHooksFiresStartedEvent` | `AgentHookPipeline` receives `.agentStarted` event when `agentRun` called |
| `agentRunWithHooksBlocksWhenHookBlocks` | Hook returning `.block` on `.agentStarted` → `agentRun` throws `AgentLifecycleError.blockedByHook` |

### ContextBudget / RetryWithBackoff

| Test | Verifies |
|------|---------|
| `isTransportRetryableTimedOut` | `isTransportRetryable(URLError(.timedOut))` returns `true` |
| `isTransportRetryableNetworkConnectionLost` | `isTransportRetryable(URLError(.networkConnectionLost))` returns `true` |
| `isTransportRetryableNotConnectedToInternet` | `isTransportRetryable(URLError(.notConnectedToInternet))` returns `true` |
| `isTransportRetryableNonURLError` | Generic `NSError` returns `false` |
| `retryWithBackoffSucceedsFirstAttempt` | Returns value without retry when operation succeeds immediately |
| `retryWithBackoffRetriesRetryableError` | Retries once on retryable error, succeeds on second attempt |
| `retryWithBackoffExhaustsRetries` | Throws after `maxAttempts` all fail with retryable error |
| `retryWithBackoffNonRetryableRethrowsImmediately` | Non-retryable error rethrown without retry |
| `retryWithBackoffCallsOnRetryCallback` | `onRetry` callback called for each failed attempt |
| `contextBudgetTracksTokens` | `record(inputTokens:outputTokens:)` updates `usedTokens` and `remainingTokens` |
| `contextBudgetIsExhausted` | `isExhausted` true when `usedTokens >= maxTokens` |
| `contextBudgetUtilizationPercentage` | `utilizationPercentage` returns correct ratio |
| `contextBudgetReset` | `reset()` sets `usedTokens` back to 0 |
| `slidingWindowCompressorKeepsLastN` | 10-entry transcript compressed with `keepLast: 3` yields 4 entries (1 summary + 3) |

### ResultTruncation / SystemPromptBuilder / Caching

| Test | Verifies |
|------|---------|
| `resultTruncatorPassesThroughShortText` | String under `maxCharacters` returned unchanged |
| `resultTruncatorTruncatesLongText` | String over `maxCharacters` contains `[Truncated:]` header |
| `resultTruncatorPreservesLastChars` | Truncated result ends with last `preserveLastCharacters` chars of original |
| `systemPromptBuilderOrdersByPriority` | Section with `priority: 10` appears before section with `priority: 200` in `build()` output |
| `systemPromptBuilderConcatenatesWithDoubleNewline` | Two sections joined with `\n\n` separator |
| `cacheGetReturnsNilForMissingKey` | Fresh `Cache<String, String>` → `get("x")` returns `nil` |
| `cacheSetAndGetReturnsValue` | `set("k", "v")` then `get("k")` returns `"v"` |
| `cacheLRUEvictsLeastRecentlyAccessed` | Capacity 2: after accessing "a", inserting "c" evicts "b" (LRU) |
| `cacheFIFOEvictsFirst` | Capacity 2: insert "a", "b", "c" → "a" evicted (FIFO) |

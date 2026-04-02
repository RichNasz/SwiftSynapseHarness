// Generated from CodeGenSpecs/CoreTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import Foundation
import SwiftSynapseHarness

// MARK: - Mock Types

private struct MockLLMTool: AgentLLMTool {
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

private struct ConcurrentMockLLMTool: AgentLLMTool {
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

private actor MockAgent: AgentExecutable {
    var _status: AgentStatus = .idle
    var _transcript: ObservableTranscript = ObservableTranscript()
    var shouldThrow = false
    func execute(goal: String) async throws -> String {
        if shouldThrow { throw AgentLifecycleError.emptyGoal }
        return "mock result"
    }
    func setShouldThrow(_ value: Bool) { shouldThrow = value }
}

private final class SyncCounter: @unchecked Sendable {
    private var _count = 0
    private let lock = NSLock()
    var count: Int { lock.withLock { _count } }
    func increment() { lock.withLock { _count += 1 } }
}

private actor HookTracker {
    var startedGoal: String? = nil
    func recordStarted(goal: String) { startedGoal = goal }
}

private actor Counter {
    var count = 0
    func increment() { count += 1 }
}

private struct RetryError: Error {}

// MARK: - AgentConfiguration Tests

@Test func cloudConfigValidURLSucceeds() throws {
    _ = try AgentConfiguration(
        executionMode: .cloud,
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "test-model"
    )
}

@Test func cloudConfigInvalidURLThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(executionMode: .cloud, serverURL: ":::bad-url", modelName: "test-model")
    }
}

@Test func cloudConfigNilURLThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(executionMode: .cloud, serverURL: nil, modelName: "test-model")
    }
}

@Test func cloudConfigEmptyURLThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(executionMode: .cloud, serverURL: "", modelName: "test-model")
    }
}

@Test func cloudConfigEmptyModelNameThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(executionMode: .cloud, serverURL: "http://127.0.0.1:1234", modelName: "")
    }
}

@Test func cloudConfigZeroTimeoutThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud, serverURL: "http://127.0.0.1:1234",
            modelName: "test-model", timeoutSeconds: 0)
    }
}

@Test func cloudConfigNegativeTimeoutThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud, serverURL: "http://127.0.0.1:1234",
            modelName: "test-model", timeoutSeconds: -1)
    }
}

@Test func cloudConfigZeroRetriesThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud, serverURL: "http://127.0.0.1:1234",
            modelName: "test-model", maxRetries: 0)
    }
}

@Test func cloudConfigElevenRetriesThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud, serverURL: "http://127.0.0.1:1234",
            modelName: "test-model", maxRetries: 11)
    }
}

@Test func onDeviceConfigNoURLRequired() throws {
    _ = try AgentConfiguration(executionMode: .onDevice, serverURL: nil, modelName: "")
}

@Test func overridesSupersedEnvVars() throws {
    let config = try AgentConfiguration.fromEnvironment(
        overrides: AgentConfiguration.Overrides(
            serverURL: "http://127.0.0.1:1234",
            modelName: "override-model"
        )
    )
    #expect(config.modelName == "override-model")
    #expect(config.serverURL == "http://127.0.0.1:1234")
}

// MARK: - ToolRegistry / AgentToolProtocol / AgentLLMTool Tests

@Test func toolRegistryRegistersAndListsDefinitions() {
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    #expect(registry.definitions().count == 1)
    #expect(registry.toolNames.contains("mock_llm_tool"))
}

@Test func toolRegistryIsNotEmptyAfterRegister() {
    let registry = ToolRegistry()
    #expect(registry.isEmpty == true)
    registry.register(MockLLMTool())
    #expect(registry.isEmpty == false)
}

@Test func toolRegistryDispatchUnknownToolThrows() async throws {
    let registry = ToolRegistry()
    await #expect(throws: ToolDispatchError.self) {
        _ = try await registry.dispatch(name: "nonexistent", callId: "c1", arguments: "{}")
    }
}

@Test func toolRegistryIsConcurrencySafeDefault() {
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    #expect(registry.isConcurrencySafe(toolName: "mock_llm_tool") == false)
}

@Test func toolRegistryIsConcurrencySafeTrue() {
    let registry = ToolRegistry()
    registry.register(ConcurrentMockLLMTool())
    #expect(registry.isConcurrencySafe(toolName: "concurrent_mock_llm_tool") == true)
}

@Test func agentLLMToolSchemaDerivesFromToolDefinition() {
    let schema = MockLLMTool.inputSchema
    #expect(schema.name == "mock_llm_tool")
    #expect(schema.description == "A mock tool for testing AgentLLMTool.")
}

@Test func agentLLMToolDispatchReturnsContent() async throws {
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    let result = try await registry.dispatch(name: "mock_llm_tool", callId: "c1", arguments: "{\"message\":\"hello\"}")
    #expect(result.output == "echo:hello")
    #expect(result.success == true)
}

@Test func agentLLMToolOutputNotDoubleQuoted() async throws {
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    let result = try await registry.dispatch(name: "mock_llm_tool", callId: "c2", arguments: "{\"message\":\"world\"}")
    #expect(result.output == "echo:world")
    #expect(!result.output.hasPrefix("\""))
}

@Test func agentLLMToolConcurrencySafeDefaultsFalse() {
    #expect(MockLLMTool.isConcurrencySafe == false)
}

@Test func agentLLMToolConcurrencySafeOverridable() {
    #expect(ConcurrentMockLLMTool.isConcurrencySafe == true)
}

@Test func agentLLMToolMultipleToolsInRegistry() {
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    registry.register(ConcurrentMockLLMTool())
    #expect(registry.toolNames.count == 2)
    #expect(registry.toolNames.contains("mock_llm_tool"))
    #expect(registry.toolNames.contains("concurrent_mock_llm_tool"))
}

// MARK: - AgentRuntime Tests

@Test func agentRunThrowsOnEmptyGoal() async throws {
    let mock = MockAgent()
    await #expect(throws: AgentLifecycleError.self) {
        try await agentRun(agent: mock, goal: "")
    }
}

@Test func agentRunSetsErrorStatusOnEmptyGoal() async throws {
    let mock = MockAgent()
    _ = try? await agentRun(agent: mock, goal: "")
    let status = await mock._status
    guard case .error = status else {
        Issue.record("Expected .error status after empty goal rejection")
        return
    }
}

@Test func agentRunCompletesSuccessfully() async throws {
    let mock = MockAgent()
    let result = try await agentRun(agent: mock, goal: "hello")
    #expect(result == "mock result")
}

@Test func agentRunSetsCompletedStatus() async throws {
    let mock = MockAgent()
    _ = try await agentRun(agent: mock, goal: "hello")
    let status = await mock._status
    guard case .completed = status else {
        Issue.record("Expected .completed status after successful run")
        return
    }
}

@Test func agentRunSetsErrorStatusOnExecuteFailure() async throws {
    let mock = MockAgent()
    await mock.setShouldThrow(true)
    _ = try? await agentRun(agent: mock, goal: "trigger error")
    let status = await mock._status
    guard case .error = status else {
        Issue.record("Expected .error status when execute() throws")
        return
    }
}

@Test func agentRunWithHooksFiresStartedEvent() async throws {
    let mock = MockAgent()
    let pipeline = AgentHookPipeline()
    let tracker = HookTracker()
    let hook = ClosureHook(on: [.agentStarted]) { event in
        if case .agentStarted(let goal) = event { await tracker.recordStarted(goal: goal) }
        return .proceed
    }
    await pipeline.add(hook)
    _ = try await agentRun(agent: mock, goal: "hook test", hooks: pipeline)
    #expect(await tracker.startedGoal == "hook test")
}

@Test func agentRunWithHooksBlocksWhenHookBlocks() async throws {
    let mock = MockAgent()
    let pipeline = AgentHookPipeline()
    let blockHook = ClosureHook(on: [.agentStarted]) { _ in .block(reason: "test block") }
    await pipeline.add(blockHook)
    await #expect(throws: AgentLifecycleError.self) {
        try await agentRun(agent: mock, goal: "should be blocked", hooks: pipeline)
    }
}

// MARK: - ContextBudget / RetryWithBackoff Tests

@Test func isTransportRetryableTimedOut() {
    #expect(isTransportRetryable(URLError(.timedOut)) == true)
}

@Test func isTransportRetryableNetworkConnectionLost() {
    #expect(isTransportRetryable(URLError(.networkConnectionLost)) == true)
}

@Test func isTransportRetryableNotConnectedToInternet() {
    #expect(isTransportRetryable(URLError(.notConnectedToInternet)) == true)
}

@Test func isTransportRetryableNonURLError() {
    #expect(isTransportRetryable(NSError(domain: "test", code: 42)) == false)
}

@Test func retryWithBackoffSucceedsFirstAttempt() async throws {
    let counter = Counter()
    let result = try await retryWithBackoff(maxAttempts: 3, baseDelay: .milliseconds(1), isRetryable: { _ in true }) {
        await counter.increment()
        return "success"
    }
    #expect(result == "success")
    #expect(await counter.count == 1)
}

@Test func retryWithBackoffRetriesRetryableError() async throws {
    let counter = Counter()
    let result = try await retryWithBackoff(maxAttempts: 3, baseDelay: .milliseconds(1), isRetryable: { _ in true }) {
        let current = await counter.count
        await counter.increment()
        if current < 1 { throw RetryError() }
        return "success-on-second"
    }
    #expect(result == "success-on-second")
    #expect(await counter.count == 2)
}

@Test func retryWithBackoffExhaustsRetries() async throws {
    let counter = Counter()
    do {
        _ = try await retryWithBackoff(maxAttempts: 3, baseDelay: .milliseconds(1), isRetryable: { _ in true }) {
            await counter.increment()
            throw RetryError()
        }
        Issue.record("Expected error to be thrown")
    } catch {
        #expect(error is RetryError)
    }
    #expect(await counter.count == 3)
}

@Test func retryWithBackoffNonRetryableRethrowsImmediately() async throws {
    let counter = Counter()
    do {
        _ = try await retryWithBackoff(maxAttempts: 5, baseDelay: .milliseconds(1), isRetryable: { _ in false }) {
            await counter.increment()
            throw RetryError()
        }
        Issue.record("Expected error to be thrown")
    } catch {
        #expect(error is RetryError)
    }
    #expect(await counter.count == 1)
}

@Test func retryWithBackoffCallsOnRetryCallback() async throws {
    let counter = SyncCounter()
    do {
        _ = try await retryWithBackoff(
            maxAttempts: 3,
            baseDelay: .milliseconds(1),
            isRetryable: { _ in true },
            onRetry: { _, _ in counter.increment() }
        ) {
            throw RetryError()
        }
    } catch {}
    // onRetry is called after attempts 1 and 2 (not after the final failing attempt)
    #expect(counter.count == 2)
}

@Test func contextBudgetTracksTokens() {
    var budget = ContextBudget(maxTokens: 1000)
    budget.record(inputTokens: 200, outputTokens: 300)
    #expect(budget.usedTokens == 500)
    #expect(budget.remainingTokens == 500)
}

@Test func contextBudgetIsExhausted() {
    var budget = ContextBudget(maxTokens: 100)
    budget.record(inputTokens: 50, outputTokens: 50)
    #expect(budget.isExhausted == true)
}

@Test func contextBudgetUtilizationPercentage() {
    var budget = ContextBudget(maxTokens: 100)
    budget.record(inputTokens: 25, outputTokens: 25)
    #expect(abs(budget.utilizationPercentage - 0.5) < 0.001)
}

@Test func contextBudgetReset() {
    var budget = ContextBudget(maxTokens: 100)
    budget.record(inputTokens: 80, outputTokens: 0)
    budget.reset()
    #expect(budget.usedTokens == 0)
    #expect(budget.remainingTokens == 100)
    #expect(budget.isExhausted == false)
}

@Test func slidingWindowCompressorKeepsLastN() async throws {
    let compressor = SlidingWindowCompressor(keepLast: 3)
    let entries: [TranscriptEntry] = (0..<10).map { .userMessage("msg \($0)") }
    let budget = ContextBudget(maxTokens: 1000)
    let result = try await compressor.compress(entries: entries, budget: budget)
    // 1 summary entry + 3 kept entries
    #expect(result.count == 4)
    if case .assistantMessage(let text) = result[0] {
        #expect(text.contains("Context compressed"))
    } else {
        Issue.record("Expected summary assistantMessage as first entry")
    }
}

// MARK: - ResultTruncation / SystemPromptBuilder / Caching Tests

@Test func resultTruncatorPassesThroughShortText() {
    let policy = TruncationPolicy(maxCharacters: 1000, preserveLastCharacters: 100)
    let short = "This is a short string"
    #expect(ResultTruncator.truncate(short, policy: policy) == short)
}

@Test func resultTruncatorTruncatesLongText() {
    let policy = TruncationPolicy(maxCharacters: 50, preserveLastCharacters: 20)
    let result = ResultTruncator.truncate(String(repeating: "a", count: 200), policy: policy)
    #expect(result.contains("[Truncated:"))
}

@Test func resultTruncatorPreservesLastChars() {
    let policy = TruncationPolicy(maxCharacters: 10, preserveLastCharacters: 5)
    let result = ResultTruncator.truncate("AAAAAAAAABBBBB", policy: policy)
    #expect(result.hasSuffix("BBBBB"))
}

@Test func systemPromptBuilderOrdersByPriority() async throws {
    let builder = SystemPromptBuilder()
    await builder.addSection(SystemPromptSection(id: "low", content: "low priority section", priority: 10))
    await builder.addSection(SystemPromptSection(id: "high", content: "high priority section", priority: 200))
    let prompt = try await builder.build()
    guard let lowRange = prompt.range(of: "low priority section"),
          let highRange = prompt.range(of: "high priority section") else {
        Issue.record("Both sections should appear in the built prompt")
        return
    }
    #expect(lowRange.lowerBound < highRange.lowerBound)
}

@Test func systemPromptBuilderConcatenatesWithDoubleNewline() async throws {
    let builder = SystemPromptBuilder()
    await builder.addSection(SystemPromptSection(id: "a", content: "Section A", priority: 1))
    await builder.addSection(SystemPromptSection(id: "b", content: "Section B", priority: 2))
    let prompt = try await builder.build()
    #expect(prompt.contains("Section A\n\nSection B"))
}

@Test func cacheGetReturnsNilForMissingKey() async {
    let cache = Cache<String, String>(policy: CachePolicy(maxEntries: 10, ttl: .seconds(300), eviction: .lru))
    #expect(await cache.get("nonexistent") == nil)
}

@Test func cacheSetAndGetReturnsValue() async {
    let cache = Cache<String, String>(policy: CachePolicy(maxEntries: 10, ttl: .seconds(300), eviction: .lru))
    await cache.set("key", "value")
    #expect(await cache.get("key") == "value")
}

@Test func cacheLRUEvictsLeastRecentlyAccessed() async {
    let cache = Cache<String, String>(policy: CachePolicy(maxEntries: 2, ttl: .seconds(300), eviction: .lru))
    await cache.set("a", "val_a")
    await cache.set("b", "val_b")
    _ = await cache.get("a")
    await cache.set("c", "val_c")
    #expect(await cache.get("a") != nil)
    #expect(await cache.get("b") == nil)
    #expect(await cache.get("c") != nil)
}

@Test func cacheFIFOEvictsFirst() async {
    let cache = Cache<String, String>(policy: CachePolicy(maxEntries: 2, ttl: .seconds(300), eviction: .fifo))
    await cache.set("a", "val_a")
    await cache.set("b", "val_b")
    await cache.set("c", "val_c")
    #expect(await cache.get("a") == nil)
    #expect(await cache.get("b") != nil)
    #expect(await cache.get("c") != nil)
}

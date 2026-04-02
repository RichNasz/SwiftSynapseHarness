// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

// MARK: - Mock Tools

private struct MockLLMTool: AgentLLMTool {
    struct Arguments: LLMToolArguments {
        let message: String
        static var jsonSchema: JSONSchemaValue {
            .object(
                properties: [("message", .string(description: "A test message"))],
                required: ["message"]
            )
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
            .object(
                properties: [("value", .string(description: "A value"))],
                required: ["value"]
            )
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

// MARK: - ToolRegistry Tests

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
        _ = try await registry.dispatch(
            name: "nonexistent",
            callId: "c1",
            arguments: "{}"
        )
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

// MARK: - AgentLLMTool Tests

@Test func agentLLMToolSchemaDerivesFromToolDefinition() {
    let schema = MockLLMTool.inputSchema
    #expect(schema.name == "mock_llm_tool")
    #expect(schema.description == "A mock tool for testing AgentLLMTool.")
}

@Test func agentLLMToolDispatchReturnsContent() async throws {
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    let result = try await registry.dispatch(
        name: "mock_llm_tool",
        callId: "c1",
        arguments: "{\"message\":\"hello\"}"
    )
    #expect(result.output == "echo:hello")
    #expect(result.success == true)
    #expect(result.name == "mock_llm_tool")
    #expect(result.callId == "c1")
}

@Test func agentLLMToolOutputNotDoubleQuoted() async throws {
    // Verifies AnyAgentTool's Output==String fast path: content is returned as-is,
    // not JSON-encoded (which would wrap it in extra quotes).
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    let result = try await registry.dispatch(
        name: "mock_llm_tool",
        callId: "c2",
        arguments: "{\"message\":\"world\"}"
    )
    #expect(result.output == "echo:world")
    #expect(!result.output.hasPrefix("\""))
}

@Test func agentLLMToolConcurrencySafeDefaultsFalse() {
    #expect(MockLLMTool.isConcurrencySafe == false)
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    #expect(registry.isConcurrencySafe(toolName: "mock_llm_tool") == false)
}

@Test func agentLLMToolConcurrencySafeOverridable() {
    #expect(ConcurrentMockLLMTool.isConcurrencySafe == true)
    let registry = ToolRegistry()
    registry.register(ConcurrentMockLLMTool())
    #expect(registry.isConcurrencySafe(toolName: "concurrent_mock_llm_tool") == true)
}

@Test func agentLLMToolMultipleToolsInRegistry() {
    let registry = ToolRegistry()
    registry.register(MockLLMTool())
    registry.register(ConcurrentMockLLMTool())
    #expect(registry.toolNames.count == 2)
    #expect(registry.toolNames.contains("mock_llm_tool"))
    #expect(registry.toolNames.contains("concurrent_mock_llm_tool"))
}

// MARK: - ToolListPolicy Tests

@Test func toolListPolicyAllowRule() async {
    let policy = ToolListPolicy(rules: [.allow(["goodTool"])])
    let result = await policy.evaluate(toolName: "goodTool", arguments: "{}")
    guard case .allowed = result else {
        Issue.record("Expected .allowed for goodTool")
        return
    }
}

@Test func toolListPolicyDenyRule() async {
    let policy = ToolListPolicy(rules: [.deny(["badTool"])])
    let result = await policy.evaluate(toolName: "badTool", arguments: "{}")
    guard case .denied = result else {
        Issue.record("Expected .denied for badTool")
        return
    }
}

@Test func toolListPolicyRequireApprovalRule() async {
    let policy = ToolListPolicy(rules: [.requireApproval(["gatedTool"])])
    let result = await policy.evaluate(toolName: "gatedTool", arguments: "{}")
    guard case .requiresApproval = result else {
        Issue.record("Expected .requiresApproval for gatedTool")
        return
    }
}

@Test func toolListPolicyFirstRuleWins() async {
    let policy = ToolListPolicy(rules: [
        .deny(["conflicted"]),
        .allow(["conflicted"]),
    ])
    let result = await policy.evaluate(toolName: "conflicted", arguments: "{}")
    guard case .denied = result else {
        Issue.record("Expected .denied — first matching rule should win")
        return
    }
}

@Test func toolListPolicyDefaultAllowsUnknown() async {
    let policy = ToolListPolicy(rules: [.deny(["badTool"])])
    let result = await policy.evaluate(toolName: "unknownTool", arguments: "{}")
    guard case .allowed = result else {
        Issue.record("Expected .allowed for unlisted tool")
        return
    }
}

// MARK: - DenialTracker Tests

@Test func denialTrackerIncrementsCount() async {
    let tracker = DenialTracker(threshold: 5)
    await tracker.recordDenial(toolName: "t")
    await tracker.recordDenial(toolName: "t")
    #expect(await tracker.denialCount(for: "t") == 2)
}

@Test func denialTrackerThresholdExceeded() async {
    let tracker = DenialTracker(threshold: 3)
    #expect(await tracker.isThresholdExceeded(toolName: "t") == false)
    await tracker.recordDenial(toolName: "t")
    await tracker.recordDenial(toolName: "t")
    await tracker.recordDenial(toolName: "t")
    #expect(await tracker.isThresholdExceeded(toolName: "t") == true)
}

@Test func denialTrackerNotExceededBelowThreshold() async {
    let tracker = DenialTracker(threshold: 3)
    await tracker.recordDenial(toolName: "t")
    await tracker.recordDenial(toolName: "t")
    #expect(await tracker.isThresholdExceeded(toolName: "t") == false)
}

@Test func denialTrackerResetOnSuccess() async {
    let tracker = DenialTracker(threshold: 3)
    await tracker.recordDenial(toolName: "t")
    await tracker.recordDenial(toolName: "t")
    await tracker.recordDenial(toolName: "t")
    #expect(await tracker.isThresholdExceeded(toolName: "t") == true)
    await tracker.recordSuccess(toolName: "t")
    #expect(await tracker.denialCount(for: "t") == 0)
    #expect(await tracker.isThresholdExceeded(toolName: "t") == false)
}

@Test func denialTrackerTracksPerToolIndependently() async {
    let tracker = DenialTracker(threshold: 2)
    await tracker.recordDenial(toolName: "toolA")
    await tracker.recordDenial(toolName: "toolA")
    #expect(await tracker.isThresholdExceeded(toolName: "toolA") == true)
    #expect(await tracker.isThresholdExceeded(toolName: "toolB") == false)
}

// MARK: - PermissionGate Tests

@Test func permissionGateAllowsAllowedTool() async throws {
    let gate = PermissionGate()
    await gate.addPolicy(ToolListPolicy(rules: [.allow(["goodTool"])]))
    // Should not throw
    try await gate.check(toolName: "goodTool", arguments: "{}")
}

@Test func permissionGateDeniedToolThrows() async throws {
    let gate = PermissionGate()
    await gate.addPolicy(ToolListPolicy(rules: [.deny(["badTool"])]))
    await #expect(throws: PermissionError.self) {
        try await gate.check(toolName: "badTool", arguments: "{}")
    }
}

@Test func permissionGateRequiresApprovalNoDelegate() async throws {
    let gate = PermissionGate()
    await gate.addPolicy(ToolListPolicy(rules: [.requireApproval(["gatedTool"])]))
    // No approval delegate set — should throw .noApprovalDelegate
    await #expect(throws: PermissionError.self) {
        try await gate.check(toolName: "gatedTool", arguments: "{}")
    }
}

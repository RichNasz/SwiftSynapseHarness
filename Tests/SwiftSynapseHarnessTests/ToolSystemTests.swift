// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

// MARK: - Mock Tools

private struct EchoTool: AgentToolProtocol {
    struct Input: Codable, Sendable { let text: String }
    typealias Output = String

    static let name = "echo"
    static let description = "Echoes input text"
    static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [("text", .string(description: "Text to echo"))],
                required: ["text"]
            ),
            strict: true
        )
    }
    func execute(input: Input) async throws -> String { input.text }
}

private struct ConcurrentEchoTool: AgentToolProtocol {
    struct Input: Codable, Sendable { let text: String }
    typealias Output = String

    static let name = "concurrentEcho"
    static let description = "Concurrent-safe echo"
    static let isConcurrencySafe = true
    static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [("text", .string(description: "Text"))],
                required: ["text"]
            ),
            strict: true
        )
    }
    func execute(input: Input) async throws -> String { input.text }
}

// MARK: - ToolRegistry Tests

@Test func toolRegistryRegistersAndListsDefinitions() {
    let registry = ToolRegistry()
    registry.register(EchoTool())
    #expect(registry.definitions().count == 1)
    #expect(registry.toolNames.contains("echo"))
}

@Test func toolRegistryIsNotEmptyAfterRegister() {
    let registry = ToolRegistry()
    #expect(registry.isEmpty == true)
    registry.register(EchoTool())
    #expect(registry.isEmpty == false)
}

@Test func toolRegistryDispatchEchoTool() async throws {
    let registry = ToolRegistry()
    registry.register(EchoTool())
    let result = try await registry.dispatch(
        name: "echo",
        callId: "c1",
        arguments: "{\"text\":\"hello\"}"
    )
    #expect(result.output == "hello")
    #expect(result.success == true)
    #expect(result.name == "echo")
    #expect(result.callId == "c1")
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
    registry.register(EchoTool())
    #expect(registry.isConcurrencySafe(toolName: "echo") == false)
}

@Test func toolRegistryIsConcurrencySafeTrue() {
    let registry = ToolRegistry()
    registry.register(ConcurrentEchoTool())
    #expect(registry.isConcurrencySafe(toolName: "concurrentEcho") == true)
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

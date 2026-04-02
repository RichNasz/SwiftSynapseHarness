// Generated from CodeGenSpecs/SafetyTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

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
    let policy = ToolListPolicy(rules: [.deny(["conflicted"]), .allow(["conflicted"])])
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
    await tracker.recordSuccess(toolName: "t")
    #expect(await tracker.denialCount(for: "t") == 0)
    #expect(await tracker.isThresholdExceeded(toolName: "t") == false)
}

// MARK: - PermissionGate Tests

@Test func permissionGateAllowsAllowedTool() async throws {
    let gate = PermissionGate()
    await gate.addPolicy(ToolListPolicy(rules: [.allow(["goodTool"])]))
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
    await #expect(throws: PermissionError.self) {
        try await gate.check(toolName: "gatedTool", arguments: "{}")
    }
}

// MARK: - ContentFilter / Guardrails Tests

@Test func contentFilterDefaultDetectsCreditCard() async {
    let filter = ContentFilter.default
    let decision = await filter.evaluate(input: .userInput(text: "Card: 4111111111111111"))
    guard case .block = decision else {
        Issue.record("Expected .block for credit card number")
        return
    }
}

@Test func contentFilterDefaultDetectsSSN() async {
    let filter = ContentFilter.default
    let decision = await filter.evaluate(input: .userInput(text: "SSN: 123-45-6789"))
    guard case .block = decision else {
        Issue.record("Expected .block for SSN")
        return
    }
}

@Test func contentFilterDefaultDetectsAPIKey() async {
    let filter = ContentFilter.default
    let decision = await filter.evaluate(input: .userInput(text: "api_key: abcdefghijklmnopqrstuvwxyz12345"))
    guard case .block = decision else {
        Issue.record("Expected .block for API key pattern")
        return
    }
}

@Test func contentFilterDefaultDetectsBearerToken() async {
    let filter = ContentFilter.default
    let decision = await filter.evaluate(
        input: .userInput(text: "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abcdefghijklmno")
    )
    guard case .block = decision else {
        Issue.record("Expected .block for bearer token")
        return
    }
}

@Test func contentFilterAllowsCleanText() async {
    let filter = ContentFilter.default
    let decision = await filter.evaluate(input: .userInput(text: "Hello, how are you?"))
    guard case .allow = decision else {
        Issue.record("Expected .allow for clean text")
        return
    }
}

@Test func contentFilterCustomPatternDetects() async {
    let pattern = ContentFilter.Pattern(name: "test_keyword", regex: "FORBIDDEN_WORD", risk: .high)
    let filter = ContentFilter(name: "CustomFilter", patterns: [pattern])
    let decision = await filter.evaluate(input: .userInput(text: "This contains FORBIDDEN_WORD in it"))
    guard case .block = decision else {
        Issue.record("Expected .block for custom pattern match")
        return
    }
}

@Test func guardrailPipelineAllowPassesThrough() async {
    let pipeline = GuardrailPipeline()
    let (decision, _) = await pipeline.evaluate(input: .userInput(text: "hello"))
    guard case .allow = decision else {
        Issue.record("Expected .allow from empty pipeline")
        return
    }
}

@Test func guardrailPipelineBlockWinsMostRestrictive() async {
    let pipeline = GuardrailPipeline()

    struct AllowAllPolicy: GuardrailPolicy {
        let name = "AllowAll"
        func evaluate(input: GuardrailInput) async -> GuardrailDecision { .allow }
    }
    struct BlockAllPolicy: GuardrailPolicy {
        let name = "BlockAll"
        func evaluate(input: GuardrailInput) async -> GuardrailDecision { .block(reason: "always blocked") }
    }

    await pipeline.add(AllowAllPolicy())
    await pipeline.add(BlockAllPolicy())
    let (decision, _) = await pipeline.evaluate(input: .userInput(text: "anything"))
    guard case .block = decision else {
        Issue.record("Expected .block — most restrictive decision should win")
        return
    }
}

// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

// MARK: - Helpers for tracking state in @Sendable closures

private actor EventTracker {
    var triggered = false
    var count = 0
    var lastGoal: String? = nil

    func trigger() { triggered = true }
    func increment() { count += 1 }
    func record(goal: String) { lastGoal = goal }
}

// MARK: - AgentHookPipeline Tests

@Test func hookPipelineFiresSubscribedHook() async {
    let pipeline = AgentHookPipeline()
    let tracker = EventTracker()

    let hook = ClosureHook(on: [.agentStarted]) { event in
        if case .agentStarted = event { await tracker.trigger() }
        return .proceed
    }
    await pipeline.add(hook)
    await pipeline.fire(.agentStarted(goal: "test"))
    #expect(await tracker.triggered == true)
}

@Test func hookPipelineSkipsUnsubscribedHook() async {
    let pipeline = AgentHookPipeline()
    let tracker = EventTracker()

    let hook = ClosureHook(on: [.agentCompleted]) { _ in
        await tracker.trigger()
        return .proceed
    }
    await pipeline.add(hook)
    // Fire a different event kind — hook should not be called
    await pipeline.fire(.agentStarted(goal: "test"))
    #expect(await tracker.triggered == false)
}

@Test func hookPipelineBlockActionReturned() async {
    let pipeline = AgentHookPipeline()
    let blockHook = ClosureHook(on: [.agentStarted]) { _ in
        .block(reason: "blocked for test")
    }
    await pipeline.add(blockHook)
    let action = await pipeline.fire(.agentStarted(goal: "test"))
    guard case .block(let reason) = action else {
        Issue.record("Expected .block action from pipeline")
        return
    }
    #expect(reason == "blocked for test")
}

@Test func hookPipelineFirstBlockWins() async {
    let pipeline = AgentHookPipeline()
    let tracker = EventTracker()

    let blockHook = ClosureHook(on: [.agentStarted]) { _ in
        .block(reason: "first hook blocks")
    }
    let secondHook = ClosureHook(on: [.agentStarted]) { _ in
        await tracker.increment()
        return .proceed
    }
    await pipeline.add(blockHook)
    await pipeline.add(secondHook)

    let action = await pipeline.fire(.agentStarted(goal: "test"))
    guard case .block = action else {
        Issue.record("Expected .block action")
        return
    }
    // Second hook should NOT have been called
    #expect(await tracker.count == 0)
}

@Test func hookPipelineProceedContinuesToNextHook() async {
    let pipeline = AgentHookPipeline()
    let tracker = EventTracker()

    let first = ClosureHook(on: [.agentStarted]) { _ in
        await tracker.increment()
        return .proceed
    }
    let second = ClosureHook(on: [.agentStarted]) { _ in
        await tracker.increment()
        return .proceed
    }
    await pipeline.add(first)
    await pipeline.add(second)

    await pipeline.fire(.agentStarted(goal: "test"))
    #expect(await tracker.count == 2)
}

@Test func hookPipelineEmptyPipelineReturnsProceed() async {
    let pipeline = AgentHookPipeline()
    let action = await pipeline.fire(.agentStarted(goal: "test"))
    guard case .proceed = action else {
        Issue.record("Expected .proceed from empty pipeline")
        return
    }
}

// MARK: - ContentFilter Tests

@Test func contentFilterDefaultDetectsCreditCard() async {
    let filter = ContentFilter.default
    let decision = await filter.evaluate(input: .userInput(text: "Card number: 4111111111111111"))
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
    // api_key_generic pattern: api_key: <20+ alphanumeric chars>
    let decision = await filter.evaluate(input: .userInput(text: "api_key: abcdefghijklmnopqrstuvwxyz12345"))
    guard case .block = decision else {
        Issue.record("Expected .block for API key pattern")
        return
    }
}

@Test func contentFilterDefaultDetectsBearerToken() async {
    let filter = ContentFilter.default
    // bearer_token pattern: Bearer <20+ chars>
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
    let decision = await filter.evaluate(input: .userInput(text: "Hello, how are you today?"))
    guard case .allow = decision else {
        Issue.record("Expected .allow for clean text")
        return
    }
}

@Test func contentFilterEvaluatesToolArguments() async {
    let filter = ContentFilter.default
    // SSN in tool arguments
    let decision = await filter.evaluate(input: .toolArguments(toolName: "lookup", arguments: "ssn: 123-45-6789"))
    guard case .block = decision else {
        Issue.record("Expected .block for SSN in tool arguments")
        return
    }
}

@Test func contentFilterCustomPatternDetects() async {
    let customPattern = ContentFilter.Pattern(
        name: "test_keyword",
        regex: "FORBIDDEN_WORD",
        risk: .high
    )
    let filter = ContentFilter(name: "CustomFilter", patterns: [customPattern])
    let decision = await filter.evaluate(input: .userInput(text: "This contains FORBIDDEN_WORD in it"))
    guard case .block = decision else {
        Issue.record("Expected .block for custom pattern match")
        return
    }
}

@Test func contentFilterCustomPatternAllowsNonMatch() async {
    let customPattern = ContentFilter.Pattern(
        name: "test_keyword",
        regex: "FORBIDDEN_WORD",
        risk: .high
    )
    let filter = ContentFilter(name: "CustomFilter", patterns: [customPattern])
    let decision = await filter.evaluate(input: .userInput(text: "This is perfectly fine text"))
    guard case .allow = decision else {
        Issue.record("Expected .allow when custom pattern does not match")
        return
    }
}

// MARK: - GuardrailPipeline Tests

@Test func guardrailPipelineEmptyAllows() async {
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
        func evaluate(input: GuardrailInput) async -> GuardrailDecision {
            .block(reason: "always blocked")
        }
    }

    await pipeline.add(AllowAllPolicy())
    await pipeline.add(BlockAllPolicy())

    let (decision, policyName) = await pipeline.evaluate(input: .userInput(text: "anything"))
    guard case .block = decision else {
        Issue.record("Expected .block — most restrictive decision should win")
        return
    }
    #expect(policyName == "BlockAll")
}

@Test func guardrailPipelineReturnsTriggeredPolicyName() async {
    let pipeline = GuardrailPipeline()
    await pipeline.add(ContentFilter.default)
    let (decision, policyName) = await pipeline.evaluate(input: .userInput(text: "SSN: 123-45-6789"))
    guard case .block = decision else {
        Issue.record("Expected .block for SSN")
        return
    }
    #expect(policyName == "DefaultContentFilter")
}

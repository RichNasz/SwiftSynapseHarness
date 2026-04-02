// Generated from CodeGenSpecs/ResilienceTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

// MARK: - Helpers

private struct ClassifiableError: Error, CustomStringConvertible {
    let description: String
}

// MARK: - ErrorClassification Tests

@Test func classifyAPIErrorAuth() {
    let error = ClassifiableError(description: "HTTP 401 unauthorized access")
    let classified = classifyAPIError(error, model: "test-model")
    guard case .auth = classified.category else {
        Issue.record("Expected .auth category for 401 error")
        return
    }
    #expect(classified.isRetryable == false)
}

@Test func classifyAPIErrorUnauthorized() {
    let error = ClassifiableError(description: "Request unauthorized — invalid credentials")
    let classified = classifyAPIError(error)
    guard case .auth = classified.category else {
        Issue.record("Expected .auth category for unauthorized error")
        return
    }
    #expect(classified.isRetryable == false)
}

@Test func classifyAPIErrorQuota() {
    let error = ClassifiableError(description: "quota exceeded for this billing period")
    let classified = classifyAPIError(error)
    guard case .quota = classified.category else {
        Issue.record("Expected .quota category")
        return
    }
    #expect(classified.isRetryable == false)
}

@Test func classifyAPIErrorRateLimit() {
    let error = ClassifiableError(description: "429 Too Many Requests — rate limit reached")
    let classified = classifyAPIError(error)
    guard case .rateLimit = classified.category else {
        Issue.record("Expected .rateLimit category for 429")
        return
    }
    #expect(classified.isRetryable == true)
}

@Test func classifyAPIErrorServerError() {
    let error = ClassifiableError(description: "500 Internal Server Error")
    let classified = classifyAPIError(error)
    guard case .serverError = classified.category else {
        Issue.record("Expected .serverError category for 500")
        return
    }
    #expect(classified.isRetryable == true)
}

@Test func classifyAPIErrorUnknown() {
    let error = ClassifiableError(description: "something completely unrelated happened")
    let classified = classifyAPIError(error)
    guard case .unknown = classified.category else {
        Issue.record("Expected .unknown category for unrecognized error")
        return
    }
}

// MARK: - RateLimiting Tests

@Test func rateLimitStateInitiallyNotInCooldown() async {
    let state = RateLimitState()
    #expect(await state.isInCooldown == false)
    #expect(await state.consecutiveHits == 0)
}

@Test func rateLimitStateEnterCooldown() async {
    let state = RateLimitState()
    await state.enterCooldown(duration: .seconds(60))
    #expect(await state.isInCooldown == true)
}

@Test func rateLimitStateConsecutiveHits() async {
    let state = RateLimitState()
    await state.enterCooldown(duration: .seconds(1))
    await state.enterCooldown(duration: .seconds(1))
    #expect(await state.consecutiveHits == 2)
}

@Test func rateLimitStateRecordSuccessResets() async {
    let state = RateLimitState()
    await state.enterCooldown(duration: .seconds(60))
    await state.recordSuccess()
    #expect(await state.isInCooldown == false)
    #expect(await state.consecutiveHits == 0)
}

// MARK: - ContextCompression Tests

@Test func microCompactorTruncatesLongResults() async throws {
    let compressor = MicroCompactor(maxResultLength: 10)
    let entries: [TranscriptEntry] = [
        .toolResult(name: "tool", result: String(repeating: "x", count: 100), duration: .zero)
    ]
    let result = try await compressor.compress(entries: entries, budget: ContextBudget(maxTokens: 1000))
    #expect(result.count == 1)
    if case .toolResult(_, let text, _) = result[0] {
        #expect(text.contains("[Truncated:"))
    } else {
        Issue.record("Expected toolResult entry")
    }
}

@Test func microCompactorPreservesShortResults() async throws {
    let compressor = MicroCompactor(maxResultLength: 100)
    let entries: [TranscriptEntry] = [
        .toolResult(name: "tool", result: "short", duration: .zero)
    ]
    let result = try await compressor.compress(entries: entries, budget: ContextBudget(maxTokens: 1000))
    #expect(result.count == 1)
    if case .toolResult(_, let text, _) = result[0] {
        #expect(text == "short")
    } else {
        Issue.record("Expected toolResult entry")
    }
}

// MARK: - ConversationRecovery Tests

@Test func transcriptIntegrityCheckDetectsOrphanedResult() {
    let checker = TranscriptIntegrityCheck()
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolResult(name: "echo", result: "hi", duration: .zero),
    ]
    let violations = checker.check(entries)
    #expect(violations.count == 1)
    guard case .orphanedToolResult(let name, _) = violations[0] else {
        Issue.record("Expected .orphanedToolResult violation")
        return
    }
    #expect(name == "echo")
}

@Test func transcriptIntegrityCheckDetectsOrphanedCall() {
    let checker = TranscriptIntegrityCheck()
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolCall(name: "echo", arguments: "{}"),
    ]
    let violations = checker.check(entries)
    #expect(violations.count == 1)
    guard case .orphanedToolCall(let name, _) = violations[0] else {
        Issue.record("Expected .orphanedToolCall violation")
        return
    }
    #expect(name == "echo")
}

@Test func transcriptIntegrityCheckPassesValid() {
    let checker = TranscriptIntegrityCheck()
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolCall(name: "echo", arguments: "{}"),
        .toolResult(name: "echo", result: "hi", duration: .zero),
    ]
    #expect(checker.check(entries).isEmpty)
}

@Test func conversationRecoveryRemovesOrphanedResult() {
    let strategy = DefaultConversationRecoveryStrategy()
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolResult(name: "echo", result: "hi", duration: .zero),
    ]
    let violations = [IntegrityViolation.orphanedToolResult(name: "echo", index: 1)]
    let repaired = strategy.repair(transcript: entries, violations: violations)
    #expect(repaired.count == 1)
    guard case .userMessage(let text) = repaired[0] else {
        Issue.record("Expected .userMessage as the only remaining entry")
        return
    }
    #expect(text == "hello")
}

@Test func conversationRecoveryAppendsSyntheticForOrphanedCall() {
    let strategy = DefaultConversationRecoveryStrategy()
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolCall(name: "echo", arguments: "{}"),
    ]
    let violations = [IntegrityViolation.orphanedToolCall(name: "echo", index: 1)]
    let repaired = strategy.repair(transcript: entries, violations: violations)
    #expect(repaired.count == 3)
    guard case .toolResult(let name, let result, _) = repaired.last else {
        Issue.record("Expected synthetic .toolResult appended")
        return
    }
    #expect(name == "echo")
    #expect(result.contains("Error"))
}

@Test func recoverTranscriptConvenienceFunction() {
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolResult(name: "orphan", result: "result", duration: .zero),
    ]
    let (repaired, violations) = recoverTranscript(entries)
    #expect(violations.count == 1)
    #expect(repaired.count == 1)
}

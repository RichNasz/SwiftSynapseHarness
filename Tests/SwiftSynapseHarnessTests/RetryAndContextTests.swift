// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.

import Testing
import Foundation
import SwiftSynapseHarness

// MARK: - Helpers

private actor Counter {
    var count = 0
    func increment() { count += 1 }
}

// MARK: - isTransportRetryable Tests

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
    let nonURLError = NSError(domain: "test", code: 42, userInfo: nil)
    #expect(isTransportRetryable(nonURLError) == false)
}

@Test func isTransportRetryableURLErrorBadURL() {
    #expect(isTransportRetryable(URLError(.badURL)) == false)
}

// MARK: - retryWithBackoff Tests

private struct RetryError: Error {}

@Test func retryWithBackoffSucceedsFirstAttempt() async throws {
    let counter = Counter()
    let result = try await retryWithBackoff(
        maxAttempts: 3,
        baseDelay: .milliseconds(1),
        isRetryable: { _ in true }
    ) {
        await counter.increment()
        return "success"
    }
    #expect(result == "success")
    #expect(await counter.count == 1)
}

@Test func retryWithBackoffRetriesRetryableError() async throws {
    let counter = Counter()
    let result = try await retryWithBackoff(
        maxAttempts: 3,
        baseDelay: .milliseconds(1),
        isRetryable: { _ in true }
    ) {
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
        _ = try await retryWithBackoff(
            maxAttempts: 3,
            baseDelay: .milliseconds(1),
            isRetryable: { _ in true }
        ) {
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
        _ = try await retryWithBackoff(
            maxAttempts: 5,
            baseDelay: .milliseconds(1),
            isRetryable: { _ in false }
        ) {
            await counter.increment()
            throw RetryError()
        }
        Issue.record("Expected error to be thrown")
    } catch {
        #expect(error is RetryError)
    }
    // Non-retryable: only 1 attempt made
    #expect(await counter.count == 1)
}

@Test func retryWithBackoffSucceedsWithCustomIsRetryable() async throws {
    let counter = Counter()
    let result = try await retryWithBackoff(
        maxAttempts: 3,
        baseDelay: .milliseconds(1),
        isRetryable: isTransportRetryable
    ) {
        await counter.increment()
        return "done"
    }
    #expect(result == "done")
    #expect(await counter.count == 1)
}

// MARK: - ContextBudget Tests

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

@Test func contextBudgetNotExhaustedBeforeMax() {
    var budget = ContextBudget(maxTokens: 100)
    budget.record(inputTokens: 30, outputTokens: 30)
    #expect(budget.isExhausted == false)
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

// MARK: - SlidingWindowCompressor Tests

@Test func slidingWindowCompressorKeepsLastN() async throws {
    let compressor = SlidingWindowCompressor(keepLast: 3)
    let entries: [TranscriptEntry] = (0..<10).map { .userMessage("msg \($0)") }
    let budget = ContextBudget(maxTokens: 1000)
    let result = try await compressor.compress(entries: entries, budget: budget)
    // 1 summary entry + 3 kept entries
    #expect(result.count == 4)
    // First entry should be the summary
    if case .assistantMessage(let text) = result[0] {
        #expect(text.contains("Context compressed"))
    } else {
        Issue.record("Expected summary assistantMessage as first entry")
    }
}

@Test func slidingWindowCompressorPassesThroughShortTranscript() async throws {
    let compressor = SlidingWindowCompressor(keepLast: 10)
    let entries: [TranscriptEntry] = (0..<5).map { .userMessage("msg \($0)") }
    let budget = ContextBudget(maxTokens: 1000)
    let result = try await compressor.compress(entries: entries, budget: budget)
    #expect(result.count == 5)
}

// MARK: - MicroCompactor Tests

@Test func microCompactorTruncatesLongResults() async throws {
    let compressor = MicroCompactor(maxResultLength: 10)
    let longResult = String(repeating: "x", count: 100)
    let entries: [TranscriptEntry] = [
        .toolResult(name: "tool", result: longResult, duration: .zero)
    ]
    let budget = ContextBudget(maxTokens: 1000)
    let result = try await compressor.compress(entries: entries, budget: budget)
    #expect(result.count == 1)
    if case .toolResult(_, let text, _) = result[0] {
        #expect(text.contains("[Truncated:"))
    } else {
        Issue.record("Expected toolResult entry")
    }
}

@Test func microCompactorPreservesShortResults() async throws {
    let compressor = MicroCompactor(maxResultLength: 100)
    let shortResult = "short"
    let entries: [TranscriptEntry] = [
        .toolResult(name: "tool", result: shortResult, duration: .zero)
    ]
    let budget = ContextBudget(maxTokens: 1000)
    let result = try await compressor.compress(entries: entries, budget: budget)
    #expect(result.count == 1)
    if case .toolResult(_, let text, _) = result[0] {
        #expect(text == shortResult)
    } else {
        Issue.record("Expected toolResult entry")
    }
}

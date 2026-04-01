// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.

import Testing
import Foundation
import SwiftSynapseHarness

// MARK: - Error Classification Tests

private struct ClassifiableError: Error, CustomStringConvertible {
    let description: String
}

@Test func classifyAPIErrorAuth401() {
    let error = ClassifiableError(description: "HTTP 401 unauthorized access")
    let classified = classifyAPIError(error, model: "test-model")
    guard case .auth = classified.category else {
        Issue.record("Expected .auth category for 401 error")
        return
    }
    #expect(classified.isRetryable == false)
    #expect(classified.model == "test-model")
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

// MARK: - ResultTruncation Tests

@Test func resultTruncatorPassesThroughShortText() {
    let policy = TruncationPolicy(maxCharacters: 1000, preserveLastCharacters: 100)
    let short = "This is a short string"
    let result = ResultTruncator.truncate(short, policy: policy)
    #expect(result == short)
}

@Test func resultTruncatorTruncatesLongText() {
    let policy = TruncationPolicy(maxCharacters: 50, preserveLastCharacters: 20)
    let long = String(repeating: "a", count: 200)
    let result = ResultTruncator.truncate(long, policy: policy)
    #expect(result.contains("[Truncated:"))
    #expect(result.count < long.count)
}

@Test func resultTruncatorPreservesLastChars() {
    let policy = TruncationPolicy(maxCharacters: 10, preserveLastCharacters: 5)
    // String with distinct suffix
    let text = "AAAAAAAAABBBBB" // 14 chars, last 5 are "BBBBB"
    let result = ResultTruncator.truncate(text, policy: policy)
    #expect(result.hasSuffix("BBBBB"))
}

@Test func resultTruncatorIncludesOriginalCount() {
    let policy = TruncationPolicy(maxCharacters: 20, preserveLastCharacters: 5)
    let long = String(repeating: "x", count: 100)
    let result = ResultTruncator.truncate(long, policy: policy)
    #expect(result.contains("100"))
}

// MARK: - RateLimitState Tests

@Test func rateLimitStateInitiallyNotInCooldown() async {
    let state = RateLimitState()
    #expect(await state.isInCooldown == false)
    #expect(await state.remainingCooldown == nil)
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
    #expect(await state.isInCooldown == true)
    await state.recordSuccess()
    #expect(await state.isInCooldown == false)
    #expect(await state.consecutiveHits == 0)
}

// MARK: - SystemPromptBuilder Tests

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
    // Lower priority number = earlier in output (sort ascending)
    #expect(lowRange.lowerBound < highRange.lowerBound)
}

@Test func systemPromptBuilderConcatenatesWithDoubleNewline() async throws {
    let builder = SystemPromptBuilder()
    await builder.addSection(SystemPromptSection(id: "a", content: "Section A", priority: 1))
    await builder.addSection(SystemPromptSection(id: "b", content: "Section B", priority: 2))

    let prompt = try await builder.build()
    #expect(prompt.contains("Section A\n\nSection B"))
}

@Test func systemPromptBuilderEmptyBuildsEmptyString() async throws {
    let builder = SystemPromptBuilder()
    let prompt = try await builder.build()
    #expect(prompt.isEmpty)
}

@Test func systemPromptBuilderRemoveSectionById() async throws {
    let builder = SystemPromptBuilder()
    await builder.addSection(SystemPromptSection(id: "removable", content: "Should be removed", priority: 1))
    await builder.addSection(SystemPromptSection(id: "keeper", content: "Should stay", priority: 2))
    await builder.removeSection(id: "removable")

    let prompt = try await builder.build()
    #expect(!prompt.contains("Should be removed"))
    #expect(prompt.contains("Should stay"))
}

// MARK: - Cache Tests

@Test func cacheGetReturnsNilForMissingKey() async {
    let policy = CachePolicy(maxEntries: 10, ttl: .seconds(300), eviction: .lru)
    let cache = Cache<String, String>(policy: policy)
    #expect(await cache.get("nonexistent") == nil)
}

@Test func cacheSetAndGetReturnsValue() async {
    let policy = CachePolicy(maxEntries: 10, ttl: .seconds(300), eviction: .lru)
    let cache = Cache<String, String>(policy: policy)
    await cache.set("key", "value")
    #expect(await cache.get("key") == "value")
}

@Test func cacheLRUEvictsLeastRecentlyAccessed() async {
    let policy = CachePolicy(maxEntries: 2, ttl: .seconds(300), eviction: .lru)
    let cache = Cache<String, String>(policy: policy)

    await cache.set("a", "val_a")
    await cache.set("b", "val_b")
    // Access "a" to update its LRU timestamp (making "b" the least recently used)
    _ = await cache.get("a")
    // Adding "c" should evict "b" (LRU)
    await cache.set("c", "val_c")

    #expect(await cache.get("a") != nil, "a should still be in cache (recently accessed)")
    #expect(await cache.get("b") == nil, "b should have been evicted (LRU)")
    #expect(await cache.get("c") != nil, "c should be in cache (just added)")
}

@Test func cacheFIFOEvictsFirst() async {
    let policy = CachePolicy(maxEntries: 2, ttl: .seconds(300), eviction: .fifo)
    let cache = Cache<String, String>(policy: policy)

    await cache.set("a", "val_a")   // first in
    await cache.set("b", "val_b")   // second in
    await cache.set("c", "val_c")   // evicts "a" (FIFO)

    #expect(await cache.get("a") == nil, "a should have been evicted (FIFO)")
    #expect(await cache.get("b") != nil, "b should still be in cache")
    #expect(await cache.get("c") != nil, "c should be in cache")
}

@Test func cacheInvalidateRemovesEntry() async {
    let policy = CachePolicy(maxEntries: 10, ttl: .seconds(300), eviction: .lru)
    let cache = Cache<String, String>(policy: policy)
    await cache.set("key", "value")
    #expect(await cache.get("key") == "value")
    await cache.invalidate("key")
    #expect(await cache.get("key") == nil)
}

@Test func cacheClearRemovesAllEntries() async {
    let policy = CachePolicy(maxEntries: 10, ttl: .seconds(300), eviction: .lru)
    let cache = Cache<String, String>(policy: policy)
    await cache.set("a", "1")
    await cache.set("b", "2")
    await cache.clear()
    #expect(await cache.count == 0)
}

// MARK: - ConversationRecovery Tests

@Test func transcriptIntegrityCheckDetectsOrphanedResult() {
    let checker = TranscriptIntegrityCheck()
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolResult(name: "echo", result: "hi", duration: .zero), // no preceding toolCall
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
        .toolCall(name: "echo", arguments: "{}"), // no following toolResult
    ]
    let violations = checker.check(entries)
    #expect(violations.count == 1)
    guard case .orphanedToolCall(let name, _) = violations[0] else {
        Issue.record("Expected .orphanedToolCall violation")
        return
    }
    #expect(name == "echo")
}

@Test func transcriptIntegrityCheckPassesValidTranscript() {
    let checker = TranscriptIntegrityCheck()
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolCall(name: "echo", arguments: "{}"),
        .toolResult(name: "echo", result: "hi", duration: .zero),
    ]
    let violations = checker.check(entries)
    #expect(violations.isEmpty)
}

@Test func conversationRecoveryRemovesOrphanedResult() {
    let strategy = DefaultConversationRecoveryStrategy()
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .toolResult(name: "echo", result: "hi", duration: .zero),
    ]
    let violations = [IntegrityViolation.orphanedToolResult(name: "echo", index: 1)]
    let repaired = strategy.repair(transcript: entries, violations: violations)
    // Orphaned toolResult at index 1 should be removed
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
    // Should append synthetic toolResult for the orphaned call
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
    #expect(repaired.count == 1) // orphaned result removed
}

@Test func recoverTranscriptReturnsUnchangedForValidTranscript() {
    let entries: [TranscriptEntry] = [
        .userMessage("hello"),
        .assistantMessage("hi"),
    ]
    let (repaired, violations) = recoverTranscript(entries)
    #expect(violations.isEmpty)
    #expect(repaired.count == 2)
}

// Generated from CodeGenSpecs/ObservabilityTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

#if Observability

// MARK: - InMemoryTelemetrySink Tests

@Test func inMemoryTelemetrySinkStartsEmpty() async {
    let sink = InMemoryTelemetrySink()
    let events = await sink.events
    #expect(events.isEmpty)
}

@Test func inMemoryTelemetrySinkCollectsEmittedEvent() async throws {
    let sink = InMemoryTelemetrySink()
    sink.emit(TelemetryEvent(kind: .agentStarted(goal: "test")))
    // Yield to allow the bridging Task to complete
    try await Task.sleep(for: .milliseconds(10))
    let events = await sink.drain()
    #expect(events.count == 1)
}

@Test func inMemoryTelemetrySinkDrainClearsBuffer() async throws {
    let sink = InMemoryTelemetrySink()
    sink.emit(TelemetryEvent(kind: .agentStarted(goal: "test")))
    try await Task.sleep(for: .milliseconds(10))
    _ = await sink.drain()
    let events = await sink.drain()
    #expect(events.isEmpty)
}

@Test func inMemoryTelemetrySinkCollectsMultipleEvents() async throws {
    let sink = InMemoryTelemetrySink()
    sink.emit(TelemetryEvent(kind: .agentStarted(goal: "first")))
    sink.emit(TelemetryEvent(kind: .agentStarted(goal: "second")))
    sink.emit(TelemetryEvent(kind: .agentStarted(goal: "third")))
    try await Task.sleep(for: .milliseconds(10))
    let events = await sink.drain()
    #expect(events.count == 3)
}

// MARK: - CompositeTelemetrySink Tests

@Test func compositeTelemetrySinkFansOutToAllSinks() async throws {
    let sink1 = InMemoryTelemetrySink()
    let sink2 = InMemoryTelemetrySink()
    let composite = CompositeTelemetrySink([sink1, sink2])
    composite.emit(TelemetryEvent(kind: .agentStarted(goal: "goal")))
    try await Task.sleep(for: .milliseconds(10))
    let events1 = await sink1.drain()
    let events2 = await sink2.drain()
    #expect(events1.count == 1)
    #expect(events2.count == 1)
}

// MARK: - CostTracker Tests

@Test func costTrackerStartsWithZeroCost() async {
    let tracker = CostTracker()
    let total = await tracker.totalCost()
    #expect(total == 0)
}

@Test func costTrackerAccumulatesCostWithPricing() async {
    let tracker = CostTracker()
    await tracker.setPricing(for: "test-model", pricing: ModelPricing(
        inputCostPerMillionTokens: 3,
        outputCostPerMillionTokens: 15
    ))
    await tracker.record(
        model: "test-model",
        inputTokens: 1_000_000,
        outputTokens: 1_000_000,
        apiDuration: .seconds(1)
    )
    let total = await tracker.totalCost()
    #expect(total == 18)
}

@Test func costTrackerUsageByModelAggregatesCorrectly() async {
    let tracker = CostTracker()
    await tracker.setPricing(for: "model-a", pricing: ModelPricing(
        inputCostPerMillionTokens: 1,
        outputCostPerMillionTokens: 2
    ))
    await tracker.record(model: "model-a", inputTokens: 100, outputTokens: 50, apiDuration: .seconds(1))
    await tracker.record(model: "model-a", inputTokens: 200, outputTokens: 100, apiDuration: .seconds(1))
    let usage = await tracker.usageByModel()
    #expect(usage["model-a"]?.callCount == 2)
    #expect(usage["model-a"]?.totalInputTokens == 300)
}

// MARK: - CostTrackingTelemetrySink Tests

@Test func costTrackingTelemetrySinkRecordsLLMCallMadeEvent() async throws {
    let tracker = CostTracker()
    let sink = CostTrackingTelemetrySink(tracker: tracker)
    sink.emit(TelemetryEvent(kind: .llmCallMade(
        model: "test-model",
        inputTokens: 100,
        outputTokens: 50,
        duration: .seconds(1)
    )))
    try await Task.sleep(for: .milliseconds(10))
    let count = await tracker.callCount
    #expect(count == 1)
}

#endif

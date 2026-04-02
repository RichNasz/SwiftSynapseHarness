// Generated from CodeGenSpecs/HooksTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

// MARK: - Helpers

private actor EventTracker {
    var triggered = false
    var count = 0

    func trigger() { triggered = true }
    func increment() { count += 1 }
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
    await pipeline.fire(.agentStarted(goal: "test"))
    #expect(await tracker.triggered == false)
}

@Test func hookPipelineBlockActionReturned() async {
    let pipeline = AgentHookPipeline()
    let hook = ClosureHook(on: [.agentStarted]) { _ in .block(reason: "blocked for test") }
    await pipeline.add(hook)
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
    let blockHook = ClosureHook(on: [.agentStarted]) { _ in .block(reason: "first hook blocks") }
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
    #expect(await tracker.count == 0)
}

@Test func hookPipelineProceedContinuesToNextHook() async {
    let pipeline = AgentHookPipeline()
    let tracker = EventTracker()
    let first = ClosureHook(on: [.agentStarted]) { _ in await tracker.increment(); return .proceed }
    let second = ClosureHook(on: [.agentStarted]) { _ in await tracker.increment(); return .proceed }
    await pipeline.add(first)
    await pipeline.add(second)
    await pipeline.fire(.agentStarted(goal: "test"))
    #expect(await tracker.count == 2)
}

@Test func hookPipelineModifyActionPropagates() async {
    let pipeline = AgentHookPipeline()
    let hook = ClosureHook(on: [.agentStarted]) { _ in .modify("replacement") }
    await pipeline.add(hook)
    let action = await pipeline.fire(.agentStarted(goal: "test"))
    guard case .modify(let value) = action else {
        Issue.record("Expected .modify action from pipeline")
        return
    }
    #expect(value == "replacement")
}

@Test func hookPipelineEmptyPipelineProceed() async {
    let pipeline = AgentHookPipeline()
    let action = await pipeline.fire(.agentStarted(goal: "test"))
    guard case .proceed = action else {
        Issue.record("Expected .proceed from empty pipeline")
        return
    }
}

@Test func closureHookSubscribedToMultipleEvents() async {
    let pipeline = AgentHookPipeline()
    let tracker = EventTracker()
    let hook = ClosureHook(on: [.preToolUse, .postToolUse]) { _ in
        await tracker.increment()
        return .proceed
    }
    await pipeline.add(hook)
    await pipeline.fire(.preToolUse(calls: []))
    await pipeline.fire(.postToolUse(results: []))
    #expect(await tracker.count == 2)
}

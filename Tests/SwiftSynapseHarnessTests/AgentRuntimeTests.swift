// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

// MARK: - Mock Agent

private actor MockAgent: AgentExecutable {
    var _status: AgentStatus = .idle
    var _transcript: ObservableTranscript = ObservableTranscript()
    var shouldThrow = false

    func execute(goal: String) async throws -> String {
        if shouldThrow { throw AgentLifecycleError.emptyGoal }
        return "mock result"
    }

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }
}

// MARK: - Hook State Tracker

private actor HookTracker {
    var startedGoal: String? = nil
    var completedResult: String? = nil

    func recordStarted(goal: String) { startedGoal = goal }
    func recordCompleted(result: String) { completedResult = result }
}

// MARK: - agentRun Tests

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

@Test func agentRunResetsTranscriptBeforeExecution() async throws {
    let mock = MockAgent()
    // Populate transcript with stale data
    await mock._transcript.append(.userMessage("stale"))
    // Run resets the transcript
    _ = try await agentRun(agent: mock, goal: "fresh run")
    let entries = await mock._transcript.entries
    let hasStale = entries.contains { entry in
        if case .userMessage(let t) = entry { return t == "stale" }
        return false
    }
    #expect(hasStale == false)
}

@Test func agentRunWithHooksFiresStartedEvent() async throws {
    let mock = MockAgent()
    let pipeline = AgentHookPipeline()
    let tracker = HookTracker()

    let hook = ClosureHook(on: [.agentStarted]) { event in
        if case .agentStarted(let goal) = event {
            await tracker.recordStarted(goal: goal)
        }
        return .proceed
    }
    await pipeline.add(hook)

    _ = try await agentRun(agent: mock, goal: "hook test", hooks: pipeline)
    #expect(await tracker.startedGoal == "hook test")
}

@Test func agentRunWithHooksBlocksWhenHookBlocks() async throws {
    let mock = MockAgent()
    let pipeline = AgentHookPipeline()

    let blockHook = ClosureHook(on: [.agentStarted]) { _ in
        .block(reason: "test block")
    }
    await pipeline.add(blockHook)

    await #expect(throws: AgentLifecycleError.self) {
        try await agentRun(agent: mock, goal: "should be blocked", hooks: pipeline)
    }
}

@Test func agentRunWithHooksFiresCompletedEvent() async throws {
    let mock = MockAgent()
    let pipeline = AgentHookPipeline()
    let tracker = HookTracker()

    let hook = ClosureHook(on: [.agentCompleted]) { event in
        if case .agentCompleted(let result) = event {
            await tracker.recordCompleted(result: result)
        }
        return .proceed
    }
    await pipeline.add(hook)

    _ = try await agentRun(agent: mock, goal: "complete me", hooks: pipeline)
    #expect(await tracker.completedResult == "mock result")
}

// Generated from CodeGenSpecs/MultiAgentTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

#if MultiAgent

// MARK: - Mock Agent (for CoordinationRunner type parameter)

private actor MultiAgentMock: AgentExecutable {
    var _status: AgentStatus = .idle
    var _transcript: ObservableTranscript = ObservableTranscript()

    func execute(goal: String) async throws -> String { "done" }
}

// MARK: - TeamMemory Tests

@Test func teamMemorySetAndGet() async {
    let memory = TeamMemory()
    await memory.set("key", value: "value")
    let result = await memory.get("key")
    #expect(result == "value")
}

@Test func teamMemoryGetMissingReturnsNil() async {
    let memory = TeamMemory()
    let result = await memory.get("nonexistent")
    #expect(result == nil)
}

@Test func teamMemoryRemoveDeletesKey() async {
    let memory = TeamMemory()
    await memory.set("k", value: "v")
    await memory.remove("k")
    let result = await memory.get("k")
    #expect(result == nil)
}

@Test func teamMemoryAllReturnsAllEntries() async {
    let memory = TeamMemory()
    await memory.set("a", value: "1")
    await memory.set("b", value: "2")
    await memory.set("c", value: "3")
    let all = await memory.all()
    #expect(all.count == 3)
}

@Test func teamMemoryClearRemovesAll() async {
    let memory = TeamMemory()
    await memory.set("a", value: "1")
    await memory.set("b", value: "2")
    await memory.clear()
    let all = await memory.all()
    #expect(all.isEmpty)
}

// MARK: - SharedMailbox Tests

@Test func sharedMailboxSendAndReceive() async {
    let mailbox = SharedMailbox()
    await mailbox.send(to: "agent", message: "hello")
    let stream = await mailbox.receive(for: "agent")
    var iterator = stream.makeAsyncIterator()
    let received = await iterator.next()
    #expect(received == "hello")
}

// MARK: - CoordinationRunner Tests

@Test func coordinationRunnerDetectsUnknownDependency() async throws {
    let config = try AgentConfiguration(
        executionMode: .onDevice,
        serverURL: nil,
        modelName: ""
    )
    let phase = CoordinationPhase<MultiAgentMock>(
        name: "step",
        goal: "do something",
        dependencies: ["nonexistent"]
    ) { _ in MultiAgentMock() }

    await #expect(throws: CoordinationError.self) {
        try await CoordinationRunner.run(phases: [phase], config: config)
    }
}

@Test func coordinationRunnerDetectsCyclicDependency() async throws {
    let config = try AgentConfiguration(
        executionMode: .onDevice,
        serverURL: nil,
        modelName: ""
    )
    let phaseA = CoordinationPhase<MultiAgentMock>(
        name: "a",
        goal: "step a",
        dependencies: ["b"]
    ) { _ in MultiAgentMock() }
    let phaseB = CoordinationPhase<MultiAgentMock>(
        name: "b",
        goal: "step b",
        dependencies: ["a"]
    ) { _ in MultiAgentMock() }

    await #expect(throws: CoordinationError.self) {
        try await CoordinationRunner.run(phases: [phaseA, phaseB], config: config)
    }
}

#endif

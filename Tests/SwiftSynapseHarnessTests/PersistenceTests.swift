// Generated from CodeGenSpecs/PersistenceTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import Foundation
import SwiftSynapseHarness

// MARK: - CodableTranscriptEntry Round-Trip Tests

@Test func codableTranscriptEntryUserMessageRoundTrips() throws {
    let original = CodableTranscriptEntry.userMessage("Hello, world!")
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: JSONEncoder().encode(original))
    guard case .userMessage(let text) = decoded else {
        Issue.record("Decoded to wrong case — expected .userMessage")
        return
    }
    #expect(text == "Hello, world!")
}

@Test func codableTranscriptEntryAssistantMessageRoundTrips() throws {
    let original = CodableTranscriptEntry.assistantMessage("I can help with that.")
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: JSONEncoder().encode(original))
    guard case .assistantMessage(let text) = decoded else {
        Issue.record("Decoded to wrong case — expected .assistantMessage")
        return
    }
    #expect(text == "I can help with that.")
}

@Test func codableTranscriptEntryToolCallRoundTrips() throws {
    let original = CodableTranscriptEntry.toolCall(name: "calculate", arguments: "{\"expression\":\"2+2\"}")
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: JSONEncoder().encode(original))
    guard case .toolCall(let name, let args) = decoded else {
        Issue.record("Decoded to wrong case — expected .toolCall")
        return
    }
    #expect(name == "calculate")
    #expect(args == "{\"expression\":\"2+2\"}")
}

@Test func codableTranscriptEntryToolResultRoundTrips() throws {
    let original = CodableTranscriptEntry.toolResult(name: "echo", result: "hi")
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: JSONEncoder().encode(original))
    guard case .toolResult(let name, let result) = decoded else {
        Issue.record("Decoded to wrong case — expected .toolResult")
        return
    }
    #expect(name == "echo")
    #expect(result == "hi")
}

@Test func codableTranscriptEntryErrorRoundTrips() throws {
    let original = CodableTranscriptEntry.error("Something failed")
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: JSONEncoder().encode(original))
    guard case .error(let msg) = decoded else {
        Issue.record("Decoded to wrong case — expected .error")
        return
    }
    #expect(msg == "Something failed")
}

@Test func codableTranscriptEntryToTranscriptEntry() {
    let codable = CodableTranscriptEntry.userMessage("hi")
    let entry = codable.toTranscriptEntry()
    guard case .userMessage(let text) = entry else {
        Issue.record("Expected .userMessage TranscriptEntry")
        return
    }
    #expect(text == "hi")
}

// MARK: - AgentSession Tests

@Test func agentSessionEncodesAndDecodes() throws {
    let session = AgentSession(
        sessionId: "sess-abc-123",
        agentType: "TestAgent",
        goal: "test goal",
        transcriptEntries: [.userMessage("test goal")],
        completedStepIndex: 0
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(AgentSession.self, from: encoder.encode(session))
    #expect(decoded.sessionId == "sess-abc-123")
    #expect(decoded.agentType == "TestAgent")
    #expect(decoded.goal == "test goal")
    #expect(decoded.completedStepIndex == 0)
}

@Test func agentSessionPreservesTranscriptEntries() throws {
    let entries: [CodableTranscriptEntry] = [
        .userMessage("hello"),
        .assistantMessage("hi there"),
        .toolCall(name: "calc", arguments: "{}"),
    ]
    let session = AgentSession(agentType: "TestAgent", goal: "multi-entry goal",
                               transcriptEntries: entries, completedStepIndex: 2)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(AgentSession.self, from: encoder.encode(session))
    #expect(decoded.transcriptEntries.count == 3)
}

// MARK: - ObservableTranscript+Harness Tests

@Test func observableTranscriptRestoreFromCodable() {
    let transcript = ObservableTranscript()
    transcript.restore(from: [.userMessage("A"), .assistantMessage("B")])
    #expect(transcript.entries.count == 2)
}

// MARK: - MemoryEntry Tests (requires Persistence trait)

#if Persistence
@Test func memoryEntryEncodesAndDecodes() throws {
    let entry = MemoryEntry(
        id: "test-id",
        category: .user,
        content: "User prefers concise answers",
        tags: ["preference", "style"]
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(MemoryEntry.self, from: encoder.encode(entry))
    #expect(decoded.id == "test-id")
    #expect(decoded.category == .user)
    #expect(decoded.content == "User prefers concise answers")
    #expect(decoded.tags == ["preference", "style"])
}

@Test func memoryEntryCategoryCustomRoundTrips() throws {
    let entry = MemoryEntry(id: "custom-id", category: .custom("myCategory"), content: "domain-specific fact")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(MemoryEntry.self, from: encoder.encode(entry))
    guard case .custom(let label) = decoded.category else {
        Issue.record("Expected .custom category after round-trip")
        return
    }
    #expect(label == "myCategory")
}
#endif

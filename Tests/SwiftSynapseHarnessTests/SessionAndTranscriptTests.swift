// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.

import Testing
import Foundation
import SwiftSynapseHarness

// MARK: - CodableTranscriptEntry Round-Trip Tests

@Test func codableTranscriptEntryUserMessageRoundTrips() throws {
    let original = CodableTranscriptEntry.userMessage("Hello, world!")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: data)
    guard case .userMessage(let text) = decoded else {
        Issue.record("Decoded to wrong case — expected .userMessage")
        return
    }
    #expect(text == "Hello, world!")
}

@Test func codableTranscriptEntryAssistantMessageRoundTrips() throws {
    let original = CodableTranscriptEntry.assistantMessage("I can help with that.")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: data)
    guard case .assistantMessage(let text) = decoded else {
        Issue.record("Decoded to wrong case — expected .assistantMessage")
        return
    }
    #expect(text == "I can help with that.")
}

@Test func codableTranscriptEntryToolCallRoundTrips() throws {
    let original = CodableTranscriptEntry.toolCall(name: "calculate", arguments: "{\"expression\":\"2+2\"}")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: data)
    guard case .toolCall(let name, let args) = decoded else {
        Issue.record("Decoded to wrong case — expected .toolCall")
        return
    }
    #expect(name == "calculate")
    #expect(args == "{\"expression\":\"2+2\"}")
}

@Test func codableTranscriptEntryToolResultRoundTrips() throws {
    let original = CodableTranscriptEntry.toolResult(name: "calculate", result: "4.0")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: data)
    guard case .toolResult(let name, let result) = decoded else {
        Issue.record("Decoded to wrong case — expected .toolResult")
        return
    }
    #expect(name == "calculate")
    #expect(result == "4.0")
}

@Test func codableTranscriptEntryErrorRoundTrips() throws {
    let original = CodableTranscriptEntry.error("Something went wrong")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CodableTranscriptEntry.self, from: data)
    guard case .error(let msg) = decoded else {
        Issue.record("Decoded to wrong case — expected .error")
        return
    }
    #expect(msg == "Something went wrong")
}

// MARK: - CodableTranscriptEntry → TranscriptEntry Conversion Tests

@Test func codableTranscriptEntryToTranscriptEntryUserMessage() {
    let codable = CodableTranscriptEntry.userMessage("hi")
    let entry = codable.toTranscriptEntry()
    guard case .userMessage(let text) = entry else {
        Issue.record("Expected .userMessage TranscriptEntry")
        return
    }
    #expect(text == "hi")
}

@Test func codableTranscriptEntryToTranscriptEntryToolResult() {
    let codable = CodableTranscriptEntry.toolResult(name: "echo", result: "hello")
    let entry = codable.toTranscriptEntry()
    guard case .toolResult(let name, let result, _) = entry else {
        Issue.record("Expected .toolResult TranscriptEntry")
        return
    }
    #expect(name == "echo")
    #expect(result == "hello")
}

// MARK: - AgentSession Tests

@Test func agentSessionEncodesAndDecodes() throws {
    let entry = CodableTranscriptEntry.userMessage("test goal")
    let session = AgentSession(
        sessionId: "sess-abc-123",
        agentType: "TestAgent",
        goal: "test goal",
        transcriptEntries: [entry],
        completedStepIndex: 0
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(session)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(AgentSession.self, from: data)

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
    let session = AgentSession(
        agentType: "TestAgent",
        goal: "multi-entry goal",
        transcriptEntries: entries,
        completedStepIndex: 2
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(session)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(AgentSession.self, from: data)

    #expect(decoded.transcriptEntries.count == 3)
}

// MARK: - ObservableTranscript+Harness Extension Tests

@Test func observableTranscriptRestoreFromCodable() {
    let transcript = ObservableTranscript()
    let codableEntries: [CodableTranscriptEntry] = [
        .userMessage("Hello"),
        .assistantMessage("Hi there"),
    ]
    transcript.restore(from: codableEntries)
    #expect(transcript.entries.count == 2)
}

@Test func observableTranscriptRestoreFromEmptyArray() {
    let transcript = ObservableTranscript()
    transcript.append(.userMessage("existing"))
    transcript.restore(from: [])
    #expect(transcript.entries.count == 0)
}

@Test func observableTranscriptRestorePreservesEntryContent() {
    let transcript = ObservableTranscript()
    let codableEntries: [CodableTranscriptEntry] = [
        .userMessage("Test message"),
    ]
    transcript.restore(from: codableEntries)
    guard case .userMessage(let text) = transcript.entries.first else {
        Issue.record("Expected .userMessage as first entry")
        return
    }
    #expect(text == "Test message")
}

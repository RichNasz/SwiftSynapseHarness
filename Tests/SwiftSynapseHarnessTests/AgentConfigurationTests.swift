// Generated from CodeGenSpecs/Tests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness

// MARK: - AgentConfiguration Tests

@Test func cloudConfigValidURLSucceeds() throws {
    _ = try AgentConfiguration(
        executionMode: .cloud,
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "test-model"
    )
}

@Test func cloudConfigInvalidURLThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud,
            serverURL: ":::bad-url",
            modelName: "test-model"
        )
    }
}

@Test func cloudConfigNilURLThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud,
            serverURL: nil,
            modelName: "test-model"
        )
    }
}

@Test func cloudConfigEmptyURLThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud,
            serverURL: "",
            modelName: "test-model"
        )
    }
}

@Test func cloudConfigEmptyModelNameThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud,
            serverURL: "http://127.0.0.1:1234",
            modelName: ""
        )
    }
}

@Test func cloudConfigZeroTimeoutThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud,
            serverURL: "http://127.0.0.1:1234",
            modelName: "test-model",
            timeoutSeconds: 0
        )
    }
}

@Test func cloudConfigNegativeTimeoutThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud,
            serverURL: "http://127.0.0.1:1234",
            modelName: "test-model",
            timeoutSeconds: -1
        )
    }
}

@Test func cloudConfigZeroRetriesThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud,
            serverURL: "http://127.0.0.1:1234",
            modelName: "test-model",
            maxRetries: 0
        )
    }
}

@Test func cloudConfigElevenRetriesThrows() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(
            executionMode: .cloud,
            serverURL: "http://127.0.0.1:1234",
            modelName: "test-model",
            maxRetries: 11
        )
    }
}

@Test func onDeviceConfigNoURLRequired() throws {
    // onDevice skips URL and model name validation
    _ = try AgentConfiguration(
        executionMode: .onDevice,
        serverURL: nil,
        modelName: ""
    )
}

@Test func overridesSupersedEnvVars() throws {
    // Overrides have highest priority — regardless of env vars
    let config = try AgentConfiguration.fromEnvironment(
        overrides: AgentConfiguration.Overrides(
            serverURL: "http://127.0.0.1:1234",
            modelName: "override-model"
        )
    )
    #expect(config.modelName == "override-model")
    #expect(config.serverURL == "http://127.0.0.1:1234")
}

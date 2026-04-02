// Generated from CodeGenSpecs/MCPTests.md — Do not edit manually. Update spec and re-generate.

import Testing
import SwiftSynapseHarness
import Foundation

#if MCP

// MARK: - MCPServerConfig Tests

@Test func mcpServerConfigEncodesAndDecodes() throws {
    let config = MCPServerConfig(
        name: "my-server",
        transport: .stdio,
        command: "/usr/bin/server",
        arguments: ["--flag"],
        url: nil,
        environment: ["KEY": "VALUE"]
    )
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(MCPServerConfig.self, from: data)
    #expect(decoded.name == config.name)
    #expect(decoded.transport == config.transport)
    #expect(decoded.command == config.command)
    #expect(decoded.arguments == config.arguments)
    #expect(decoded.environment == config.environment)
}

// MARK: - MCPMessage Tests

@Test func mcpMessageEncodesAndDecodes() throws {
    let message = MCPMessage(id: 42, method: "tools/list", params: nil)
    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(MCPMessage.self, from: data)
    #expect(decoded.id == 42)
    #expect(decoded.method == "tools/list")
    #expect(decoded.jsonrpc == "2.0")
}

// MARK: - MCPToolBridge Tests

@Test func mcpToolBridgeDynamicSchemaUsesDefinitionName() {
    let definition = MCPToolDefinition(name: "my_tool", description: "A useful tool")
    let config = MCPServerConfig(name: "server", command: "/bin/server")
    let connection = MCPServerConnection(config: config)
    let bridge = MCPToolBridge(definition: definition, connection: connection)
    #expect(bridge.dynamicSchema.name == "my_tool")
}

@Test func mcpToolBridgeDynamicSchemaUsesDefinitionDescription() {
    let definition = MCPToolDefinition(name: "my_tool", description: "A useful tool")
    let config = MCPServerConfig(name: "server", command: "/bin/server")
    let connection = MCPServerConnection(config: config)
    let bridge = MCPToolBridge(definition: definition, connection: connection)
    #expect(bridge.dynamicSchema.description == "A useful tool")
}

// MARK: - MCPManager Tests

@Test func mcpManagerStartsEmpty() async throws {
    let manager = MCPManager()
    // discoverTools on an empty manager returns no bridges
    let bridges = try await manager.discoverTools()
    #expect(bridges.isEmpty)
}

#endif

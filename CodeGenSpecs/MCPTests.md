# Spec: MCP Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/MCPTests.swift`

**Sources under test:** `MCP.swift`

## Generation Rules

Same as `CoreTests.md`: Swift Testing, top-level `@Test` functions, `#expect()`, `async throws`. Live tests (requiring actual MCP server process) gated with `SWIFTSYNAPSE_LIVE_TESTS`.

## Test Functions

### MCPServerConfig / MCPMessage

| Test | Verifies |
|------|---------|
| `mcpServerConfigEncodesAndDecodes` | `MCPServerConfig` with known fields Codable round-trips with matching fields |
| `mcpMessageEncodesAndDecodes` | `MCPMessage` with id, method, and params Codable round-trips |

### MCPToolDefinition / MCPToolBridge

| Test | Verifies |
|------|---------|
| `mcpToolBridgeDynamicSchemaUsesDefinitionName` | `MCPToolBridge(definition:connection:).dynamicSchema.name == definition.name` |
| `mcpToolBridgeDynamicSchemaUsesDefinitionDescription` | `dynamicSchema.description == definition.description` |

### MCPManager

| Test | Verifies |
|------|---------|
| `mcpManagerStartsEmpty` | Freshly created `MCPManager` has no registered bridges |
| `mcpManagerConnectStdioLive` | Live: `addServer` + `discoverTools()` succeeds with a real stdio MCP server process |

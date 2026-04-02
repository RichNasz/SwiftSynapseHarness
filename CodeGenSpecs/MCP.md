# Spec: MCP Trait

**Trait guard:** `#if MCP` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/MCP.swift`

## Overview

The MCP trait connects agents to external systems via the Model Context Protocol (JSON-RPC 2.0). MCP tools are bridged into `ToolRegistry` as standard `AgentToolProtocol` tools — the LLM interacts with them identically to native tools. Not included in the default `Production` trait — requires explicit opt-in via `traits: ["Production", "MCP"]` or `traits: ["Advanced"]`.

No external dependencies — Foundation covers stdio (`Process`), SSE (`URLSession`), and WebSocket.

---

## Transport Layer

- `MCPTransport` protocol: `send(_ message: MCPMessage) async throws`, `receive() -> AsyncThrowingStream<MCPMessage, Error>`, `close() async`
- `StdioMCPTransport` actor: communicates via stdin/stdout of a child `Process`. Content-Length header framing per JSON-RPC spec.
- Future transports: `SSEMCPTransport`, `WebSocketMCPTransport` (Foundation URLSession-based)

---

## Message Types

- `MCPMessage`: JSON-RPC 2.0 fields (jsonrpc, id, method, params, result, error)
- `MCPError`: code, message, data
- `AnyCodable`: type-erased JSON value for dynamic params/results

---

## Connection Management

- `MCPServerConfig`: name, transport type, command/args (for stdio), URL (for SSE/WebSocket), environment
- `MCPTransportType` enum: `.stdio`, `.sse`, `.webSocket`
- `MCPServerConnection` actor: `connect()`, initialize handshake, `discoverTools() -> [MCPToolDefinition]`, `callTool(name:arguments:) -> String`, `disconnect()`
- `MCPConnectionError`: `.notConnected`, `.missingCommand`, `.unsupportedTransport`, `.handshakeFailed`

---

## Tool Bridge

- `MCPToolDefinition`: tool definition from MCP server (name, description, inputSchema as JSON)
- `MCPToolBridge`: wraps an MCP-discovered tool as `AgentToolProtocol`. JSON pass-through input/output — the LLM provides arguments; the bridge forwards them to the MCP server and returns the result.
- `dynamicSchema: FunctionToolParam` — returns the tool's actual name and description (since `MCPToolBridge` is a single generic type, static protocol requirements are placeholders; `MCPManager.registerAll()` registers dynamic schemas directly).

---

## MCPManager

`actor MCPManager`: manages multiple server connections.

- `addServer(_ config: MCPServerConfig)` — registers a server configuration
- `discoverTools()` — connects to all registered servers and discovers their tools
- `registerAll(in registry: ToolRegistry)` — registers all discovered tools as `MCPToolBridge` instances
- `disconnectAll()` — disconnects all active connections (register with `ShutdownRegistry`)

### Integration Example
```swift
let mcp = MCPManager()
await mcp.addServer(MCPServerConfig(
    name: "filesystem",
    transportType: .stdio,
    command: "npx",
    args: ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/files"]
))
try await mcp.discoverTools()
await mcp.registerAll(in: tools)

// Register disconnection with graceful shutdown
await shutdown.register(name: "mcp") { await mcp.disconnectAll() }
```

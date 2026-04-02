# Spec: LLM Tool Macro Integration

**Generates:**
- `Sources/SwiftSynapseHarness/LLMToolSupport.swift`

## Overview

Integrates `SwiftLLMToolMacros` (`@LLMTool`, `@LLMToolArguments`, `@LLMToolGuide`) into `AgentToolProtocol` / `ToolRegistry`. `AgentLLMTool` is the canonical way to define tools in SwiftSynapseHarness.

`AgentLLMTool` inherits from both `LLMTool` and `AgentToolProtocol`, constrains `Input == Arguments` and `Output == String`, and provides three default implementations that cover all `AgentToolProtocol` requirements not already synthesized by `@LLMTool`:

- `inputSchema` — converts `ToolDefinition` → `FunctionToolParam` via `FunctionToolParam.init(from:)`
- `isConcurrencySafe` — defaults to `false`, overridable per tool
- `execute(input:)` — calls `call(arguments:)` and returns `ToolOutput.content`

No new macros are introduced. All macro expansion happens in `SwiftLLMToolMacros`.

---

## Imports

```swift
import SwiftLLMToolMacros
import SwiftOpenResponsesDSL
```

`SwiftOpenResponsesDSL` is a transitive dependency (via `SwiftSynapseMacrosClient`) imported here for `FunctionToolParam`. `SwiftLLMToolMacros` is a direct dependency declared in `Package.swift`.

---

## Re-exports (Typealiases)

```swift
public typealias LLMTool = SwiftLLMToolMacros.LLMTool
public typealias LLMToolArguments = SwiftLLMToolMacros.LLMToolArguments
public typealias ToolOutput = SwiftLLMToolMacros.ToolOutput
```

Users only need `import SwiftSynapseHarness`. No direct import of `SwiftLLMToolMacros` required at the call site.

---

## AgentLLMTool Protocol

```swift
public protocol AgentLLMTool: LLMTool & AgentToolProtocol
    where Input == Arguments, Output == String {}
```

The `where` clause enforces both associated type equalities at the conformance site. Tool authors write no `typealias` declarations. `@LLMTool` generates `static var name: String` (snake_cased struct name) and `static var description: String` (from the doc comment) — these satisfy the identically named requirements on both `LLMTool` and `AgentToolProtocol` simultaneously via standard Swift protocol composition.

---

## Default Implementations

### inputSchema

```swift
public static var inputSchema: FunctionToolParam {
    FunctionToolParam(from: Self.toolDefinition)
}
```

`toolDefinition` is synthesized by `@LLMTool` from the struct's snake_cased name and doc comment. `FunctionToolParam.init(from: ToolDefinition)` exists in `SwiftOpenResponsesDSL` and maps `name`, `description`, and `parameters` directly.

### isConcurrencySafe

```swift
public static var isConcurrencySafe: Bool { false }
```

Overridable: add `static var isConcurrencySafe: Bool { true }` to the conforming struct.

### execute(input:)

```swift
public func execute(input: Arguments) async throws -> String {
    let output = try await call(arguments: input)
    return output.content
}
```

`AnyAgentTool`'s `Output == String` fast path (line 124 of `AgentToolProtocol.swift`) returns the string directly — tool output is never double-quoted.

---

## Usage Example

```swift
import SwiftSynapseHarness

/// Get the current weather for a location.
@LLMTool
struct GetCurrentWeather: AgentLLMTool {
    @LLMToolArguments
    struct Arguments {
        @LLMToolGuide(description: "City and state, e.g. Alpharetta, GA")
        var location: String

        @LLMToolGuide(description: "Temperature unit", .anyOf(["celsius", "fahrenheit"]))
        var unit: String?
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        ToolOutput(content: "{\"temperature\": 22}")
    }
}

let registry = ToolRegistry()
registry.register(GetCurrentWeather())
```

---

## Package.swift Changes

```swift
// In package dependencies array:
.package(url: "https://github.com/RichNasz/SwiftLLMToolMacros", branch: "main"),

// In SwiftSynapseHarness target dependencies array:
.product(name: "SwiftLLMToolMacros", package: "SwiftLLMToolMacros"),
```

Commit `Package.swift` and the updated `Package.resolved` together.

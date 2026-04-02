# How to Add Tools to an Agent

Define a typed tool, register it, and wire it into the tool loop.

## Overview

Tools are how agents interact with external systems. Annotate your struct with `@LLMTool` and conform to ``AgentLLMTool`` — the macro generates the name (snake_cased), description (from the doc comment), and JSON Schema automatically.

## Define a Tool

```swift
/// Searches documentation for a query.
@LLMTool
struct SearchDocsTool: AgentLLMTool {
    @LLMToolArguments
    struct Arguments {
        @LLMToolGuide(description: "The search query")
        var query: String

        @LLMToolGuide(description: "Maximum results to return", .range(1...50))
        var maxResults: Int
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        let results = try await DocumentationIndex.search(arguments.query, limit: arguments.maxResults)
        return ToolOutput(content: results.joined(separator: "\n"))
    }
}
```

Register and use the tool:

```swift
let tools = ToolRegistry()
tools.register(SearchDocsTool())
```

To enable parallel execution with other safe tools during streaming, override the concurrency default:

```swift
@LLMTool
struct PureComputeTool: AgentLLMTool {
    // ...
    static var isConcurrencySafe: Bool { true }
}
```

Tools with shared mutable state, database access, or ordering requirements should leave `isConcurrencySafe` at the default (`false`).

Register multiple tools in a ``ToolRegistry`` before passing it to ``AgentToolLoop``:

```swift
let tools = ToolRegistry()
tools.register(SearchDocsTool())
tools.register(CalculateTool())
tools.register(ConvertUnitTool())
```

The registry handles type erasure via `AnyAgentTool` internally. You never interact with `AnyAgentTool` directly.

## Report Progress (Optional)

For long-running tools, conform to ``ProgressReportingTool`` instead of ``AgentToolProtocol`` to emit intermediate progress. This variant of `execute` receives a `callId` and a ``ToolProgressDelegate``:

```swift
struct IndexingTool: ProgressReportingTool {
    struct Input: Codable, Sendable { let directory: String }
    struct Output: Codable, Sendable { let filesIndexed: Int }

    static let name = "index_files"
    static let description = "Indexes all Swift files in a directory."
    static let inputSchema: FunctionToolParam = .init(/* ... */)

    func execute(input: Input, callId: String, progress: any ToolProgressDelegate) async throws -> Output {
        let files = try listSwiftFiles(in: input.directory)
        for (i, file) in files.enumerated() {
            await progress.reportProgress(ToolProgressUpdate(
                callId: callId,
                toolName: Self.name,
                message: "Indexing \(file.name) (\(i+1)/\(files.count))",
                fractionComplete: Double(i+1) / Double(files.count)
            ))
            try await index(file)
        }
        return Output(filesIndexed: files.count)
    }
}
```

Progress updates appear in `ObservableTranscript.toolProgress` for real-time SwiftUI display. The default `execute(input:)` implementation calls the progress variant with a no-op delegate, so the tool is also usable without a delegate.

## See Also

- <doc:AgentHarnessGuide> — typed tool system, batch dispatch, ``StreamingToolExecutor``
- ``AgentLLMTool`` — the protocol for defining tools with `@LLMTool`
- <doc:HowToConfigurePermissions> — restrict which tools an agent can call

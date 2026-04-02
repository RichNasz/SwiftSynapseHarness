# How to Add Tools to an Agent

Define a typed tool, register it, and wire it into the tool loop.

## Overview

Tools are how agents interact with external systems. Each tool has typed `Input` and `Output`, a name, a description, and an `execute(input:)` method. This guide walks through building a tool from scratch, registering it, and optionally adding progress reporting for long-running work.

## Step 1: Conform to AgentToolProtocol

Every tool provides typed `Input` and `Output` structs, a `name`, a `description`, an `inputSchema`, and an `execute(input:)` method:

```swift
struct SearchDocsTool: AgentToolProtocol {
    struct Input: Codable, Sendable {
        let query: String
        let maxResults: Int
    }
    struct Output: Codable, Sendable {
        let results: [String]
    }

    static let name = "search_docs"
    static let description = "Searches documentation for a query."
    static let inputSchema: FunctionToolParam = .init(
        name: name,
        description: description,
        parameters: .init(
            properties: [
                "query": .init(type: "string", description: "The search query"),
                "maxResults": .init(type: "integer", description: "Maximum results to return")
            ],
            required: ["query"]
        )
    )

    func execute(input: Input) async throws -> Output {
        let results = try await DocumentationIndex.search(input.query, limit: input.maxResults)
        return Output(results: results)
    }
}
```

## Step 2: Mark Concurrency Safety

If your tool has no shared mutable state, mark it concurrency-safe. This enables parallel execution with other safe tools during streaming — improving throughput significantly when the agent calls multiple tools in one turn:

```swift
static let isConcurrencySafe = true
```

Tools that access shared resources, databases, or external state with ordering requirements should leave this as the default (`false`).

## Step 3: Register the Tool

Register tools in a ``ToolRegistry`` before passing it to ``AgentToolLoop``:

```swift
let tools = ToolRegistry()
tools.register(SearchDocsTool())
tools.register(CalculateTool())
tools.register(ConvertUnitTool())
```

The registry handles type erasure via `AnyAgentTool` internally. You never interact with `AnyAgentTool` directly.

## Step 4: Report Progress (Optional)

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
- <doc:HowToConfigurePermissions> — restrict which tools an agent can call

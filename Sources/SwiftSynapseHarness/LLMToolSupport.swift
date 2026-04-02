// Generated from CodeGenSpecs/Shared-LLMToolMacros.md — Do not edit manually. Update spec and re-generate.

import Foundation
import SwiftLLMToolMacros
import SwiftOpenResponsesDSL

#if Core

// MARK: - Re-exports

/// Re-export macro-side types so users only need `import SwiftSynapseHarness`.
public typealias LLMTool = SwiftLLMToolMacros.LLMTool
public typealias LLMToolArguments = SwiftLLMToolMacros.LLMToolArguments
public typealias ToolOutput = SwiftLLMToolMacros.ToolOutput

// MARK: - AgentLLMTool

/// The canonical way to define an agent tool in SwiftSynapseHarness.
///
/// Annotate your struct with `@LLMTool` and conform to `AgentLLMTool`. The macro
/// generates `name` (snake_cased), `description` (from the doc comment), and
/// `toolDefinition`. Default implementations on this protocol satisfy the remaining
/// ``AgentToolProtocol`` requirements — you only implement `call(arguments:)`.
///
/// ```swift
/// /// Get the current weather for a location.
/// @LLMTool
/// struct GetCurrentWeather: AgentLLMTool {
///     @LLMToolArguments
///     struct Arguments {
///         @LLMToolGuide(description: "City and state, e.g. Alpharetta, GA")
///         var location: String
///
///         @LLMToolGuide(description: "Temperature unit", .anyOf(["celsius", "fahrenheit"]))
///         var unit: String?
///     }
///
///     func call(arguments: Arguments) async throws -> ToolOutput {
///         ToolOutput(content: "{\"temperature\": 22}")
///     }
/// }
///
/// let registry = ToolRegistry()
/// registry.register(GetCurrentWeather())
/// ```
public protocol AgentLLMTool: LLMTool & AgentToolProtocol
    where Input == Arguments, Output == String {}

// MARK: - Default Implementations

extension AgentLLMTool {

    /// Bridges `LLMTool.toolDefinition` (a `ToolDefinition`) to the
    /// `FunctionToolParam` that `AgentToolProtocol.inputSchema` requires.
    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(from: Self.toolDefinition)
    }

    /// Defaults to `false` (sequential execution). Override per-tool when safe.
    public static var isConcurrencySafe: Bool { false }

    /// Calls `call(arguments:)` and returns `ToolOutput.content` as a plain `String`.
    ///
    /// `AnyAgentTool` detects `Output == String` at the call site and returns
    /// the value directly, avoiding the double-quote wrapping that
    /// JSON-encoding a `String` would otherwise produce.
    public func execute(input: Arguments) async throws -> String {
        let output = try await call(arguments: input)
        return output.content
    }
}

#endif

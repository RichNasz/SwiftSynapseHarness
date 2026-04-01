// Generated from CodeGenSpecs/Client-AgentHarness.md — Do not edit manually. Update spec and re-generate.

import Foundation

// MARK: - Tool Progress Delegate

/// A delegate that receives progress updates from tools during execution.
///
/// Implement this protocol to display progress bars, update UI, or log progress.
public protocol ToolProgressDelegate: Sendable {
    func reportProgress(_ update: ToolProgressUpdate) async
}

// MARK: - Progress-Reporting Tool Protocol

/// A refinement of `AgentToolProtocol` for tools that emit progress during execution.
///
/// Tools conforming to this protocol receive a `ToolProgressDelegate` during execution,
/// allowing them to report intermediate progress for long-running operations.
///
/// ```swift
/// struct DataImportTool: ProgressReportingTool {
///     // ...
///     func execute(input: Input, callId: String, progress: any ToolProgressDelegate) async throws -> Output {
///         for (i, batch) in batches.enumerated() {
///             await progress.reportProgress(ToolProgressUpdate(
///                 callId: callId,
///                 toolName: Self.name,
///                 message: "Importing batch \(i+1)/\(batches.count)",
///                 fractionComplete: Double(i+1) / Double(batches.count)
///             ))
///             try await processBatch(batch)
///         }
///         return .success
///     }
/// }
/// ```
public protocol ProgressReportingTool: AgentToolProtocol {
    /// Executes the tool with progress reporting.
    func execute(input: Input, callId: String, progress: any ToolProgressDelegate) async throws -> Output
}

extension ProgressReportingTool {
    /// Default implementation bridges to the progress-aware version with a no-op delegate.
    public func execute(input: Input) async throws -> Output {
        try await execute(input: input, callId: "", progress: NoOpProgressDelegate())
    }
}

/// A no-op progress delegate used when no delegate is provided.
struct NoOpProgressDelegate: ToolProgressDelegate {
    func reportProgress(_ update: ToolProgressUpdate) async {}
}

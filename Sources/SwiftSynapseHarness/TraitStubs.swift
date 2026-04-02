// Generated from CodeGenSpecs/Traits.md — Do not edit manually. Update spec and re-generate.
//
// Centralized no-op stubs for cross-trait type references.
//
// When a trait is disabled, Core files still reference its types in function
// signatures and method bodies. These stubs provide the minimum API surface
// so that everything compiles. All stubs are inert: hooks never fire,
// guardrails always allow, telemetry emits into the void, recovery never
// triggers, and sessions never save.

import Foundation

// MARK: - Hooks Stubs

#if !Hooks

/// Lightweight enum for subscription filtering without matching associated values.
public enum AgentHookEventKind: Hashable, Sendable {
    case agentStarted
    case agentCompleted
    case agentFailed
    case agentCancelled
    case preToolUse
    case postToolUse
    case llmRequestSent
    case llmResponseReceived
    case transcriptUpdated
    case sessionSaved
    case sessionRestored
    case guardrailTriggered
    case coordinationPhaseStarted
    case coordinationPhaseCompleted
    case memoryUpdated
    case transcriptRepaired
}

/// Events fired during agent and tool execution.
public enum AgentHookEvent: Sendable {
    case agentStarted(goal: String)
    case agentCompleted(result: String)
    case agentFailed(error: Error)
    case agentCancelled

    case preToolUse(calls: [AgentToolCall])
    case postToolUse(results: [ToolResult])

    case llmRequestSent(request: AgentRequest)
    case llmResponseReceived(response: AgentResponse)

    case transcriptUpdated(entry: TranscriptEntry)

    case sessionSaved(sessionId: String)
    case sessionRestored(sessionId: String)

    case guardrailTriggered(policy: String, decision: GuardrailDecision, input: GuardrailInput)

    case coordinationPhaseStarted(phase: String)
    case coordinationPhaseCompleted(phase: String)

    case memoryUpdated(entry: MemoryEntry)
    case transcriptRepaired(violations: [IntegrityViolation])

    public var kind: AgentHookEventKind {
        switch self {
        case .agentStarted: .agentStarted
        case .agentCompleted: .agentCompleted
        case .agentFailed: .agentFailed
        case .agentCancelled: .agentCancelled
        case .preToolUse: .preToolUse
        case .postToolUse: .postToolUse
        case .llmRequestSent: .llmRequestSent
        case .llmResponseReceived: .llmResponseReceived
        case .transcriptUpdated: .transcriptUpdated
        case .sessionSaved: .sessionSaved
        case .sessionRestored: .sessionRestored
        case .guardrailTriggered: .guardrailTriggered
        case .coordinationPhaseStarted: .coordinationPhaseStarted
        case .coordinationPhaseCompleted: .coordinationPhaseCompleted
        case .memoryUpdated: .memoryUpdated
        case .transcriptRepaired: .transcriptRepaired
        }
    }
}

/// The action a hook returns to control execution flow.
public enum HookAction: Sendable {
    case proceed
    case modify(String)
    case block(reason: String)
}

/// A hook that intercepts agent and tool execution events.
public protocol AgentHook: Sendable {
    var subscribedEvents: Set<AgentHookEventKind> { get }
    func handle(_ event: AgentHookEvent) async -> HookAction
}

/// A convenience hook that uses a closure for handling events.
public struct ClosureHook: AgentHook {
    public let subscribedEvents: Set<AgentHookEventKind>
    private let handler: @Sendable (AgentHookEvent) async -> HookAction

    public init(
        on events: Set<AgentHookEventKind>,
        handler: @escaping @Sendable (AgentHookEvent) async -> HookAction
    ) {
        self.subscribedEvents = events
        self.handler = handler
    }

    public func handle(_ event: AgentHookEvent) async -> HookAction {
        await handler(event)
    }
}

/// Stub pipeline — fire() always returns .proceed, add() is a no-op.
public actor AgentHookPipeline {
    public init() {}

    @discardableResult
    public func fire(_ event: AgentHookEvent) -> HookAction { .proceed }

    public func add(_ hook: any AgentHook) {}
}

#endif

// MARK: - Safety Stubs

#if !Safety

/// The kind of content being evaluated by a guardrail.
public enum GuardrailInput: Sendable {
    case toolArguments(toolName: String, arguments: String)
    case llmOutput(text: String)
    case userInput(text: String)
}

/// The decision returned by a guardrail policy.
public enum GuardrailDecision: Sendable {
    case allow
    case sanitize(replacement: String)
    case block(reason: String)
    case warn(reason: String)
}

/// Risk level associated with a guardrail trigger, used for telemetry.
public enum RiskLevel: String, Sendable, Codable {
    case low
    case medium
    case high
    case critical
}

/// A policy that evaluates content for safety before or after processing.
public protocol GuardrailPolicy: Sendable {
    var name: String { get }
    func evaluate(input: GuardrailInput) async -> GuardrailDecision
}

/// Stub pipeline — evaluate() always returns .allow.
public actor GuardrailPipeline {
    public init() {}

    public func add(_ policy: any GuardrailPolicy) {}

    public func evaluate(input: GuardrailInput) async -> (decision: GuardrailDecision, policy: String?) {
        (.allow, nil)
    }
}

/// Errors from guardrail enforcement.
public enum GuardrailError: Error, Sendable {
    case blocked(policy: String, reason: String)
}

/// Stub permission gate — check() is a no-op.
public actor PermissionGate {
    public init() {}

    public func check(toolName: String, arguments: String) async throws {}
}

/// Errors from the permission system.
public enum PermissionError: Error, Sendable {
    case denied(tool: String, reason: String)
    case noApprovalDelegate(tool: String)
    case rejected(tool: String)
}

#endif

// MARK: - Observability Stubs

#if !Observability

/// A structured telemetry event emitted during agent execution.
public struct TelemetryEvent: Sendable {
    public let timestamp: Date
    public let kind: TelemetryEventKind
    public let agentType: String
    public let sessionId: String?

    public init(
        kind: TelemetryEventKind,
        agentType: String = "",
        sessionId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.timestamp = timestamp
        self.kind = kind
        self.agentType = agentType
        self.sessionId = sessionId
    }
}

/// The kind of telemetry event.
public enum TelemetryEventKind: Sendable {
    case agentStarted(goal: String)
    case agentCompleted(result: String, duration: Duration)
    case agentFailed(error: Error)
    case llmCallMade(model: String, inputTokens: Int, outputTokens: Int, duration: Duration, cacheCreationTokens: Int = 0, cacheReadTokens: Int = 0)
    case toolCalled(name: String, duration: Duration, success: Bool)
    case retryAttempted(error: Error, attempt: Int)
    case tokenBudgetExhausted(used: Int, limit: Int)
    case guardrailTriggered(policy: String, risk: RiskLevel)
    case contextCompacted(entriesBefore: Int, entriesAfter: Int, strategy: String)
    case apiErrorClassified(category: String, model: String?)
    case pluginActivated(name: String)
    case pluginError(name: String, error: Error)
}

/// A destination for telemetry events.
public protocol TelemetrySink: Sendable {
    func emit(_ event: TelemetryEvent)
}

/// Tracks cumulative token usage across LLM calls within an agent session.
public actor TokenUsageTracker {
    public private(set) var totalInputTokens: Int = 0
    public private(set) var totalOutputTokens: Int = 0
    public private(set) var callCount: Int = 0

    public init() {}

    public func record(inputTokens: Int, outputTokens: Int) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        callCount += 1
    }

    public var totalTokens: Int { totalInputTokens + totalOutputTokens }

    public func reset() {
        totalInputTokens = 0
        totalOutputTokens = 0
        callCount = 0
    }
}

#endif

// MARK: - Resilience Stubs

#if !Resilience

/// Mutable state tracking which recovery strategies have been attempted.
public struct RecoveryState: Sendable {
    public var hasAttemptedCompaction: Bool = false
    public var hasAttemptedTokenEscalation: Bool = false
    public var hasAttemptedContinuation: Bool = false
    public var maxOutputTokensOverride: Int? = nil
    public var recoveryCount: Int = 0
    public let maxRecoveryAttempts: Int

    public init(maxRecoveryAttempts: Int = 3) {
        self.maxRecoveryAttempts = maxRecoveryAttempts
    }

    public var canRecover: Bool { false }
}

/// Errors that can trigger recovery strategies.
public enum RecoverableError: Sendable {
    case contextWindowExceeded
    case outputTruncated
    case apiError(Error)
}

/// The result of a recovery attempt.
public enum RecoveryResult: Sendable {
    case recovered(continuationPrompt: String?)
    case cannotRecover
}

/// Stub recovery chain — .default is nil, attemptRecovery always returns .cannotRecover.
public struct RecoveryChain: Sendable {
    public static var `default`: RecoveryChain {
        RecoveryChain()
    }

    public init() {}

    public func attemptRecovery(
        from error: RecoverableError,
        state: inout RecoveryState,
        transcript: ObservableTranscript,
        compressor: (any TranscriptCompressor)?,
        budget: inout ContextBudget?
    ) async throws -> RecoveryResult {
        .cannotRecover
    }
}

/// Stub classifyRecoverableError — always returns nil.
public func classifyRecoverableError(_ error: Error) -> RecoverableError? {
    nil
}

/// Configures when transcript compression fires in the tool loop.
public enum CompactionTrigger: Sendable {
    case threshold(Double)
    case tokenCount(Int)
    case entryCount(Int)
    case manual

    public static var `default`: CompactionTrigger { .manual }

    public func shouldCompact(budget: ContextBudget?, entryCount: Int) -> Bool {
        false
    }
}

/// Tracks per-model cooldown state for rate-limit-aware retry logic.
public actor RateLimitState {
    public init() {}
}

/// Stub retryWithRateLimit — passes through to operation directly.
public func retryWithRateLimit<T: Sendable>(
    rateLimitState: RateLimitState,
    policy: Never? = nil,
    telemetry: (any TelemetrySink)? = nil,
    operation: @Sendable () async throws -> T
) async throws -> T {
    try await operation()
}

/// A transcript integrity violation detected during consistency checking.
public enum IntegrityViolation: Sendable {
    case orphanedToolCall(name: String, index: Int)
    case orphanedToolResult(name: String, index: Int)
    case invalidSequence(expected: String, found: String, index: Int)
}

/// Semantic classification of API errors for structured handling.
public enum APIErrorCategory: Sendable {
    case auth
    case quota
    case rateLimit(retryAfterSeconds: Int?)
    case connectivity
    case serverError
    case badRequest
    case unknown
}

/// An error enriched with semantic classification and execution context.
public struct ClassifiedError: Error, Sendable {
    public let underlyingError: Error
    public let category: APIErrorCategory
    public let model: String?
    public let isRetryable: Bool
    public let retryAfterSeconds: Int?

    public init(
        underlyingError: Error,
        category: APIErrorCategory,
        model: String? = nil,
        isRetryable: Bool = false,
        retryAfterSeconds: Int? = nil
    ) {
        self.underlyingError = underlyingError
        self.category = category
        self.model = model
        self.isRetryable = isRetryable
        self.retryAfterSeconds = retryAfterSeconds
    }
}

/// Stub classifyAPIError — returns .unknown.
public func classifyAPIError(_ error: Error, model: String? = nil) -> ClassifiedError {
    ClassifiedError(underlyingError: error, category: .unknown, model: model, isRetryable: false)
}

#endif

// MARK: - Persistence Stubs

#if !Persistence

/// A codable snapshot of agent state for session persistence and resume.
public struct AgentSession: Codable, Sendable {
    public let sessionId: String
    public let agentType: String
    public let goal: String
    public let transcriptEntries: [CodableTranscriptEntry]
    public let completedStepIndex: Int
    public let customState: Data?
    public let createdAt: Date
    public let savedAt: Date

    public init(
        sessionId: String = UUID().uuidString,
        agentType: String,
        goal: String,
        transcriptEntries: [CodableTranscriptEntry],
        completedStepIndex: Int,
        customState: Data? = nil,
        createdAt: Date = Date(),
        savedAt: Date = Date()
    ) {
        self.sessionId = sessionId
        self.agentType = agentType
        self.goal = goal
        self.transcriptEntries = transcriptEntries
        self.completedStepIndex = completedStepIndex
        self.customState = customState
        self.createdAt = createdAt
        self.savedAt = savedAt
    }
}

/// A codable mirror of TranscriptEntry for session persistence.
public enum CodableTranscriptEntry: Codable, Sendable {
    case userMessage(String)
    case assistantMessage(String)
    case toolCall(name: String, arguments: String)
    case toolResult(name: String, result: String)
    case error(String)

    public init(from entry: TranscriptEntry) {
        switch entry {
        case .userMessage(let text):
            self = .userMessage(text)
        case .assistantMessage(let text):
            self = .assistantMessage(text)
        case .toolCall(let name, let args):
            self = .toolCall(name: name, arguments: args)
        case .toolResult(let name, let result, _):
            self = .toolResult(name: name, result: result)
        case .reasoning:
            self = .assistantMessage("[reasoning]")
        case .error(let msg):
            self = .error(msg)
        }
    }

    public func toTranscriptEntry() -> TranscriptEntry {
        switch self {
        case .userMessage(let text):
            return .userMessage(text)
        case .assistantMessage(let text):
            return .assistantMessage(text)
        case .toolCall(let name, let args):
            return .toolCall(name: name, arguments: args)
        case .toolResult(let name, let result):
            return .toolResult(name: name, result: result, duration: .zero)
        case .error(let msg):
            return .error(msg)
        }
    }
}

/// Abstract persistence backend for agent sessions.
public protocol SessionStore: Sendable {
    func save(_ session: AgentSession) async throws
    func load(sessionId: String) async throws -> AgentSession?
    func list() async throws -> [SessionMetadata]
    func delete(sessionId: String) async throws
}

/// Lightweight summary of a saved session for listing without loading full transcripts.
public struct SessionMetadata: Codable, Sendable, Identifiable {
    public let id: String
    public let agentType: String
    public let goal: String
    public let createdAt: Date
    public let savedAt: Date
    public let status: SessionStatus

    public init(
        id: String,
        agentType: String,
        goal: String,
        createdAt: Date,
        savedAt: Date,
        status: SessionStatus
    ) {
        self.id = id
        self.agentType = agentType
        self.goal = goal
        self.createdAt = createdAt
        self.savedAt = savedAt
        self.status = status
    }
}

/// The persistence status of a saved session.
public enum SessionStatus: String, Codable, Sendable {
    case active
    case paused
    case completed
    case failed
}

/// Categories for organizing agent memory entries.
public enum MemoryCategory: Codable, Hashable, Sendable {
    case user
    case feedback
    case project
    case reference
    case custom(String)
}

/// A single persistent memory entry stored across sessions.
public struct MemoryEntry: Codable, Sendable, Identifiable {
    public let id: String
    public let category: MemoryCategory
    public var content: String
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        category: MemoryCategory,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.content = content
        self.createdAt = createdAt
    }
}

#endif

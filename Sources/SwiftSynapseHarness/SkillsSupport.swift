// Generated from CodeGenSpecs/Shared-Skills.md — Do not edit manually. Update spec and re-generate.

import Foundation
import SwiftOpenSkills
import SwiftOpenResponsesDSL

#if Core

// MARK: - Re-exports

/// Re-exports ``SkillStore`` so users only need `import SwiftSynapseHarness`.
public typealias SkillStore = SwiftOpenSkills.SkillStore

/// Re-exports ``SkillSearchPath`` so users only need `import SwiftSynapseHarness`.
public typealias SkillSearchPath = SwiftOpenSkills.SkillSearchPath

/// Re-exports ``Skill`` so users only need `import SwiftSynapseHarness`.
public typealias Skill = SwiftOpenSkills.Skill

#if canImport(SwiftOpenSkillsResponses)
import SwiftOpenSkillsResponses

/// Re-exports ``SkillsAgent`` so users only need `import SwiftSynapseHarness`.
public typealias SkillsAgent = SwiftOpenSkillsResponses.SkillsAgent

/// Re-exports ``Skills`` so users only need `import SwiftSynapseHarness`.
public typealias Skills = SwiftOpenSkillsResponses.Skills
#endif

// MARK: - SkillsError

/// Domain errors thrown by skill tools before reaching ``SkillStore`` handlers.
public enum SkillsError: Error, Sendable {
    /// The skill store has not been loaded. Call `store.load()` before registering or invoking skills.
    case storeNotLoaded
    /// Failed to encode skill tool input as UTF-8 JSON. Should never occur in practice.
    case encodingFailed
}

// MARK: - ActivateSkillTool

/// A tool that activates a skill by slug, returning its full instruction text.
///
/// When the LLM calls this tool with a skill slug, the backing ``SkillStore`` loads
/// and returns the skill's instruction text with variable substitution applied
/// (`${SKILL_DIR}` → absolute path, `${SKILL_SLUG}` → canonical slug). The LLM
/// then follows those instructions.
///
/// Register via ``ToolRegistry/registerSkills(_:)`` and prepend
/// `store.catalog().systemPromptSection()` to the system prompt so the LLM knows
/// which skills are available before deciding which to activate.
public struct ActivateSkillTool: AgentToolProtocol {
    /// The slug of the skill to activate.
    public struct Input: Codable, Sendable {
        /// The slug of the skill to activate.
        public var name: String
    }
    public typealias Output = String

    public static var name: String { SkillStore.activateSkillToolName }
    public static var description: String { SkillStore.activateSkillToolDescription }

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: SkillStore.activateSkillToolName,
            description: SkillStore.activateSkillToolDescription,
            parameters: .object(
                properties: ["name": .string(description: "The slug of the skill to activate")],
                required: ["name"]
            )
        )
    }

    /// Sequential — the handler performs file I/O and variable substitution.
    public static var isConcurrencySafe: Bool { false }

    private let store: SkillStore

    public init(store: SkillStore) {
        self.store = store
    }

    public func execute(input: Input) async throws -> String {
        guard await store.isLoaded else { throw SkillsError.storeNotLoaded }
        let data = try JSONEncoder().encode(input)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SkillsError.encodingFailed
        }
        return try await store.activateSkillHandler(argumentsJSON: json)
    }
}

// MARK: - ListSkillsTool

/// A tool that returns a JSON catalog of all loaded skills.
///
/// The LLM calls this to discover available skills before deciding which to activate
/// via ``ActivateSkillTool``. Each entry includes the skill's slug, description,
/// `whenToUse` hint, argument hints, and aliases.
///
/// Register via ``ToolRegistry/registerSkills(_:)``.
public struct ListSkillsTool: AgentToolProtocol {
    /// No input parameters required.
    public struct Input: Codable, Sendable {}
    public typealias Output = String

    public static var name: String { SkillStore.listSkillsToolName }
    public static var description: String { SkillStore.listSkillsToolDescription }

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: SkillStore.listSkillsToolName,
            description: SkillStore.listSkillsToolDescription,
            parameters: .object(properties: [:], required: [])
        )
    }

    /// Concurrent-safe — read-only catalog query with no side effects.
    public static var isConcurrencySafe: Bool { true }

    private let store: SkillStore

    public init(store: SkillStore) {
        self.store = store
    }

    public func execute(input: Input) async throws -> String {
        guard await store.isLoaded else { throw SkillsError.storeNotLoaded }
        return try await store.listSkillsHandler(argumentsJSON: "{}")
    }
}

// MARK: - ToolRegistry Extension

extension ToolRegistry {
    /// Registers ``ActivateSkillTool`` and ``ListSkillsTool`` for the given store.
    ///
    /// Call this after loading the store. Then prepend
    /// `store.catalog().systemPromptSection()` to the agent's system prompt so the
    /// LLM knows which skills are available.
    ///
    /// ```swift
    /// let store = SkillStore()
    /// _ = try await store.load()
    /// tools.registerSkills(store)
    /// ```
    public func registerSkills(_ store: SkillStore) {
        register(ActivateSkillTool(store: store))
        register(ListSkillsTool(store: store))
    }
}

#endif

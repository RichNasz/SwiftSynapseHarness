# Spec: Skills Integration

**Generates:**
- `Sources/SwiftSynapseHarness/SkillsSupport.swift`

## Overview

Integrates SwiftOpenSkills (`SkillStore`) into `AgentToolProtocol` / `ToolRegistry`. Two tool implementations bridge `SkillStore`'s raw LLM handlers into the typed tool system:

- **`ActivateSkillTool`** — wraps `SkillStore.activateSkillHandler()`. When the LLM calls this tool with a skill slug, the store loads and returns the skill's full instruction text (with variable substitution). The LLM then follows those instructions.
- **`ListSkillsTool`** — wraps `SkillStore.listSkillsHandler()`. Returns a JSON catalog of all loaded skills so the LLM can choose which to activate.

Skills are purely declarative — they contain instruction text, not executable closures. The bridge works because `activateSkillHandler(argumentsJSON:)` and `listSkillsHandler(argumentsJSON:)` already accept JSON input and return strings, mapping directly to `AgentToolProtocol`'s `execute(input:) -> Output` where `Output == String`.

A convenience `ToolRegistry.registerSkills(_:)` extension registers both tools in one call. Prepend `store.catalog().systemPromptSection()` to the agent's system prompt so the LLM knows which skills are available before deciding which to activate.

---

## Imports

```swift
import Foundation
import SwiftOpenSkills
import SwiftOpenResponsesDSL
```

`SwiftOpenResponsesDSL` is imported for `FunctionToolParam` and `JSONSchema` (= `JSONSchemaValue`). `SwiftOpenSkills` provides `SkillStore`, `SkillSearchPath`, and `Skill`. Both are declared in `Package.swift`.

---

## Re-exports (Typealiases)

```swift
public typealias SkillStore = SwiftOpenSkills.SkillStore
public typealias SkillSearchPath = SwiftOpenSkills.SkillSearchPath
public typealias Skill = SwiftOpenSkills.Skill
```

Users only need `import SwiftSynapseHarness` — no direct import of `SwiftOpenSkills` required at the call site.

Conditional re-exports for the Responses DSL integration (available when `SwiftOpenSkillsResponses` can be imported):

```swift
#if canImport(SwiftOpenSkillsResponses)
import SwiftOpenSkillsResponses
public typealias SkillsAgent = SwiftOpenSkillsResponses.SkillsAgent
public typealias Skills = SwiftOpenSkillsResponses.Skills
#endif
```

---

## SkillsError

Domain errors for skill tool execution. Thrown before reaching `SkillStore` handlers so callers get a clear, typed failure rather than a confusing downstream error.

```swift
public enum SkillsError: Error, Sendable {
    /// The skill store has not been loaded. Call `store.load()` before registering or invoking skills.
    case storeNotLoaded
    /// Failed to encode skill tool input as UTF-8 JSON. Should never occur in practice.
    case encodingFailed
}
```

---

## ActivateSkillTool

`AgentToolProtocol` conformance that calls `SkillStore.activateSkillHandler(argumentsJSON:)`.

**Input:** `struct { var name: String }` — decoded from `{"name":"<slug>"}`, matching the handler's expected JSON format.

**Output:** `String` — the skill's full instruction text with variable substitution applied (`${SKILL_DIR}` → absolute path, `${SKILL_SLUG}` → canonical slug).

**Static properties:**
- `name` = `SkillStore.activateSkillToolName` (= `"activate_skill"`)
- `description` = `SkillStore.activateSkillToolDescription`
- `inputSchema` — object schema with a single required `name: String` property
- `isConcurrencySafe = false` — handler performs file I/O and variable substitution

**`execute(input:)`:** Guards that `store.isLoaded` (throws `SkillsError.storeNotLoaded` if not). JSON-encodes `input` via `JSONEncoder`; if UTF-8 conversion fails, throws `SkillsError.encodingFailed` rather than silently substituting `"{}"`. Passes the JSON string to `store.activateSkillHandler(argumentsJSON:)` and returns the instruction string. `AnyAgentTool`'s `Output == String` fast path returns the string directly without re-encoding.

```swift
public struct ActivateSkillTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
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

    public static var isConcurrencySafe: Bool { false }

    private let store: SkillStore
    public init(store: SkillStore) { self.store = store }

    public func execute(input: Input) async throws -> String {
        guard await store.isLoaded else { throw SkillsError.storeNotLoaded }
        let data = try JSONEncoder().encode(input)
        guard let json = String(data: data, encoding: .utf8) else {
            throw SkillsError.encodingFailed
        }
        return try await store.activateSkillHandler(argumentsJSON: json)
    }
}
```

---

## ListSkillsTool

`AgentToolProtocol` conformance that calls `SkillStore.listSkillsHandler(argumentsJSON:)`.

**Input:** `struct {}` — no parameters. The handler ignores its input entirely.

**Output:** `String` — JSON array of `CatalogEntry` objects (slug, name, description, whenToUse, argumentHint, aliases, allowedTools).

**Static properties:**
- `name` = `SkillStore.listSkillsToolName` (= `"list_skills"`)
- `description` = `SkillStore.listSkillsToolDescription`
- `inputSchema` — empty object schema (no properties, no required fields)
- `isConcurrencySafe = true` — read-only catalog query with no side effects

**`execute(input:)`:** Guards that `store.isLoaded` (throws `SkillsError.storeNotLoaded` if not), then passes `"{}"` to `store.listSkillsHandler(argumentsJSON:)` and returns the JSON catalog string.

```swift
public struct ListSkillsTool: AgentToolProtocol {
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

    public static var isConcurrencySafe: Bool { true }

    private let store: SkillStore
    public init(store: SkillStore) { self.store = store }

    public func execute(input: Input) async throws -> String {
        guard await store.isLoaded else { throw SkillsError.storeNotLoaded }
        return try await store.listSkillsHandler(argumentsJSON: "{}")
    }
}
```

---

## ToolRegistry Extension

```swift
extension ToolRegistry {
    public func registerSkills(_ store: SkillStore) {
        register(ActivateSkillTool(store: store))
        register(ListSkillsTool(store: store))
    }
}
```

Registers `activate_skill` and `list_skills` in one call. Call this after the store has been loaded.

---

## Usage Example

```swift
import SwiftSynapseHarness

// 1. Load skills from standard locations
let store = SkillStore()
_ = try await store.load()

// 2. Register skill tools so the LLM can discover and activate them
let tools = ToolRegistry()
tools.register(MyOtherTool())
tools.registerSkills(store)          // adds activate_skill + list_skills

// 3. Prepend the skill catalog to the system prompt
let skillSection = await store.catalog().systemPromptSection()
let systemPrompt = """
You are a helpful assistant.

\(skillSection)
"""

// 4. Run — the LLM will call list_skills to discover, then activate_skill
//    to load instruction text for any skill it needs
let config = try AgentConfiguration.fromEnvironment()
let client = config.buildClient()
let response = try await AgentToolLoop.run(
    client: client,
    config: config,
    goal: goal,
    tools: tools,
    transcript: transcript,
    systemPrompt: systemPrompt
)
```

---

## Package.swift Reference

```swift
// In package dependencies (already declared):
.package(url: "https://github.com/RichNasz/SwiftOpenSkills", branch: "main"),

// In SwiftSynapseHarness target dependencies (already declared):
.product(name: "SwiftOpenSkills", package: "SwiftOpenSkills"),
.product(name: "SwiftOpenSkillsResponses", package: "SwiftOpenSkills"),
```

---

## Implementation Notes for Generator

- All new types (`ActivateSkillTool`, `ListSkillsTool`, `ToolRegistry` extension) live inside `#if Core` / `#endif`
- Re-exports and `#if canImport(SwiftOpenSkillsResponses)` block are also inside `#if Core`
- Imports (`Foundation`, `SwiftOpenSkills`, `SwiftOpenResponsesDSL`) go outside the `#if Core` guard, at the top of the file
- `FunctionToolParam.parameters` uses `JSONSchemaValue` from `SwiftLLMToolMacros` (re-exported via `SwiftOpenResponsesDSL` as `JSONSchema`)
- Use the dictionary overload `.object(properties: [String: JSONSchemaValue], required: [String])` from the `JSONSchemaValue` extension in `SwiftOpenResponsesDSL` — it sorts keys alphabetically for stable output
- The `SkillStore.activateSkillToolName`, `activateSkillToolDescription`, `listSkillsToolName`, and `listSkillsToolDescription` are all `static let` on `SkillStore` — accessible without an instance

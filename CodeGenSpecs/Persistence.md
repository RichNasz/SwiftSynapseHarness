# Spec: Persistence Trait

**Trait guard:** `#if Persistence` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/AgentSession.swift`
- `Sources/SwiftSynapseHarness/SessionPersistence.swift`
- `Sources/SwiftSynapseHarness/AgentMemory.swift`

## Overview

The Persistence trait provides session snapshots for pause/resume workflows and cross-session agent memory. Not included in the default `Production` trait — requires explicit opt-in via `traits: ["Production", "Persistence"]` or `traits: ["Advanced"]`.

Stubs in `TraitStubs.swift` provide minimal `AgentSession`, `CodableTranscriptEntry`, `MemoryEntry` types and an unimplemented `SessionStore` protocol when this trait is disabled, so Core/Hooks files that reference these types compile without Persistence.

---

## AgentSession

Codable snapshot of agent state for pause/resume:

- `AgentSession`: sessionId, agentType, goal, transcriptEntries (`[CodableTranscriptEntry]`), completedStepIndex, customState (`[String: String]`), createdAt, updatedAt
- `CodableTranscriptEntry`: Codable bridge for `TranscriptEntry`. Cases: `.userMessage(String)`, `.assistantMessage(String)`, `.toolCall(name:arguments:)`, `.toolResult(name:result:)`, `.error(String)`. Methods: `toTranscriptEntry()`, `from(_ entry: TranscriptEntry) -> CodableTranscriptEntry?`

---

## SessionPersistence

File-based persistence for `AgentSession` snapshots:

- `SessionStore` protocol: `save(_ session:)`, `load(sessionId:)`, `list() -> [SessionMetadata]`, `delete(sessionId:)` — all `async throws`, `Sendable`
- `SessionMetadata`: lightweight summary (id, agentType, goal, createdAt, updatedAt, status)
- `SessionStatus` enum: `.active`, `.paused`, `.completed`, `.failed`
- `FileSessionStore` actor: one JSON file per session in configurable directory (default `~/.swiftsynapse/sessions/`)

**Integration:** `agentRun()` accepts optional `sessionStore`. Auto-saves on completion, error, and cancellation. Hook events: `.sessionSaved(sessionId:)`, `.sessionRestored(sessionId:)`.

---

## AgentMemory

Cross-session persistent memory, distinct from `TeamMemory` (coordination-scoped) and `SessionStore` (single-session snapshots):

- `MemoryCategory` enum (Codable): `.user`, `.feedback`, `.project`, `.reference`, `.custom(String)`
- `MemoryEntry` (Codable, Identifiable): id, category, content, createdAt, lastAccessedAt, accessCount, tags (`[String]`)
- `MemoryStore` protocol: `save(_ entry:)`, `retrieve(category:limit:)`, `search(query:limit:)`, `delete(id:)`, `all()`, `clear()`
- `FileMemoryStore` actor: one JSON file per entry in `~/.swiftsynapse/memory/`, entries named by id

**Hook event:** `.memoryUpdated(entry:)`

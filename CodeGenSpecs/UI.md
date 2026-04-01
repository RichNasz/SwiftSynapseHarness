# SwiftSynapseUI Spec

## Purpose

Defines the `SwiftSynapseUI` library target — a collection of SwiftUI views and protocols that provide a complete, drop-in agent UI for any `@SpecDrivenAgent` actor.

`SwiftSynapseUI` is a separate SPM product from `SwiftSynapseHarness`. Apps that need UI import both; CLI tools and server-side agents import `SwiftSynapseHarness` only.

## Files

### `ObservableAgent.swift`

Protocol `ObservableAgent: Actor` that all `@SpecDrivenAgent` actors conform to. Exposes `status`, `transcript`, `run(goal:)`, and `execute(goal:)`. Views accept any `ObservableAgent`, making them reusable across all agents.

Imports: `SwiftSynapseMacrosClient`

### `AgentAppIntent.swift`

Protocol `AgentAppIntent: AppIntent` for agent-backed App Intents. Associates an `AgentType: ObservableAgent` and requires `goal: String` and `createAgent() throws -> AgentType`. Default `perform()` implementation calls `agent.execute(goal:)` and returns the result.

Imports: `AppIntents`, `SwiftSynapseMacrosClient`

### `AgentStatusView.swift`

`AgentStatusView: View` — displays `AgentStatus` as an icon + label:
- `.idle` → gray circle
- `.running` → animated `ProgressView`
- `.paused` → yellow pause icon
- `.completed` → green checkmark
- `.error` → red exclamation, tappable popover with error detail

Imports: `SwiftUI`, `SwiftSynapseMacrosClient`

### `AgentChatView.swift`

`AgentChatView<A: ObservableAgent>: View` — complete drop-in chat UI. Combines `AgentStatusView`, `TranscriptView`, and an input bar (TextField + send button). Send is disabled while running. Supports Cmd+Return keyboard shortcut.

Imports: `SwiftUI`, `SwiftSynapseMacrosClient`

### `TranscriptView.swift`

`TranscriptView: View` — renders `ObservableTranscript` as a chat-style list using `ScrollViewReader`. User messages: right-aligned blue bubble. Assistant messages: left-aligned gray bubble. Tool calls: `ToolCallDetailView`. Errors: red row. Streaming text: `StreamingTextView` at the bottom. Auto-scrolls on new entries and streaming delta.

Imports: `SwiftUI`, `SwiftSynapseMacrosClient`

### `StreamingTextView.swift`

`StreamingTextView: View` — renders `ObservableTranscript.streamingText` with an animated blinking cursor (`|`) while `isStreaming` is true. Cursor uses `easeInOut(duration: 0.5).repeatForever(autoreverses: true)`. Shows final text without cursor when not streaming.

Imports: `SwiftUI`, `SwiftSynapseMacrosClient`

### `ToolCallDetailView.swift`

`ToolCallDetailView: View` — expandable `DisclosureGroup` showing tool name (orange wrench icon), arguments (JSON pretty-printed in monospaced font), optional result, and optional duration badge. `formatJSON(_:)` private method uses `JSONSerialization` to pretty-print; falls back to raw string.

Imports: `SwiftUI`, `SwiftSynapseMacrosClient`

## Dependencies

`SwiftSynapseUI` target depends on `SwiftSynapseHarness` (not directly on `SwiftSynapseMacrosClient`). Because `SwiftSynapseHarness` re-exports `SwiftSynapseMacrosClient` via `@_exported import`, all `import SwiftSynapseMacrosClient` statements in these files resolve correctly. `SwiftUI` and `AppIntents` are system frameworks — not SPM products.

## Platforms

iOS 26+, macOS 26+, visionOS 2+

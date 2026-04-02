# SwiftSynapseUI Guide

Drop-in SwiftUI components for any `ObservableAgent`.

## Overview

SwiftSynapseUI provides seven components that work with any agent conforming to ``ObservableAgent``. All components observe `agent.status` and `agent.transcript` for automatic UI updates via SwiftUI's observation system and actor isolation. Import `SwiftSynapseUI` alongside `SwiftSynapseHarness` — both are products in the same package.

```swift
import SwiftSynapseHarness
import SwiftSynapseUI
```

## ObservableAgent Protocol

``ObservableAgent`` is the bridge between your agent and SwiftSynapseUI views. All `@SpecDrivenAgent` actors automatically conform:

```swift
public protocol ObservableAgent: Actor {
    var status: AgentStatus { get }
    var transcript: ObservableTranscript { get }
    func run(goal: String) async throws -> String
    func execute(goal: String) async throws -> String
}
```

**What each member means:**

| Member | Purpose |
|--------|---------|
| `status` | Current state: `.idle`, `.running`, `.paused`, `.completed(String)`, `.error(Error)` |
| `transcript` | Observable collection of `TranscriptEntry` values |
| `run(goal:)` | Macro-generated entry point — manages full lifecycle |
| `execute(goal:)` | Implement your agent logic here; don't call this directly |

### Custom Conformance

If you're not using `@SpecDrivenAgent`, conform to `ObservableAgent` manually. Use `@Observable` for SwiftUI compatibility:

```swift
@Observable
actor MyCustomAgent: ObservableAgent {
    var status: AgentStatus = .idle
    var transcript = ObservableTranscript()

    func run(goal: String) async throws -> String {
        status = .running
        transcript.reset()
        do {
            let result = try await execute(goal: goal)
            status = .completed(result)
            return result
        } catch {
            status = .error(error)
            throw error
        }
    }

    func execute(goal: String) async throws -> String {
        // Your agent logic here
        return "Done"
    }
}
```

## AgentChatView

``AgentChatView`` is a complete, drop-in chat interface. Pass an agent and get a full conversational UI:

```swift
import SwiftSynapseUI

struct ContentView: View {
    @State var agent = WeatherAgent(config: config, tools: tools)

    var body: some View {
        AgentChatView(agent: agent)
    }
}
```

**What it renders:**

| Component | Description |
|-----------|-------------|
| ``AgentStatusView`` | Status bar at the top |
| ``TranscriptView`` | Scrollable transcript in the middle |
| Text input + Send button | At the bottom, disabled while running |

`AgentChatView` is generic over any `A: ObservableAgent`, so it works with every agent type without modification. The Send button calls `agent.run(goal:)` with the text field's content.

## AgentStatusView

``AgentStatusView`` renders the current agent status as an icon + label. Embed it anywhere you need a lightweight status indicator:

```swift
HStack {
    AgentStatusView(status: agent.status)
    Text("Weather Agent")
    Spacer()
}
.padding()
```

**Status rendering:**

| Status | Icon | Label |
|--------|------|-------|
| `.idle` | Gray circle | "Idle" |
| `.running` | Animated spinner | "Running" |
| `.paused` | Yellow pause icon | "Paused" |
| `.completed` | Green checkmark | "Completed" |
| `.error(e)` | Red exclamation | "Error" + tap for detail popover |

Tapping the error state shows a popover with the error's `localizedDescription`.

## TranscriptView

``TranscriptView`` renders all transcript entries as a chat-style scrollable list. It auto-scrolls to the bottom as new entries arrive:

```swift
TranscriptView(transcript: agent.transcript)
```

**Entry rendering:**

| Entry type | Appearance |
|------------|------------|
| `.user(String)` | Right-aligned blue bubble |
| `.assistant(String)` | Left-aligned gray bubble |
| `.toolCall(name:args:)` | Expandable ``ToolCallDetailView`` |
| `.toolResult(name:result:duration:)` | Expandable result row |
| `.error(String)` | Red error row |

The last assistant entry during streaming uses ``StreamingTextView`` with an animated cursor. Once the response completes, it transitions to static text.

## StreamingTextView

``StreamingTextView`` displays text being streamed in real-time, with a blinking cursor while streaming is active:

```swift
StreamingTextView(
    text: streamingContent,
    isStreaming: agent.status == .running
)
```

While `isStreaming` is `true`, the cursor blinks after the last character. When `isStreaming` becomes `false`, the cursor disappears and the text is displayed statically.

Use this directly when building custom layouts that need to show streaming text outside of a full `TranscriptView`.

## ToolCallDetailView

``ToolCallDetailView`` renders a single tool call as an expandable disclosure group:

```swift
ToolCallDetailView(
    name: "search_docs",
    arguments: #"{"query": "SwiftUI animation", "maxResults": 5}"#,
    result: "Found 12 results: ...",
    duration: 0.342
)
```

**What it shows when expanded:**

| Field | Description |
|-------|-------------|
| Tool name | Displayed in the disclosure group header |
| Arguments | Pretty-printed JSON, monospaced, selectable |
| Result | Monospaced, selectable |
| Duration | Formatted as milliseconds or seconds |

The disclosure group is collapsed by default. ``TranscriptView`` embeds this automatically for `.toolCall` and `.toolResult` entries.

## AgentAppIntent

``AgentAppIntent`` lets you expose any agent as a Siri Shortcut or App Shortcuts action:

```swift
import AppIntents
import SwiftSynapseUI

struct AskWeatherAgentIntent: AgentAppIntent {
    static var title: LocalizedStringResource = "Ask Weather Agent"
    static var description = IntentDescription("Get weather info using AI")

    @Parameter(title: "Goal") var goal: String

    func createAgent() throws -> WeatherAgent {
        let config = try AgentConfiguration.fromEnvironment()
        let tools = ToolRegistry()
        tools.register(GetWeatherTool())
        return WeatherAgent(config: config, tools: tools)
    }
}
```

`AgentAppIntent` provides a default `perform()` implementation that:
1. Calls `createAgent()` to instantiate your agent
2. Calls `agent.execute(goal: goal)` 
3. Returns the result as a `String` value to Shortcuts

Register the intent in your app's `AppShortcutsProvider` to expose it in the Shortcuts app and Siri.

**Requirements:**
- Import `AppIntents` alongside `SwiftSynapseUI`
- The associated `AgentType` must conform to `ObservableAgent`
- `createAgent()` is synchronous-throwing (not async) — all async setup happens in `execute(goal:)`

## Platform Requirements

| Platform | Minimum Version |
|----------|----------------|
| macOS | 26+ |
| iOS | 26+ |
| visionOS | 2+ |

`AgentAppIntent` requires the `AppIntents` framework, available on all supported platforms.

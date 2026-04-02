# Doc-SwiftSynapseUI

## Purpose

Specifies all documentation for the `SwiftSynapseUI` product. This includes the DocC catalog (navigation/index) and the full usage guide covering all 7 views, the `ObservableAgent` protocol, and `AgentAppIntent`.

## Generates

- `Sources/SwiftSynapseUI/SwiftSynapseUI.docc/SwiftSynapseUI.md` (catalog)
- `Sources/SwiftSynapseUI/SwiftSynapseUI.docc/UIGuide.md` (usage guide)

Note: The `SwiftSynapseUI.docc/` directory is new and must be created.

---

## SwiftSynapseUI.md (Catalog)

### Title & Overview

Title: ` ``SwiftSynapseUI`` `

Tagline: Drop-in SwiftUI views and App Intents for any `ObservableAgent` — chat UI, status display, transcript rendering, streaming text, and Siri Shortcuts.

Overview prose: SwiftSynapseUI provides ready-made SwiftUI views that work with any agent conforming to `ObservableAgent`. Import `SwiftSynapseUI` to add a complete chat interface, real-time status display, and Siri Shortcut support to any SwiftSynapse agent in minutes.

### Topics

#### Essentials

- `<doc:UIGuide>`

#### Core Protocol

- `` ``ObservableAgent`` ``

#### Views

- `` ``AgentChatView`` ``
- `` ``AgentStatusView`` ``
- `` ``TranscriptView`` ``
- `` ``StreamingTextView`` ``
- `` ``ToolCallDetailView`` ``

#### App Intents

- `` ``AgentAppIntent`` ``

---

## UIGuide.md (Usage Guide)

### Title & Overview

Title: `SwiftSynapseUI Guide`

Tagline: Drop-in SwiftUI components for any `ObservableAgent`.

Overview: SwiftSynapseUI provides seven components that work with any agent conforming to `ObservableAgent`. All components observe `agent.status` and `agent.transcript` for automatic UI updates via SwiftUI's `@State` and actor isolation. Import `SwiftSynapseUI` alongside `SwiftSynapseHarness` — both are in the same package.

---

### Section: ObservableAgent Protocol

`ObservableAgent` is the bridge between your agent and SwiftSynapseUI views. All `@SpecDrivenAgent` actors automatically conform.

```swift
public protocol ObservableAgent: Actor {
    var status: AgentStatus { get }
    var transcript: ObservableTranscript { get }
    func run(goal: String) async throws -> String
    func execute(goal: String) async throws -> String
}
```

**What each property means:**
- `status` — current state: `.idle`, `.running`, `.paused`, `.completed(String)`, `.error(Error)`
- `transcript` — observable collection of `TranscriptEntry` values (user messages, assistant responses, tool calls, tool results, errors)
- `run(goal:)` — macro-generated entry point; manages lifecycle, calls `execute(goal:)` internally
- `execute(goal:)` — implement your agent logic here; do not call it directly

If you have a custom agent class (not using `@SpecDrivenAgent`), conform to `ObservableAgent` manually:

```swift
@Observable
actor MyCustomAgent: ObservableAgent {
    var status: AgentStatus = .idle
    var transcript = ObservableTranscript()

    func run(goal: String) async throws -> String {
        status = .running
        defer { /* update status */ }
        return try await execute(goal: goal)
    }

    func execute(goal: String) async throws -> String {
        // your logic
    }
}
```

---

### Section: AgentChatView

`AgentChatView<A>` is a complete, drop-in chat interface. It handles the input field, send button, transcript display, and running state automatically.

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
- `AgentStatusView` at the top showing current status
- `TranscriptView` in the middle (scrollable, auto-scrolls to bottom)
- Text input field + Send button at the bottom
- Disables input while `agent.status == .running`

`AgentChatView` is generic over any `ObservableAgent`, so it works with every agent type without modification.

---

### Section: AgentStatusView

`AgentStatusView` renders the current agent status as an icon + label. Embed it anywhere you need a lightweight status indicator:

```swift
HStack {
    AgentStatusView(status: agent.status)
    Text("My Agent")
}
```

**Status rendering:**

| Status | Icon | Label |
|--------|------|-------|
| `.idle` | Gray circle | "Idle" |
| `.running` | Animated spinner | "Running" |
| `.paused` | Yellow pause | "Paused" |
| `.completed` | Green checkmark | "Completed" |
| `.error(e)` | Red exclamation | "Error" + tap for detail popover |

Tapping the error state shows a popover with the error's `localizedDescription`.

---

### Section: TranscriptView

`TranscriptView` renders all transcript entries as a chat-style scrollable list. It auto-scrolls to the bottom as new entries arrive:

```swift
TranscriptView(transcript: agent.transcript)
```

**Entry rendering:**

| Entry type | Appearance |
|------------|------------|
| `.user(String)` | Right-aligned blue bubble |
| `.assistant(String)` | Left-aligned gray bubble |
| `.toolCall(name:args:)` | Expandable `ToolCallDetailView` |
| `.toolResult(name:result:duration:)` | Expandable result row |
| `.error(String)` | Red error row |

Streaming text at the tail of the transcript renders via `StreamingTextView` with an animated cursor.

---

### Section: StreamingTextView

`StreamingTextView` displays text that is being streamed in real-time, with an animated blinking cursor:

```swift
StreamingTextView(
    text: currentStreamingText,
    isStreaming: agent.status == .running
)
```

While `isStreaming` is `true`, the cursor blinks after the last character. When `isStreaming` becomes `false`, the cursor disappears and the final text is displayed statically. `TranscriptView` uses this automatically for the last assistant entry during streaming.

---

### Section: ToolCallDetailView

`ToolCallDetailView` renders a single tool call as an expandable disclosure group showing the tool name, arguments (pretty-printed JSON), result, and duration:

```swift
ToolCallDetailView(
    name: "search_docs",
    arguments: #"{"query": "SwiftUI animation"}"#,
    result: "Found 12 results...",
    duration: 0.342
)
```

The arguments and result are rendered in a monospaced font with text selection enabled. The disclosure group is collapsed by default — the user taps to expand. `TranscriptView` embeds this automatically for `.toolCall` and `.toolResult` entries.

---

### Section: AgentAppIntent

`AgentAppIntent` lets you expose any agent as a Siri Shortcut or App Shortcuts action with minimal code:

```swift
import AppIntents
import SwiftSynapseUI

struct AskWeatherAgentIntent: AgentAppIntent {
    static var title: LocalizedStringResource = "Ask Weather Agent"
    static var description = IntentDescription("Get weather info from the AI agent")

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
3. Returns the result as a `String` value

Register the intent in your app's `AppShortcutsProvider` to make it appear in Shortcuts and Siri.

**Requirements:**
- Import `AppIntents` alongside `SwiftSynapseUI`
- The associated `AgentType` must conform to `ObservableAgent`
- Your `createAgent()` factory should be synchronous (throws, not async)

---

### Section: Platform Requirements

SwiftSynapseUI requires:

| Platform | Minimum Version |
|----------|----------------|
| macOS | 26+ |
| iOS | 26+ |
| visionOS | 2+ |

`AgentAppIntent` additionally requires the `AppIntents` framework, available on all supported platforms.

---

## Implementation Notes for Generator

- `SwiftSynapseUI.md` is the catalog (navigation only) — no prose content beyond overview
- `UIGuide.md` is the full usage guide with code + tables + prose
- The `SwiftSynapseUI.docc/` directory must be created alongside the two .md files
- All type links use `` ``TypeName`` `` syntax
- Article links use `<doc:UIGuide>` syntax
- `@Observable` macro usage in the custom conformance example is intentional — SwiftSynapseUI is SwiftUI-integrated
- Every view section must include a code example showing how to embed it

# ``SwiftSynapseUI``

Drop-in SwiftUI views and App Intents for any `ObservableAgent` — chat UI, status display, transcript rendering, streaming text, and Siri Shortcuts.

## Overview

SwiftSynapseUI provides ready-made SwiftUI views that work with any agent conforming to ``ObservableAgent``. Import `SwiftSynapseUI` to add a complete chat interface, real-time status display, and Siri Shortcut support to any SwiftSynapse agent in minutes.

All views observe `agent.status` and `agent.transcript` automatically — no additional wiring required.

## Topics

### Essentials

- <doc:UIGuide>

### Core Protocol

- ``ObservableAgent``

### Views

- ``AgentChatView``
- ``AgentStatusView``
- ``TranscriptView``
- ``StreamingTextView``
- ``ToolCallDetailView``

### App Intents

- ``AgentAppIntent``

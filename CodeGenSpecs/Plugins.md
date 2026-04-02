# Spec: Plugins Trait

**Trait guard:** `#if Plugins` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/PluginSystem.swift`

## Overview

The Plugins trait provides a modular extension mechanism for agents. Plugins can register tools, hooks, guardrails, and configuration at activation time and clean up at deactivation. Not included in the default `Production` trait — requires explicit opt-in via `traits: ["Production", "Plugins"]` or `traits: ["Advanced"]`.

---

## AgentPlugin Protocol

```swift
public protocol AgentPlugin: Sendable {
    var name: String { get }
    var version: String { get }
    func activate(context: PluginContext) async throws
    func deactivate() async
}
```

---

## PluginContext

Provides harness extension points to plugins at activation:

```swift
public struct PluginContext: Sendable {
    public let toolRegistry: ToolRegistry
    public let hookPipeline: AgentHookPipeline
    public let guardrailPipeline: GuardrailPipeline?   // nil if Safety trait disabled
    public let configResolver: ConfigurationResolver?  // nil if no hierarchy configured
}
```

---

## PluginManager

`actor PluginManager`:

- `register(_ plugin: any AgentPlugin)` — adds plugin to registry
- `activateAll(context:telemetry:)` — activates plugins in registration order. Emits `.pluginActivated(name:)` on success, `.pluginError(name:error:)` on failure (continues remaining plugins).
- `deactivate(name:)` — deactivates a single plugin by name
- `deactivateAll()` — deactivates all active plugins in reverse registration order (register with `ShutdownRegistry`)

### Integration Example
```swift
let plugins = PluginManager()
await plugins.register(MyAnalyticsPlugin())
await plugins.register(MyCompliancePlugin())

let ctx = PluginContext(toolRegistry: tools, hookPipeline: hooks)
try await plugins.activateAll(context: ctx, telemetry: telemetry)

// Register cleanup with graceful shutdown
await shutdown.register(name: "plugins") { await plugins.deactivateAll() }
```

# Spec: Plugins Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/PluginsTests.swift`

**Sources under test:** `PluginSystem.swift`

## Generation Rules

Same as `CoreTests.md`: Swift Testing, top-level `@Test` functions, `#expect()`, `async throws`.

## Mock Types (file scope)

```swift
actor MockPlugin: AgentPlugin {
    let name: String
    let version: String = "1.0"
    var activateCallCount = 0
    var deactivateCallCount = 0

    init(name: String) { self.name = name }

    func activate(context: PluginContext) async throws {
        activateCallCount += 1
    }

    func deactivate() async {
        deactivateCallCount += 1
    }
}

actor FailingPlugin: AgentPlugin {
    let name = "failing"
    let version = "1.0"
    func activate(context: PluginContext) async throws {
        throw NSError(domain: "PluginTest", code: 1, userInfo: nil)
    }
    func deactivate() async {}
}
```

## Test Functions

| Test | Verifies |
|------|---------|
| `pluginManagerActivatesRegisteredPlugin` | Register `MockPlugin`, `activateAll()` → `plugin.activateCallCount == 1` |
| `pluginManagerActivatesInRegistrationOrder` | Two plugins registered A then B → A activated before B (check call order via timestamps or counters) |
| `pluginManagerDeactivatesAll` | After `activateAll()`, `deactivateAll()` → both plugins' `deactivateCallCount == 1` |
| `pluginManagerDeactivatesInReverseOrder` | Two plugins A, B → deactivated B then A (LIFO) |
| `pluginManagerContinuesAfterActivationFailure` | `FailingPlugin` registered before `MockPlugin` → `MockPlugin` still activated despite failure |
| `pluginManagerDeactivateSingleByName` | Register two plugins, `deactivate(name: "mock")` → only that plugin's `deactivateCallCount == 1` |

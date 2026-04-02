# How to Test Agents

Deterministic, fast agent tests using VCR recording/replay, in-memory telemetry, and fixture stores.

## Overview

Agent tests have two challenges: LLM responses are non-deterministic, and making real API calls in CI is slow and expensive. SwiftSynapseHarness solves both with ``VCRClient`` (record once, replay forever), ``InMemoryTelemetrySink`` (assert on events without IO), and hook-based assertions.

## Step 1: Record Agent Interactions with VCR

``VCRClient`` wraps any ``AgentLLMClient`` and intercepts requests. In `.record` mode it makes real API calls and saves responses as fixture files. In `.replay` mode it returns saved responses without making any network calls.

```swift
// XCTestCase setup
let store = FileFixtureStore(directoryPath: "Tests/Fixtures/WeatherTests")

// Record mode — run this locally once to capture real responses
let vcr = VCRClient(client: realClient, store: store, mode: .record)

let agent = WeatherAgent(client: vcr, config: config, tools: tools)
let result = try await agent.run(goal: "What's the weather in Tokyo?")
// Fixture saved to Tests/Fixtures/WeatherTests/<sha256-of-request>.json
```

Fixtures are keyed by SHA-256 of the full request content, so the same request always maps to the same fixture file.

## Step 2: Replay in CI (No Network Calls)

Switch to `.replay` mode for deterministic, network-free test execution:

```swift
func testWeatherAgent() async throws {
    let store = FileFixtureStore(directoryPath: "Tests/Fixtures/WeatherTests")
    let vcr = VCRClient(client: realClient, store: store, mode: .replay)

    let agent = WeatherAgent(client: vcr, config: config, tools: tools)
    let result = try await agent.run(goal: "What's the weather in Tokyo?")

    XCTAssertTrue(result.lowercased().contains("tokyo"))
    XCTAssertFalse(result.isEmpty)
}
```

If no fixture exists for a request, ``VCRClient`` throws ``VCRError/fixtureNotFound``. Use `.passthrough` to always make real calls without recording.

## Step 3: Assert on Telemetry Events

``InMemoryTelemetrySink`` collects all emitted events for inspection:

```swift
func testToolWasCalled() async throws {
    let sink = InMemoryTelemetrySink()
    let telemetry = CompositeTelemetrySink([sink])

    let agent = WeatherAgent(telemetry: telemetry, ...)
    _ = try await agent.run(goal: "What's the weather in Tokyo?")

    let events = await sink.events
    let toolEvents = events.filter {
        if case .toolCalled(let name, _, _) = $0.kind { return name == "get_weather" }
        return false
    }
    XCTAssertFalse(toolEvents.isEmpty, "Expected get_weather to be called")
    XCTAssertFalse(
        events.contains { if case .retryAttempted = $0.kind { return true }; return false },
        "Expected no retries"
    )
}
```

## Step 4: Test Hook Behavior

Use ``ClosureHook`` to intercept and assert on hook events during a test run:

```swift
func testPreToolHookFires() async throws {
    var capturedCalls: [AgentToolCall] = []

    let hook = ClosureHook(on: [.preToolUse]) { event in
        if case .preToolUse(let calls) = event {
            capturedCalls.append(contentsOf: calls)
        }
        return .proceed
    }

    let hooks = AgentHookPipeline()
    await hooks.add(hook)

    let agent = WeatherAgent(hooks: hooks, ...)
    _ = try await agent.run(goal: "What's the weather in Tokyo?")

    XCTAssertEqual(capturedCalls.count, 1)
    XCTAssertEqual(capturedCalls.first?.name, "get_weather")
}
```

Test that hooks can block tool calls:

```swift
func testHookCanBlockTool() async throws {
    let blockHook = ClosureHook(on: [.preToolUse]) { _ in
        return .block(reason: "Blocked by test")
    }
    await hooks.add(blockHook)

    do {
        _ = try await agent.run(goal: "Check the weather")
        XCTFail("Expected agent to throw due to blocked tool")
    } catch let error as ToolDispatchError {
        XCTAssertTrue(error.reason.contains("Blocked by test"))
    }
}
```

## Step 5: Test Guardrail Decisions

Test that guardrails block or sanitize expected content in isolation:

```swift
func testContentFilterBlocksAPIKey() async throws {
    let pipeline = GuardrailPipeline()
    await pipeline.add(ContentFilter.default)

    let sensitiveInput = GuardrailInput.toolArguments(#"{"key": "sk-abc123def456"}"#)
    let decision = await pipeline.evaluate(sensitiveInput)

    switch decision {
    case .block: break  // Expected
    default: XCTFail("ContentFilter should have blocked API key pattern")
    }
}
```

## See Also

- <doc:ProductionGuide> — ``VCRClient``, ``FileFixtureStore``, ``FixtureMode``
- <doc:AgentHarnessGuide> — telemetry sinks, hook system
- <doc:HowToGoToProduction> — production configuration to test against

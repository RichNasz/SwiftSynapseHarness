# How to Configure Tool Permissions

Control which tools run automatically, which require human approval, and which are always blocked.

## Overview

``PermissionGate`` provides policy-driven access control for tool calls. You define rules that allow, block, or require human approval for specific tools. ``AdaptivePermissionGate`` adds automatic mode-switching when users repeatedly deny requests.

## Step 1: Create a ToolListPolicy

``ToolListPolicy`` takes an ordered list of rules evaluated top-to-bottom. The first matching rule wins:

```swift
let policy = ToolListPolicy(rules: [
    .allow(["search_docs", "calculate", "get_weather"]),  // Always allowed
    .requireApproval(["send_email", "charge_card"]),      // Ask human first
    .deny(["delete_account", "drop_database"])            // Always blocked
])
```

Tools not matching any rule fall through to the configurable default (`.deny` by default, for safety).

## Step 2: Wire Into a PermissionGate

```swift
let gate = PermissionGate()
await gate.addPolicy(policy)
await gate.setApprovalDelegate(UIApprovalDelegate())

tools.permissionGate = gate
```

Implement ``ApprovalDelegate`` to show your approval UI — an alert, a Slack message, or any other mechanism:

```swift
struct UIApprovalDelegate: ApprovalDelegate {
    func requestApproval(for tool: String, input: String) async -> Bool {
        // Show an alert and return the user's decision
        return await showApprovalAlert(tool: tool, input: input)
    }
}
```

The gate calls `requestApproval` on the main actor, so it's safe to present UI from this method.

## Step 3: Add Adaptive Behavior (Optional)

``AdaptivePermissionGate`` switches permission modes automatically when users repeatedly deny requests:

```swift
let adaptiveGate = AdaptivePermissionGate(
    gate: gate,
    mode: .default,
    denialThreshold: 3  // After 3 consecutive denials, switch to .planOnly
)
```

| Mode | Behavior | Best for |
|------|----------|----------|
| `.default` | Policy-driven, tracks denials | Normal interactive use |
| `.autoApprove` | Always allow | Trusted CI environments |
| `.alwaysPrompt` | Ask for every tool call | High-security contexts |
| `.planOnly` | Block all tools, describe what would run | Preview / review mode |

Reset the denial counter manually when appropriate:

```swift
await adaptiveGate.denialTracker.reset()
```

## Step 4: Hook Into Permission Events (Optional)

Use ``ClosureHook`` to observe permission decisions without modifying the gate:

```swift
let hook = ClosureHook(on: [.preToolUse]) { event in
    if case .preToolUse(let calls) = event {
        for call in calls {
            logger.info("Permission check: \(call.name)")
        }
    }
    return .proceed
}
await hooks.add(hook)
```

The `preToolUse` hook fires before permission evaluation — return `.block(reason:)` to deny a specific call regardless of policy.

## See Also

- <doc:AgentHarnessGuide> — full permission system and adaptive permission gate details
- <doc:ProductionGuide> — guardrails for content safety (separate from permissions)

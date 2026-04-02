# Spec: Safety Trait

**Trait guard:** `#if Safety` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/Permission.swift`
- `Sources/SwiftSynapseHarness/ToolListPolicy.swift`
- `Sources/SwiftSynapseHarness/Guardrails.swift`
- `Sources/SwiftSynapseHarness/DenialTracking.swift`

## Overview

The Safety trait provides policy-driven tool access control and content safety checks. Included in the default `Production` trait.

Stubs in `TraitStubs.swift` provide no-op `GuardrailPipeline.evaluate() → .allow` and no-op `PermissionGate.check()` when this trait is disabled.

---

## Permission System

Policy-driven tool access control with human-in-the-loop approval.

### Types
- `ToolPermission` enum: `.allowed`, `.requiresApproval(reason:)`, `.denied(reason:)`
- `PermissionPolicy` protocol: `evaluate(toolName:arguments:) async -> ToolPermission`
- `ApprovalDelegate` protocol: `requestApproval(toolName:arguments:reason:) async -> Bool`
- `PermissionError`: `.denied(tool:reason:)`, `.noApprovalDelegate(tool:)`, `.rejected(tool:)`

### PermissionGate
`actor PermissionGate`:
- `addPolicy(_ policy: any PermissionPolicy)` — appends a policy
- `setApprovalDelegate(_ delegate: any ApprovalDelegate)` — sets human-approval handler
- `check(toolName:arguments:)` — evaluates all policies; most-restrictive-wins. Calls delegate for `.requiresApproval`.

---

## ToolListPolicy

List-based permission policy with ordered rules:

```swift
let policy = ToolListPolicy(rules: [
    .allow(["calculate", "search"]),
    .requireApproval(["sendEmail"]),
    .deny(["deleteAccount"])
])
```

Rules evaluate top-to-bottom; first matching rule wins. Default for unmatched tools: `.allowed`.

---

## Guardrails

Input/output content filtering and compliance:

### Types
- `GuardrailInput` enum: `.toolArguments(toolName:arguments:)`, `.llmOutput(text:)`, `.userInput(text:)`
- `GuardrailDecision` enum: `.allow`, `.sanitize(replacement:)`, `.block(reason:)`, `.warn(reason:)`
- `RiskLevel` enum: `.low`, `.medium`, `.high`, `.critical`
- `GuardrailPolicy` protocol: `name: String`, `evaluate(input:) async -> GuardrailDecision`
- `GuardrailError`: `.blocked(policy:reason:)`

### ContentFilter
Regex-based PII/secret detection. Default patterns: credit cards, SSNs, API keys, bearer tokens. Custom patterns configurable at init.

### GuardrailPipeline
`actor GuardrailPipeline`:
- `add(_ policy: any GuardrailPolicy)` — appends policy
- `evaluate(_ input: GuardrailInput) async -> GuardrailDecision` — most-restrictive-wins (`.block` > `.sanitize` > `.warn` > `.allow`)

**Integration:** `AgentToolLoop.run()` accepts optional `guardrails` parameter. Checks before tool dispatch (on arguments) and after LLM response (on output text). Hook event: `.guardrailTriggered(policy:decision:input:)`. Telemetry: `.guardrailTriggered(policy:risk:)`.

---

## DenialTracking

Adaptive permission behavior based on consecutive denials:

### Types
- `PermissionMode` enum: `.default` (policy-driven), `.autoApprove` (trusted), `.alwaysPrompt` (force approval for every call), `.planOnly` (block all tools, explain what would have been called)
- `DenialTracker` actor: `recordDenial(toolName:)`, `recordSuccess(toolName:)` (resets count), `denialCount(for:)`, `isThresholdExceeded(for:)`. Configurable threshold (default 3).

### AdaptivePermissionGate
`actor AdaptivePermissionGate` wraps a base `PermissionGate` with mode and denial tracking:

| Mode | Behavior |
|------|----------|
| `.autoApprove` | Always allow, skip gate |
| `.planOnly` | Always deny with explanation |
| `.alwaysPrompt` | Delegate every call to gate |
| `.default` | Check denial threshold, then delegate to gate. Record success/denial. |

Access `adaptiveGate.denialTracker` to read denial counts or reset.

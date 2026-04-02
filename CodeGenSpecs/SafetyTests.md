# Spec: Safety Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/SafetyTests.swift`

**Sources under test:** `Permission.swift`, `ToolListPolicy.swift`, `Guardrails.swift`, `DenialTracking.swift`

## Generation Rules

Same as `CoreTests.md`: Swift Testing, top-level `@Test` functions, `#expect()`, `async throws`.

## Test Functions

### ToolListPolicy

| Test | Verifies |
|------|---------|
| `toolListPolicyAllowRule` | `.allow(["goodTool"])` → `evaluate("goodTool")` returns `.allowed` |
| `toolListPolicyDenyRule` | `.deny(["badTool"])` → `evaluate("badTool")` returns `.denied` |
| `toolListPolicyRequireApprovalRule` | `.requireApproval(["gatedTool"])` → returns `.requiresApproval` |
| `toolListPolicyFirstRuleWins` | Rules `[.deny(["t"]), .allow(["t"])]` → evaluate("t") returns `.denied` |
| `toolListPolicyDefaultAllowsUnknown` | Tool not matching any rule → `.allowed` by default |

### DenialTracking

| Test | Verifies |
|------|---------|
| `denialTrackerIncrementsCount` | After 2 `recordDenial(toolName:)` calls, `denialCount(for:)` returns 2 |
| `denialTrackerThresholdExceeded` | threshold: 3, after 3 denials → `isThresholdExceeded` returns `true` |
| `denialTrackerNotExceededBelowThreshold` | threshold: 3, after 2 denials → `isThresholdExceeded` returns `false` |
| `denialTrackerResetOnSuccess` | After 3 denials, `recordSuccess(toolName:)` resets count to 0 |

### PermissionGate

| Test | Verifies |
|------|---------|
| `permissionGateAllowsAllowedTool` | Gate with `allow(["goodTool"])` policy → `check("goodTool")` does not throw |
| `permissionGateDeniedToolThrows` | Gate with `deny(["badTool"])` policy → `check("badTool")` throws `PermissionError` |
| `permissionGateRequiresApprovalNoDelegate` | Gate with `requireApproval(["gated"])`, no delegate → throws `PermissionError.noApprovalDelegate` |

### ContentFilter / Guardrails

| Test | Verifies |
|------|---------|
| `contentFilterDefaultDetectsCreditCard` | `"Card: 4111111111111111"` → `.block` decision |
| `contentFilterDefaultDetectsSSN` | `"SSN: 123-45-6789"` → `.block` decision |
| `contentFilterDefaultDetectsAPIKey` | `"api_key: abcdefghijklmnopqrstuvwx"` (20+ chars) → `.block` decision |
| `contentFilterDefaultDetectsBearerToken` | `"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abcdefghijklmno"` → `.block` decision |
| `contentFilterAllowsCleanText` | `"Hello, how are you?"` → `.allow` decision |
| `contentFilterCustomPatternDetects` | Custom regex pattern detects configured keyword |
| `guardrailPipelineAllowPassesThrough` | Empty pipeline → `.allow` for any input |
| `guardrailPipelineBlockWinsMostRestrictive` | One allow policy + one block policy → result is `.block` |

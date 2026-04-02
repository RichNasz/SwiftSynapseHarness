# Spec: Resilience Trait Tests

**Generates:** `Tests/SwiftSynapseHarnessTests/ResilienceTests.swift`

**Sources under test:** `ErrorClassification.swift`, `RateLimiting.swift`, `ContextCompression.swift`, `ConversationRecovery.swift`, `RecoveryStrategy.swift`

## Generation Rules

Same as `CoreTests.md`: Swift Testing, top-level `@Test` functions, `#expect()`, `async throws`.

## Test Functions

### ErrorClassification

| Test | Verifies |
|------|---------|
| `classifyAPIErrorAuth` | Error description containing `"401"` → `APIErrorCategory.auth`, `isRetryable: false` |
| `classifyAPIErrorUnauthorized` | Error description containing `"unauthorized"` → `.auth` |
| `classifyAPIErrorQuota` | Error description containing `"quota"` → `.quota`, not retryable |
| `classifyAPIErrorRateLimit` | Error description containing `"429"` → `.rateLimit`, retryable |
| `classifyAPIErrorServerError` | Error description containing `"500"` → `.serverError`, retryable |
| `classifyAPIErrorUnknown` | Unrelated error description → `.unknown` |

### RateLimiting

| Test | Verifies |
|------|---------|
| `rateLimitStateInitiallyNotInCooldown` | Freshly created `RateLimitState.isInCooldown` is `false` |
| `rateLimitStateEnterCooldown` | After `enterCooldown(duration: .seconds(60))` → `isInCooldown == true` |
| `rateLimitStateConsecutiveHits` | Each `enterCooldown` call increments `consecutiveHits` |
| `rateLimitStateRecordSuccessResets` | `recordSuccess()` after cooldown → `isInCooldown == false`, `consecutiveHits == 0` |

### ContextCompression

| Test | Verifies |
|------|---------|
| `microCompactorTruncatesLongResults` | Tool result entry exceeding `maxResultLength` → entry gets `[Truncated:]` suffix |
| `microCompactorPreservesShortResults` | Tool result entry within `maxResultLength` passes through unchanged |

### ConversationRecovery

| Test | Verifies |
|------|---------|
| `transcriptIntegrityCheckDetectsOrphanedResult` | `[.userMessage, .toolResult]` (no preceding toolCall) → 1 `.orphanedToolResult` violation |
| `transcriptIntegrityCheckDetectsOrphanedCall` | `[.userMessage, .toolCall]` (no following toolResult) → 1 `.orphanedToolCall` violation |
| `transcriptIntegrityCheckPassesValid` | `[.userMessage, .toolCall, .toolResult]` paired correctly → 0 violations |
| `conversationRecoveryRemovesOrphanedResult` | `DefaultConversationRecoveryStrategy` removes orphaned toolResult from transcript |
| `conversationRecoveryAppendsSyntheticForOrphanedCall` | Strategy appends synthetic error toolResult for orphaned toolCall |
| `recoverTranscriptConvenienceFunction` | `recoverTranscript([.userMessage, .toolResult])` → 1 violation and repaired transcript with 1 entry |

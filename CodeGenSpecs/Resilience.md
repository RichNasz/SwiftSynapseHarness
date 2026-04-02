# Spec: Resilience Trait

**Trait guard:** `#if Resilience` / `#endif`

**Generates:**
- `Sources/SwiftSynapseHarness/RecoveryStrategy.swift`
- `Sources/SwiftSynapseHarness/ErrorClassification.swift`
- `Sources/SwiftSynapseHarness/RateLimiting.swift`
- `Sources/SwiftSynapseHarness/ConversationRecovery.swift`
- `Sources/SwiftSynapseHarness/ContextCompression.swift`

## Overview

The Resilience trait provides self-healing from context exhaustion, output truncation, API errors, and rate limits — plus transcript integrity repair. Included in the default `Production` trait.

Stubs in `TraitStubs.swift` provide inert `RecoveryChain.default` (never recovers), passthrough `retryWithRateLimit()`, and no-op `CompactionTrigger.default → .manual` when this trait is disabled.

---

## RecoveryStrategy

Self-healing from context window exhaustion and output truncation:

- `RecoverableError` enum: `.contextWindowExceeded`, `.outputTruncated`, `.apiError`
- `RecoveryStrategy` protocol: `attemptRecovery(from:state:transcript:compressor:budget:) async -> RecoveryResult`
- `RecoveryResult`: `.recovered(continuationPrompt:)`, `.cannotRecover`
- `RecoveryState`: tracks attempted strategies, recovery count, max output token overrides
- `classifyRecoverableError(_ error:)` — delegates to `classifyAPIError()` for consistent classification

### Built-in Strategies
| Strategy | Recovers from |
|----------|--------------|
| `ReactiveCompactionStrategy` | Context window exceeded — compresses transcript |
| `OutputTokenEscalationStrategy` | Output truncated — increases max tokens |
| `ContinuationStrategy` | Output truncated — sends continuation prompt |

### RecoveryChain
Ordered chain, first success wins:
- `RecoveryChain.default` = [ReactiveCompaction → OutputTokenEscalation → Continuation]
- Custom chains: `RecoveryChain(strategies: [...])`

---

## ErrorClassification

Structured error typing for API and tool errors:

- `APIErrorCategory` enum: `.auth`, `.quota`, `.rateLimit(retryAfterSeconds:)`, `.connectivity`, `.serverError`, `.badRequest`, `.unknown`
- `ToolErrorCategory` enum: `.inputDecoding`, `.executionFailure`, `.timeout`, `.permissionDenied`, `.unknown`
- `ClassifiedError`: wraps original `Error` with `category`, `model`, `isRetryable`, `retryAfterSeconds`
- `classifyAPIError(_ error:model:)` — inspects error description for HTTP status codes and patterns
- `classifyToolError(_ error:toolName:)` — classifies tool execution errors
- **Telemetry:** `.apiErrorClassified(category:model:)`

---

## RateLimiting

Rate-limit-aware retry with cooldown tracking, separate from general backoff in Core:

- `RateLimitPolicy`: `maxRetries`, `initialBackoff`, `maxBackoff`, `jitterFactor`. Static `.default`.
- `RateLimitError` enum: `.rateLimited(retryAfter:)`, `.serverOverloaded(retryAfter:)`, `.retriesExhausted(lastError:)`
- `RateLimitState` actor: per-model cooldown. `isInCooldown`, `remainingCooldown`, `consecutiveHits`, `enterCooldown(duration:)`, `recordSuccess()`, `waitForCooldown()`
- `retryWithRateLimit()` — wraps operation with cooldown check before send, classifies errors via `classifyAPIError`, enters cooldown on rate limit, jittered exponential backoff
- **Integration:** `AgentToolLoop.run()` accepts optional `rateLimitState`. When provided, wraps the LLM call with `retryWithRateLimit`.

---

## ConversationRecovery

Transcript consistency checking and repair after interruptions:

- `IntegrityViolation` enum: `.orphanedToolCall(name:index:)`, `.orphanedToolResult(name:index:)`, `.invalidSequence(expected:found:index:)`
- `TranscriptIntegrityCheck`: `check(_ entries:) -> [IntegrityViolation]` — validates tool call/result pairing
- `ConversationRecoveryStrategy` protocol: `repair(transcript:violations:) -> [TranscriptEntry]`
- `DefaultConversationRecoveryStrategy`: appends synthetic error results for orphaned calls, removes orphaned results
- `recoverTranscript(_:strategy:)` — validates and repairs in one call
- **Hook event:** `.transcriptRepaired(violations:)`

---

## ContextCompression

Advanced compression strategies beyond `SlidingWindowCompressor` (defined in `Core`):

- `MicroCompactor`: truncates individual tool results exceeding `maxResultLength` (default 2048 chars)
- `ImportanceCompressor`: scores entries by type (user > error > assistant > reasoning > toolCall > toolResult). Drops lowest-scored first, protects first and last entries. Configurable scoring function.
- `AutoCompactCompressor`: aggressive compression keeping first entry + last N + summary
- `CompositeCompressor`: chains compressors in order. `.default` = [MicroCompactor → ImportanceCompressor → SlidingWindowCompressor]
- **Integration:** `AgentToolLoop.run()` `compactionTrigger` parameter (see `Core.md`) triggers these compressors. Emits `.contextCompacted` telemetry on compression.

# Spec: README Generation

**Generates:** `README.md` (root)

## Overview

The README is the primary documentation surface for SwiftSynapseHarness on GitHub. It covers the full agent harness, production capabilities, and production polish features.

## Structure

1. Title and tagline
2. Overview — what the package provides, relationship to SwiftSynapseMacros
3. Requirements and installation
4. Quick start example (import SwiftSynapseHarness, @SpecDrivenAgent, AgentToolLoop)
5. Agent harness sections (tools, hooks, permissions, recovery, streaming, LLM backends)
6. Production capabilities (session persistence, guardrails, MCP, coordination, cost tracking, rate limiting, plugins)
7. Also included (compression, configuration, caching, denial tracking, error classification, truncation, system prompts, VCR testing, shutdown, memory, conversation recovery)
8. Telemetry
9. Dependencies
10. Spec-driven development note

## Key Points

- Import is `SwiftSynapseHarness` (not SwiftSynapseMacrosClient)
- Re-exports SwiftSynapseMacrosClient so users get macros + core types automatically
- Code examples should use `import SwiftSynapseHarness`
- Link to SwiftSynapseMacros for macro-only usage

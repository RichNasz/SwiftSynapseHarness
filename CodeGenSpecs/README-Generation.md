# Spec: README Generation

**Generates:** `README.md` (root)

## Overview

The README is the primary documentation surface for SwiftSynapseHarness on GitHub. It covers the full agent harness, production capabilities, and production polish features.

## Structure

1. Title and tagline
2. Overview — what the package provides, relationship to SwiftSynapseMacros
3. Documentation — two paths: GitHub Pages link and Xcode Developer Documentation steps
4. Requirements and installation
4. Quick start example (import SwiftSynapseHarness, @SpecDrivenAgent, AgentToolLoop)
5. Agent harness sections (tools, hooks, permissions, recovery, streaming, LLM backends)
6. Production capabilities (session persistence, guardrails, MCP, coordination, cost tracking, rate limiting, plugins)
7. Also included (compression, configuration, caching, denial tracking, error classification, truncation, system prompts, VCR testing, shutdown, memory, conversation recovery)
8. Telemetry
9. Dependencies
10. Spec-driven development note
11. Contributing — one sentence with link to CONTRIBUTING.md
12. License — one sentence Apache 2.0 statement

## Section: Documentation

This section appears immediately after the Overview (before Requirements).

### Content to convey:

The full documentation is available as DocC via two paths:

**GitHub Pages (easiest — no Xcode required):**
`https://richnasz.github.io/SwiftSynapseHarness/documentation/swiftsynapseharness/`
Deployed automatically on push to `main`.

**Xcode Developer Documentation (richest experience during development):**

1. Open this project (or any project that depends on it) in Xcode.
2. Choose **Product > Build Documentation** (or open the Documentation window).
3. Navigate to **SwiftSynapseHarness** in the documentation navigator.

Both paths cover all guides and API reference. The README covers installation and orientation only; the DocC documentation covers usage in depth.

### Formatting guidance:

- Lead with the GitHub Pages link — it works without any tooling.
- Use a numbered list for the Xcode steps (they are sequential).
- Do not duplicate DocC content in the README.
- The GitHub Pages docs are deployed automatically on push to `main` via `.github/workflows/deploy-docs.yml`.

---

## Contributing and License Sections

These appear at the bottom of the README, after the Spec-Driven Development note.

- **Contributing**: One sentence linking to `CONTRIBUTING.md`. Example: "Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the spec-first workflow, commit conventions, and PR standards."
- **License**: One sentence stating the license. Example: "SwiftSynapseHarness is available under the Apache License 2.0."

---

## Key Points

- Import is `SwiftSynapseHarness` (not SwiftSynapseMacrosClient)
- Re-exports SwiftSynapseMacrosClient so users get macros + core types automatically
- Code examples should use `import SwiftSynapseHarness`
- Link to SwiftSynapseMacros for macro-only usage

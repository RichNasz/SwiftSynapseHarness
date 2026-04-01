# Security Policy

## Scope

SwiftSynapseHarness is a Swift agent runtime that executes tool calls, manages LLM interactions, and handles persistent session data. Security concerns for this project include:

- **Tool execution safety**: Ensuring tool inputs are validated and tool dispatch does not introduce injection vulnerabilities
- **API key handling**: `AgentConfiguration` and LLM client usage must not expose credentials in logs or transcripts
- **Hook system integrity**: Hooks intercept all agent events — malicious or poorly written hooks can leak data or alter agent behavior
- **Permission policy correctness**: `ToolListPolicy` rules must accurately reflect intended access control
- **MCP server trust**: External MCP servers execute as subprocesses — validate server configs and sources carefully
- **Session persistence security**: `FileSessionStore` writes conversation history to disk — ensure secure file paths and appropriate access controls
- **Dependency vulnerabilities**: Issues in SwiftSynapseMacros, SwiftOpenSkills, or transitive dependencies that could affect this package

## Supported Versions

| Version | Supported |
|---------|-----------|
| main branch | Yes |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub Issue for security vulnerabilities
2. Email the maintainer or use GitHub's private vulnerability reporting feature
3. Include a description of the vulnerability, steps to reproduce, and potential impact

## Response Timeline

- **Acknowledgment**: Within 48 hours of report
- **Assessment**: Within 1 week
- **Fix**: Dependent on severity; critical issues prioritized for immediate resolution

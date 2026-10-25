# GitHub CLI

- `gh` is already installed and authenticated. In the sandbox, GitHub-facing
  `gh` commands commonly fail because network access is blocked. Run them with
  sandbox escalation immediately; do not diagnose the failure as missing `gh`
  configuration or authentication.

# External services

- Check my configured MCP servers first and use a matching MCP for the required
  external service or tool.
- Use `mcp__codex_apps__*` connectors only and only if no configured MCP supports the
  required service or capability.
- If a matching MCP fails, report the failure; do not treat it as an absent MCP
  and switch to a connector.

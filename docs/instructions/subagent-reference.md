# Subagent Reference

## Available subagents in `.opencode/agent/`:

- **prd** - Requirements gathering and PRD creation (optional first step)
- **architect** - Feature planning and TDD design
- **phoenix-tdd** - Phoenix backend and LiveView implementation with TDD
- **typescript-tdd** - TypeScript implementation with TDD (hooks, clients, standalone code)


## MCP Tools Integration

All subagents have access to **Context7 MCP tools** for up-to-date library documentation:

### Available MCP Tools:

- `mcp__context7__resolve-library-id` - Resolve library name to Context7 ID
- `mcp__context7__get-library-docs` - Fetch documentation for a library

### Common Libraries:

- Phoenix: `/phoenixframework/phoenix`
- Phoenix LiveView: `/phoenixframework/phoenix_live_view`
- Ecto: `/elixir-ecto/ecto`
- Vitest: `/vitest-dev/vitest`
- TypeScript: `/microsoft/TypeScript`
- Mox: `/dashbitco/mox`

### When Subagents Use MCP Tools:

1. **architect** - Research library capabilities before planning
2. **phoenix-tdd** - Check Phoenix/Elixir testing patterns and API usage
3. **typescript-tdd** - Verify TypeScript patterns and Vitest usage

### Example Usage:

```
Subagent needs Phoenix Channel testing patterns:
1. mcp__context7__resolve-library-id("phoenix") → "/phoenixframework/phoenix"
2. mcp__context7__get-library-docs("/phoenixframework/phoenix", topic: "channels")
3. Use documentation to implement/validate correctly
```

This ensures all subagents work with **current, official documentation** rather than outdated patterns.
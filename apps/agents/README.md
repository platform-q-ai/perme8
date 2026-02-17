# Agents

Standalone umbrella app for agent definitions, LLM orchestration, and the Knowledge MCP tool endpoint.

## Architecture

The agents app follows Clean Architecture with three boundary-enforced layers:

```
Agents.Domain          -- Pure entities, policies, value objects (no I/O)
Agents.Application     -- Use cases, behaviours, gateway interfaces
Agents.Infrastructure  -- MCP server, tools, ERM gateway, auth plug
```

### Agent CRUD

Agent definitions (CRUD, cloning, workspace assignment, LLM client, query execution) were extracted from `jarga` into this standalone app. The `Agents` facade exposes all public API functions. `jarga_web` LiveViews and `jarga_api` controllers call the facade directly.

### Knowledge MCP

A standalone [MCP](https://modelcontextprotocol.io/) endpoint exposes 6 knowledge graph tools via JSON-RPC 2.0 over HTTP. The tools allow LLM agents to create, search, update, relate, traverse, and retrieve knowledge entries stored in the Entity Relationship Manager (ERM).

| Tool | Description |
|------|-------------|
| `knowledge.create` | Create a knowledge entry with title, body, category, tags |
| `knowledge.get` | Retrieve an entry by ID |
| `knowledge.search` | Search by keyword, category, or tags |
| `knowledge.update` | Update an entry's fields |
| `knowledge.relate` | Create a relationship between two entries |
| `knowledge.traverse` | Walk the knowledge graph from an entry |

**Protocol:** MCP (JSON-RPC 2.0) via Hermes StreamableHTTP transport
**Auth:** Bearer token (Identity API keys) validated by `AuthPlug`
**Port:** 4007 (test)

### Key Modules

| Module | Purpose |
|--------|---------|
| `Agents` | Public facade for agent CRUD and knowledge operations |
| `Agents.OTPApp` | OTP supervisor -- starts Bandit HTTP server for MCP |
| `Agents.Infrastructure.Mcp.Router` | Plug router with `/health` and MCP pipeline |
| `Agents.Infrastructure.Mcp.McpPipeline` | Chains AuthPlug with Hermes StreamableHTTP.Plug |
| `Agents.Infrastructure.Mcp.AuthPlug` | Validates Bearer tokens via Identity API keys |
| `Agents.Infrastructure.Mcp.Server` | Hermes MCP server with tool registration |
| `Agents.Infrastructure.Gateways.ErmGateway` | Adapter to EntityRelationshipManager facade |
| `Agents.Domain.Entities.KnowledgeEntry` | Pure domain struct for knowledge entries |
| `Agents.Domain.Policies.KnowledgeValidationPolicy` | Category, tag, and relationship validation |
| `Agents.Domain.Policies.SearchPolicy` | Search criteria validation and normalization |

## Dependencies

- **`identity`** (in_umbrella) -- authentication, workspace resolution, API keys
- **`entity_relationship_manager`** (in_umbrella) -- knowledge graph storage
- Hermes MCP -- MCP protocol library (JSON-RPC 2.0)
- Bandit -- HTTP server for MCP endpoint
- Boundary -- compile-time boundary enforcement

## Testing

```bash
# Run all agents unit tests (297 tests)
mix test apps/agents/test

# Run exo-bdd HTTP integration tests (26 scenarios)
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents/test/exo-bdd-agents.config.ts --adapter http

# Run exo-bdd security tests (16 scenarios, requires ZAP)
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents/test/exo-bdd-agents.config.ts --adapter security

# Run with tag filter
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents/test/exo-bdd-agents.config.ts \
  --adapter http --tags "@smoke"
```

### Test Coverage

| Layer | Tests | Notes |
|-------|-------|-------|
| Domain entities | 25 | Pure struct tests, validation |
| Domain policies | 28 | Category, tag, relationship, search validation |
| Application use cases | 120 | CRUD, bootstrap, create, search, traverse, relate, update, auth |
| Infrastructure | 124 | MCP tools, auth plug, router, server, ERM gateway |
| Exo-BDD HTTP | 26 scenarios | End-to-end MCP protocol tests |
| Exo-BDD Security | 16 scenarios | ZAP security scans (SQLi, XSS, headers, baseline) |

## Configuration

The MCP HTTP server is configured in `config/test.exs`:

```elixir
config :agents, :mcp_transport, :http
config :agents, :mcp_http_port, 4007
```

The exo-bdd config is at `apps/agents/test/exo-bdd-agents.config.ts`.

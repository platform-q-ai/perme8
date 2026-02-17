# KnowledgeMcp

A workspace-scoped knowledge base of institutional learnings, exposed via MCP (Model Context Protocol) tools. LLM agents authenticate via Identity API keys, then create, search, traverse, and maintain knowledge entries stored as ERM graph entities.

## Dependencies

- `entity_relationship_manager` -- graph storage for knowledge entries and relationships
- `identity` -- API key verification and workspace resolution
- `hermes_mcp` -- MCP server framework (Hermes)

## Architecture

Clean Architecture with four layers:

```
Domain        -> Pure structs (KnowledgeEntry, KnowledgeRelationship) and policies
Application   -> Use cases with dependency injection via opts
Infrastructure -> ERM gateway, MCP server, auth plug, tool components
Interface      -> MCP tools (no HTTP REST or LiveView)
```

## MCP Tools

| Tool | Description |
|------|-------------|
| `knowledge.search` | Keyword/tag search across entries |
| `knowledge.get` | Fetch entry with relationships |
| `knowledge.traverse` | Walk the knowledge graph |
| `knowledge.create` | Write a new knowledge entry |
| `knowledge.update` | Update an existing entry |
| `knowledge.relate` | Create relationships between entries |

## Knowledge Entry Categories

`how_to`, `pattern`, `convention`, `architecture_decision`, `gotcha`, `concept`

## Relationship Types

`relates_to`, `depends_on`, `prerequisite_for`, `example_of`, `part_of`, `supersedes`

## Configuration

```elixir
# config/config.exs
config :knowledge_mcp, :erm_gateway, KnowledgeMcp.Infrastructure.ErmGateway
config :knowledge_mcp, :identity_module, Identity

# config/test.exs
config :knowledge_mcp, :erm_gateway, KnowledgeMcp.Mocks.ErmGatewayMock
config :knowledge_mcp, :identity_module, KnowledgeMcp.Mocks.IdentityMock
```

## Testing

```bash
mix test apps/knowledge_mcp/test
```

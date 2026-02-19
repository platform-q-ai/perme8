# AgentsApi

JSON REST API for managing AI agents, executing queries, and listing available skills.

## Dependencies

- `agents` (in_umbrella) -- agent domain logic (CRUD, query execution)
- `identity` (in_umbrella) -- API key verification and user lookup

## Configuration

| Environment | Port |
|-------------|------|
| Dev         | 4008 |
| Test        | 4009 |

## Authentication

All endpoints (except `/api/health` and `/api/openapi`) require a Bearer token:

```
Authorization: Bearer <api_key_token>
```

API keys are created and managed through the Identity service.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Health check |
| GET | `/api/openapi` | OpenAPI 3.0 specification |
| GET | `/api/agents` | List agents owned by the authenticated user |
| GET | `/api/agents/:id` | Get agent details |
| POST | `/api/agents` | Create a new agent |
| PATCH | `/api/agents/:id` | Update an agent |
| DELETE | `/api/agents/:id` | Delete an agent |
| POST | `/api/agents/:id/query` | Execute a query against an agent |
| GET | `/api/agents/:id/skills` | List MCP tools available to an agent |

## Testing

```bash
mix test apps/agents_api
```

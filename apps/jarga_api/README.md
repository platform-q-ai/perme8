# JargaApi

Dedicated JSON REST API application for the Perme8 platform. Provides external programmatic access to workspaces, projects, and documents via API key authentication. Extracted from `jarga_web` to separate browser and API concerns.

## Architecture

JargaApi follows Clean Architecture with its own endpoint, router, and controllers:

```
Interface (Controllers, JSON Views, Plugs, Router, Endpoint)
    |
Application (Use Cases)
    |
Domain (ApiKeyScope)
```

### Domain Layer

| Module | Description |
|--------|-------------|
| `ApiKeyScope` | Defines the scope and permissions model for API key access |

### Application Layer

7 use cases covering workspace, project, and document operations:

| Use Case | Description |
|----------|-------------|
| `ListAccessibleWorkspaces` | List workspaces accessible to the API key holder |
| `GetWorkspaceWithDetails` | Get a workspace with its projects and members |
| `CreateProjectViaApi` | Create a new project in a workspace |
| `GetProjectWithDocumentsViaApi` | Get a project with its documents |
| `GetDocumentViaApi` | Get a single document by ID |
| `UpdateDocumentViaApi` | Update document content or metadata |
| `CreateDocumentViaApi` | Create a new document in a project |

### Interface Layer

**Controllers:**

| Controller | Endpoints |
|------------|-----------|
| `WorkspaceApiController` | List workspaces, get workspace details |
| `ProjectApiController` | Create project, get project with documents |
| `DocumentApiController` | Get, create, and update documents |

**Plugs:**

| Plug | Description |
|------|-------------|
| `ApiAuthPlug` | Bearer token authentication via Identity API key verification |
| `SecurityHeadersPlug` | Security headers (CSP, HSTS, X-Frame-Options, etc.) |

**JSON Views:** `WorkspaceApiJSON`, `ProjectApiJSON`, `DocumentApiJSON`

## API Routes

All routes require a Bearer token in the `Authorization` header.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/workspaces` | List accessible workspaces |
| `GET` | `/api/v1/workspaces/:id` | Get workspace with details |
| `POST` | `/api/v1/workspaces/:workspace_id/projects` | Create a project |
| `GET` | `/api/v1/workspaces/:workspace_id/projects/:id` | Get project with documents |
| `GET` | `/api/v1/workspaces/:workspace_id/projects/:project_id/documents/:id` | Get a document |
| `POST` | `/api/v1/workspaces/:workspace_id/projects/:project_id/documents` | Create a document |
| `PUT` | `/api/v1/workspaces/:workspace_id/projects/:project_id/documents/:id` | Update a document |

## Dependencies

- **`jarga`** (in_umbrella) -- core domain logic, repo, schemas
- **`identity`** (in_umbrella) -- API key verification and user resolution
- Phoenix, Jason, Bandit -- web framework and HTTP server
- Boundary -- compile-time boundary enforcement

## Testing

```bash
# Run jarga_api tests
mix test apps/jarga_api/test
```

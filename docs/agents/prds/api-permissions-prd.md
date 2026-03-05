# PRD: API Permissions Management per API Key

**Ticket:** #56 — Add API permissions management per API key
**Primary App:** identity (schema, domain, facade)
**Consuming Apps:** agents, agents_api, agents_web, identity_web
**Status:** Draft

## Summary

- **Problem**: API keys currently grant blanket access to all API endpoints and MCP tools within the scoped workspaces. There is no way to restrict what an API key can _do_ — only which workspaces it can access. For agent-to-agent communication, different agents need different access levels (e.g., a read-only agent should not be able to create or delete resources).
- **Value**: Granular API permissions reduce blast radius if a key is compromised, enable least-privilege access for automated agents, and satisfy security best practices for multi-tenant API platforms.
- **Users**: Developers and operators who create API keys for external integrations, agent-to-agent communication, and CI/CD pipelines.

## User Stories

- As a developer, I want to create an API key that can only read agents but not modify them, so that I can safely share it with a monitoring service.
- As an operator, I want to restrict an agent's API key to only specific MCP tools (e.g., `knowledge.search` but not `knowledge.create`), so that agents follow the principle of least privilege.
- As a developer, I want to see which permissions an API key has at a glance in the UI, so that I can audit access.
- As a developer, I want existing API keys to continue working without changes, so that this enhancement doesn't break current integrations.

## Functional Requirements

### Must Have (P0)

1. **Permissions field on API keys** — Add a `permissions` field to the `api_keys` table storing a list of permission scopes (e.g., `["agents:read", "agents:write", "mcp:knowledge.*"]`).
2. **Permission scope format** — Scopes follow a `resource:action` convention with wildcard support:
   - `agents:read` — List and show agents via REST API
   - `agents:write` — Create, update, delete agents via REST API
   - `agents:query` — Execute queries against agents via REST API
   - `mcp:knowledge.*` — All knowledge MCP tools
   - `mcp:knowledge.search` — Only the knowledge search tool
   - `mcp:jarga.*` — All Jarga MCP tools
   - `mcp:jarga.list_workspaces` — Only the list workspaces tool
   - `*` — Full access (all permissions)
3. **Backward compatibility** — API keys with `nil` or empty `permissions` field are treated as `["*"]` (full access). Existing keys retain all capabilities without migration action.
4. **Permission checking in REST API** — `agents_api` controllers enforce permission scopes before executing operations. A request to a restricted endpoint returns `403 Forbidden` with a descriptive error.
5. **Permission checking in MCP server** — MCP tool invocations check the API key's `mcp:<tool_name>` permission before executing. Unauthorized tool calls return an MCP error response.
6. **Create/edit UI** — Extend the existing `IdentityWeb.ApiKeysLive` to include a permissions section when creating or editing API keys.
7. **Identity facade API** — Extend `Identity.create_api_key/2` and `Identity.update_api_key/3` to accept a `permissions` attribute. Expose a `Identity.api_key_has_permission?/2` helper for consuming apps.
8. **IdentityBehaviour extension** — Add `api_key_has_permission?/2` to the behaviour so agents app can check permissions via DI.

### Should Have (P1)

1. **Permission presets** — Pre-defined permission groups in the UI:
   - "Full Access" → `["*"]`
   - "Read Only" → `["agents:read", "mcp:knowledge.search", "mcp:knowledge.get", "mcp:knowledge.traverse", "mcp:jarga.list_workspaces", "mcp:jarga.get_workspace", "mcp:jarga.list_projects", "mcp:jarga.get_project", "mcp:jarga.list_documents", "mcp:jarga.get_document"]`
   - "Agent Operator" → `["agents:read", "agents:write", "agents:query"]`
   - "Custom" → User selects individual scopes
2. **Permission display on key list** — The API keys table shows a summary badge or tag for the permission level (e.g., "Full Access", "Read Only", "Custom (5 scopes)").
3. **REST API for managing permissions** — Extend the existing API key CRUD endpoints in a new `identity_api` app (or within `agents_api` as a dedicated route) to accept `permissions` in create/update payloads.

### Nice to Have (P2)

1. **Permission audit log** — Emit a domain event (`ApiKeyPermissionsUpdated`) when permissions change.
2. **Permission validation on save** — Validate that all scopes in the `permissions` list are recognized scope strings (reject typos).
3. **MCP tool discovery with permissions** — The `GET /api/agents/:id/skills` endpoint filters returned tools based on the requesting API key's permissions.

## User Workflows

### Creating an API Key with Permissions

1. User navigates to **Settings → API Keys** (`/users/settings/api-keys`)
2. User clicks **"New API Key"**
3. Create modal shows: Name, Description, Workspace Access (existing), **Permissions** (new section)
4. Permissions section shows preset buttons ("Full Access", "Read Only", "Agent Operator", "Custom")
5. Selecting "Custom" expands a grouped checkbox list of available scopes
6. User submits → System creates key with selected permissions → Token displayed once

### Editing API Key Permissions

1. User clicks **edit** on an existing active API key
2. Edit modal shows current permissions pre-selected
3. User modifies permissions → Saves → Permissions updated immediately

### Permission Enforcement (REST API)

1. External client sends `GET /api/agents` with Bearer token
2. `ApiAuthPlug` authenticates the key and assigns `api_key` to conn
3. New `ApiPermissionPlug` (or inline check in plug) reads `api_key.permissions`
4. System checks if `agents:read` is in the key's permission set (considering wildcards)
5. **Allowed** → Request proceeds to controller → Response returned
6. **Denied** → 403 `{"error": "insufficient_permissions", "required": "agents:read"}` returned

### Permission Enforcement (MCP)

1. Agent calls MCP tool `knowledge.search` via the MCP server
2. `AuthPlug` authenticates and resolves workspace + user
3. Before tool execution, system checks if `mcp:knowledge.search` or `mcp:knowledge.*` or `mcp:*` or `*` is in the API key's permissions
4. **Allowed** → Tool executes normally
5. **Denied** → MCP error response indicating insufficient permissions

## Data Requirements

### Capture

- **`permissions`** — `{:array, :string}`, default: `nil` (treated as full access), stored on `api_keys` table
- Each element is a scope string: `"resource:action"` or `"resource:sub.action"` or `"*"`
- Maximum 100 scopes per key (validation constraint)
- All scope strings must match the pattern `^(\*|[a-z_]+:[a-z_.*]+)$`

### Display

- Permission presets resolved client-side from the scope list
- Badge/tag on API key list showing permission summary
- Full scope list visible in edit modal

### Relationships

- `api_keys.permissions` is a denormalized array on the existing `api_keys` table (no join table needed — scope lists are small and always loaded with the key)
- No new tables required

## Technical Considerations

### Affected Layers

| App | Layer | Changes |
|-----|-------|---------|
| **identity** | Domain | New `ApiKey` entity field, `ApiKeyPermissionPolicy` for scope matching |
| **identity** | Infrastructure | Migration adding `permissions` column, schema/changeset update |
| **identity** | Application | Update `CreateApiKey`, `UpdateApiKey` use cases; new `api_key_has_permission?/2` facade function |
| **identity_web** | Interface | Extend `ApiKeysLive` create/edit modals with permissions UI |
| **agents** | Application | Update `IdentityBehaviour` with `api_key_has_permission?/2` callback |
| **agents** | Infrastructure | Add permission check to MCP `AuthPlug` or tool execution pipeline |
| **agents_api** | Interface | New `ApiPermissionPlug` for REST endpoint permission enforcement |

### Integration Points

- **Identity ↔ Agents**: Via `IdentityBehaviour` (DI). Agents app calls `identity_module.api_key_has_permission?(api_key, scope)` — never accesses `Identity.Repo`.
- **Identity ↔ agents_api**: `ApiAuthPlug` already assigns `api_key` to conn. New `ApiPermissionPlug` reads from `conn.assigns.api_key.permissions`.
- **Identity ↔ MCP**: `AuthenticateMcpRequest` use case returns the api_key entity (or at minimum, its permissions). MCP auth plug or tool execution checks permissions.

### Permission Matching Algorithm

The `ApiKeyPermissionPolicy` (pure domain policy, no I/O) implements scope matching:

```
has_permission?(permissions, required_scope)
```

Rules:
1. `nil` permissions → full access (backward compat)
2. `"*"` in permissions → matches everything
3. Exact match: `"agents:read"` matches `"agents:read"`
4. Wildcard suffix: `"mcp:knowledge.*"` matches `"mcp:knowledge.search"`, `"mcp:knowledge.get"`, etc.
5. Category wildcard: `"mcp:*"` matches any `"mcp:..."` scope
6. No match → denied

### Canonical Scope Registry

All valid scopes should be defined in a single module (`Identity.Domain.Policies.ApiKeyPermissionPolicy` or a dedicated `ApiKeyScopes` value object) so that:
- The UI can enumerate available scopes
- Validation can reject unknown scopes (P2)
- New tools/endpoints register their scopes in one place

**REST API scopes:**

| Scope | Endpoint(s) | Description |
|-------|-------------|-------------|
| `agents:read` | `GET /api/agents`, `GET /api/agents/:id`, `GET /api/agents/:id/skills` | Read agent data |
| `agents:write` | `POST /api/agents`, `PATCH /api/agents/:id`, `DELETE /api/agents/:id` | Modify agents |
| `agents:query` | `POST /api/agents/:id/query` | Execute agent queries |

**MCP tool scopes:**

| Scope | Tool(s) | Description |
|-------|---------|-------------|
| `mcp:knowledge.search` | `knowledge.search` | Search knowledge entries |
| `mcp:knowledge.get` | `knowledge.get` | Get knowledge entry |
| `mcp:knowledge.traverse` | `knowledge.traverse` | Traverse knowledge graph |
| `mcp:knowledge.create` | `knowledge.create` | Create knowledge entries |
| `mcp:knowledge.update` | `knowledge.update` | Update knowledge entries |
| `mcp:knowledge.relate` | `knowledge.relate` | Create relationships |
| `mcp:jarga.list_workspaces` | `jarga.list_workspaces` | List workspaces |
| `mcp:jarga.get_workspace` | `jarga.get_workspace` | Get workspace details |
| `mcp:jarga.list_projects` | `jarga.list_projects` | List projects |
| `mcp:jarga.create_project` | `jarga.create_project` | Create projects |
| `mcp:jarga.get_project` | `jarga.get_project` | Get project details |
| `mcp:jarga.list_documents` | `jarga.list_documents` | List documents |
| `mcp:jarga.create_document` | `jarga.create_document` | Create documents |
| `mcp:jarga.get_document` | `jarga.get_document` | Get document details |

**Wildcard scopes:**

| Scope | Matches |
|-------|---------|
| `*` | Everything |
| `agents:*` | All `agents:*` scopes |
| `mcp:*` | All `mcp:*` scopes |
| `mcp:knowledge.*` | All `mcp:knowledge.*` scopes |
| `mcp:jarga.*` | All `mcp:jarga.*` scopes |

### Performance

- Permission checks are in-memory list operations on already-loaded API key data — no additional DB queries.
- The `permissions` array is loaded as part of `verify_api_key/1` (already returns the full entity).
- Scope matching is O(n) where n is the number of permissions on a key (typically <20).

### Security

- Permissions are **additive**: the list defines what is allowed; everything else is denied.
- `nil` permissions means full access (backward compat) — this is explicitly documented and surfaced in the UI as "Full Access".
- Workspace access (`workspace_access`) and permissions (`permissions`) are independent checks. Both must pass: the key must have workspace access AND the required permission scope.
- Permission changes take effect immediately (no caching layer for API key data).

## Edge Cases & Error Handling

1. **Existing API keys with no permissions field** → Treated as `["*"]` (full access). No data migration needed.
2. **API key with empty permissions list `[]`** → Treated as no permissions (deny all). The UI should warn before saving an empty permissions list.
3. **Unknown scope string saved** → Accepted and stored (forward-compatible for new tools). Optional P2 validation to warn about unrecognized scopes.
4. **Wildcard vs. specific deny** → No deny semantics. Permissions are purely additive (allow-list).
5. **MCP tool added after key creation** → Key with `mcp:*` wildcard automatically gains access. Key with specific scopes must be updated.
6. **Permission check on unauthenticated request** → `ApiAuthPlug` halts with 401 before permission check runs.
7. **API key with workspace access but no permission for the endpoint** → 403 Forbidden (not 401).

## Acceptance Criteria

- [ ] `api_keys` table has a `permissions` column (`{:array, :string}`, nullable, default `nil`)
- [ ] `ApiKey` domain entity and `ApiKeySchema` include `permissions` field
- [ ] `Identity.create_api_key/2` accepts `permissions` in attrs
- [ ] `Identity.update_api_key/3` accepts `permissions` in attrs
- [ ] `Identity.api_key_has_permission?/2` checks an api_key entity against a required scope
- [ ] `ApiKeyPermissionPolicy` implements wildcard-aware scope matching (pure function, no I/O)
- [ ] `IdentityBehaviour` includes `api_key_has_permission?/2` callback
- [ ] Existing API keys with `nil` permissions retain full access (backward compatible)
- [ ] `agents_api` REST endpoints enforce permission scopes via a plug — returns 403 on denial
- [ ] MCP tool execution checks `mcp:<tool_name>` permission — returns MCP error on denial
- [ ] `IdentityWeb.ApiKeysLive` create modal includes permissions section with presets
- [ ] `IdentityWeb.ApiKeysLive` edit modal allows modifying permissions
- [ ] API keys list displays permission summary (badge/tag)
- [ ] Empty permissions `[]` denies all access (UI warns before saving)
- [ ] Workspace access and permissions are checked independently (both must pass)

## Codebase Context

### Existing Patterns

- **Role-based RBAC**: `Identity.Domain.Policies.WorkspacePermissionsPolicy` — `can?(role, action)` with role hierarchy. This feature adds a parallel scope-based permission model for API keys.
- **API key scoping**: `Webhooks.workspace_in_scope?/2` — checks `workspace_access` array. The new permissions field follows the same array-on-entity pattern.
- **DI via behaviour**: `Agents.Application.Behaviours.IdentityBehaviour` — agents app consumes identity through this interface. New permission checks flow through the same pattern.

### Affected Files (Indicative)

**Identity app (domain owner):**
- `apps/identity/priv/repo/migrations/*_add_permissions_to_api_keys.exs` — new migration
- `apps/identity/lib/identity/domain/entities/api_key.ex` — add `permissions` field
- `apps/identity/lib/identity/domain/policies/api_key_permission_policy.ex` — new policy (scope matching)
- `apps/identity/lib/identity/infrastructure/schemas/api_key_schema.ex` — add `permissions` field, update changeset
- `apps/identity/lib/identity/application/use_cases/create_api_key.ex` — pass through permissions
- `apps/identity/lib/identity/application/use_cases/update_api_key.ex` — pass through permissions
- `apps/identity/lib/identity/application/use_cases/verify_api_key.ex` — permissions already loaded (entity includes all fields)
- `apps/identity/lib/identity.ex` — add `api_key_has_permission?/2` facade function

**Identity web (UI):**
- `apps/identity/lib/identity_web/live/api_keys_live.ex` — permissions UI in create/edit modals

**Agents app (MCP enforcement):**
- `apps/agents/lib/agents/application/behaviours/identity_behaviour.ex` — add callback
- `apps/agents/lib/agents/infrastructure/mcp/auth_plug.ex` — assign api_key to conn (currently only assigns workspace_id/user_id)
- `apps/agents/lib/agents/application/use_cases/authenticate_mcp_request.ex` — return api_key entity (or permissions) alongside workspace_id
- MCP tool execution layer — add permission check before tool dispatch

**Agents API app (REST enforcement):**
- `apps/agents_api/lib/agents_api/plugs/api_permission_plug.ex` — new plug
- `apps/agents_api/lib/agents_api/router.ex` — add plug to pipeline
- `apps/agents_api/lib/agents_api/plugs/api_auth_plug.ex` — already assigns `api_key` (no changes needed)

### Available Infrastructure

- `ApiKeyTokenService` — token generation/hashing (no changes needed)
- `ApiKeyRepository` — data access for API keys (changeset update for new field)
- `Perme8.Events.EventBus` — for optional `ApiKeyPermissionsUpdated` event (P2)
- `ToolProvider` behaviour — tool registry that provides canonical tool names for scope mapping

## Open Questions

- [ ] Should the `agents_api` permission plug be a generic plug that accepts the required scope as an option (e.g., `plug ApiPermissionPlug, scope: "agents:read"`), or should it infer the scope from the HTTP method and path?
- [ ] Should `AuthenticateMcpRequest` return the full `ApiKey` entity to the MCP auth plug (so it can check permissions), or should permissions be checked at a different layer (e.g., inside each tool component)?
- [ ] Should there be scope validation on save (reject unrecognized scopes) in v1, or defer to P2?
- [ ] If new MCP tool providers are added (beyond knowledge and jarga), how should their scopes be registered? Should each `ToolProvider` module declare its required scopes?

## Out of Scope

- **OAuth2 / JWT-based scopes** — This feature uses simple scope strings on API keys, not an OAuth2 flow.
- **Per-workspace permissions** — Permissions are per-key, not per-workspace-per-key. A key's permissions apply across all its accessible workspaces.
- **Rate limiting per scope** — Different rate limits based on permission level.
- **Permission inheritance / groups** — No role→permission mapping. Presets are UI sugar, not stored entities.
- **Deny rules** — No deny semantics; permissions are purely additive (allow-list only).
- **webhooks_api / jarga_api enforcement** — This PRD focuses on agents_api and MCP. Other API apps can adopt the same pattern in future tickets.

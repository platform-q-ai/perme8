# App Ownership Registry

> The authoritative reference for app boundaries, responsibilities, and file placement in the Perme8 umbrella. All Claude skills and agents MUST consult this document when determining where to place code.
>
> If this document conflicts with other docs (`docs/umbrella_apps.md`, `docs/architecture/service_evolution_plan.md`), **this document wins**.

## Ownership Registry

Each app has a single owner and a clear set of responsibilities. No two apps own the same concept.

| App | Type | Owns | Repo | Depends On |
|-----|------|------|------|------------|
| **identity** | Domain context | Users, auth, sessions, workspaces, memberships, roles, API keys | `Identity.Repo` | `perme8_events` |
| **jarga** | Domain context | Projects, documents, notes, collaboration (Yjs), slugs, chat, notifications | `Jarga.Repo` | `identity`, `perme8_events` |
| **agents** | Domain context | Agent definitions, LLM orchestration, perme8-mcp server, ToolProvider infrastructure, Sessions | `Agents.Repo` | `identity`, `perme8_events` |
| **webhooks** | Domain context | Outbound/inbound webhooks, HMAC signing, audit logging | `Webhooks.Repo` | `identity`, `perme8_events` |
| **entity_relationship_manager** | Domain context | Schema definitions, entities, edges, graph traversal | Needs own Repo | `identity`, `perme8_events` |
| **perme8_events** | Shared infrastructure | Eventbus facade (`Perme8.Events`), EventBus dispatcher, EventHandler behaviour, DomainEvent macro, PubSub server -- **planned, see [#200](https://github.com/platform-q-ai/perme8/issues/200)** | None | Nothing (foundational) |
| **jarga_web** | Interface (LiveView) | UI shell, mounts companion `_web` apps | None | `jarga`, `agents`, `identity`, `perme8_events` |
| **jarga_api** | Interface (REST) | JSON API for workspaces, projects, documents | None | `jarga`, `identity` |
| **agents_web** | Interface (LiveView) | Sessions UI, agent management UI | None | `agents`, `identity` |
| **agents_api** | Interface (REST) | JSON API for agents | None | `agents`, `identity` |
| **webhooks_api** | Interface (REST) | JSON API for webhooks | None | `webhooks`, `identity` |
| **exo_dashboard** | Dev tool | BDD feature dashboard | None | Nothing |
| **perme8_dashboard** | Dev tool | Unified dev-tool hub | None | `exo_dashboard`, `agents_web` |
| **alkali** | Standalone | Static site generator | None | Nothing |
| **chat** | Domain context | Chat sessions, messages, real-time messaging -- **planned, currently in `jarga`** | Needs own Repo | `identity`, `agents`, `perme8_events` |
| **notifications** | Domain context | Notification creation, delivery, preferences, subscriptions -- **planned, currently in `jarga`** | Needs own Repo | `identity`, `perme8_events` |
| **perme8_tools** | Dev tool | Mix tasks, linters | None | Nothing |

### Path Conventions

Most apps use `apps/<app>/lib/<app>/` as their root namespace (e.g., `apps/agents/lib/agents/`). However, **jarga** organises its bounded contexts as peer directories under `apps/jarga/lib/`:

- `apps/jarga/lib/projects/` -- Projects context
- `apps/jarga/lib/documents/` -- Documents context
- `apps/jarga/lib/chat/` -- Chat context
- `apps/jarga/lib/notifications/` -- Notifications context

Each context has its own `domain/`, `application/`, and `infrastructure/` layers.

### Pending Changes

- **perme8_events** -- Being extracted from `jarga` and `identity` in [#200](https://github.com/platform-q-ai/perme8/issues/200). Until that lands, eventbus infrastructure still lives in `jarga` (runtime) and `identity` (DomainEvent macro). The dependency relationships above reflect the target state.
- **perme8-mcp** -- The MCP server in `agents` is being renamed from `knowledge-mcp` to `perme8-mcp` with a `ToolProvider` abstraction in [#181](https://github.com/platform-q-ai/perme8/issues/181). The `agents` ownership description above reflects the target state.
- **chat** -- Planned extraction from `jarga` (see [service evolution plan](docs/architecture/service_evolution_plan.md)). Currently lives in `apps/jarga/lib/chat/`. Until extracted, all chat code belongs in `jarga`.
- **notifications** -- Planned extraction from `jarga` (see [service evolution plan](docs/architecture/service_evolution_plan.md)). Currently lives in `apps/jarga/lib/notifications/`. Until extracted, all notifications code belongs in `jarga`.

---

## File Placement Rules

| Artifact | Location | Example |
|----------|----------|---------|
| Migrations | `apps/<owning_app>/priv/repo/migrations/` | `apps/agents/priv/repo/migrations/` |
| Domain events | `apps/<owning_app>/lib/<app>/domain/events/` or `apps/<owning_app>/lib/<context>/domain/events/` | `apps/agents/lib/agents/domain/events/agent_created.ex`, `apps/jarga/lib/chat/domain/events/chat_message_sent.ex` |
| Entities | `apps/<owning_app>/lib/<context>/domain/entities/` | `apps/jarga/lib/documents/domain/entities/document.ex` |
| Policies | `apps/<owning_app>/lib/<context>/domain/policies/` | `apps/jarga/lib/documents/domain/policies/document_access_policy.ex` |
| Use cases | `apps/<owning_app>/lib/<app>/application/use_cases/` or `apps/<owning_app>/lib/<context>/application/use_cases/` | `apps/identity/lib/identity/application/use_cases/register_user.ex`, `apps/jarga/lib/chat/application/use_cases/create_session.ex` |
| Behaviours (ports) | `apps/<owning_app>/lib/<app>/application/` or `apps/<owning_app>/lib/<context>/application/behaviours/` | `apps/agents/lib/agents/application/agent_repository.ex` |
| Schemas | `apps/<owning_app>/lib/<app>/<context>/infrastructure/schemas/` or `apps/<owning_app>/lib/<context>/infrastructure/schemas/` | `apps/webhooks/lib/webhooks/infrastructure/schemas/webhook_schema.ex` |
| Repositories | `apps/<owning_app>/lib/<context>/infrastructure/repositories/` | `apps/jarga/lib/documents/infrastructure/repositories/document_repository.ex` |
| LiveViews | `apps/<owning_app_web>/lib/<app_web>/live/` | `apps/agents_web/lib/agents_web/live/` |
| Controllers | `apps/<owning_app_api>/lib/<app_api>/controllers/` | `apps/jarga_api/lib/jarga_api/controllers/` |
| Feature files (domain) | `apps/<owning_app>/test/features/` | `apps/agents/test/features/knowledge-mcp/` |
| Feature files (UI) | `apps/<owning_app_web>/test/features/` | `apps/jarga_web/test/features/documents/` |
| Feature files (API) | `apps/<owning_app_api>/test/features/` | `apps/jarga_api/test/features/` |
| MCP tool providers | `apps/agents/lib/agents/infrastructure/mcp/tool_providers/` | `apps/agents/lib/agents/infrastructure/mcp/tool_providers/knowledge_provider.ex` |

---

## Domain Event Ownership

Domain events follow a simple rule: **events live in the emitting app**.

- The app that produces an event defines its struct (using the `DomainEvent` macro) and publishes it via the eventbus.
- The event infrastructure itself (facade, dispatcher, behaviours, macros, PubSub server) lives in `perme8_events` (see [#200](https://github.com/platform-q-ai/perme8/issues/200)).
- Subscribers can live in any app -- they depend on the emitting app for the event struct definition.

| App | Events |
|-----|--------|
| **identity** | `MemberInvited`, `MemberRemoved`, `WorkspaceInvitationNotified`, `WorkspaceUpdated` |
| **jarga** (projects) | `ProjectCreated`, `ProjectUpdated`, `ProjectArchived`, `ProjectDeleted` |
| **jarga** (documents) | `DocumentCreated`, `DocumentDeleted`, `DocumentPinnedChanged`, `DocumentTitleChanged`, `DocumentVisibilityChanged` |
| **jarga** (chat) | `ChatMessageSent`, `ChatSessionStarted`, `ChatSessionDeleted` |
| **jarga** (notifications) | `NotificationCreated`, `NotificationRead`, `NotificationActionTaken` |
| **agents** | `AgentCreated`, `AgentUpdated`, `AgentDeleted`, `AgentAddedToWorkspace`, `AgentRemovedFromWorkspace` |
| **entity_relationship_manager** | `SchemaCreated`, `SchemaUpdated`, `EntityCreated`, `EntityUpdated`, `EntityDeleted`, `EdgeCreated`, `EdgeDeleted` |
| **webhooks** | _(none yet)_ |

---

## Feature File Ownership

Feature files test the **owning app**, not the mounting app:

- **Domain feature files** (e.g., HTTP API tests) go in the owning domain app: `apps/agents/test/features/`
- **UI feature files** (e.g., browser tests) go in the owning web app: `apps/jarga_web/test/features/`
- **API feature files** go in the owning API app: `apps/jarga_api/test/features/`

If `jarga_web` mounts a LiveView from `agents_web`, the feature file for that view goes in `agents_web`, not `jarga_web`.

# App Ownership Registry

> The authoritative reference for app boundaries, responsibilities, and file placement in the Perme8 umbrella. All Claude skills and agents MUST consult this document when determining where to place code.
>
> If this document conflicts with other docs (`docs/umbrella_apps.md`, `docs/architecture/service_evolution_plan.md`), **this document wins**.

## Ownership Registry

Each app has a single owner and a clear set of responsibilities. No two apps own the same concept.

| App | Type | Owns | Repo | Depends On |
|-----|------|------|------|------------|
| **identity** | Domain context | Users, auth, sessions, workspaces, memberships, roles, API keys | `Identity.Repo` | `perme8_events` |
| **jarga** | Domain context | Projects, documents, notes, collaboration (Yjs), slugs | `Jarga.Repo` | `identity`, `notifications`, `perme8_events` |
| **agents** | Domain context | Agent definitions, LLM orchestration, perme8-mcp server, ToolProvider infrastructure, Sessions (task lifecycle, containers, queues), Tickets (GitHub issue sync, triage, ordering) | `Agents.Repo` | `identity`, `perme8_events` |
| **webhooks** | Domain context | Outbound/inbound webhooks, HMAC signing, audit logging | `Webhooks.Repo` | `identity`, `perme8_events` |
| **entity_relationship_manager** | Domain context + API | Schema definitions, entities, edges, graph traversal | Needs own Repo (currently borrows `Jarga.Repo`) | `identity`, `perme8_events` |
| **perme8_events** | Shared infrastructure | Eventbus facade (`Perme8.Events`), EventBus dispatcher, EventHandler behaviour, DomainEvent macro, PubSub server | None | Nothing (foundational) |
| **perme8_plugs** | Shared infrastructure | Shared Plug modules (`Perme8.Plugs.SecurityHeaders`) | None | Nothing (foundational) |
| **jarga_web** | Interface (LiveView) | UI shell, mounts companion `_web` apps | None | `jarga`, `agents`, `chat`, `chat_web`, `identity`, `notifications`, `perme8_events` |
| **jarga_api** | Interface (REST) | JSON API for workspaces, projects, documents | None | `jarga`, `identity` |
| **agents_web** | Interface (LiveView) | Sessions UI, agent management UI | None | `agents`, `identity` |
| **agents_api** | Interface (REST) | JSON API for agents | None | `agents`, `identity` |
| **webhooks_api** | Interface (REST) | JSON API for webhooks | None | `webhooks`, `identity` |
| **exo_dashboard** | Dev tool | BDD feature dashboard | None | Nothing |
| **perme8_dashboard** | Dev tool | Unified dev-tool hub | None | `exo_dashboard`, `agents_web` |
| **alkali** | Standalone | Static site generator | None | Nothing |
| **chat** | Domain context | Chat sessions, messages, real-time messaging | `Chat.Repo` | `identity`, `agents`, `perme8_events` |
| **chat_web** | Interface (LiveView) | Chat panel UI, message components | None | `chat`, `identity`, `agents` |
| **notifications** | Domain context | Notification creation, delivery, preferences, subscriptions | `Notifications.Repo` | `identity`, `perme8_events` |
| **perme8_tools** | Dev tool | Mix tasks, linters | None | Nothing |

### App Naming Conventions

Domain apps follow a `{app}` / `{app}_web` / `{app}_api` triad:

| Suffix | Role | Contains | Does NOT contain |
|--------|------|----------|-----------------|
| `{app}` | Domain context | Business logic, entities, use cases, repositories, schemas, domain events | Controllers, endpoints, routers, API routes, LiveViews |
| `{app}_web` | Interface (LiveView) | LiveViews, live components, browser routes, Phoenix endpoints | Domain logic, API endpoints, REST controllers |
| `{app}_api` | Interface (REST) | Controllers, JSON views, API routes, Phoenix endpoints | Domain logic, LiveViews, browser routes |

**Key rules:**

- **No API routes in domain apps.** REST endpoints, controllers, and JSON views always go in a dedicated `{app}_api` app. The domain app exposes a public facade that the API app calls.
- **No domain logic in interface apps.** `_web` and `_api` apps are thin wrappers that call into the domain app. They own routing, request/response handling, and presentation only.
- **Not every domain app needs all three.** Some apps only have `{app}` (e.g., `webhooks` has `webhooks` + `webhooks_api` but no `webhooks_web`). Only create interface apps when needed.
- **Exception: `entity_relationship_manager`** is a combined domain + API app (see registry). This is a legacy pattern -- new apps should follow the triad.

### Path Conventions

Most apps use `apps/<app>/lib/<app>/` as their root namespace (e.g., `apps/agents/lib/agents/`). However, **jarga** organises its bounded contexts as peer directories under `apps/jarga/lib/`:

- `apps/jarga/lib/projects/` -- Projects context
- `apps/jarga/lib/documents/` -- Documents context
Each context has its own `domain/`, `application/`, and `infrastructure/` layers.

### Pending Changes

- **perme8-mcp** -- The MCP server in `agents` is being renamed from `knowledge-mcp` to `perme8-mcp` with a `ToolProvider` abstraction in [#181](https://github.com/platform-q-ai/perme8/issues/181). The `agents` ownership description above reflects the target state.
- **entity_relationship_manager** -- Currently borrows `Jarga.Repo`. Needs its own Repo as part of the Standalone App Principle enforcement.

### Completed Migrations

- **perme8_events** -- Extracted in [#200](https://github.com/platform-q-ai/perme8/issues/200). EventBus, EventHandler, DomainEvent macro, and PubSub server now live in `apps/perme8_events/`.
- **notifications** -- Extracted from `jarga` in [#38](https://github.com/platform-q-ai/perme8/issues/38). Now lives in `apps/notifications/` with its own `Notifications.Repo`.
- **chat** -- Extracted from `jarga` in [#60](https://github.com/platform-q-ai/perme8/issues/60). Now lives in `apps/chat/` with its own `Chat.Repo`. Web layer in `apps/chat_web/`.
- **perme8_plugs** -- Extracted in [#118](https://github.com/platform-q-ai/perme8/issues/118). Shared `SecurityHeaders` plug with `:liveview`/`:api` profiles now lives in `apps/perme8_plugs/`, replacing 7 duplicate plug modules across the umbrella.

---

## File Placement Rules

| Artifact | Location | Example |
|----------|----------|---------|
| Migrations | `apps/<owning_app>/priv/repo/migrations/` | `apps/agents/priv/repo/migrations/` |
| Domain events | `apps/<owning_app>/lib/<app>/domain/events/` or `apps/<owning_app>/lib/<context>/domain/events/` | `apps/agents/lib/agents/domain/events/agent_created.ex`, `apps/chat/lib/chat/domain/events/chat_message_sent.ex` |
| Entities | `apps/<owning_app>/lib/<context>/domain/entities/` | `apps/jarga/lib/documents/domain/entities/document.ex` |
| Policies | `apps/<owning_app>/lib/<context>/domain/policies/` | `apps/jarga/lib/documents/domain/policies/document_access_policy.ex` |
| Use cases | `apps/<owning_app>/lib/<app>/application/use_cases/` or `apps/<owning_app>/lib/<context>/application/use_cases/` | `apps/identity/lib/identity/application/use_cases/register_user.ex`, `apps/chat/lib/chat/application/use_cases/create_session.ex` |
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
| **identity** | `MemberInvited`, `MemberJoined`, `MemberRemoved`, `WorkspaceInvitationNotified`, `WorkspaceUpdated` |
| **jarga** (projects) | `ProjectCreated`, `ProjectUpdated`, `ProjectArchived`, `ProjectDeleted` |
| **jarga** (documents) | `DocumentCreated`, `DocumentDeleted`, `DocumentPinnedChanged`, `DocumentTitleChanged`, `DocumentVisibilityChanged` |
| **chat** | `ChatMessageSent`, `ChatSessionStarted`, `ChatSessionDeleted` |
| **notifications** | `NotificationCreated`, `NotificationRead` |
| **agents** | `AgentCreated`, `AgentUpdated`, `AgentDeleted`, `AgentAddedToWorkspace`, `AgentRemovedFromWorkspace`, `TaskCreated`, `TaskCompleted`, `TaskFailed`, `TaskCancelled`, `SessionStateChanged`, `SessionWarmingStarted`, `SessionWarmed`, `SessionCompacted`, `SessionDiffProduced`, `SessionErrorOccurred`, `SessionFileEdited`, `SessionMessageUpdated`, `SessionMetadataUpdated`, `SessionPermissionRequested`, `SessionPermissionResolved`, `SessionRetrying`, `SessionServerConnected` |
| **entity_relationship_manager** | `SchemaCreated`, `SchemaUpdated`, `EntityCreated`, `EntityUpdated`, `EntityDeleted`, `EdgeCreated`, `EdgeDeleted` |
| **webhooks** | _(none yet)_ |

---

## Feature File Ownership

Feature files test the **owning app**, not the mounting app:

- **Domain feature files** (e.g., HTTP API tests) go in the owning domain app: `apps/agents/test/features/`
- **UI feature files** (e.g., browser tests) go in the owning web app: `apps/agents_web/test/features/`
- **API feature files** go in the owning API app: `apps/jarga_api/test/features/`

### Mounting Apps vs. Owning Apps

Some apps exist primarily to mount other apps into a unified shell (e.g., `jarga_web` mounts `agents_web`, `perme8_dashboard` mounts `exo_dashboard`). These mounting apps should only contain feature files for:

- **Navigation** -- verifying the user can navigate to the mounted app
- **Shell integration** -- verifying the mounted app renders within the shell (tabs, layout, sidebar)

The mounted app's **own functionality** (forms, interactions, data display, workflows) is tested in feature files within the mounted app itself.

| Scenario | Feature file location | What it tests |
|----------|----------------------|---------------|
| Agent session management UI | `apps/agents_web/test/features/` | Session creation, message sending, agent behaviour |
| Navigating to agents from jarga shell | `apps/jarga_web/test/features/` | Navigation link works, agents UI mounts in shell |
| BDD dashboard functionality | `apps/exo_dashboard/test/features/` | Feature browsing, run triggering, result display |
| Navigating to exo dashboard tab | `apps/perme8_dashboard/test/features/` | Tab renders, dashboard mounts in hub |

---

## Skill Enforcement

The following Claude skills consult this document when generating code or making file-placement decisions. If this registry is updated (new apps, changed ownership, moved boundaries), these skills automatically pick up the changes:

| Skill | How It Uses This Document |
|-------|--------------------------|
| **Generate Exo-BDD Features** | Determines the owning app for feature file placement; detects mounting/integration apps and scopes test scenarios accordingly |
| **CRUD Create** | Identifies the owning app, Repo, and file placement paths before delegating to architect/TDD agents; validates artifact placement before finalizing |
| **CRUD Update** | Validates that target files are in the correct owning app during impact analysis; detects and fixes boundary violations as part of the change |
| **CRUD Delete** | Scans for cross-app coupling (shared Repo usage, schema imports, facade calls, event subscribers) before removal; ensures clean removal leaves no orphaned cross-app references |
| **Check Documentation** | Verifies this document is updated when domain ownership shifts or new apps are created |
| **Review PR** | Checks for `app_ownership.md` staleness via its **Check Documentation** worker when reviewing changes |
| **Finalize** | Verifies this document is current via its **Check Documentation** composition step as part of the finalization quality gate |

**Keeping this document current is critical** -- skills reference it at invocation time, so stale entries lead to misplaced artifacts. The Check Documentation skill flags this document for update whenever domain ownership changes are detected.

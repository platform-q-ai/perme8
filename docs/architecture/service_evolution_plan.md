# Service Evolution Plan

> High-level roadmap for decomposing the Perme8 umbrella into focused, independently deployable services.

## Vision

Each bounded context becomes its own umbrella app (or standalone service) with a clear ownership boundary. `jarga` shrinks from a monolithic domain app into a focused **project and document management** service. All other concerns — identity, notifications, agents, chat, and the component system — live in dedicated apps.

---

## Current State

```
apps/
  identity/                    # Users, auth, workspaces, memberships, API keys
  jarga/                       # Projects, documents, notes, chat, notifications
  agents/                      # Agent definitions, LLM orchestration, Knowledge MCP (EXTRACTED)
  jarga_web/                   # Browser UI (LiveView)
  jarga_api/                   # REST API
  entity_relationship_manager/ # Schema-driven graph layer (Neo4j + PG)
  alkali/                      # Static site generator (independent)
  perme8_tools/                # Dev-time Mix tasks (independent)
```

`jarga` currently owns 5 bounded contexts: Projects, Documents (+ Notes), Chat, Notifications, and thin delegation facades for Accounts/Workspaces. Agents has been extracted into its own app.

---

## Target State

```
apps/
  identity/                    # Users, auth, workspaces, memberships, roles, API keys
  jarga/                       # Projects, documents, notes, document collaboration
  jarga_web/                   # Browser UI (LiveView) — routes to all service facades
  jarga_api/                   # REST API — routes to all service facades
  notifications/               # Notification delivery, preferences, subscriptions
  agents/                      # Agent definitions, LLM orchestration, agent queries
  chat/                        # Chat sessions, messages, real-time messaging
  components/                  # Component system — reusable document components
  entity_relationship_manager/ # Schema-driven graph layer (Neo4j + PG)
  alkali/                      # Static site generator (independent)
  jarga_tools/                 # Dev-time Mix tasks (independent)
```

---

## Service Boundaries

### 1. Identity (already extracted)

**Owns:** Users, authentication, sessions, workspaces, workspace memberships, roles, API keys.

**Status:** Complete. Already a standalone app with its own endpoint (port 4001).

No further extraction needed. Remove the thin `Jarga.Accounts` and `Jarga.Workspaces` delegation facades once all callers migrate to `Identity` directly.

| Responsibility | Current | Target |
|---|---|---|
| User registration & auth | `identity` | `identity` (no change) |
| Workspace CRUD | `identity` | `identity` (no change) |
| Membership & roles | `identity` | `identity` (no change) |
| API key management | `identity` | `identity` (no change) |
| `Jarga.Accounts` facade | `jarga` (delegation) | **Remove** |
| `Jarga.Workspaces` facade | `jarga` (delegation) | **Remove** |

---

### 2. Jarga (narrowed scope)

**Owns:** Projects, documents, notes, document collaboration (Yjs), slug generation.

This is the core content management service. Everything that isn't a project or document gets extracted out.

| Responsibility | Current | Target |
|---|---|---|
| Projects CRUD | `jarga` | `jarga` (no change) |
| Documents CRUD | `jarga` | `jarga` (no change) |
| Notes (Yjs collab) | `jarga` | `jarga` (no change) |
| Document access policy | `jarga` | `jarga` (no change) |
| Slug generation | `jarga` | `jarga` (no change) |
| Agents | `jarga` | **Extract to `agents`** |
| Chat | `jarga` | **Extract to `chat`** |
| Notifications | `jarga` | **Extract to `notifications`** |
| Document components | `jarga` | **Extract to `components`** |
| Agent query parsing (documents) | `jarga` | Moves with agents; jarga calls agents via behaviour |

---

### 3. Notifications (new app)

**Owns:** Notification creation, delivery, preferences, subscription management.

| Responsibility | Source | Notes |
|---|---|---|
| `Jarga.Notifications` context | `jarga` | Full extraction — domain, use cases, infra |
| `NotificationSchema` | `jarga` | Moves to `notifications` with its own repo or shared repo |
| `WorkspaceInvitationSubscriber` | `jarga` | Moves to `notifications`; EventHandler subscribing to identity domain events |
| Notification bell (LiveView) | `jarga_web` | Stays in `jarga_web`; calls `Notifications` facade |

**Integration pattern:** Event-driven via `Perme8.Events.EventBus`. Other services emit structured domain events (e.g., `identity` emits `MemberInvited`, `jarga` emits `DocumentCreated`). Notifications uses `EventHandler` subscribers to react and create/deliver notifications.

---

### 4. Agents (EXTRACTED)

**Owns:** Agent definitions, workspace-agent associations, LLM client orchestration, agent query execution, Knowledge MCP tools.

**Status:** Extracted as standalone app. Agent CRUD, cloning, LLM client, query execution, and Knowledge MCP (6 tools via JSON-RPC 2.0 on port 4007) are implemented with 297 unit tests and 26 exo-bdd HTTP scenarios.

| Responsibility | Source | Status |
|---|---|---|
| `Jarga.Agents` context | `jarga` | Extracted to `agents` app |
| `AgentSchema`, `WorkspaceAgentJoinSchema` | `jarga` | In `agents` |
| `AgentCloner` | `jarga` | In `agents` |
| `LLMClient` | `jarga` | In `agents` |
| `AgentQueryParser` (in Documents) | `jarga` | In `agents`; jarga calls via behaviour |
| `ExecuteAgentQuery` use case | `jarga` | In `agents` |
| Knowledge MCP (6 tools) | `knowledge_mcp` (deleted) | In `agents` |
| Agent LiveViews (Index/Form) | `jarga_web` | Stays in `jarga_web`; calls `Agents` facade |

**Integration pattern:** Synchronous calls from documents/chat into the agents facade. Agents depends on `identity` (auth) and `entity_relationship_manager` (knowledge graph). Agents emits lifecycle domain events via `Perme8.Events.EventBus` (e.g., `AgentCreated`, `AgentUpdated`, `AgentDeleted`).

---

### 5. Chat (new app)

**Owns:** Chat sessions, messages, real-time messaging.

| Responsibility | Source | Notes |
|---|---|---|
| `Jarga.Chat` context | `jarga` | Full extraction — domain, use cases, infra |
| `SessionSchema`, `MessageSchema` | `jarga` | Moves to `chat` |
| Chat panel (LiveView) | `jarga_web` | Stays in `jarga_web`; calls `Chat` facade |

**Integration pattern:** EventBus domain events for real-time message broadcasting (`ChatMessageSent`, `ChatSessionStarted`). Chat may call `Agents` for AI-powered responses. Chat may trigger `Notifications` events.

---

### 6. Components (new app)

**Owns:** Component definitions, component rendering, component registry, component loading.

| Responsibility | Source | Notes |
|---|---|---|
| `DocumentComponent` entity | `jarga` (Documents domain) | Moves to `components` |
| `DocumentComponentSchema` | `jarga` | Moves to `components` |
| `ComponentLoader` | `jarga` | Moves to `components` |
| Component rendering logic | `jarga_web` | Stays in `jarga_web` for now; calls `Components` facade |

**Integration pattern:** Documents reference components by ID. The `components` app owns the component catalog and schema. Documents call into `Components` to resolve and load components.

---

## Dependency Graph (Target)

```
                    identity (standalone)
                   /    |    \        \
                  /     |     \        \
                 v      v      v        v
            jarga   agents   chat   notifications
              |       |  \       |
              v       |   v      |
          components  |  ERM     |
                      |          |
                      +←---------+

  jarga_web  ──→  all of the above (UI layer)
  jarga_api  ──→  all of the above (API layer)

  alkali        (independent)
  perme8_tools  (independent)
```

**Rules:**
- `identity` depends on nothing in the umbrella
- Domain apps (`jarga`, `agents`, `chat`, `notifications`, `components`) depend on `identity` for auth/workspace context
- `jarga` depends on `agents` and `components` (documents reference agents and components)
- `agents` depends on `identity` and `entity_relationship_manager` (knowledge graph data)
- `chat` depends on `agents` (for AI responses) and `identity`
- `notifications` depends on `identity`; integrates with others via PubSub only
- `jarga_web` and `jarga_api` depend on all domain apps (they are interface layers)

---

## Extraction Order

Recommended sequence based on coupling and complexity:

| Phase | Extraction | Status |
|---|---|---|
| 0 | Remove delegation facades | Pending -- clean up `Jarga.Accounts`/`Jarga.Workspaces` |
| 1 | **Notifications** | Pending -- lowest coupling, event-driven |
| 2 | **Chat** | Pending -- self-contained sessions/messages |
| 3 | **Agents** | **DONE** -- extracted to `apps/agents/` with Knowledge MCP |
| 4 | **Components** | Pending -- tightest coupling to documents |

Each extraction follows the same playbook:
1. Write a PRD for the extraction
2. Create an architectural plan with TDD phases
3. Create the new umbrella app with its own boundary config
4. Move domain, application, and infrastructure layers
5. Define behaviours/callbacks at the boundary
6. Update `jarga_web` and `jarga_api` to call the new facade
7. Remove old code from `jarga`
8. Run full test suite + boundary checks

---

## Shared Infrastructure Decisions

| Concern | Approach |
|---|---|
| **Database** | Shared PostgreSQL instance; each app owns its tables via its own Ecto schemas. Consider separate repos per app or a shared repo with prefixed migrations. |
| **PubSub** | Shared `Jarga.PubSub` (rename to `Perme8.PubSub`?) for inter-service events within the umbrella. |
| **Mailer** | Keep in one place (likely `notifications` after extraction, or a shared `Perme8.Mailer`). |
| **Auth context** | Always resolved by `identity`. Other apps receive workspace/user context, never manage auth themselves. |
| **Repo** | Each new app can either bring its own Ecto Repo or share `Jarga.Repo`. Separate repos are cleaner but add migration complexity. Decide per extraction. |

---

## Open Questions

1. **Repo strategy** — One shared repo or one repo per service? Shared is simpler in an umbrella; separate is cleaner for future extraction to standalone services.
2. **PubSub namespace** — Rename `Jarga.PubSub` to `Perme8.PubSub` to reflect it's umbrella-wide?
3. **Component system scope** — Does the component system include rendering, or only the data model/registry? Rendering may stay in `jarga_web`.
4. **Agent-document interface** — What's the contract? A behaviour in `jarga` that `agents` implements, or a direct call from `jarga` into `agents`?
5. **Chat-agent integration** — Does chat embed agent logic, or does it call agents as a service?
6. **Future: standalone deployment** — Are any of these services candidates for deployment outside the umbrella (separate Fly apps, separate repos)? This affects the repo/PubSub/auth decisions.

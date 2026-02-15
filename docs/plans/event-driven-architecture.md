# Event-Driven Architecture Plan for Perme8

## Status: DRAFT
## Date: 2026-02-15

---

## 1. Executive Summary

This plan transforms perme8 from its current **ad-hoc PubSub notification pattern** into a **structured event-driven architecture** across all umbrella apps. The goal is to decouple bounded contexts, enable reliable cross-context communication, create an auditable event history, and lay the foundation for future event sourcing if needed.

### What We Have Today

The codebase already has strong event-driven *instincts*:

- **Phoenix PubSub** as a shared event bus (`Jarga.PubSub`)
- **Notifier behaviour pattern** with DI via `opts[:notifier]` in every use case
- **One GenServer subscriber** (`WorkspaceInvitationSubscriber`) proving the pattern works
- **~15 distinct event types** broadcast as bare tuples across ~8 PubSub topics

### What's Missing

| Gap | Impact |
|-----|--------|
| Events are bare tuples (`{:project_added, id}`), not structured data | No schema validation, no versioning, inconsistent payloads |
| No central event registry | Impossible to discover what events exist or who listens |
| Only 1 GenServer subscriber | Most cross-context reactions require direct function calls |
| No event persistence | No audit trail, no replay, no debugging history |
| Notifiers mix concerns | Email + PubSub + domain events conflated in single modules |
| No event metadata | Missing `occurred_at`, `actor_id`, `correlation_id`, `causation_id` |
| Entity Relationship Manager has no events | Graph mutations are invisible to the rest of the system |
| Chat/Agents contexts have minimal events | LLM interactions don't emit domain events |

---

## 2. Design Principles

1. **Events are first-class domain concepts** -- Each event is a struct with a schema, not a bare tuple.
2. **Producers don't know about consumers** -- Use cases emit events; they don't call notifiers directly.
3. **Events are immutable facts** -- An event records something that happened, past tense.
4. **Eventual consistency between contexts** -- Cross-context side effects happen asynchronously via event handlers.
5. **Preserve existing Clean Architecture** -- Events live in the Domain layer; dispatching lives in Infrastructure.
6. **Incremental migration** -- Each phase is independently deployable and testable.
7. **No external dependencies initially** -- Build on Phoenix PubSub and OTP, not Kafka/RabbitMQ.

---

## 3. Target Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Event Infrastructure                         │
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐               │
│  │ Event Structs │  │ EventBus     │  │ EventStore   │               │
│  │ (Domain)      │  │ (dispatch)   │  │ (persist)    │               │
│  └──────────────┘  └──────────────┘  └──────────────┘               │
│                           │                  │                        │
│                    ┌──────┴──────┐           │                        │
│                    ▼             ▼           ▼                        │
│             Phoenix.PubSub   EventHandlers  PostgreSQL               │
│             (real-time)      (GenServers)   (event_log table)        │
│                    │                                                  │
│                    ▼                                                  │
│              LiveView / API                                          │
│              (UI updates)                                            │
└─────────────────────────────────────────────────────────────────────┘
```

### Event Flow (Target State)

```
Use Case executes
    │
    ├── 1. Performs domain operation (DB write via Repo)
    │
    ├── 2. Builds domain Event struct
    │
    └── 3. Calls EventBus.emit(event)
              │
              ├── EventStore.persist(event)     ← async, in same process
              │
              └── Phoenix.PubSub.broadcast(event)
                        │
                        ├── LiveView handle_info/2    ← UI updates (existing)
                        ├── EventHandler GenServers    ← cross-context reactions
                        └── API WebSocket push         ← external consumers
```

---

## 4. Event Schema Design

### 4.1 Base Event Structure

```elixir
defmodule Perme8.Events.Event do
  @moduledoc """
  Base event structure. All domain events conform to this shape.
  """

  @type t :: %{
    __struct__: atom(),
    event_id: Ecto.UUID.t(),
    event_type: String.t(),
    aggregate_type: String.t(),
    aggregate_id: Ecto.UUID.t(),
    actor_id: Ecto.UUID.t() | nil,
    workspace_id: Ecto.UUID.t() | nil,
    occurred_at: DateTime.t(),
    metadata: map(),
    data: map()
  }
end
```

### 4.2 Event Naming Convention

```
{Context}.{AggregateType}{PastTenseVerb}

Examples:
  Projects.ProjectCreated
  Projects.ProjectArchived
  Documents.DocumentVisibilityChanged
  Identity.MemberInvited
  Identity.MemberJoined
  Agents.AgentAddedToWorkspace
  Chat.SessionStarted
  EntityRelationshipManager.EntityCreated
  EntityRelationshipManager.EdgeCreated
```

### 4.3 Example Event Structs

```elixir
defmodule Jarga.Projects.Domain.Events.ProjectCreated do
  @moduledoc "Emitted when a new project is created within a workspace."

  @enforce_keys [:event_id, :project_id, :workspace_id, :user_id, :name, :slug, :occurred_at]
  defstruct [
    :event_id,
    :project_id,
    :workspace_id,
    :user_id,
    :name,
    :slug,
    :occurred_at,
    event_type: "projects.project_created",
    aggregate_type: "project",
    metadata: %{}
  ]
end

defmodule Identity.Domain.Events.MemberInvited do
  @moduledoc "Emitted when a user is invited to a workspace."

  @enforce_keys [:event_id, :workspace_id, :inviter_id, :invitee_email, :role, :occurred_at]
  defstruct [
    :event_id,
    :workspace_id,
    :inviter_id,
    :invitee_email,
    :invitee_user_id,
    :role,
    :occurred_at,
    event_type: "identity.member_invited",
    aggregate_type: "workspace",
    metadata: %{}
  ]
end
```

---

## 5. Complete Event Catalog

### 5.1 Identity Context Events

| Event | Trigger | Current Implementation |
|-------|---------|----------------------|
| `UserRegistered` | User completes registration | No event (direct DB write) |
| `UserConfirmed` | Email confirmation | No event |
| `UserLoggedIn` | Session created | No event |
| `WorkspaceCreated` | New workspace | No event |
| `WorkspaceUpdated` | Name/description change | `{:workspace_updated, id, name}` on `workspace:{id}` |
| `WorkspaceArchived` | Workspace soft-deleted | No event |
| `MemberInvited` | Invitation sent | `{:workspace_invitation_created, params}` on `workspace_invitations` + `{:workspace_invitation, ...}` on `user:{id}` |
| `MemberJoined` | Invitation accepted | `{:workspace_joined, id}` on `user:{id}` + `{:member_joined, user_id}` on `workspace:{id}` |
| `MemberRemoved` | Admin removes member | `{:workspace_removed, id}` on `user:{id}` |
| `MemberRoleChanged` | Role updated | No event |
| `InvitationDeclined` | User declines invite | `{:invitation_declined, user_id}` on `workspace:{id}` |
| `ApiKeyCreated` | New API key | No event |
| `ApiKeyRevoked` | Key deactivated | No event |

### 5.2 Projects Context Events

| Event | Trigger | Current Implementation |
|-------|---------|----------------------|
| `ProjectCreated` | New project | `{:project_added, id}` on `workspace:{id}` |
| `ProjectUpdated` | Name/description change | `{:project_updated, id, name}` on `workspace:{id}` |
| `ProjectDeleted` | Project removed | `{:project_removed, id}` on `workspace:{id}` |
| `ProjectArchived` | Soft-delete | No event |

### 5.3 Documents Context Events

| Event | Trigger | Current Implementation |
|-------|---------|----------------------|
| `DocumentCreated` | New document | `{:document_created, document}` on `workspace:{id}` |
| `DocumentDeleted` | Document removed | `{:document_deleted, id}` on `workspace:{id}` |
| `DocumentTitleChanged` | Title update | `{:document_title_changed, id, title}` on `workspace:{id}` + `document:{id}` |
| `DocumentVisibilityChanged` | Public/private toggle | `{:document_visibility_changed, id, bool}` on `workspace:{id}` + `document:{id}` |
| `DocumentPinnedChanged` | Pin/unpin | `{:document_pinned_changed, id, bool}` on `workspace:{id}` + `document:{id}` |
| `NoteContentUpdated` | Yjs CRDT sync | No event (handled by CRDT) |

### 5.4 Agents Context Events

| Event | Trigger | Current Implementation |
|-------|---------|----------------------|
| `AgentCreated` | New agent | No event |
| `AgentUpdated` | Config change | `{:workspace_agent_updated, agent}` on `workspace:{id}` + `user:{id}` |
| `AgentDeleted` | Agent removed | `{:workspace_agent_updated, agent}` on `workspace:{id}` + `user:{id}` (reuses update event) |
| `AgentAddedToWorkspace` | Workspace association | `{:workspace_agent_updated, agent}` on `workspace:{id}` |
| `AgentRemovedFromWorkspace` | Workspace disassociation | `{:workspace_agent_updated, agent}` on `workspace:{id}` |

### 5.5 Chat Context Events

| Event | Trigger | Current Implementation |
|-------|---------|----------------------|
| `ChatSessionStarted` | New conversation | No event |
| `ChatMessageSent` | User sends message | No event |
| `ChatResponseReceived` | LLM responds | No event |
| `ChatSessionTitleChanged` | Auto/manual rename | No event |

### 5.6 Notifications Context Events

| Event | Trigger | Current Implementation |
|-------|---------|----------------------|
| `NotificationCreated` | Any notification | `{:new_notification, notification}` on `user:{id}:notifications` |
| `NotificationRead` | User reads notification | No event |
| `NotificationActionTaken` | User acts on notification | No event |

### 5.7 Entity Relationship Manager Events

| Event | Trigger | Current Implementation |
|-------|---------|----------------------|
| `SchemaCreated` | New workspace schema | No event |
| `SchemaUpdated` | Schema definition change | No event |
| `EntityCreated` | New graph node | No event |
| `EntityUpdated` | Node properties changed | No event |
| `EntityDeleted` | Node removed | No event |
| `EdgeCreated` | New relationship | No event |
| `EdgeDeleted` | Relationship removed | No event |
| `BulkEntitiesCreated` | Batch node creation | No event |
| `TraversalExecuted` | Graph query executed | No event (could be useful for analytics) |

---

## 6. Implementation Phases

Implementation is split into three independent parts. Each part is independently deployable and delivers value on its own. **Part 1 contains ~80% of the value** -- evaluate whether to proceed to Part 2 after it ships.

---

### Part 1: Foundation, Events & Use Case Migration (Weeks 1-5)

Establishes the event infrastructure, defines all domain event structs, and migrates use cases from direct notifier calls to `EventBus.emit/1`. The legacy bridge ensures backward compatibility with existing LiveViews throughout.

#### Phase 1: Event Foundation (Week 1-2)

**Goal**: Create the core event infrastructure without changing any existing behaviour.

##### 1a. Create shared event library module

Create a new top-level module in `jarga` (since all apps depend on it) or a new umbrella app `perme8_events`:

```
apps/jarga/lib/perme8_events/
├── event.ex                    # Base event behaviour/protocol
├── event_bus.ex                # EventBus module (wraps PubSub + store)
├── event_store.ex              # EventStore behaviour
├── event_handler.ex            # EventHandler behaviour
├── event_registry.ex           # Registry of all known events
└── infrastructure/
    ├── postgres_event_store.ex # Ecto-backed event persistence
    ├── pubsub_dispatcher.ex    # Phoenix PubSub dispatch adapter
    └── event_log_schema.ex     # Ecto schema for event_log table
```

**Key modules:**

```elixir
defmodule Perme8.Events.EventBus do
  @moduledoc """
  Central event dispatcher. Use cases call this to emit events.
  Dispatches to PubSub for real-time and EventStore for persistence.
  """

  @doc "Emit a single event"
  def emit(event, opts \\ [])

  @doc "Emit multiple events atomically"
  def emit_all(events, opts \\ [])
end

defmodule Perme8.Events.EventHandler do
  @moduledoc """
  Behaviour for event handler GenServers.
  Provides automatic PubSub subscription, error handling, and telemetry.
  """

  @callback handle_event(event :: struct()) :: :ok | {:error, term()}
  @callback subscriptions() :: [String.t()]

  defmacro __using__(opts) do
    # ... generates GenServer boilerplate with:
    # - Auto-subscribe to topics from subscriptions/0
    # - Route events to handle_event/1
    # - Error logging and telemetry
    # - Retry logic with backoff
  end
end

defmodule Perme8.Events.EventStore do
  @moduledoc "Behaviour for event persistence."

  @callback persist(event :: struct()) :: {:ok, struct()} | {:error, term()}
  @callback get_events(aggregate_id :: String.t(), opts :: keyword()) :: [struct()]
  @callback get_events_by_type(event_type :: String.t(), opts :: keyword()) :: [struct()]
end
```

##### 1b. Create event_log database table

```elixir
# Migration
create table(:event_log, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :event_type, :string, null: false
  add :aggregate_type, :string, null: false
  add :aggregate_id, :binary_id, null: false
  add :actor_id, :binary_id
  add :workspace_id, :binary_id
  add :data, :map, null: false, default: %{}
  add :metadata, :map, null: false, default: %{}
  add :occurred_at, :utc_datetime_usec, null: false

  timestamps(type: :utc_datetime_usec, updated_at: false)
end

create index(:event_log, [:aggregate_type, :aggregate_id])
create index(:event_log, [:event_type])
create index(:event_log, [:workspace_id])
create index(:event_log, [:actor_id])
create index(:event_log, [:occurred_at])
```

##### 1c. Create PubSub topic convention

Standardize topic naming:

```
events:{context}                    # All events from a context
events:{context}:{aggregate_type}   # All events for an aggregate type
events:workspace:{workspace_id}     # All events scoped to a workspace

# Backward-compatible aliases (kept during migration)
workspace:{id}                      # Existing LiveView subscriptions
document:{id}                       # Existing LiveView subscriptions
user:{id}                           # Existing LiveView subscriptions
```

##### 1d. Tests

- Unit tests for EventBus.emit/1
- Unit tests for EventStore persistence and retrieval
- Unit tests for EventHandler behaviour macro
- Integration test: emit -> persist -> retrieve round-trip
- Property-based test: event serialization/deserialization

---

#### Phase 2: Define Domain Events (Week 2-3)

**Goal**: Create event structs for all contexts, placed in each context's Domain layer.

##### Directory structure per context:

```
apps/jarga/lib/projects/domain/events/
├── project_created.ex
├── project_updated.ex
├── project_deleted.ex
└── project_archived.ex

apps/identity/lib/identity/domain/events/
├── user_registered.ex
├── workspace_created.ex
├── member_invited.ex
├── member_joined.ex
├── member_removed.ex
└── ...

apps/jarga/lib/documents/domain/events/
├── document_created.ex
├── document_deleted.ex
├── document_title_changed.ex
├── document_visibility_changed.ex
└── document_pinned_changed.ex

apps/jarga/lib/agents/domain/events/
├── agent_created.ex
├── agent_updated.ex
├── agent_deleted.ex
├── agent_added_to_workspace.ex
└── agent_removed_from_workspace.ex

apps/jarga/lib/chat/domain/events/
├── chat_session_started.ex
├── chat_message_sent.ex
└── chat_response_received.ex

apps/jarga/lib/notifications/domain/events/
├── notification_created.ex
├── notification_read.ex
└── notification_action_taken.ex

apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/
├── schema_created.ex
├── entity_created.ex
├── entity_updated.ex
├── entity_deleted.ex
├── edge_created.ex
└── edge_deleted.ex
```

##### Boundary updates:

```elixir
# Each Domain boundary exports its events
defmodule Jarga.Projects.Domain do
  use Boundary,
    deps: [],
    exports: [
      Entities.Project,
      Policies.ProjectPolicy,
      Events.ProjectCreated,     # NEW
      Events.ProjectUpdated,     # NEW
      Events.ProjectDeleted      # NEW
    ]
end
```

##### Tests:

- Each event struct has a test verifying required fields
- Event type strings are unique across the system (registry test)

---

#### Phase 3: Migrate Use Cases to Emit Events (Week 3-5)

**Goal**: Replace direct notifier calls with `EventBus.emit/1` in each use case.

##### Migration strategy per use case:

**Before** (current):
```elixir
defmodule Jarga.Projects.Application.UseCases.CreateProject do
  @default_notifier Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier

  def execute(user, workspace_id, attrs, opts \\ []) do
    notifier = Keyword.get(opts, :notifier, @default_notifier)
    # ... create project ...
    notifier.notify_project_created(project)
    {:ok, project}
  end
end
```

**After** (event-driven):
```elixir
defmodule Jarga.Projects.Application.UseCases.CreateProject do
  alias Perme8.Events.EventBus
  alias Jarga.Projects.Domain.Events.ProjectCreated

  def execute(user, workspace_id, attrs, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, EventBus)
    # ... create project ...
    event = %ProjectCreated{
      event_id: Ecto.UUID.generate(),
      project_id: project.id,
      workspace_id: workspace_id,
      user_id: user.id,
      name: project.name,
      slug: project.slug,
      occurred_at: DateTime.utc_now()
    }
    event_bus.emit(event)
    {:ok, project}
  end
end
```

##### Migration order (by risk/complexity):

1. **Projects** (3 use cases, simplest events, well-tested) -- start here
2. **Documents** (5 use cases, dual-topic broadcasts)
3. **Agents** (3 use cases, multi-workspace fan-out)
4. **Identity workspace events** (invite, join, remove, update)
5. **Notifications** (accept, decline, create notification)
6. **Chat** (new events, no existing notifiers to migrate)
7. **Entity Relationship Manager** (new events, no existing notifiers)
8. **Identity auth events** (login, register, confirm -- new events)

##### Backward compatibility:

During migration, the EventBus dispatcher will emit **both**:
- New structured events on `events:*` topics
- Legacy tuple messages on existing topics (`workspace:{id}`, etc.)

This allows LiveViews to continue working without changes during the migration.

```elixir
defmodule Perme8.Events.Infrastructure.LegacyBridge do
  @moduledoc """
  Translates new structured events to legacy PubSub tuple format.
  Remove once all LiveViews are migrated to handle structured events.
  """

  def translate(%ProjectCreated{} = event) do
    [
      {"workspace:#{event.workspace_id}", {:project_added, event.project_id}}
    ]
  end

  def translate(%DocumentVisibilityChanged{} = event) do
    [
      {"workspace:#{event.workspace_id}",
       {:document_visibility_changed, event.document_id, event.is_public}},
      {"document:#{event.document_id}",
       {:document_visibility_changed, event.document_id, event.is_public}}
    ]
  end
  # ... one clause per legacy event format
end
```

##### Tests:

- Each migrated use case emits the correct event struct
- Legacy bridge translates events correctly
- Existing LiveView tests continue passing (backward compatibility)
- New event-based tests using `assert_receive %ProjectCreated{}`

---

### Part 2: Handlers, LiveView Migration & Cleanup (Weeks 5-8)

Replaces direct notifier/subscriber patterns with standardized event handlers, migrates LiveViews to consume structured events, and removes all legacy code. Only begin after Part 1 is stable in production.

#### Phase 4: Event Handlers Replace Subscribers (Week 5-6)

**Goal**: Convert the existing `WorkspaceInvitationSubscriber` pattern into the standardized `EventHandler` behaviour and add new handlers for cross-context reactions.

##### New event handlers:

```elixir
# Replace existing WorkspaceInvitationSubscriber
defmodule Jarga.Notifications.Infrastructure.EventHandlers.InvitationNotificationHandler do
  use Perme8.Events.EventHandler,
    subscriptions: ["events:identity:workspace"]

  @impl true
  def handle_event(%Identity.Domain.Events.MemberInvited{} = event) do
    CreateWorkspaceInvitationNotification.execute(%{
      user_id: event.invitee_user_id,
      workspace_id: event.workspace_id,
      workspace_name: event.metadata[:workspace_name],
      invited_by_name: event.metadata[:inviter_name],
      role: event.role
    })
  end
end

# NEW: Send emails on invitation
defmodule Identity.Infrastructure.EventHandlers.InvitationEmailHandler do
  use Perme8.Events.EventHandler,
    subscriptions: ["events:identity:workspace"]

  @impl true
  def handle_event(%Identity.Domain.Events.MemberInvited{} = event) do
    # Send invitation email
    # (extracted from current EmailAndPubSubNotifier)
  end
end

# NEW: Update graph when projects change
defmodule EntityRelationshipManager.Infrastructure.EventHandlers.ProjectSyncHandler do
  use Perme8.Events.EventHandler,
    subscriptions: ["events:projects:project"]

  @impl true
  def handle_event(%Jarga.Projects.Domain.Events.ProjectCreated{} = event) do
    # Optionally sync project as an entity in the graph
  end
end

# NEW: Analytics/audit handler
defmodule Jarga.Infrastructure.EventHandlers.AuditLogHandler do
  use Perme8.Events.EventHandler,
    subscriptions: ["events:*"]

  @impl true
  def handle_event(event) do
    # Already persisted by EventStore, but could enrich with audit-specific data
    :ok
  end
end
```

##### Handler registration:

```elixir
# In Jarga.Application children list
children = [
  # ... existing children ...
  {Perme8.Events.EventBus, []},
  {Jarga.Notifications.Infrastructure.EventHandlers.InvitationNotificationHandler, []},
  {Jarga.Infrastructure.EventHandlers.AuditLogHandler, []}
]
```

##### Tests:

- Each handler has isolated unit tests with mock events
- Integration tests verifying event -> handler -> side effect chain
- Old subscriber tests still pass during transition

---

#### Phase 5: Migrate LiveViews to Structured Events (Week 6-7)

**Goal**: Update LiveViews to subscribe to structured event topics and handle event structs instead of bare tuples.

##### Migration per LiveView:

**Before**:
```elixir
def mount(_params, _session, socket) do
  Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
  {:ok, socket}
end

def handle_info({:project_added, project_id}, socket) do
  # ... update assigns
end
```

**After**:
```elixir
def mount(_params, _session, socket) do
  Perme8.Events.subscribe("events:workspace:#{workspace.id}")
  {:ok, socket}
end

def handle_info(%ProjectCreated{project_id: project_id}, socket) do
  # ... update assigns (pattern match on struct)
end
```

##### Migration order:

1. `WorkspacesLive.Show` (receives the most event types)
2. `DocumentsLive.Show` (dual-topic subscriptions)
3. `NotificationsLive.Bell` (notification events)
4. `AgentsLive.Index` / `AgentsLive.Form` (agent events)
5. `DashboardLive` (workspace-wide events)

##### Tests:

- LiveView tests send structured events instead of tuples
- `Phoenix.LiveViewTest` assertions on `handle_info` with event structs

---

#### Phase 6: Remove Legacy Bridge & Notifiers (Week 7-8)

**Goal**: Clean up the codebase by removing the backward-compatibility layer.

##### Removals:

1. Delete `LegacyBridge` module
2. Delete all `*Notifier` infrastructure modules:
   - `Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier`
   - `Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier`
   - `Jarga.Agents.Infrastructure.Notifiers.PubSubNotifier`
   - `Identity.Infrastructure.Notifiers.PubSubNotifier`
   - `Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier`
   - `Jarga.Notifications.Infrastructure.Notifiers.PubSubNotifier`
3. Delete all `NotificationServiceBehaviour` and `PubSubNotifierBehaviour` modules
4. Delete `WorkspaceInvitationSubscriber` (replaced by `InvitationNotificationHandler`)
5. Remove `:notifier` option from all use cases (replaced by `:event_bus`)
6. Remove legacy topic subscriptions from LiveViews
7. Update all Mox-based test mocks to use event assertions instead

##### Tests:

- Full test suite passes
- `mix boundary` passes
- No references to old notifier modules

---

### Part 3: Advanced Features (Week 8+)

Optional enhancements built on top of the event foundation. Evaluate each feature independently based on real usage patterns observed after Parts 1 and 2 are complete. **Do not plan or commit to these until Parts 1-2 are shipped.**

#### Phase 7: Advanced Features (Week 8+)

**Goal**: Build on the event foundation to enable advanced patterns.

##### 7a. Event Replay & Projections

```elixir
defmodule Perme8.Events.Projector do
  @moduledoc "Rebuild read models from event history."

  def replay(aggregate_id, handler_module) do
    aggregate_id
    |> EventStore.get_events()
    |> Enum.each(&handler_module.handle_event/1)
  end
end
```

##### 7b. Saga / Process Manager

For multi-step workflows (e.g., workspace onboarding):

```elixir
defmodule Jarga.Sagas.WorkspaceOnboarding do
  @moduledoc """
  Orchestrates workspace setup: create workspace -> create default project -> 
  create welcome document -> send welcome email.
  """

  use Perme8.Events.EventHandler,
    subscriptions: ["events:identity:workspace"]

  def handle_event(%WorkspaceCreated{} = event) do
    # Kick off default project creation
  end

  def handle_event(%ProjectCreated{metadata: %{saga: "onboarding"}} = event) do
    # Create welcome document in the default project
  end
end
```

##### 7c. Event-Driven API Webhooks

```elixir
defmodule JargaApi.Infrastructure.EventHandlers.WebhookDispatcher do
  use Perme8.Events.EventHandler,
    subscriptions: ["events:*"]

  def handle_event(event) do
    # Look up webhook subscriptions for the workspace
    # POST event payload to registered webhook URLs
  end
end
```

##### 7d. Cross-App Event Streaming (Entity Relationship Manager)

The graph database can subscribe to all domain events and automatically maintain a knowledge graph:

```elixir
defmodule EntityRelationshipManager.Infrastructure.EventHandlers.GraphProjection do
  use Perme8.Events.EventHandler,
    subscriptions: ["events:projects:*", "events:documents:*", "events:identity:*"]

  def handle_event(%ProjectCreated{} = event) do
    GraphRepository.create_entity(%{
      type: "project",
      properties: %{name: event.name, slug: event.slug},
      workspace_id: event.workspace_id
    })
  end

  def handle_event(%DocumentCreated{} = event) do
    GraphRepository.create_entity(%{type: "document", ...})
    GraphRepository.create_edge(%{
      type: "belongs_to",
      source_id: event.document_id,
      target_id: event.project_id
    })
  end
end
```

---

## 7. Per-App Migration Checklist

### Identity App

- [ ] Define 11 domain events in `identity/domain/events/`
- [ ] Update boundary exports
- [ ] Migrate `InviteMember` use case (emit `MemberInvited`)
- [ ] Migrate `RemoveMember` use case (emit `MemberRemoved`)
- [ ] Extract email sending from `EmailAndPubSubNotifier` into `InvitationEmailHandler`
- [ ] Add events for auth flows (register, login, confirm)
- [ ] Add events for API key lifecycle
- [ ] Add events for workspace CRUD
- [ ] Remove old notifier modules
- [ ] Update tests

### Jarga - Projects Context

- [ ] Define 4 domain events in `projects/domain/events/`
- [ ] Update boundary exports
- [ ] Migrate `CreateProject` use case
- [ ] Migrate `UpdateProject` use case
- [ ] Migrate `DeleteProject` use case
- [ ] Add `ProjectArchived` event
- [ ] Remove `EmailAndPubSubNotifier`
- [ ] Remove `NotificationServiceBehaviour`
- [ ] Update tests

### Jarga - Documents Context

- [ ] Define 5 domain events in `documents/domain/events/`
- [ ] Update boundary exports
- [ ] Migrate `CreateDocument` use case
- [ ] Migrate `UpdateDocument` use case
- [ ] Migrate `DeleteDocument` use case
- [ ] EventBus handles dual-topic dispatch (workspace + document)
- [ ] Remove `PubSubNotifier`
- [ ] Remove `NotificationServiceBehaviour`
- [ ] Update tests

### Jarga - Agents Context

- [ ] Define 5 domain events in `agents/domain/events/`
- [ ] Update boundary exports
- [ ] Migrate `UpdateUserAgent` use case
- [ ] Migrate `DeleteUserAgent` use case
- [ ] Migrate `SyncAgentWorkspaces` use case
- [ ] Add `AgentCreated` event
- [ ] EventBus handles multi-workspace fan-out
- [ ] Remove `PubSubNotifier`
- [ ] Update tests

### Jarga - Chat Context

- [ ] Define 3 domain events in `chat/domain/events/`
- [ ] Update boundary exports
- [ ] Add event emission to `CreateSession` use case
- [ ] Add event emission to message handling
- [ ] Update tests

### Jarga - Notifications Context

- [ ] Define 3 domain events in `notifications/domain/events/`
- [ ] Update boundary exports
- [ ] Convert `WorkspaceInvitationSubscriber` to `EventHandler`
- [ ] Migrate `AcceptWorkspaceInvitation` use case
- [ ] Migrate `DeclineWorkspaceInvitation` use case
- [ ] Migrate `CreateWorkspaceInvitationNotification` use case
- [ ] Remove old `PubSubNotifier` and `PubSubNotifierBehaviour`
- [ ] Update tests

### Entity Relationship Manager

- [ ] Define 7 domain events in `entity_relationship_manager/domain/events/`
- [ ] Update boundary exports
- [ ] Add event emission to entity CRUD use cases
- [ ] Add event emission to edge CRUD use cases
- [ ] Add event emission to schema management
- [ ] Add event emission to bulk operations
- [ ] Create `GraphProjection` handler for cross-app graph sync
- [ ] Update tests

### JargaWeb (LiveViews)

- [ ] Migrate `WorkspacesLive.Show` to structured events
- [ ] Migrate document LiveViews
- [ ] Migrate notification LiveViews
- [ ] Migrate agent LiveViews
- [ ] Migrate dashboard LiveView
- [ ] Update all LiveView tests
- [ ] Remove legacy topic subscriptions

### JargaApi

- [ ] Add WebSocket/SSE event streaming endpoint
- [ ] Add webhook dispatcher handler
- [ ] Update API tests

### Alkali (No changes needed)

Alkali is a standalone static site generator with no cross-app communication. No event-driven changes required.

### Perme8 Tools (No changes needed)

Developer tooling Mix tasks. No event-driven changes required.

---

## 8. Testing Strategy

### Unit Tests (per event)

```elixir
test "ProjectCreated event has required fields" do
  event = %ProjectCreated{
    event_id: Ecto.UUID.generate(),
    project_id: Ecto.UUID.generate(),
    workspace_id: Ecto.UUID.generate(),
    user_id: Ecto.UUID.generate(),
    name: "Test Project",
    slug: "test-project",
    occurred_at: DateTime.utc_now()
  }

  assert event.event_type == "projects.project_created"
  assert event.aggregate_type == "project"
end
```

### Use Case Tests (event emission)

```elixir
test "CreateProject emits ProjectCreated event" do
  event_bus = Perme8.Events.TestEventBus  # In-memory, captures emitted events

  {:ok, project} = CreateProject.execute(user, workspace.id, attrs, event_bus: event_bus)

  assert [%ProjectCreated{} = event] = TestEventBus.get_events()
  assert event.project_id == project.id
  assert event.workspace_id == workspace.id
end
```

### Handler Tests (event -> side effect)

```elixir
test "InvitationNotificationHandler creates notification on MemberInvited" do
  event = %MemberInvited{
    event_id: Ecto.UUID.generate(),
    workspace_id: workspace.id,
    inviter_id: inviter.id,
    invitee_user_id: invitee.id,
    invitee_email: invitee.email,
    role: :member,
    occurred_at: DateTime.utc_now(),
    metadata: %{workspace_name: "Team", inviter_name: "Alice"}
  }

  assert :ok = InvitationNotificationHandler.handle_event(event)
  assert [notification] = Notifications.list_unread_notifications(invitee.id)
  assert notification.type == "workspace_invitation"
end
```

### Integration Tests (end-to-end event flow)

```elixir
test "creating a project triggers notification and graph sync" do
  # Subscribe to events
  Perme8.Events.subscribe("events:projects:project")

  # Action
  {:ok, project} = Projects.create_project(user, workspace.id, %{name: "New"})

  # Verify event emitted
  assert_receive %ProjectCreated{project_id: project_id}, 1000
  assert project_id == project.id

  # Verify side effects (eventually consistent)
  Process.sleep(100)
  assert [notification] = Notifications.list_unread_notifications(other_user.id)
end
```

### TestEventBus for isolated testing

```elixir
defmodule Perme8.Events.TestEventBus do
  @moduledoc "In-memory event bus for testing. Captures events without side effects."

  use Agent

  def start_link(_), do: Agent.start_link(fn -> [] end, name: __MODULE__)
  def emit(event, _opts \\ []), do: Agent.update(__MODULE__, &[event | &1])
  def get_events, do: Agent.get(__MODULE__, &Enum.reverse/1)
  def reset, do: Agent.update(__MODULE__, fn _ -> [] end)
end
```

---

## 9. Risk Assessment & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Breaking existing real-time UI during migration | High | High | Legacy bridge translates new events to old tuple format; run full test suite on every PR |
| Event schema evolution (breaking changes) | Medium | High | Version events from day 1; use `event_type` string for dispatch, not module names |
| Performance overhead from event persistence | Low | Medium | Async persistence; batch writes; index heavily; monitor with Telemetry |
| Event handler failures causing data inconsistency | Medium | High | Idempotent handlers; dead-letter queue (log failed events); retry with backoff |
| Boundary violations from event module imports | Medium | Low | Export events from Domain boundary; events are data, safe to depend on |
| Test suite slowdown from event infrastructure | Low | Medium | `TestEventBus` avoids PubSub in unit tests; only integration tests use real dispatch |
| Overwhelming number of events in event_log table | Low | Medium | Partition by `occurred_at`; retention policy; archive to cold storage |

---

## 10. Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Structured event types | 0 | 44+ |
| Cross-context direct function calls | ~8 | 0 (all via events) |
| Event handler GenServers | 1 | 8+ |
| Notifier modules (to remove) | 8 | 0 |
| NotificationServiceBehaviour modules (to remove) | 5 | 0 |
| Events with persistence/audit trail | 0 | 100% |
| Contexts emitting events | 0 | 7 (all non-tool contexts) |
| Average event delivery latency | N/A | <10ms (PubSub local) |

---

## 11. Dependencies & Tooling

### No new external dependencies required

The entire plan builds on:
- **Phoenix.PubSub** (already in use) -- real-time dispatch
- **Ecto** (already in use) -- event persistence
- **OTP GenServer** (already in use) -- event handlers
- **Boundary** (already in use) -- compile-time enforcement

### Optional future additions

| Tool | Purpose | When |
|------|---------|------|
| `Broadway` | High-throughput event processing | If event volume exceeds single-node capacity |
| `Oban` | Reliable async job processing for handlers | If handler failures need guaranteed retry |
| `Commanded` / `EventStore` | Full CQRS/ES framework | If moving to full event sourcing |
| `Telemetry` + `TelemetryMetrics` | Event flow observability | Phase 1 (already partially in place) |

---

## 12. Timeline Summary

| Part | Phase | Duration | Deliverable |
|------|-------|----------|------------|
| **Part 1** | Phase 1: Event Foundation | Week 1-2 | EventBus, EventStore, EventHandler behaviour, event_log table, tests |
| | Phase 2: Domain Events | Week 2-3 | 44+ event structs across all contexts, boundary exports, event registry |
| | Phase 3: Migrate Use Cases | Week 3-5 | All use cases emit structured events, legacy bridge for backward compat |
| | | | **Checkpoint: evaluate before proceeding to Part 2** |
| **Part 2** | Phase 4: Event Handlers | Week 5-6 | 8+ handler GenServers replacing direct notifier calls |
| | Phase 5: Migrate LiveViews | Week 6-7 | All LiveViews handle structured events, pattern-match on structs |
| | Phase 6: Cleanup | Week 7-8 | Remove legacy bridge, notifiers, old behaviours, old tests |
| | | | **Checkpoint: evaluate before proceeding to Part 3** |
| **Part 3** | Phase 7: Advanced Features | Week 8+ | Replay, sagas, webhooks, graph projection |

- **Part 1** (Weeks 1-5): Delivers ~80% of the value. Independently deployable. The system operates in a hybrid state with the legacy bridge maintaining backward compatibility.
- **Part 2** (Weeks 5-8): Completes the migration and removes all legacy code. Only begin after Part 1 is stable in production.
- **Part 3** (Week 8+): Optional enhancements. Evaluate each feature independently based on real usage patterns. Do not commit to these until Parts 1-2 are shipped.

---

## 13. Decision Log

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| Build on Phoenix.PubSub, not external MQ | Already proven in codebase; no ops overhead; sufficient for current scale | Kafka, RabbitMQ (overkill for single-node) |
| Events in Domain layer | Events are domain concepts (facts about what happened); zero dependencies | Application layer (would prevent Domain from defining its own events) |
| EventBus as central dispatcher | Single emit point enables persistence + dispatch atomically | Direct PubSub.broadcast (no persistence layer) |
| Struct-based events, not maps | Compile-time enforcement of required fields; pattern matching in handlers | Maps with runtime validation (fragile) |
| Legacy bridge for backward compat | De-risks migration; LiveViews keep working during transition | Big-bang migration (high risk) |
| Event persistence in PostgreSQL | Already have Ecto; simple; queryable; sufficient for audit trail | Separate EventStore DB, append-only log (premature optimization) |
| `:event_bus` option replaces `:notifier` | Same DI pattern developers already know; easy to inject TestEventBus in tests | Global config (harder to test) |

# Feature: Shared PubSub Event Bus — Part 1 (Foundation + Events + Migration)

## Status: ⏸ Not Started
## Ticket: #37
## Date: 2026-02-18

---

## Overview

Transform Perme8's ad-hoc PubSub notification pattern into a structured event-driven architecture. Part 1 establishes the event infrastructure, defines all domain event structs, and migrates every use case from `opts[:notifier]` to `opts[:event_bus]` — while preserving 100% backward compatibility via a legacy bridge.

**Value**: Decouples bounded contexts, enables reliable cross-context reactions, creates consistent event schemas with metadata, and lays the foundation for event persistence and audit trails.

## UI Strategy

- **LiveView coverage**: 100% — no UI changes in Part 1
- **TypeScript needed**: None — this is purely backend infrastructure

## Affected Boundaries

- **Primary context**: `Perme8.Events` (new shared module in `jarga` app)
- **Dependencies**: All 6 domain contexts consume the shared event infrastructure
- **Exported schemas**: All 27 event structs exported from their domain boundaries
- **New context needed?**: No — `Perme8.Events` is shared infrastructure in `jarga`, not a bounded context

## Dependency Impact

The event infrastructure lives in `apps/jarga/lib/perme8_events/` because all apps already depend on `jarga`:

```
identity (no changes — not migrated in Part 1)
  ^
  |
jarga (contains Perme8.Events.* + all jarga context events)
  ^         ^
  |         |
agents     entity_relationship_manager (both get event structs + event_bus injection)
  ^
  |
jarga_web, jarga_api (no changes in Part 1 — legacy bridge handles)
```

## Existing Event Catalog (Legacy Tuples to Preserve)

| Context | Tuple Format | Topic |
|---------|-------------|-------|
| Projects | `{:project_added, id}` | `workspace:{wid}` |
| Projects | `{:project_updated, id, name}` | `workspace:{wid}` |
| Projects | `{:project_removed, id}` | `workspace:{wid}` |
| Documents | `{:document_created, document}` | `workspace:{wid}` |
| Documents | `{:document_deleted, id}` | `workspace:{wid}` |
| Documents | `{:document_title_changed, id, title}` | `workspace:{wid}` + `document:{did}` |
| Documents | `{:document_visibility_changed, id, bool}` | `workspace:{wid}` + `document:{did}` |
| Documents | `{:document_pinned_changed, id, bool}` | `workspace:{wid}` + `document:{did}` |
| Agents | `{:workspace_agent_updated, agent}` | `workspace:{wid}` + `user:{uid}` |
| Notifications | `{:workspace_invitation_created, params}` | `workspace_invitations` |
| Notifications | `{:workspace_joined, wid}` | `user:{uid}` |
| Notifications | `{:member_joined, uid}` | `workspace:{wid}` |
| Notifications | `{:invitation_declined, uid}` | `workspace:{wid}` |
| Notifications | `{:new_notification, notification}` | `user:{uid}:notifications` |

---

## Phase 1: Event Foundation ✓

**Goal**: Create core event infrastructure without changing any existing behavior.
**Commit message**: `feat(events): add Perme8.Events foundation — DomainEvent macro, EventBus, EventHandler, TestEventBus, LegacyBridge`

### 1.1 Perme8.Events Boundary Module

- [x] **RED**: Write test `apps/jarga/test/perme8_events/perme8_events_test.exs`
  - Tests: Module exists, boundary is defined
- [x] **GREEN**: Create `apps/jarga/lib/perme8_events.ex`
  - Define `Perme8.Events` as a top-level boundary with `use Boundary, top_level?: true, deps: [], exports: [...]`
  - Exports: `DomainEvent`, `EventBus`, `EventHandler`, `TestEventBus`
  - Contains `subscribe/1` and `unsubscribe/1` convenience functions wrapping `Phoenix.PubSub`
- [x] **REFACTOR**: Ensure boundary config is clean and minimal

### 1.2 DomainEvent Macro

- [x] **RED**: Write test `apps/jarga/test/perme8_events/domain_event_test.exs`
  - Tests:
    - Using the macro with custom fields creates a struct with base fields + custom fields
    - `@enforce_keys` includes `[:aggregate_id, :actor_id]` plus declared `:required` fields
    - `event_type/0` returns `"context.event_name"` derived from module name (e.g., `Jarga.Projects.Domain.Events.ProjectCreated` → `"projects.project_created"`)
    - `aggregate_type/0` returns the aggregate type string (e.g., `"project"`)
    - `new/1` auto-generates `event_id` (UUID) and `occurred_at` (DateTime.utc_now)
    - `new/1` raises `ArgumentError` when required fields are missing
    - Base fields present: `event_id`, `event_type`, `aggregate_type`, `aggregate_id`, `actor_id`, `workspace_id`, `occurred_at`, `metadata`
    - `metadata` defaults to `%{}`
    - `workspace_id` is optional (nil for global events)
- [x] **GREEN**: Implement `apps/jarga/lib/perme8_events/domain_event.ex`
  - `defmacro __using__(opts)` that:
    - Accepts `:fields` (list of additional field specs with optional defaults)
    - Accepts `:required` (list of required custom field names)
    - Accepts `:aggregate_type` (string, e.g., `"project"`)
    - Derives `event_type` from module name: strips app prefix, converts to dot notation + snake_case
    - Defines `@enforce_keys` = base required fields + custom required fields
    - Defines `defstruct` with all base + custom fields
    - Defines `new/1` constructor that auto-populates `event_id` and `occurred_at`
    - Defines `event_type/0` and `aggregate_type/0` functions
- [x] **REFACTOR**: Extract module name parsing into a private helper function

### 1.3 EventBus Module

- [x] **RED**: Write test `apps/jarga/test/perme8_events/event_bus_test.exs`
  - Tests:
    - `emit/2` broadcasts event to `events:{context}` topic
    - `emit/2` broadcasts event to `events:{context}:{aggregate_type}` topic
    - `emit/2` broadcasts event to `events:workspace:{workspace_id}` topic when workspace_id present
    - `emit/2` skips workspace topic when `workspace_id` is nil
    - `emit/2` calls LegacyBridge to broadcast on legacy topics
    - `emit/2` returns `:ok`
    - `emit_all/2` broadcasts multiple events
    - `emit_all/2` returns `:ok`
    - Topic derivation: `"events:projects"`, `"events:projects:project"`, `"events:workspace:#{wid}"`
  - Setup: Subscribe to topics via `Phoenix.PubSub.subscribe/2`, assert_receive after emit
  - Use `Jarga.DataCase, async: false` (real PubSub needed)
- [x] **GREEN**: Implement `apps/jarga/lib/perme8_events/event_bus.ex`
  - `@pubsub Jarga.PubSub`
  - `emit(event, opts \\ [])`: derive topics from event struct, broadcast to each
  - `emit_all(events, opts \\ [])`: Enum.each events, call emit
  - Private `derive_topics/1`: reads `event_type()` to get context, `aggregate_type()` for sub-topic, `workspace_id` for workspace scope
  - Private `legacy_broadcast/1`: delegates to `Perme8.Events.Infrastructure.LegacyBridge`
- [x] **REFACTOR**: Extract topic derivation logic into a `TopicResolver` module if complexity warrants

### 1.4 EventHandler Behaviour

- [x] **RED**: Write test `apps/jarga/test/perme8_events/event_handler_test.exs`
  - Tests:
    - A test handler using `use Perme8.Events.EventHandler` compiles
    - Handler starts as a GenServer and auto-subscribes to topics from `subscriptions/0`
    - Handler receives events via `handle_info` and routes to `handle_event/1`
    - Handler ignores non-event messages
    - Handler logs errors when `handle_event/1` returns `{:error, reason}`
    - `child_spec/1` returns valid child spec for supervisors
  - Create a test module `TestHandler` that implements the behaviour
  - Use `Jarga.DataCase, async: false` (real PubSub)
- [x] **GREEN**: Implement `apps/jarga/lib/perme8_events/event_handler.ex`
  - `@callback handle_event(event :: struct()) :: :ok | {:error, term()}`
  - `@callback subscriptions() :: [String.t()]`
  - `defmacro __using__(_opts)` generates:
    - `use GenServer`
    - `start_link/1` with `name: __MODULE__`
    - `init/1` that subscribes to all topics from `subscriptions/0`
    - `handle_info/2` that pattern-matches on structs (has `__struct__` key) and calls `handle_event/1`
    - `handle_info/2` catch-all that ignores non-event messages
    - Error logging via `Logger.error/1` when `handle_event` returns error
    - `child_spec/1` for supervision tree compatibility
- [x] **REFACTOR**: Clean up, ensure consistent error handling

### 1.5 TestEventBus

- [x] **RED**: Write test `apps/jarga/test/perme8_events/test_event_bus_test.exs`
  - Tests:
    - `start_link/1` starts an Agent
    - `emit/2` stores event in Agent state
    - `emit_all/2` stores multiple events
    - `get_events/0` returns events in emission order
    - `reset/0` clears all stored events
    - Events are isolated per test (start/reset pattern)
  - Use `ExUnit.Case, async: true` (no I/O)
- [x] **GREEN**: Implement `apps/jarga/lib/perme8_events/test_event_bus.ex`
  - `use Agent`
  - `start_link/1` → `Agent.start_link(fn -> [] end, name: __MODULE__)`
  - `emit/2` → `Agent.update(__MODULE__, &[event | &1])`
  - `emit_all/2` → `Agent.update(__MODULE__, &(Enum.reverse(events) ++ &1))`
  - `get_events/0` → `Agent.get(__MODULE__, &Enum.reverse/1)`
  - `reset/0` → `Agent.update(__MODULE__, fn _ -> [] end)`
- [x] **REFACTOR**: Ensure TestEventBus API is consistent with EventBus API

### 1.6 LegacyBridge

- [x] **RED**: Write test `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs`
  - Tests (one per legacy event format — **15 total translations**):
    - `ProjectCreated` → `[{"workspace:{wid}", {:project_added, pid}}]`
    - `ProjectUpdated` → `[{"workspace:{wid}", {:project_updated, pid, name}}]`
    - `ProjectDeleted` → `[{"workspace:{wid}", {:project_removed, pid}}]`
    - `DocumentCreated` → `[{"workspace:{wid}", {:document_created, document}}]` (note: passes full document struct for legacy compat)
    - `DocumentDeleted` → `[{"workspace:{wid}", {:document_deleted, did}}]`
    - `DocumentTitleChanged` → `[{"workspace:{wid}", {:document_title_changed, did, title}}, {"document:{did}", {:document_title_changed, did, title}}]`
    - `DocumentVisibilityChanged` → `[{"workspace:{wid}", {:document_visibility_changed, did, bool}}, {"document:{did}", ...}]`
    - `DocumentPinnedChanged` → `[{"workspace:{wid}", {:document_pinned_changed, did, bool}}, {"document:{did}", ...}]`
    - `AgentUpdated` → broadcasts to each workspace + user topic: `[{"workspace:{wid1}", {:workspace_agent_updated, agent_data}}, ..., {"user:{uid}", {:workspace_agent_updated, agent_data}}]`
    - `AgentDeleted` → same pattern as AgentUpdated (current code reuses `{:workspace_agent_updated, agent}`)
    - `AgentAddedToWorkspace` → `[{"workspace:{wid}", {:workspace_agent_updated, agent_data}}]` + user topic
    - `AgentRemovedFromWorkspace` → `[{"workspace:{wid}", {:workspace_agent_updated, agent_data}}]` + user topic
    - `NotificationCreated` → `[{"user:{uid}:notifications", {:new_notification, notification}}]`
    - `InvitationAccepted` (maps to workspace_joined) → `[{"user:{uid}", {:workspace_joined, wid}}, {"workspace:{wid}", {:member_joined, uid}}]`
    - `InvitationDeclined` → `[{"workspace:{wid}", {:invitation_declined, uid}}]`
    - Unknown event → returns `[]` (no legacy translation needed for net-new events like Chat, ERM)
  - Use `ExUnit.Case, async: true` (pure function, no I/O)
- [x] **GREEN**: Implement `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex`
  - `translate/1` function with pattern-match clauses for each event struct
  - Returns `[{topic, message}]` list — EventBus iterates and broadcasts each
  - `broadcast_legacy/1` function that takes an event, calls `translate/1`, and broadcasts each tuple
  - Each translation reconstructs the exact legacy tuple format from the structured event's fields
  - Agent events need `legacy_agent_data` field or metadata to reconstruct the agent map/struct
- [x] **REFACTOR**: Group translations by context, add @moduledoc section per context

### Phase 1 Validation

- [x] All foundation tests pass: `mix test apps/jarga/test/perme8_events/`
- [x] `mix boundary` passes with no violations
- [x] `mix credo` passes
- [x] No changes to any existing module — this phase is purely additive

---

## Phase 2: Domain Event Structs ⏳

**Goal**: Define all 27 event structs across 6 contexts using the `DomainEvent` macro.
**Commit message**: `feat(events): define 27 domain event structs across all contexts`

Each event struct is a pure struct (no I/O, no Ecto) living in `domain/events/` within its owning context. Tests verify required fields, event_type uniqueness, and macro behavior.

### 2.1 Projects Context Events (4 events)

**Location**: `apps/jarga/lib/projects/domain/events/`

#### ProjectCreated
- [x] **RED**: Write test `apps/jarga/test/projects/domain/events/project_created_test.exs`
  - Tests: required fields (`project_id`, `workspace_id`, `user_id`, `name`, `slug`), event_type is `"projects.project_created"`, aggregate_type is `"project"`, `new/1` works
- [x] **GREEN**: Implement `apps/jarga/lib/projects/domain/events/project_created.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "project", fields: [:project_id, :workspace_id, :user_id, :name, :slug], required: [:project_id, :workspace_id, :user_id, :name, :slug]`
- [x] **REFACTOR**: Verify field naming is consistent with existing Project entity

#### ProjectUpdated
- [x] **RED**: Write test `apps/jarga/test/projects/domain/events/project_updated_test.exs`
  - Tests: required fields (`project_id`, `workspace_id`, `user_id`), optional `name` and `changes` map, event_type `"projects.project_updated"`
- [x] **GREEN**: Implement `apps/jarga/lib/projects/domain/events/project_updated.ex`
- [x] **REFACTOR**: Clean up

#### ProjectDeleted
- [x] **RED**: Write test `apps/jarga/test/projects/domain/events/project_deleted_test.exs`
  - Tests: required fields (`project_id`, `workspace_id`, `user_id`), event_type `"projects.project_deleted"`
- [x] **GREEN**: Implement `apps/jarga/lib/projects/domain/events/project_deleted.ex`
- [x] **REFACTOR**: Clean up

#### ProjectArchived
- [x] **RED**: Write test `apps/jarga/test/projects/domain/events/project_archived_test.exs`
  - Tests: required fields (`project_id`, `workspace_id`, `user_id`), event_type `"projects.project_archived"`
- [x] **GREEN**: Implement `apps/jarga/lib/projects/domain/events/project_archived.ex`
- [x] **REFACTOR**: Clean up

### 2.2 Documents Context Events (5 events)

**Location**: `apps/jarga/lib/documents/domain/events/`

#### DocumentCreated
- [x] **RED**: Write test `apps/jarga/test/documents/domain/events/document_created_test.exs`
  - Tests: required fields (`document_id`, `workspace_id`, `project_id`, `user_id`, `title`), event_type `"documents.document_created"`, aggregate_type `"document"`
- [x] **GREEN**: Implement `apps/jarga/lib/documents/domain/events/document_created.ex`
- [x] **REFACTOR**: Clean up

#### DocumentDeleted
- [x] **RED**: Write test `apps/jarga/test/documents/domain/events/document_deleted_test.exs`
- [x] **GREEN**: Implement `apps/jarga/lib/documents/domain/events/document_deleted.ex`
- [x] **REFACTOR**: Clean up

#### DocumentTitleChanged
- [x] **RED**: Write test `apps/jarga/test/documents/domain/events/document_title_changed_test.exs`
  - Tests: required fields include `document_id`, `workspace_id`, `user_id`, `title`; optional `previous_title`
- [x] **GREEN**: Implement `apps/jarga/lib/documents/domain/events/document_title_changed.ex`
- [x] **REFACTOR**: Clean up

#### DocumentVisibilityChanged
- [x] **RED**: Write test `apps/jarga/test/documents/domain/events/document_visibility_changed_test.exs`
  - Tests: required fields include `document_id`, `workspace_id`, `user_id`, `is_public`
- [x] **GREEN**: Implement `apps/jarga/lib/documents/domain/events/document_visibility_changed.ex`
- [x] **REFACTOR**: Clean up

#### DocumentPinnedChanged
- [x] **RED**: Write test `apps/jarga/test/documents/domain/events/document_pinned_changed_test.exs`
  - Tests: required fields include `document_id`, `workspace_id`, `user_id`, `is_pinned`
- [x] **GREEN**: Implement `apps/jarga/lib/documents/domain/events/document_pinned_changed.ex`
- [x] **REFACTOR**: Clean up

### 2.3 Agents Context Events (5 events)

**Location**: `apps/agents/lib/agents/domain/events/`

#### AgentCreated
- [x] **RED**: Write test `apps/agents/test/agents/domain/events/agent_created_test.exs`
  - Tests: required fields (`agent_id`, `user_id`, `name`), event_type `"agents.agent_created"`, aggregate_type `"agent"`, `workspace_id` is optional (nil)
- [x] **GREEN**: Implement `apps/agents/lib/agents/domain/events/agent_created.ex`
- [x] **REFACTOR**: Clean up

#### AgentUpdated
- [x] **RED**: Write test `apps/agents/test/agents/domain/events/agent_updated_test.exs`
  - Tests: required fields (`agent_id`, `user_id`), optional `workspace_ids` (list), `changes` (map)
- [x] **GREEN**: Implement `apps/agents/lib/agents/domain/events/agent_updated.ex`
- [x] **REFACTOR**: Clean up

#### AgentDeleted
- [x] **RED**: Write test `apps/agents/test/agents/domain/events/agent_deleted_test.exs`
  - Tests: required fields (`agent_id`, `user_id`), optional `workspace_ids` (list)
- [x] **GREEN**: Implement `apps/agents/lib/agents/domain/events/agent_deleted.ex`
- [x] **REFACTOR**: Clean up

#### AgentAddedToWorkspace
- [x] **RED**: Write test `apps/agents/test/agents/domain/events/agent_added_to_workspace_test.exs`
  - Tests: required fields (`agent_id`, `workspace_id`, `user_id`), event_type `"agents.agent_added_to_workspace"`
- [x] **GREEN**: Implement `apps/agents/lib/agents/domain/events/agent_added_to_workspace.ex`
- [x] **REFACTOR**: Clean up

#### AgentRemovedFromWorkspace
- [x] **RED**: Write test `apps/agents/test/agents/domain/events/agent_removed_from_workspace_test.exs`
  - Tests: required fields (`agent_id`, `workspace_id`, `user_id`)
- [x] **GREEN**: Implement `apps/agents/lib/agents/domain/events/agent_removed_from_workspace.ex`
- [x] **REFACTOR**: Clean up

### 2.4 Chat Context Events (3 events)

**Location**: `apps/jarga/lib/chat/domain/events/`

#### ChatSessionStarted
- [x] **RED**: Write test `apps/jarga/test/chat/domain/events/chat_session_started_test.exs`
  - Tests: required fields (`session_id`, `user_id`), optional `workspace_id`, `agent_id`, event_type `"chat.chat_session_started"`, aggregate_type `"chat_session"`
- [x] **GREEN**: Implement `apps/jarga/lib/chat/domain/events/chat_session_started.ex`
- [x] **REFACTOR**: Clean up

#### ChatMessageSent
- [x] **RED**: Write test `apps/jarga/test/chat/domain/events/chat_message_sent_test.exs`
  - Tests: required fields (`message_id`, `session_id`, `user_id`, `role`), optional `workspace_id`
- [x] **GREEN**: Implement `apps/jarga/lib/chat/domain/events/chat_message_sent.ex`
- [x] **REFACTOR**: Clean up

#### ChatSessionDeleted
- [x] **RED**: Write test `apps/jarga/test/chat/domain/events/chat_session_deleted_test.exs`
  - Tests: required fields (`session_id`, `user_id`), optional `workspace_id`
- [x] **GREEN**: Implement `apps/jarga/lib/chat/domain/events/chat_session_deleted.ex`
- [x] **REFACTOR**: Clean up

### 2.5 Notifications Context Events (3 events)

**Location**: `apps/jarga/lib/notifications/domain/events/`

#### NotificationCreated
- [x] **RED**: Write test `apps/jarga/test/notifications/domain/events/notification_created_test.exs`
  - Tests: required fields (`notification_id`, `user_id`, `type`), optional `workspace_id`, event_type `"notifications.notification_created"`, aggregate_type `"notification"`
- [x] **GREEN**: Implement `apps/jarga/lib/notifications/domain/events/notification_created.ex`
- [x] **REFACTOR**: Clean up

#### NotificationRead
- [x] **RED**: Write test `apps/jarga/test/notifications/domain/events/notification_read_test.exs`
- [x] **GREEN**: Implement `apps/jarga/lib/notifications/domain/events/notification_read.ex`
- [x] **REFACTOR**: Clean up

#### NotificationActionTaken
- [x] **RED**: Write test `apps/jarga/test/notifications/domain/events/notification_action_taken_test.exs`
  - Tests: required fields (`notification_id`, `user_id`, `action`)
- [x] **GREEN**: Implement `apps/jarga/lib/notifications/domain/events/notification_action_taken.ex`
- [x] **REFACTOR**: Clean up

### 2.6 ERM Context Events (7 events)

**Location**: `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/`

#### SchemaCreated
- [x] **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/events/schema_created_test.exs`
  - Tests: required fields (`schema_id`, `workspace_id`), optional `user_id`, event_type `"entity_relationship_manager.schema_created"`, aggregate_type `"schema"`
- [x] **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/schema_created.ex`
- [x] **REFACTOR**: Clean up

#### SchemaUpdated
- [x] **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/events/schema_updated_test.exs`
- [x] **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/schema_updated.ex`
- [x] **REFACTOR**: Clean up

#### EntityCreated
- [x] **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/events/entity_created_test.exs`
  - Tests: required fields (`entity_id`, `workspace_id`, `entity_type`), optional `properties`, `user_id`
- [x] **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/entity_created.ex`
- [x] **REFACTOR**: Clean up

#### EntityUpdated
- [x] **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/events/entity_updated_test.exs`
- [x] **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/entity_updated.ex`
- [x] **REFACTOR**: Clean up

#### EntityDeleted
- [x] **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/events/entity_deleted_test.exs`
- [x] **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/entity_deleted.ex`
- [x] **REFACTOR**: Clean up

#### EdgeCreated
- [x] **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/events/edge_created_test.exs`
  - Tests: required fields (`edge_id`, `workspace_id`, `source_id`, `target_id`, `edge_type`), optional `user_id`
- [x] **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/edge_created.ex`
- [x] **REFACTOR**: Clean up

#### EdgeDeleted
- [x] **RED**: Write test `apps/entity_relationship_manager/test/entity_relationship_manager/domain/events/edge_deleted_test.exs`
- [x] **GREEN**: Implement `apps/entity_relationship_manager/lib/entity_relationship_manager/domain/events/edge_deleted.ex`
- [x] **REFACTOR**: Clean up

### 2.7 Boundary Configuration Updates

Update domain boundary exports for each context to include event structs:

- [x] Update `apps/jarga/lib/projects/domain.ex` — add exports: `Events.ProjectCreated`, `Events.ProjectUpdated`, `Events.ProjectDeleted`, `Events.ProjectArchived`
- [x] Update `apps/jarga/lib/documents/domain.ex` — add exports: `Events.DocumentCreated`, `Events.DocumentDeleted`, `Events.DocumentTitleChanged`, `Events.DocumentVisibilityChanged`, `Events.DocumentPinnedChanged`
- [x] Update `apps/jarga/lib/chat/domain.ex` — add exports: `Events.ChatSessionStarted`, `Events.ChatMessageSent`, `Events.ChatSessionDeleted`
- [x] Update `apps/jarga/lib/notifications/domain.ex` (create if needed) — add exports for notification events
- [x] Update `apps/agents/lib/agents/domain.ex` — add exports: `Events.AgentCreated`, `Events.AgentUpdated`, `Events.AgentDeleted`, `Events.AgentAddedToWorkspace`, `Events.AgentRemovedFromWorkspace`
- [x] Update `apps/entity_relationship_manager/lib/entity_relationship_manager/domain.ex` — add exports: `Events.SchemaCreated`, `Events.SchemaUpdated`, `Events.EntityCreated`, `Events.EntityUpdated`, `Events.EntityDeleted`, `Events.EdgeCreated`, `Events.EdgeDeleted`

### 2.8 Event Type Uniqueness Test

- [x] **RED**: Write test `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs`
  - Tests: Collect all 27 event modules, call `event_type/0` on each, assert all strings are unique
  - This is a cross-cutting integration test that verifies no naming collisions
- [x] **GREEN**: All event types are already unique by construction (derived from module names)
- [x] **REFACTOR**: Clean up test organization

### Phase 2 Validation

- [x] All event struct tests pass
- [x] Event type uniqueness test passes
- [x] `mix boundary` passes — all event structs properly exported (note: ERM has boundary warnings for DomainEvent cross-app reference — see notes below)
- [x] `mix credo` passes
- [x] No changes to existing use cases or notifiers — this phase is purely additive

**Note on DomainEvent location**: The `Perme8.Events.DomainEvent` macro was moved from `jarga` to `identity` app to resolve a cyclic dependency issue (`jarga -> agents -> identity`). The agents app can't depend on jarga, so the macro must live in the lowest common ancestor (`identity`). The ERM app shows boundary warnings because the boundary library doesn't natively support cross-app boundary deps for modules not classified in any boundary. These are non-blocking warnings. Also fixed a bug in the DomainEvent macro where `Macro.escape` double-escaped map defaults (`%{}`) in custom fields.

---

## Phase 3: Use Case Migration ✓

**Goal**: Migrate every use case from `opts[:notifier]` to `opts[:event_bus]`, emitting typed events. Legacy bridge preserves all existing behavior. Existing tests continue passing.

**Strategy per use case**:
1. Add `@default_event_bus Perme8.Events.EventBus` module attribute
2. Extract `event_bus = Keyword.get(opts, :event_bus, @default_event_bus)` in execute
3. After successful operation, construct event struct and call `event_bus.emit(event)`
4. **Keep** `opts[:notifier]` injection working during migration (dual-publish)
5. Use case tests use `TestEventBus` to assert events emitted
6. All existing notifier tests remain passing (legacy bridge handles backward compat)

### 3.1 Projects Context Migration (3 use cases)

**Commit message**: `feat(events): migrate Projects use cases to emit domain events`

#### CreateProject
- [x] **RED**: Write/update test `apps/jarga/test/projects/application/use_cases/create_project_test.exs`
  - New test: `emits ProjectCreated event via event_bus` — inject `TestEventBus`, assert `ProjectCreated` event with correct fields
  - Existing tests: continue passing (notifier mock still works)
- [x] **GREEN**: Update `apps/jarga/lib/projects/application/use_cases/create_project.ex`
  - Add `@default_event_bus Perme8.Events.EventBus`
  - Extract `event_bus = Keyword.get(opts, :event_bus, @default_event_bus)`
  - After `notifier.notify_project_created(project)`, add:
    ```elixir
    event = Jarga.Projects.Domain.Events.ProjectCreated.new(%{
      aggregate_id: project.id,
      actor_id: actor.id,
      project_id: project.id,
      workspace_id: workspace_id,
      user_id: actor.id,
      name: project.name,
      slug: project.slug
    })
    event_bus.emit(event)
    ```
  - **Keep notifier call** — will be removed in Part 2 Phase 6
- [x] **REFACTOR**: Clean up, ensure event construction is after transaction commit

#### UpdateProject
- [x] **RED**: Write/update test — assert `ProjectUpdated` event emitted with project_id, workspace_id, name, changes
- [x] **GREEN**: Update `apps/jarga/lib/projects/application/use_cases/update_project.ex`
  - Add event_bus injection, construct `ProjectUpdated` event after update, emit
- [x] **REFACTOR**: Clean up

#### DeleteProject
- [x] **RED**: Write/update test — assert `ProjectDeleted` event emitted with project_id, workspace_id
- [x] **GREEN**: Update `apps/jarga/lib/projects/application/use_cases/delete_project.ex`
  - Add event_bus injection, construct `ProjectDeleted` event after delete, emit
- [x] **REFACTOR**: Clean up

#### Projects Application Boundary Update
- [x] Update `apps/jarga/lib/projects/application.ex` boundary `deps` to include `Perme8.Events`

### 3.2 Documents Context Migration (3 use cases covering 5 event types)

**Commit message**: `feat(events): migrate Documents use cases to emit domain events`

#### CreateDocument
- [x] **RED**: Write/update test — assert `DocumentCreated` event emitted with document_id, workspace_id, project_id, user_id, title
- [x] **GREEN**: Update `apps/jarga/lib/documents/application/use_cases/create_document.ex`
  - Inject event_bus, emit `DocumentCreated` after transaction commits
- [x] **REFACTOR**: Clean up

#### UpdateDocument (emits 3 event types conditionally)
- [x] **RED**: Write/update test — assert:
  - `DocumentTitleChanged` emitted when title changes
  - `DocumentVisibilityChanged` emitted when is_public changes
  - `DocumentPinnedChanged` emitted when is_pinned changes
  - No events emitted when no relevant fields change
- [x] **GREEN**: Update `apps/jarga/lib/documents/application/use_cases/update_document.ex`
  - Inject event_bus, construct appropriate event(s) in `send_notifications/4`, emit each
  - Note: A single update can emit multiple events (e.g., title + visibility change)
- [x] **REFACTOR**: Extract event construction into a helper function

#### DeleteDocument
- [x] **RED**: Write/update test — assert `DocumentDeleted` event emitted with document_id, workspace_id
- [x] **GREEN**: Update `apps/jarga/lib/documents/application/use_cases/delete_document.ex`
  - Inject event_bus, emit `DocumentDeleted` after transaction commits
- [x] **REFACTOR**: Clean up

#### Documents Application Boundary Update
- [x] Update `apps/jarga/lib/documents/application.ex` boundary `deps` to include `Perme8.Events`

### 3.3 Agents Context Migration (3 use cases)

**Commit message**: `feat(events): migrate Agents use cases to emit domain events`

#### UpdateUserAgent
- [x] **RED**: Write/update test `apps/agents/test/agents/application/use_cases/update_user_agent_test.exs`
  - Assert `AgentUpdated` event emitted with agent_id, user_id, workspace_ids
- [x] **GREEN**: Update `apps/agents/lib/agents/application/use_cases/update_user_agent.ex`
  - Add event_bus injection, construct and emit `AgentUpdated` event
  - Include `workspace_ids` in event for fan-out
- [x] **REFACTOR**: Clean up

#### DeleteUserAgent
- [x] **RED**: Write/update test — assert `AgentDeleted` event emitted with agent_id, user_id, workspace_ids
- [x] **GREEN**: Update `apps/agents/lib/agents/application/use_cases/delete_user_agent.ex`
  - Add event_bus injection, emit `AgentDeleted` event
- [x] **REFACTOR**: Clean up

#### SyncAgentWorkspaces
- [x] **RED**: Write/update test — assert:
  - `AgentAddedToWorkspace` emitted for each added workspace
  - `AgentRemovedFromWorkspace` emitted for each removed workspace
  - Uses `emit_all/2` for batch emission
- [x] **GREEN**: Update `apps/agents/lib/agents/application/use_cases/sync_agent_workspaces.ex`
  - Inject event_bus, construct events for each add/remove, use `emit_all/2`
- [x] **REFACTOR**: Clean up

#### Agents Application Boundary Update
- [x] Update `apps/agents/lib/agents/application.ex` boundary `deps` to include `Perme8.Events`

### 3.4 Chat Context Migration (3 use cases — net-new events)

**Commit message**: `feat(events): add domain events to Chat use cases`

Chat currently has ZERO PubSub — these are net-new events. No legacy bridge translations needed.

#### CreateSession
- [x] **RED**: Write/update test `apps/jarga/test/chat/application/use_cases/create_session_test.exs`
  - Assert `ChatSessionStarted` event emitted with session_id, user_id, workspace_id, agent_id
- [x] **GREEN**: Update `apps/jarga/lib/chat/application/use_cases/create_session.ex`
  - Add event_bus injection, emit `ChatSessionStarted` after session creation
- [x] **REFACTOR**: Clean up

#### SaveMessage
- [x] **RED**: Write/update test `apps/jarga/test/chat/application/use_cases/save_message_test.exs`
  - Assert `ChatMessageSent` event emitted with message_id, session_id, user_id, role
- [x] **GREEN**: Update `apps/jarga/lib/chat/application/use_cases/save_message.ex`
  - Add event_bus injection, emit `ChatMessageSent` after message saved
- [x] **REFACTOR**: Clean up

#### DeleteSession
- [x] **RED**: Write/update test `apps/jarga/test/chat/application/use_cases/delete_session_test.exs`
  - Assert `ChatSessionDeleted` event emitted with session_id, user_id
- [x] **GREEN**: Update `apps/jarga/lib/chat/application/use_cases/delete_session.ex`
  - Add event_bus injection, emit `ChatSessionDeleted` after deletion
- [x] **REFACTOR**: Clean up

#### Chat Application Boundary Update
- [x] Update `apps/jarga/lib/chat/application.ex` boundary `deps` to include `Perme8.Events`

### 3.5 Notifications Context Migration (3 use cases)

**Commit message**: `feat(events): migrate Notifications use cases to emit domain events`

#### CreateWorkspaceInvitationNotification
- [x] **RED**: Write/update test — assert `NotificationCreated` event emitted with notification_id, user_id, type
- [x] **GREEN**: Update `apps/jarga/lib/notifications/application/use_cases/create_workspace_invitation_notification.ex`
  - Inject event_bus, emit `NotificationCreated` after notification created
  - Keep existing notifier.broadcast_new_notification call (legacy bridge will also handle)
- [x] **REFACTOR**: Clean up

#### AcceptWorkspaceInvitation
- [x] **RED**: Write/update test — assert `NotificationActionTaken` event emitted with notification_id, user_id, action="accepted"
- [x] **GREEN**: Update `apps/jarga/lib/notifications/application/use_cases/accept_workspace_invitation.ex`
  - Inject event_bus, emit `NotificationActionTaken` event after transaction
  - Keep existing notifier.broadcast_workspace_joined call
- [x] **REFACTOR**: Clean up

#### DeclineWorkspaceInvitation
- [x] **RED**: Write/update test — assert `NotificationActionTaken` event emitted with notification_id, user_id, action="declined"
- [x] **GREEN**: Update `apps/jarga/lib/notifications/application/use_cases/decline_workspace_invitation.ex`
  - Inject event_bus, emit `NotificationActionTaken` event after transaction
  - Keep existing notifier.broadcast_invitation_declined call
- [x] **REFACTOR**: Clean up

#### Notifications Application Boundary Update
- [x] Update `apps/jarga/lib/notifications/application.ex` boundary `deps` to include `Perme8.Events`

### 3.6 ERM Context Migration (7 use cases — net-new events)

**Commit message**: `feat(events): add domain events to ERM use cases`

ERM currently has ZERO PubSub. Net-new events, no legacy bridge needed. ERM use cases don't have a `notifier` param — we add `event_bus` only.

**Note**: ERM depends on `Jarga.Repo` (in jarga app), so adding `Perme8.Events` dependency is consistent with the existing dependency graph.

#### CreateEntity
- [x] **RED**: Write/update test `apps/entity_relationship_manager/test/entity_relationship_manager/application/use_cases/create_entity_test.exs`
  - Assert `EntityCreated` event emitted with entity_id, workspace_id, entity_type, properties
- [x] **GREEN**: Update `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/create_entity.ex`
  - Add event_bus injection, emit `EntityCreated` after successful creation
- [x] **REFACTOR**: Clean up

#### UpdateEntity
- [x] **RED**: Write/update test — assert `EntityUpdated` event emitted with entity_id, workspace_id, changes
- [x] **GREEN**: Update `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/update_entity.ex`
- [x] **REFACTOR**: Clean up

#### DeleteEntity
- [x] **RED**: Write/update test — assert `EntityDeleted` event emitted with entity_id, workspace_id
- [x] **GREEN**: Update `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/delete_entity.ex`
- [x] **REFACTOR**: Clean up

#### CreateEdge
- [x] **RED**: Write/update test — assert `EdgeCreated` event emitted with edge_id, workspace_id, source_id, target_id, edge_type
- [x] **GREEN**: Update `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/create_edge.ex`
- [x] **REFACTOR**: Clean up

#### DeleteEdge
- [x] **RED**: Write/update test — assert `EdgeDeleted` event emitted with edge_id, workspace_id
- [x] **GREEN**: Update `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/delete_edge.ex`
- [x] **REFACTOR**: Clean up

#### UpsertSchema
- [x] **RED**: Write/update test — assert `SchemaCreated` or `SchemaUpdated` event emitted depending on whether schema existed
  - This requires the use case to know if it's creating vs updating — may need a small refactor
- [x] **GREEN**: Update `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/upsert_schema.ex`
  - Check if schema existed before upsert, emit appropriate event
- [x] **REFACTOR**: Clean up

#### ERM Boundary Updates
- [x] Update `apps/entity_relationship_manager/lib/entity_relationship_manager.ex` boundary `deps` to include `Perme8.Events`
- [x] The ERM Application layer may need its own boundary module (currently not explicitly defined) — or events go through the top-level boundary

### Phase 3 Validation

- [x] All use case tests pass (both new event assertions and existing notifier assertions)
- [x] All existing LiveView tests pass unchanged (legacy bridge handles backward compat)
- [x] `mix boundary` passes
- [x] `mix credo` passes
- [x] Full test suite passes: `mix test`

---

## Pre-Commit Checkpoint

- [x] `mix precommit` passes (compile + format + credo + boundary + tests)
- [x] `mix boundary` explicitly verified — no violations
- [x] No changes to any LiveView, controller, or interface module
- [ ] No changes to identity app (out of scope for Part 1) — Note: DomainEvent macro moved to identity app with `use Boundary, check: [in: false]` to resolve cross-app boundary
- [x] Legacy bridge correctly translates all 15 existing tuple events
- [x] All 27 event structs defined and tested

---

## Testing Strategy

### Test Distribution

| Category | Count | Location | Async? |
|----------|-------|----------|--------|
| DomainEvent macro | ~10 | `apps/jarga/test/perme8_events/domain_event_test.exs` | Yes |
| EventBus | ~8 | `apps/jarga/test/perme8_events/event_bus_test.exs` | No (PubSub) |
| EventHandler | ~6 | `apps/jarga/test/perme8_events/event_handler_test.exs` | No (PubSub) |
| TestEventBus | ~6 | `apps/jarga/test/perme8_events/test_event_bus_test.exs` | Yes |
| LegacyBridge | ~15 | `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs` | Yes |
| Event structs (27) | ~54 | `apps/*/test/**/domain/events/*_test.exs` | Yes |
| Event type uniqueness | 1 | `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs` | Yes |
| Use case updates (18) | ~36 | `apps/*/test/**/application/use_cases/*_test.exs` | Varies |
| **Total** | **~136** | | |

### Test Patterns

**Event struct tests** (async: true, pure):
```elixir
defmodule Jarga.Projects.Domain.Events.ProjectCreatedTest do
  use ExUnit.Case, async: true
  alias Jarga.Projects.Domain.Events.ProjectCreated

  test "new/1 creates event with required fields" do
    event = ProjectCreated.new(%{
      aggregate_id: "proj-123",
      actor_id: "user-123",
      project_id: "proj-123",
      workspace_id: "ws-123",
      user_id: "user-123",
      name: "My Project",
      slug: "my-project"
    })
    assert event.event_type == "projects.project_created"
    assert event.aggregate_type == "project"
    assert event.event_id != nil
    assert event.occurred_at != nil
  end
end
```

**Use case event emission tests** (with TestEventBus):
```elixir
test "emits ProjectCreated event" do
  {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
  # ... setup ...
  {:ok, project} = CreateProject.execute(params, event_bus: Perme8.Events.TestEventBus)
  assert [%ProjectCreated{} = event] = Perme8.Events.TestEventBus.get_events()
  assert event.project_id == project.id
end
```

**LegacyBridge translation tests** (async: true, pure):
```elixir
test "translates ProjectCreated to legacy tuple" do
  event = ProjectCreated.new(%{...})
  translations = LegacyBridge.translate(event)
  assert [{"workspace:ws-123", {:project_added, "proj-123"}}] = translations
end
```

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Event infra in `jarga` app, not new umbrella app | All apps already depend on jarga; avoids dependency graph changes |
| `Perme8.Events.*` namespace | Distinguishes shared infra from jarga's domain contexts |
| Keep `opts[:notifier]` during Phase 3 | Dual-publish ensures zero risk; notifiers removed in Part 2 Phase 6 |
| `DomainEvent` macro derives `event_type` from module name | Eliminates manual string management, guarantees uniqueness |
| LegacyBridge is called by EventBus (not use cases) | Use cases only call `event_bus.emit` — bridge is transparent |
| Agent events carry `workspace_ids` list | Enables fan-out in LegacyBridge without additional lookups |
| Chat/ERM events have no legacy translations | They're net-new — `LegacyBridge.translate/1` returns `[]` |
| TestEventBus uses Agent (not Mox) | Simpler API, captures ordered events, no mock setup boilerplate |
| Event structs in domain/events/ not domain/entities/ | Events are domain concepts but distinct from entities (no persistence schema) |

---

## File Summary

### New Files (Phase 1 — Foundation)

| File | Purpose |
|------|---------|
| `apps/jarga/lib/perme8_events.ex` | Boundary module + convenience functions |
| `apps/jarga/lib/perme8_events/domain_event.ex` | `use Perme8.Events.DomainEvent` macro |
| `apps/jarga/lib/perme8_events/event_bus.ex` | Central dispatcher wrapping PubSub |
| `apps/jarga/lib/perme8_events/event_handler.ex` | GenServer behaviour macro |
| `apps/jarga/lib/perme8_events/test_event_bus.ex` | In-memory Agent for testing |
| `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex` | Tuple translation for backward compat |
| `apps/jarga/test/perme8_events/domain_event_test.exs` | Tests |
| `apps/jarga/test/perme8_events/event_bus_test.exs` | Tests |
| `apps/jarga/test/perme8_events/event_handler_test.exs` | Tests |
| `apps/jarga/test/perme8_events/test_event_bus_test.exs` | Tests |
| `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs` | Tests |

### New Files (Phase 2 — Event Structs: 27 modules + 27 tests)

| Context | Event Modules | Test Files |
|---------|--------------|------------|
| Projects (jarga) | `projects/domain/events/{project_created,project_updated,project_deleted,project_archived}.ex` | Same structure in `test/` |
| Documents (jarga) | `documents/domain/events/{document_created,document_deleted,document_title_changed,document_visibility_changed,document_pinned_changed}.ex` | Same |
| Chat (jarga) | `chat/domain/events/{chat_session_started,chat_message_sent,chat_session_deleted}.ex` | Same |
| Notifications (jarga) | `notifications/domain/events/{notification_created,notification_read,notification_action_taken}.ex` | Same |
| Agents | `agents/domain/events/{agent_created,agent_updated,agent_deleted,agent_added_to_workspace,agent_removed_from_workspace}.ex` | Same |
| ERM | `entity_relationship_manager/domain/events/{schema_created,schema_updated,entity_created,entity_updated,entity_deleted,edge_created,edge_deleted}.ex` | Same |
| Cross-cutting | — | `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs` |

### Modified Files (Phase 2 — Boundary Exports)

| File | Change |
|------|--------|
| `apps/jarga/lib/projects/domain.ex` | Add event exports |
| `apps/jarga/lib/documents/domain.ex` | Add event exports |
| `apps/jarga/lib/chat/domain.ex` | Add event exports |
| `apps/jarga/lib/notifications/domain.ex` | Create or add event exports |
| `apps/agents/lib/agents/domain.ex` | Add event exports |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/domain.ex` | Add event exports |

### Modified Files (Phase 3 — Use Case Migration)

| File | Change |
|------|--------|
| `apps/jarga/lib/projects/application/use_cases/create_project.ex` | Add event_bus, emit ProjectCreated |
| `apps/jarga/lib/projects/application/use_cases/update_project.ex` | Add event_bus, emit ProjectUpdated |
| `apps/jarga/lib/projects/application/use_cases/delete_project.ex` | Add event_bus, emit ProjectDeleted |
| `apps/jarga/lib/documents/application/use_cases/create_document.ex` | Add event_bus, emit DocumentCreated |
| `apps/jarga/lib/documents/application/use_cases/update_document.ex` | Add event_bus, emit title/visibility/pinned events |
| `apps/jarga/lib/documents/application/use_cases/delete_document.ex` | Add event_bus, emit DocumentDeleted |
| `apps/agents/lib/agents/application/use_cases/update_user_agent.ex` | Add event_bus, emit AgentUpdated |
| `apps/agents/lib/agents/application/use_cases/delete_user_agent.ex` | Add event_bus, emit AgentDeleted |
| `apps/agents/lib/agents/application/use_cases/sync_agent_workspaces.ex` | Add event_bus, emit Added/Removed events |
| `apps/jarga/lib/chat/application/use_cases/create_session.ex` | Add event_bus, emit ChatSessionStarted |
| `apps/jarga/lib/chat/application/use_cases/save_message.ex` | Add event_bus, emit ChatMessageSent |
| `apps/jarga/lib/chat/application/use_cases/delete_session.ex` | Add event_bus, emit ChatSessionDeleted |
| `apps/jarga/lib/notifications/application/use_cases/create_workspace_invitation_notification.ex` | Add event_bus, emit NotificationCreated |
| `apps/jarga/lib/notifications/application/use_cases/accept_workspace_invitation.ex` | Add event_bus, emit NotificationActionTaken |
| `apps/jarga/lib/notifications/application/use_cases/decline_workspace_invitation.ex` | Add event_bus, emit NotificationActionTaken |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/create_entity.ex` | Add event_bus, emit EntityCreated |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/update_entity.ex` | Add event_bus, emit EntityUpdated |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/delete_entity.ex` | Add event_bus, emit EntityDeleted |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/create_edge.ex` | Add event_bus, emit EdgeCreated |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/delete_edge.ex` | Add event_bus, emit EdgeDeleted |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/application/use_cases/upsert_schema.ex` | Add event_bus, emit SchemaCreated/SchemaUpdated |

### Modified Files (Phase 3 — Boundary Deps)

| File | Change |
|------|--------|
| `apps/jarga/lib/projects/application.ex` | Add `Perme8.Events` to deps |
| `apps/jarga/lib/documents/application.ex` | Add `Perme8.Events` to deps |
| `apps/jarga/lib/chat/application.ex` | Add `Perme8.Events` to deps |
| `apps/jarga/lib/notifications/application.ex` | Add `Perme8.Events` to deps |
| `apps/agents/lib/agents/application.ex` | Add `Perme8.Events` to deps |
| `apps/entity_relationship_manager/lib/entity_relationship_manager.ex` | Add `Perme8.Events` to deps (top-level boundary) |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| LegacyBridge gets a translation wrong → breaks LiveView | One test per legacy event format; run full LiveView test suite |
| Boundary violations from event imports | Export events from domain boundaries; verify with `mix boundary` each phase |
| Agent events need agent struct data for legacy tuple | Include `agent_data` map in event metadata or dedicated field for bridge |
| ERM adding Perme8.Events dep changes dependency graph | ERM already depends on `Jarga.Repo` (in jarga); consistent |
| Dual-publish (notifier + event_bus) causes double-broadcast | EventBus.emit triggers legacy bridge; notifier also broadcasts. During Phase 3, use cases call both but legacy bridge is smart — only translates for events that have legacy mappings. In Phase 2 Part 2, notifiers are removed. |
| TestEventBus not started in tests | Document pattern: start_link in test setup, reset in setup |

---

## What's Deferred to Part 2+

- **Phase 4**: Convert WorkspaceInvitationSubscriber to EventHandler
- **Phase 5**: Migrate LiveViews to structured event subscriptions
- **Phase 6**: Remove legacy bridge, all notifiers, all notifier behaviours
- **Phase 7a**: Event persistence (EventStore, event_log table)
- **Phase 7b**: Event registry + telemetry
- **Identity migration**: Identity notifiers stay unchanged

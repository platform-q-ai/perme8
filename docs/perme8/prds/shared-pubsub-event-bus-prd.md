# PRD: Shared PubSub Event Bus

**Ticket**: #37 — Make all apps event driven via shared PubSub event bus
**Status**: Implemented (Parts 1 + 2a + 2b + 2c complete; P1/P2 enhancements deferred)
**Date**: 2026-02-18

---

## Summary

- **Problem**: Perme8 umbrella apps communicate through a mix of direct function calls and unstructured PubSub broadcasts (bare tuples). There is no shared event schema, no event registry, no event persistence, and only one cross-app GenServer subscriber. This tight coupling makes it impossible to add new consumers without modifying producers, prevents audit trails, and blocks future service extraction.
- **Value**: A structured event bus decouples bounded contexts, enables reliable cross-context reactions, creates an auditable event history, and lays the foundation for service extraction. Event-Driven Design is one of four core platform principles — this ticket fulfills that commitment.
- **Users**: All Perme8 developers (internal consumers of the event bus API), and indirectly all end users who benefit from real-time UI updates and cross-context side effects (notifications, graph sync, etc.).

---

## User Stories

- As a **developer**, I want to emit a typed domain event from any use case, so that I don't need to know which consumers react to it.
- As a **developer**, I want to subscribe an EventHandler GenServer to specific event types, so that cross-context reactions are decoupled and testable.
- As a **developer**, I want all events to follow a consistent schema with metadata (actor_id, workspace_id, occurred_at, correlation_id), so that I can reason about event flows and build audit trails.
- As a **developer**, I want a TestEventBus that captures events in-memory, so that I can write fast isolated unit tests for use cases without PubSub side effects.
- As a **developer**, I want existing LiveView PubSub subscriptions to keep working during migration, so that no UI breaks while the transition is underway.
- As an **end user**, I want real-time updates when collaborators change projects, documents, or agents, so that my workspace view is always current.
- As an **end user**, I want notifications when I'm invited to a workspace or when relevant changes occur, so that I stay informed without polling.

---

## Functional Requirements

### Must Have (P0)

1. **Shared EventBus module** — A `Perme8.Events.EventBus` module that wraps `Phoenix.PubSub` with a single `emit/2` function and optional `emit_all/2` for batches. Injectable via `opts[:event_bus]` in use cases (same DI pattern as existing `opts[:notifier]`).

2. **Typed domain event structs** — Each domain event is a pure struct with `@enforce_keys` for required fields. Every event includes: `event_id`, `event_type` (string, e.g. `"projects.project_created"`), `aggregate_type`, `aggregate_id`, `actor_id`, `workspace_id`, `occurred_at`, `metadata` (map), and domain-specific data fields.

3. **Event struct macro/behaviour** — A `use Perme8.Events.DomainEvent` macro that enforces the base schema fields, generates `event_type` and `aggregate_type` from the module name, and provides a `new/1` constructor that auto-populates `event_id` and `occurred_at`.

4. **Standardized PubSub topic convention** — Events are broadcast to structured topics:
   - `"events:{context}"` — all events from a context (e.g. `"events:projects"`)
   - `"events:{context}:{aggregate_type}"` — scoped to aggregate (e.g. `"events:projects:project"`)
   - `"events:workspace:{workspace_id}"` — all events scoped to a workspace
   - Legacy topics (`"workspace:{id}"`, `"document:{id}"`, `"user:{id}"`) are preserved via a legacy bridge during migration.

5. **Legacy bridge** — A `Perme8.Events.Infrastructure.LegacyBridge` module that translates new structured events to the existing bare tuple format and broadcasts on legacy topics. This ensures all current LiveView `handle_info/2` clauses continue working without changes during the migration.

6. **EventHandler behaviour** — A `use Perme8.Events.EventHandler` macro that generates a GenServer with:
   - Auto-subscription to topics specified in `subscriptions/0` callback
   - Event routing to `handle_event/1` callback
   - Error logging
   - Supervision-friendly (child_spec for supervisor trees)

7. **Jarga (Projects) emits domain events** — Migrate `CreateProject`, `UpdateProject`, `DeleteProject` use cases to emit `ProjectCreated`, `ProjectUpdated`, `ProjectDeleted` events via EventBus. Remove direct notifier calls.

8. **Jarga (Documents) emits domain events** — Migrate all 5 document use cases to emit `DocumentCreated`, `DocumentDeleted`, `DocumentTitleChanged`, `DocumentVisibilityChanged`, `DocumentPinnedChanged` events. Handle the dual-topic dispatch (workspace + document) in EventBus topic resolution.

9. **Agents emits lifecycle events** — Migrate `UpdateUserAgent`, `DeleteUserAgent`, `SyncAgentWorkspaces` use cases to emit `AgentUpdated`, `AgentDeleted`, `AgentAddedToWorkspace`, `AgentRemovedFromWorkspace` events. Handle multi-workspace fan-out in topic resolution.

10. **Chat emits domain events** — Add event emission to chat use cases: `ChatSessionStarted`, `ChatMessageSent`, `ChatSessionDeleted`. Chat currently has ZERO PubSub — this is net-new.

11. **Notifications subscribes via EventHandler** — Convert the existing `WorkspaceInvitationSubscriber` GenServer to the new `EventHandler` behaviour. Add subscription to all relevant event types from identity, projects, documents, and agents contexts.

12. **ERM emits events** — Add event emission to entity_relationship_manager CRUD operations: `EntityCreated`, `EntityUpdated`, `EntityDeleted`, `EdgeCreated`, `EdgeDeleted`, `SchemaCreated`, `SchemaUpdated`.

13. **No direct cross-app function calls remain** — All inter-context communication goes through the event bus. The only cross-app dependencies that remain are: reading data via context public APIs (which is correct) and shared domain entities (exported via Boundary).

14. **TestEventBus** — An in-memory event bus implementation (Agent-based) for unit tests that captures emitted events without PubSub side effects. Supports `get_events/0` and `reset/0`.

### Should Have (P1)

1. **Event persistence (EventStore)** — A `Perme8.Events.EventStore` behaviour with a PostgreSQL implementation that persists all events to an `event_log` table. Async persistence (doesn't block the emit path). Includes `event_id`, `event_type`, `aggregate_type`, `aggregate_id`, `actor_id`, `workspace_id`, `data` (jsonb), `metadata` (jsonb), `occurred_at`, `inserted_at`.

2. **Event registry** — A compile-time or runtime registry that catalogs all known event types, their source context, and their struct module. Useful for documentation, debugging, and future schema validation.

3. **Telemetry integration** — Emit `:telemetry` events for `[:perme8, :events, :emit]`, `[:perme8, :events, :handle]`, and `[:perme8, :events, :persist]` spans, enabling observability of event throughput, latency, and handler failures.

4. **Identity event schema adoption** — Existing identity notifiers adopt the new event struct format. Identity continues to own its notifiers (it's not in the ticket's migration list), but its events should conform to the shared schema so downstream consumers (notifications) can pattern-match consistently.

### Nice to Have (P2)

1. **Event replay** — Ability to replay events from the event_log for a given aggregate, enabling read-model rebuilding.

2. **Dead-letter logging** — Failed handler executions are logged with the event payload for debugging and manual retry.

3. **jarga_api event streaming** — WebSocket or SSE endpoint that streams domain events to external consumers, enabling real-time API integrations.

4. **Saga/Process Manager pattern** — Reusable orchestration for multi-step workflows (e.g., workspace onboarding: create workspace -> default project -> welcome document).

---

## User Workflows

### Workflow 1: Developer Emits Event from Use Case

1. Developer writes a use case that performs a domain operation (e.g., `CreateProject`)
2. After the database transaction commits, the use case constructs a `ProjectCreated` event struct using `ProjectCreated.new(attrs)`
3. Use case calls `event_bus.emit(event)` (where `event_bus` is injected via opts, defaulting to `Perme8.Events.EventBus`)
4. EventBus broadcasts the structured event to `events:projects:project` and `events:workspace:{workspace_id}`
5. LegacyBridge also broadcasts `{:project_added, id}` to `workspace:{id}` for backward compatibility
6. (P1) EventStore persists the event asynchronously

### Workflow 2: Developer Creates an EventHandler

1. Developer creates a module that `use Perme8.Events.EventHandler`
2. Implements `subscriptions/0` returning topic patterns (e.g., `["events:identity:workspace"]`)
3. Implements `handle_event/1` with pattern-matching clauses for specific event structs
4. Adds the handler to the appropriate application's supervision tree
5. Handler auto-subscribes on start and receives events via `handle_info`

### Workflow 3: Existing LiveView Receives Event (During Migration)

1. LiveView subscribes to legacy topic `"workspace:#{id}"` (no change)
2. A use case emits a `ProjectCreated` structured event
3. EventBus broadcasts to new topics AND LegacyBridge broadcasts `{:project_added, id}` to `workspace:{id}`
4. LiveView's existing `handle_info({:project_added, _}, socket)` fires as before
5. No LiveView code changes required during the migration period

### Workflow 4: LiveView Migration to Structured Events (Post-Migration)

1. LiveView subscribes to `"events:workspace:#{id}"` using `Perme8.Events.subscribe/1`
2. LiveView's `handle_info(%ProjectCreated{project_id: id}, socket)` pattern-matches on the struct
3. LegacyBridge and legacy topics are removed

---

## Data Requirements

### Event Struct (Base Fields)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_id` | `binary_id` (UUID) | Yes | Unique ID for this event instance |
| `event_type` | `String.t()` | Yes | Dot-notation type (e.g., `"projects.project_created"`) |
| `aggregate_type` | `String.t()` | Yes | Entity type (e.g., `"project"`, `"document"`) |
| `aggregate_id` | `binary_id` | Yes | ID of the entity this event is about |
| `actor_id` | `binary_id` | No | User who triggered the action (nil for system events) |
| `workspace_id` | `binary_id` | No | Workspace scope (nil for global events) |
| `occurred_at` | `DateTime.t()` | Yes | When the event occurred (UTC) |
| `metadata` | `map()` | Yes (defaults `%{}`) | Correlation/causation IDs, extra context |
| `data` | domain-specific fields | Varies | Event-specific payload fields on the struct |

### Event Log Table (P1)

| Column | Type | Nullable | Index |
|--------|------|----------|-------|
| `id` | `binary_id` (PK) | No | Primary |
| `event_type` | `string` | No | Yes |
| `aggregate_type` | `string` | No | Composite with `aggregate_id` |
| `aggregate_id` | `binary_id` | No | Composite with `aggregate_type` |
| `actor_id` | `binary_id` | Yes | Yes |
| `workspace_id` | `binary_id` | Yes | Yes |
| `data` | `jsonb` | No | - |
| `metadata` | `jsonb` | No | - |
| `occurred_at` | `utc_datetime_usec` | No | Yes |
| `inserted_at` | `utc_datetime_usec` | No | - |

### Complete Event Catalog

**Projects Context** (4 events):
- `ProjectCreated` — project_id, workspace_id, user_id, name, slug
- `ProjectUpdated` — project_id, workspace_id, user_id, name, changes
- `ProjectDeleted` — project_id, workspace_id, user_id
- `ProjectArchived` — project_id, workspace_id, user_id

**Documents Context** (5 events):
- `DocumentCreated` — document_id, workspace_id, project_id, user_id, title
- `DocumentDeleted` — document_id, workspace_id, user_id
- `DocumentTitleChanged` — document_id, workspace_id, user_id, title, previous_title
- `DocumentVisibilityChanged` — document_id, workspace_id, user_id, is_public
- `DocumentPinnedChanged` — document_id, workspace_id, user_id, is_pinned

**Agents Context** (5 events):
- `AgentCreated` — agent_id, user_id, name
- `AgentUpdated` — agent_id, user_id, workspace_ids, changes
- `AgentDeleted` — agent_id, user_id, workspace_ids
- `AgentAddedToWorkspace` — agent_id, workspace_id, user_id
- `AgentRemovedFromWorkspace` — agent_id, workspace_id, user_id

**Chat Context** (3 events):
- `ChatSessionStarted` — session_id, workspace_id, user_id, agent_id
- `ChatMessageSent` — message_id, session_id, workspace_id, user_id, role
- `ChatSessionDeleted` — session_id, workspace_id, user_id

**Notifications Context** (3 events):
- `NotificationCreated` — notification_id, user_id, type, workspace_id
- `NotificationRead` — notification_id, user_id
- `NotificationActionTaken` — notification_id, user_id, action

**Entity Relationship Manager** (7 events):
- `SchemaCreated` — schema_id, workspace_id, user_id, name
- `SchemaUpdated` — schema_id, workspace_id, user_id, changes
- `EntityCreated` — entity_id, workspace_id, user_id, entity_type, properties
- `EntityUpdated` — entity_id, workspace_id, user_id, changes
- `EntityDeleted` — entity_id, workspace_id, user_id
- `EdgeCreated` — edge_id, workspace_id, user_id, source_id, target_id, edge_type
- `EdgeDeleted` — edge_id, workspace_id, user_id

**Identity Context** (events adopt new schema but identity doesn't migrate its notifiers — see Technical Considerations):
- `MemberInvited` — workspace_id, inviter_id, invitee_email, invitee_user_id, role
- `MemberJoined` — workspace_id, user_id
- `MemberRemoved` — workspace_id, user_id
- `WorkspaceUpdated` — workspace_id, name
- `InvitationDeclined` — workspace_id, user_id

### Relationships

- Events reference aggregates by ID (not by association) — events are self-contained
- Events carry workspace_id for scoping/filtering, but don't enforce FK relationships
- The event_log table has no foreign keys (events are immutable facts, not relational data)

---

## Technical Considerations

### Affected Layers

| Layer | Changes |
|-------|---------|
| **Domain** | New `domain/events/` directories in each context containing event structs. Events are pure structs — no Ecto, no I/O. |
| **Application** | Use cases gain `opts[:event_bus]` injection (replacing `opts[:notifier]`). Use cases construct and emit event structs after transactions commit. |
| **Infrastructure** | New `Perme8.Events.EventBus`, `EventHandler` behaviour, `LegacyBridge`, `PostgresEventStore`. Existing notifier modules are eventually removed. Existing `WorkspaceInvitationSubscriber` converts to `EventHandler`. |
| **Interface** | LiveViews initially unchanged (legacy bridge). Later migrated to subscribe to structured event topics and pattern-match on event structs. |

### Where to Place the Event Infrastructure

The event bus infrastructure should live as a **top-level shared module** within the `jarga` app (since all apps already depend on `jarga` through the dependency graph), namespaced under `Perme8.Events`. This follows the existing pattern where `Jarga.PubSub` is defined in jarga and shared across all apps.

Alternatively, a dedicated `perme8_events` umbrella app could be created, but this adds dependency management overhead for minimal benefit at current scale. The architect should decide based on dependency graph impact.

```
apps/jarga/lib/perme8_events/
├── domain_event.ex            # `use Perme8.Events.DomainEvent` macro
├── event_bus.ex               # Central dispatcher (wraps PubSub)
├── event_handler.ex           # `use Perme8.Events.EventHandler` macro
├── event_store.ex             # Behaviour for persistence
├── event_registry.ex          # Catalog of all event types
├── test_event_bus.ex          # In-memory bus for tests
└── infrastructure/
    ├── pubsub_dispatcher.ex   # Phoenix.PubSub adapter
    ├── legacy_bridge.ex       # Tuple translation for backward compat
    ├── postgres_event_store.ex
    └── schemas/
        └── event_log_schema.ex
```

### Integration Points

| Integration | Description |
|-------------|-------------|
| **Phoenix.PubSub** (`Jarga.PubSub`) | EventBus wraps this for real-time dispatch. No change to the PubSub server itself. |
| **Existing notifiers** (6 modules) | Gradually replaced by EventBus.emit in use cases. During migration, LegacyBridge replicates their broadcast behavior. |
| **Existing WorkspaceInvitationSubscriber** | Converts to EventHandler behaviour. Same functionality, standardized pattern. |
| **LiveView subscriptions** (7+ LiveViews) | Initially unchanged via legacy bridge. Migrated in a later phase to structured event topics. |
| **Boundary library** | Event structs are exported from Domain boundaries. EventBus infrastructure is a shared dependency. |
| **Credo check: NoPubSubInContexts** | Still enforced — use cases call EventBus (infrastructure), not Phoenix.PubSub directly. The Credo check may need updating to also flag direct `Phoenix.PubSub.broadcast` in use case modules (currently only checks context modules). |

### Performance

- **Event dispatch latency**: Target <5ms for local PubSub broadcast (current Phoenix.PubSub is ~1ms). The EventBus adds struct construction overhead but no network I/O.
- **Event persistence**: Async (non-blocking). A failed persist should not prevent PubSub dispatch. Target <50ms for Ecto insert.
- **Handler throughput**: Each EventHandler GenServer processes events sequentially. For high-throughput events (e.g., ChatMessageSent), handlers should be lightweight or delegate to async workers.
- **Memory**: Event structs are small (~500 bytes). No concern at current scale.
- **event_log growth**: With ~44 event types and moderate usage, expect ~10K-100K events/day. Partition by `occurred_at` month if needed (P2).

### Security

- Events carry `actor_id` for attribution. All state-changing events should include the acting user.
- `workspace_id` enables workspace-scoped filtering. Events should never leak cross-workspace data.
- Event metadata should NOT contain sensitive data (passwords, tokens, PII beyond user IDs).
- The event_log table should be treated as an audit trail — read access restricted to admin operations.
- PubSub topics are process-scoped (only processes that subscribe receive messages). No new attack surface.

### Backward Compatibility Strategy

The migration uses a **dual-publish approach**:

1. **Phase 1-3**: Use cases emit structured events via EventBus. EventBus broadcasts to new `events:*` topics AND LegacyBridge broadcasts tuple messages to old topics. All existing LiveViews and the WorkspaceInvitationSubscriber continue working unchanged.

2. **Phase 4-5**: EventHandlers replace subscriber GenServers. LiveViews migrate to structured event subscriptions.

3. **Phase 6**: LegacyBridge and old notifier modules are deleted. Legacy topics are removed.

At no point should the system be in a broken state. Each phase is independently deployable.

---

## Edge Cases & Error Handling

1. **EventBus.emit called inside a transaction** → **Expected**: The existing Credo check `NoBroadcastInTransaction` catches this at compile time. Use cases must emit events AFTER `Repo.transact/1` returns `{:ok, result}`. Document this as a hard rule.

2. **EventHandler crashes processing an event** → **Expected**: GenServer restarts via supervisor. The event is lost for that handler (PubSub is fire-and-forget). P1 mitigation: persist events first, handlers can replay from store. P2 mitigation: dead-letter log for failed handler executions.

3. **EventStore persistence fails** → **Expected**: Log the error, do NOT fail the emit. PubSub dispatch still succeeds. Events are primarily for real-time reactivity; persistence is a secondary concern.

4. **Duplicate events emitted** → **Expected**: Handlers should be idempotent where possible. event_id provides deduplication key. For non-idempotent handlers (e.g., sending emails), use event_id to check if already processed.

5. **Legacy bridge produces incorrect tuple format** → **Expected**: Comprehensive translation tests for every existing event format. The bridge is temporary — errors here break existing LiveViews.

6. **Event struct missing required fields** → **Expected**: `@enforce_keys` catches this at compile time. The `DomainEvent.new/1` constructor raises `ArgumentError` for missing required fields.

7. **High-throughput event bursts (e.g., bulk ERM operations)** → **Expected**: EventBus supports `emit_all/2` for batch emission. Handlers should handle bursts gracefully (no N+1 queries per event).

8. **Chat events emitted for private conversations** → **Expected**: Chat events include workspace_id for scoping. EventHandlers that react to chat events must respect workspace membership. Chat events should NOT be broadcast to workspace-wide topics — only to session-specific or user-specific topics.

9. **Identity app not fully migrated** → **Expected**: Identity's existing notifiers continue working. They can optionally adopt event structs conforming to the shared schema, but identity is not required to use EventBus.emit until a future ticket. The LegacyBridge handles identity's tuple-format broadcasts for downstream consumers.

10. **EventHandler subscribes to topic with no events** → **Expected**: No-op. Handler sits idle. No errors. This is normal for newly registered handlers before producers are migrated.

---

## Acceptance Criteria

### Foundation
- [ ] `Perme8.Events.EventBus` module exists with `emit/2` and `emit_all/2` functions
- [ ] `Perme8.Events.DomainEvent` macro enforces base schema fields (event_id, event_type, aggregate_type, aggregate_id, occurred_at, metadata)
- [ ] `Perme8.Events.EventHandler` behaviour provides GenServer boilerplate with auto-subscription and `handle_event/1` routing
- [ ] `Perme8.Events.TestEventBus` captures events in-memory for testing
- [ ] Standardized topic naming convention is implemented and documented

### Event Structs
- [ ] All 27+ event structs defined across projects, documents, agents, chat, notifications, and ERM contexts
- [ ] Every event struct uses `@enforce_keys` for required fields
- [ ] Every event struct has a unique `event_type` string
- [ ] Event structs live in `domain/events/` within their owning context
- [ ] Event structs are exported from Domain boundaries

### Use Case Migration
- [ ] Jarga Projects use cases (create, update, delete) emit typed events via EventBus
- [ ] Jarga Documents use cases (create, delete, title, visibility, pinned) emit typed events via EventBus
- [ ] Agents use cases (update, delete, sync workspaces) emit typed events via EventBus
- [ ] Chat use cases (create session, save message, delete session) emit typed events via EventBus
- [ ] Notifications use cases (create, accept, decline) emit typed events via EventBus
- [ ] ERM use cases (entity CRUD, edge CRUD, schema CRUD) emit typed events via EventBus

### Legacy Compatibility
- [ ] LegacyBridge translates all existing ~15 tuple-format events correctly
- [ ] All existing LiveView tests pass without modification during migration
- [ ] All existing PubSub subscriptions in LiveViews receive events as before

### Cross-App Communication
- [ ] `WorkspaceInvitationSubscriber` is converted to an `EventHandler`
- [ ] Notifications context subscribes to identity, projects, documents, and agents events via EventHandler
- [ ] No direct cross-app function calls remain for event-driven concerns (notification creation, workspace sync, etc.)

### Testing
- [ ] Unit tests for every event struct (required fields, event_type uniqueness)
- [ ] Unit tests for EventBus.emit dispatching to PubSub
- [ ] Unit tests for EventHandler subscription and event routing
- [ ] Unit tests for LegacyBridge translation (one test per existing event format)
- [ ] Integration tests for full event flow: use case -> EventBus -> EventHandler -> side effect
- [ ] Use case tests use TestEventBus to assert correct events are emitted
- [ ] `mix boundary` passes with no violations
- [ ] `mix credo` passes (no PubSub calls in context modules)

### Cleanup (Post-Migration)
- [ ] LegacyBridge module removed
- [ ] All 6+ notifier infrastructure modules removed
- [ ] All 5+ notifier behaviour modules removed
- [ ] `opts[:notifier]` replaced with `opts[:event_bus]` in all use cases
- [ ] LiveViews subscribe to structured event topics and pattern-match on event structs

---

## Codebase Context

### Existing Patterns

**Notifier infrastructure** (6 modules, to be replaced):
- `apps/agents/lib/agents/infrastructure/notifiers/pub_sub_notifier.ex`
- `apps/identity/lib/identity/infrastructure/notifiers/pubsub_notifier.ex`
- `apps/identity/lib/identity/infrastructure/notifiers/email_and_pubsub_notifier.ex`
- `apps/jarga/lib/projects/infrastructure/notifiers/email_and_pubsub_notifier.ex`
- `apps/jarga/lib/documents/infrastructure/notifiers/pub_sub_notifier.ex`
- `apps/jarga/lib/notifications/infrastructure/notifiers/pubsub_notifier.ex`

**Notifier behaviours** (5 modules, to be replaced):
- `apps/agents/lib/agents/application/behaviours/pub_sub_notifier_behaviour.ex`
- `apps/identity/lib/identity/application/behaviours/pub_sub_notifier_behaviour.ex`
- `apps/jarga/lib/notifications/application/behaviours/pub_sub_notifier_behaviour.ex`
- Plus NotificationServiceBehaviour modules in projects and documents

**Only cross-app subscriber** (1 module, to be converted):
- `apps/jarga/lib/notifications/infrastructure/subscribers/workspace_invitation_subscriber.ex`

**PubSub server**: `Jarga.PubSub` — started in jarga's application.ex, configured across all endpoints in `config/config.exs` (lines 47, 57, 67, 131).

**Credo architectural enforcement**:
- `.credo/checks/no_pubsub_in_contexts.ex` — prevents `Phoenix.PubSub.broadcast` in context modules
- `.credo/checks/no_broadcast_in_transaction.ex` — prevents broadcasting inside `Repo.transaction`

**LiveView PubSub subscriptions** (7+ modules):
- `apps/jarga_web/lib/live/app_live/workspaces/show.ex` (line 617)
- `apps/jarga_web/lib/live/app_live/workspaces/index.ex` (lines 87-117)
- `apps/jarga_web/lib/live/app_live/documents/show.ex` (lines 30-31)
- `apps/jarga_web/lib/live/app_live/projects/show.ex` (line 201)
- `apps/jarga_web/lib/live/app_live/dashboard.ex` (lines 85-115)
- `apps/jarga_web/lib/live/notifications_live/on_mount.ex` (line 18)

### Affected Contexts

| App | Context | Change Type |
|-----|---------|-------------|
| `jarga` | Projects | Emit events, remove notifier |
| `jarga` | Documents | Emit events, remove notifier |
| `jarga` | Chat | Add events (net-new, zero PubSub today) |
| `jarga` | Notifications | Convert subscriber, emit events, remove notifier |
| `agents` | Agents | Emit events, remove notifier |
| `entity_relationship_manager` | ERM | Add events (net-new, no PubSub today) |
| `jarga_api` | API | Subscribe to events for external streaming (P2) |
| `identity` | Identity | Adopt event schema format (P1), keep existing notifiers during migration |
| `jarga_web` | LiveViews | Initially unchanged (legacy bridge), later migrate to structured events |

### Available Infrastructure to Leverage

- **Phoenix.PubSub** — battle-tested, already running as `Jarga.PubSub`
- **Boundary library** — compile-time enforcement of event struct exports
- **Credo checks** — existing architectural guards extend naturally to event patterns
- **DI via opts pattern** — already used in every use case (`opts[:notifier]`), trivially extends to `opts[:event_bus]`
- **GenServer supervision** — OTP supervisors already manage processes in every app
- **Ecto/PostgreSQL** — available for event_log persistence (P1)
- **Existing event-driven architecture plan** — `docs/plans/event-driven-architecture.md` contains detailed implementation design that aligns with this PRD

---

## Phasing Recommendations

### Part 1: Foundation + Event Structs + Use Case Migration (P0)

**Delivers ~80% of the value.** Independently deployable. The system operates in hybrid mode with the legacy bridge.

| Phase | Scope | Estimated Effort |
|-------|-------|-----------------|
| Phase 1 | Event Foundation (EventBus, EventHandler, DomainEvent macro, TestEventBus, LegacyBridge) | 1-2 weeks |
| Phase 2 | Define all domain event structs across all contexts | 1 week |
| Phase 3 | Migrate use cases to emit events (projects -> documents -> agents -> chat -> notifications -> ERM) | 2-3 weeks |

**Checkpoint**: Evaluate stability before proceeding to Part 2.

### Part 2: Handlers + LiveView Migration + Cleanup

| Phase | Scope | Estimated Effort |
|-------|-------|-----------------|
| Phase 4 | Convert subscriber to EventHandler, add new cross-context handlers | 1 week |
| Phase 5 | Migrate LiveViews to structured event subscriptions | 1 week |
| Phase 6 | Remove LegacyBridge, all notifiers, all notifier behaviours | 1 week |

### Part 3: Advanced (P1/P2, evaluate after Parts 1-2 ship)

| Phase | Scope | Estimated Effort |
|-------|-------|-----------------|
| Phase 7a | Event persistence (EventStore, event_log table, migrations) | 1 week |
| Phase 7b | Event registry + telemetry | 1 week |
| Phase 7c | Identity event schema adoption | 1 week |
| Phase 7d | Event replay, sagas, API streaming | 2+ weeks |

### Migration Order Within Part 1 (by risk/complexity)

1. **Projects** — 3 use cases, simplest events, well-tested. Start here.
2. **Documents** — 5 use cases, dual-topic broadcasts. Medium complexity.
3. **Agents** — 3 use cases, multi-workspace fan-out. Medium complexity.
4. **Chat** — Net-new events, no existing notifiers to migrate. Low risk.
5. **Notifications** — Subscriber conversion, accept/decline use cases. Medium complexity.
6. **ERM** — Net-new events, standalone app. Low risk.

---

## Open Questions

- [ ] **Event infrastructure location**: Should `Perme8.Events` live inside the `jarga` app (leveraging existing dependency graph) or in a new `perme8_events` umbrella app? The former is simpler but semantically odd (event infrastructure in a domain app). The architect should decide.
- [ ] **Identity migration scope**: The ticket lists 6 apps but not identity. Should identity's notifiers be left completely untouched, or should they adopt the event struct format (without switching to EventBus)? This PRD recommends P1 schema adoption.
- [ ] **Chat event granularity**: Should `ChatResponseReceived` (LLM response) be a separate event from `ChatMessageSent`? Both represent messages but from different actors (user vs. LLM). This PRD treats LLM responses as out of scope for the initial migration since they're streamed incrementally.
- [ ] **Event persistence priority**: The existing plan (docs/plans/event-driven-architecture.md) includes event persistence in Part 1. This PRD moves it to P1/Part 3 to reduce initial scope. Should persistence be P0?
- [ ] **Wildcard topic subscriptions**: Does Phoenix.PubSub support wildcard topic patterns like `"events:*"`? If not, EventHandler may need to subscribe to explicit topic lists. The architect should verify and design accordingly.
- [ ] **ERM dependency graph**: ERM is currently standalone. Adding event emission means it needs access to `Perme8.Events`. If events live in `jarga`, this creates a new dependency `entity_relationship_manager -> jarga`. Is this acceptable, or does this argue for a separate `perme8_events` app?

---

## Out of Scope

- **Full CQRS/Event Sourcing** — This is a PubSub event bus, not a full event store with projections and aggregate reconstruction.
- **External message brokers** (Kafka, RabbitMQ) — Build on Phoenix.PubSub and OTP. Evaluate external brokers only if scaling beyond single-node.
- **Identity notifier rewrite** — Identity's existing notifiers continue working. Schema adoption is P1.
- **alkali and perme8_tools** — Standalone apps with no cross-app communication. No changes needed.
- **Real-time CRDT sync events** — Document content sync (Yjs) operates outside the domain event model. Only document metadata events are in scope.
- **Authentication/authorization events** — User login, logout, session management events are deferred to a future ticket.
- **Webhook delivery** — jarga_api webhook dispatching is P2.
- **UI changes** — No user-facing UI changes. The event bus is a backend infrastructure concern. LiveView migrations change implementation, not user behavior.

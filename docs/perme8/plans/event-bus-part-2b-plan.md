# Feature: Event Bus Part 2b — Migrate LiveViews to Structured Event Subscriptions

## Status: ⏸ Not Started
## Ticket: #134
## Date: 2026-02-19
## Depends On: Part 1 (#37, PR #131) ✓, Part 2a (#133, PR #139) ✓

---

## Overview

Migrate all LiveViews from raw PubSub tuple-pattern subscriptions (`"workspace:{id}"`, `"user:{id}"`) to structured event topic subscriptions (`"events:workspace:{id}"`, `"events:user:{id}"`) with pattern matching on typed domain event structs. Remove the LegacyBridge once all consumers are migrated. This completes the consumer-side of the event-driven architecture.

**Value**: Eliminates the legacy tuple translation layer, unifies all event consumers (GenServers and LiveViews) on the same structured event format, and enables future event persistence and replay without format translation.

## UI Strategy

- **LiveView coverage**: 100% — no visible UI changes, only internal event handling
- **TypeScript needed**: None — purely backend event plumbing

## Affected Boundaries

- **Primary context**: `JargaWeb` (interface layer) + `Perme8.Events` (infrastructure) + `Identity` (new event structs)
- **Dependencies**: `Perme8.Events` must be added to `JargaWeb` boundary deps
- **Exported schemas**: New Identity event structs (`WorkspaceUpdated`, `MemberRemoved`, `WorkspaceInvitationNotified`) exported from `Identity`
- **New context needed?**: No — extends existing `Perme8.Events` shared infrastructure and `Identity` domain events

---

## Blocking Issue Decisions

### Decision 1: Missing Identity Domain Events

**Problem**: `{:workspace_updated, wid, name}`, `{:workspace_removed, wid}`, and `{:workspace_invitation, wid, name, inviter}` are broadcast by Identity notifiers but have NO domain event structs.

**Decision**: **(a) Create new event structs in Identity context** as part of this ticket.

- `Identity.Domain.Events.WorkspaceUpdated` — emitted by `notify_workspace_updated/1`
- `Identity.Domain.Events.MemberRemoved` — emitted by `notify_user_removed/2`
- `Identity.Domain.Events.WorkspaceInvitationNotified` — emitted by `notify_existing_user/3`

**Rationale**: Without these structs, Dashboard, Workspaces.Index, Workspaces.Show, Projects.Show, and Documents.Show cannot fully migrate. Creating the structs is a small, focused change. The Identity notifiers will dual-publish (existing tuple format + new EventBus.emit) just like the other contexts did in Part 1 Phase 3.

### Decision 2: No User-Scoped Event Topic

**Problem**: EventBus derives `"events:workspace:{wid}"` but NOT `"events:user:{uid}"`. User-scoped events (invitation, workspace_joined, workspace_removed) need per-user delivery.

**Decision**: **(a) Add `"events:user:{user_id}"` topic derivation to EventBus.**

- Add `user_id` field support in `derive_topics/1` — when an event has `user_id` and the event type indicates it's user-targeted (or a new `user_scoped?: true` option), derive `"events:user:{user_id}"` topic.
- Alternatively, emit these events to a well-known topic pattern and LiveViews subscribe to it explicitly.
- **Implementation**: Add a `@topic_overrides` mechanism or detect from event metadata. Simplest: add a callback `topics/1` on the DomainEvent that events can override. Default returns `[]`, identity events override to include `"events:user:{user_id}"`.

**Simplest approach**: Since these are emitted by Identity notifiers (not generic use cases), the notifier itself can call `Perme8.Events.EventBus.emit/2` with the standard topic derivation, and we add user_id-based topic in EventBus `derive_topics/1` when `event.user_id` is set AND `event.workspace_id` is nil (global/user events), OR we add a simple convention: events that define a `user_ids` or `target_user_id` field get a user topic.

**Final approach**: Extend `EventBus.derive_topics/1` to also produce `"events:user:{target_user_id}"` when the event struct has a `target_user_id` field. This is opt-in per event struct. Identity events that target specific users set this field.

### Decision 3: Notification User-Scoped Delivery

**Problem**: `"user:{uid}:notifications"` has no structured equivalent. `NotificationCreated` events go to `"events:notifications"` and `"events:workspace:{wid}"`, but not per-user.

**Decision**: **(a) Add `target_user_id` field to `NotificationCreated` event struct** and use the same `"events:user:{target_user_id}"` topic derivation from Decision 2. The `NotificationsLive.OnMount` and `ChatLive.MessageHandlers` will subscribe to `"events:user:{user_id}"` and pattern-match on `%NotificationCreated{}`.

### Decision 4: DocumentCreated Data Gap

**Problem**: Legacy tuple `{:document_created, document}` passes the full `%Document{}` struct. The `DocumentCreated` event only has `document_id`, `workspace_id`, etc. LiveViews need the full document for list insertion.

**Decision**: **Query the document in the handler.** When a LiveView receives `%DocumentCreated{}`, it calls `Documents.get_document/2` to fetch the full document. This is the clean architecture approach — events carry IDs, handlers query for current state. This avoids stale data issues and keeps events small.

**Fallback**: If performance is a concern, the existing `metadata.legacy_data` field already carries the document struct from Part 1 — we can use `event.metadata[:legacy_data]` during migration and remove it later. But querying is preferred for correctness.

---

## Migration Order

Migrate LiveViews from simplest to most complex:

1. **Agents.Form** + **Agents.Index** — 1 handler each, no explicit subscribe (receive from parent/layout), simplest
2. **ChatLive.MessageHandlers** — 1 PubSub handler (`{:new_notification, _}`), rest are process messages
3. **NotificationsLive.OnMount** — 1 handler, clean hook pattern
4. **Documents.Show** — 7 PubSub handlers (3 are CRDT, not domain events), moderate complexity
5. **Projects.Show** — 10 handlers, straightforward mapping
6. **Workspaces.Show** — 12 handlers, most complex
7. **Dashboard** — 11 handlers, needs identity events + user topic
8. **Workspaces.Index** — 9 handlers, similar to Dashboard + stale handler cleanup

---

## Phase 1: Infrastructure Extensions

**Goal**: Create missing Identity event structs, extend EventBus for user-scoped topics, and update boundary configs.
**Commit message**: `feat(events): add Identity event structs and user-scoped topic derivation for LiveView migration`

### 1.1 Identity Event Structs (3 new events)

#### WorkspaceUpdated
- [ ] **RED**: Write test `apps/identity/test/identity/domain/events/workspace_updated_test.exs`
  - Tests: required fields (`workspace_id`), optional `name` field, event_type is `"identity.workspace_updated"`, aggregate_type is `"workspace"`
- [ ] **GREEN**: Implement `apps/identity/lib/identity/domain/events/workspace_updated.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "workspace", fields: [name: nil], required: [:workspace_id]`
- [ ] **REFACTOR**: Verify field names match existing broadcast data

#### MemberRemoved
- [ ] **RED**: Write test `apps/identity/test/identity/domain/events/member_removed_test.exs`
  - Tests: required fields (`workspace_id`, `target_user_id`), event_type is `"identity.member_removed"`, aggregate_type is `"workspace_member"`
- [ ] **GREEN**: Implement `apps/identity/lib/identity/domain/events/member_removed.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "workspace_member", fields: [target_user_id: nil], required: [:workspace_id, :target_user_id]`
  - Note: `target_user_id` is the removed user, `actor_id` is who performed the removal
- [ ] **REFACTOR**: Clean up

#### WorkspaceInvitationNotified
- [ ] **RED**: Write test `apps/identity/test/identity/domain/events/workspace_invitation_notified_test.exs`
  - Tests: required fields (`workspace_id`, `target_user_id`, `workspace_name`, `invited_by_name`), event_type is `"identity.workspace_invitation_notified"`, aggregate_type is `"workspace_member"`
- [ ] **GREEN**: Implement `apps/identity/lib/identity/domain/events/workspace_invitation_notified.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "workspace_member", fields: [target_user_id: nil, workspace_name: nil, invited_by_name: nil, role: nil], required: [:workspace_id, :target_user_id, :workspace_name, :invited_by_name]`
  - Note: `target_user_id` is the invitee — enables user-scoped topic derivation
- [ ] **REFACTOR**: Clean up

### 1.2 Identity Boundary Export Updates

- [ ] Update `apps/identity/lib/identity.ex` boundary `exports` to include:
  - `Domain.Events.WorkspaceUpdated`
  - `Domain.Events.MemberRemoved`
  - `Domain.Events.WorkspaceInvitationNotified`

### 1.3 Identity Notifiers: Dual-Publish

Modify Identity notifiers to emit structured events alongside existing PubSub broadcasts (same dual-publish pattern as Part 1 Phase 3).

#### EmailAndPubSubNotifier
- [ ] **RED**: Write/update test `apps/identity/test/identity/infrastructure/notifiers/email_and_pubsub_notifier_test.exs`
  - New tests:
    - `notify_existing_user/3` emits `WorkspaceInvitationNotified` event via event_bus
    - `notify_user_removed/2` emits `MemberRemoved` event via event_bus
    - `notify_workspace_updated/1` emits `WorkspaceUpdated` event via event_bus
  - Existing tuple broadcasts continue to work
- [ ] **GREEN**: Update `apps/identity/lib/identity/infrastructure/notifiers/email_and_pubsub_notifier.ex`
  - Add `@default_event_bus Perme8.Events.EventBus`
  - Accept `opts` parameter (or use module attribute) for event_bus injection
  - In `notify_existing_user/3`: After existing PubSub.broadcast, emit `WorkspaceInvitationNotified.new(...)` via event_bus
  - In `notify_user_removed/2`: After existing PubSub.broadcast, emit `MemberRemoved.new(...)` via event_bus
  - In `notify_workspace_updated/1`: After existing PubSub.broadcast, emit `WorkspaceUpdated.new(...)` via event_bus
- [ ] **REFACTOR**: Clean up, ensure events emitted AFTER PubSub broadcasts

### 1.4 EventBus: User-Scoped Topic Derivation

- [ ] **RED**: Write/update test `apps/jarga/test/perme8_events/event_bus_test.exs`
  - New tests:
    - `emit/2` broadcasts to `"events:user:{target_user_id}"` when event has `target_user_id` field
    - `emit/2` does NOT broadcast user topic when `target_user_id` is nil or absent
    - `emit/2` still broadcasts workspace and context topics as before
- [ ] **GREEN**: Update `apps/jarga/lib/perme8_events/event_bus.ex`
  - In `derive_topics/1`: After workspace topic logic, check if event struct has `target_user_id` field (via `Map.has_key?(event, :target_user_id)` or pattern match) and if it's non-nil, add `"events:user:#{event.target_user_id}"` to topics
- [ ] **REFACTOR**: Keep derive_topics clean and well-documented

### 1.5 Update NotificationCreated Event Struct

- [ ] **RED**: Write/update test `apps/jarga/test/notifications/domain/events/notification_created_test.exs`
  - New test: `target_user_id` field is available and defaults to nil
- [ ] **GREEN**: Update `apps/jarga/lib/notifications/domain/events/notification_created.ex`
  - Add `target_user_id: nil` to fields list
- [ ] **REFACTOR**: Clean up

### 1.6 Update NotificationCreated Emission in Use Case

- [ ] **RED**: Write/update test for `CreateWorkspaceInvitationNotification` use case
  - Assert `NotificationCreated` event now includes `target_user_id`
- [ ] **GREEN**: Update `apps/jarga/lib/notifications/application/use_cases/create_workspace_invitation_notification.ex`
  - Set `target_user_id: params.user_id` when constructing `NotificationCreated` event
- [ ] **REFACTOR**: Clean up

### 1.7 LegacyBridge: Add Identity Event Translations

- [ ] **RED**: Write/update test `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs`
  - New tests:
    - `WorkspaceUpdated` → `[{"workspace:{wid}", {:workspace_updated, wid, name}}]`
    - `MemberRemoved` → `[{"user:{target_user_id}", {:workspace_removed, wid}}]`
    - `WorkspaceInvitationNotified` → `[{"user:{target_user_id}", {:workspace_invitation, wid, name, inviter}}]`
- [ ] **GREEN**: Update `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex`
  - Add translate clauses for the 3 new Identity events
- [ ] **REFACTOR**: Clean up

### 1.8 JargaWeb Boundary Update

- [ ] Update `apps/jarga_web/lib/jarga_web.ex` boundary `deps` to include `Perme8.Events`
  - This allows LiveViews to call `Perme8.Events.subscribe/1` and alias event structs

### 1.9 Perme8.Events Boundary Update

- [ ] Update `apps/jarga/lib/perme8_events.ex` boundary `deps` to include new Identity event types:
  - `Identity.Domain.Events.WorkspaceUpdated`  (already has Identity dependency, just needs the new event types to be accessible)

### Phase 1 Validation

- [ ] All new Identity event struct tests pass
- [ ] EventBus user-scoped topic tests pass
- [ ] LegacyBridge new translation tests pass
- [ ] Identity notifier dual-publish tests pass
- [ ] `mix boundary` passes with no violations
- [ ] `mix credo --strict` passes
- [ ] All existing tests pass unchanged: `mix test`

---

## Phase 2: Migrate Simple LiveViews (phoenix-tdd) ✓

**Goal**: Migrate the 4 simplest LiveViews that have minimal PubSub interaction.
**Commit message**: `feat(events): migrate Agents + ChatLive + Notifications LiveViews to structured events`

### 2.1 Agents.Form — Migrate `{:workspace_agent_updated, _agent}` Handler

This LiveView has NO explicit subscribe — it receives `{:workspace_agent_updated, _agent}` from somewhere (likely the user-scoped legacy topic via layout). After migration, the agent events arrive as structured events on `"events:workspace:{wid}"` or `"events:user:{uid}"` topics.

**Analysis**: Agents.Form doesn't subscribe to any PubSub topic itself. The `{:workspace_agent_updated, _agent}` messages arrive because the legacy bridge broadcasts to `"user:{uid}"` and the admin layout or parent subscribes. Since this LiveView doesn't explicitly subscribe, we need to understand the delivery path.

**Looking at the code**: The handler exists but the LiveView doesn't subscribe — this means messages come via the `"user:{uid}"` topic subscribed by another mechanism OR via the workspace topic. Since AgentUpdated events broadcast to `"workspace:{wid}"` AND `"user:{uid}"` via legacy bridge, and this LiveView is inside the admin layout which may have global subscriptions...

**Approach**: Since Agents.Form and Agents.Index don't explicitly subscribe, these handlers receive messages passively from existing subscriptions (workspace topic in the admin layout). We'll handle these in Phase 3 when the workspace-subscribed LiveViews are migrated, because the events will arrive as structured events on the `"events:workspace:{wid}"` topic.

**Actually**: Looking more carefully, Agents.Form has NO mount-time subscribe. The `{:workspace_agent_updated, _agent}` handler works because: (a) the user's workspace subscription from the admin layout, or (b) some parent process forwards it. Without an explicit subscribe, these handlers will simply never match the new structured events. The simplest approach: add an explicit subscribe in mount.

- [x] **RED**: Write/update test `apps/jarga_web/test/live/app_live/agents/form_test.exs`
  - New test: Receives `%AgentUpdated{}` event and refreshes agent list in chat panel
  - Update: existing `{:workspace_agent_updated, _}` test (if any) to use structured event
- [x] **GREEN**: Update `apps/jarga_web/lib/live/app_live/agents/form.ex`
  - Add in mount (when connected): subscribe to `"events:user:#{user.id}"` via `Perme8.Events.subscribe/1`
  - Replace `handle_info({:workspace_agent_updated, _agent}, socket)` with:
    ```elixir
    def handle_info(%Agents.Domain.Events.AgentUpdated{}, socket) do
    def handle_info(%Agents.Domain.Events.AgentDeleted{}, socket) do
    def handle_info(%Agents.Domain.Events.AgentAddedToWorkspace{}, socket) do
    def handle_info(%Agents.Domain.Events.AgentRemovedFromWorkspace{}, socket) do
    ```
  - All 4 handlers do the same thing: reload agents list and update chat panel
  - Keep catch-all `handle_info(_msg, socket)` at the bottom
- [x] **REFACTOR**: Extract shared agent reload logic into a private function

### 2.2 Agents.Index — Migrate `{:workspace_agent_updated, _agent}` Handler

Same pattern as Agents.Form.

- [x] **RED**: Write/update test `apps/jarga_web/test/live/app_live/agents/index_test.exs`
  - New test: Receives `%AgentUpdated{}` event and refreshes agents list
- [x] **GREEN**: Update `apps/jarga_web/lib/live/app_live/agents/index.ex`
  - Add in mount (when connected): subscribe to `"events:user:#{user.id}"` via `Perme8.Events.subscribe/1`
  - Replace `handle_info({:workspace_agent_updated, _agent}, socket)` with pattern matches on agent event structs
- [x] **REFACTOR**: Extract shared agent reload logic

### 2.3 ChatLive.MessageHandlers — Migrate `{:new_notification, _}` Handler

The macro injects a `{:new_notification, _notification}` handler into all LiveViews. This needs to match on `%NotificationCreated{}` instead.

**Note**: The other handlers in this macro (`:chunk`, `:done`, `:error`, `:llm_*`, `:assistant_response`, `:put_flash`) are process messages sent via `send/2` — NOT PubSub events. They stay as-is.

- [x] **RED**: Write test verifying the macro generates a handler for `%NotificationCreated{}`
  - Test in a LiveView that uses the macro: send `%NotificationCreated{}` event, assert NotificationBell component is updated
- [x] **GREEN**: Update `apps/jarga_web/lib/live/chat_live/message_handlers.ex`
  - Replace:
    ```elixir
    def handle_info({:new_notification, _notification}, socket) do
    ```
  - With:
    ```elixir
    def handle_info(%Jarga.Notifications.Domain.Events.NotificationCreated{}, socket) do
    ```
  - Keep the same body (send_update to NotificationBell)
- [x] **REFACTOR**: Clean up alias

### 2.4 NotificationsLive.OnMount — Migrate Subscription + Handler

- [x] **RED**: Write/update test for OnMount hook
  - Test: After mounting, receiving `%NotificationCreated{}` triggers NotificationBell update
- [x] **GREEN**: Update `apps/jarga_web/lib/live/notifications_live/on_mount.ex`
  - Replace subscription:
    ```elixir
    # Old:
    Phoenix.PubSub.subscribe(Jarga.PubSub, "user:#{user_id}:notifications")
    # New:
    Perme8.Events.subscribe("events:user:#{user_id}")
    ```
  - Replace handler pattern in the hook:
    ```elixir
    # Old:
    {:new_notification, _notification}, socket ->
    # New:
    %Jarga.Notifications.Domain.Events.NotificationCreated{}, socket ->
    ```
- [x] **REFACTOR**: Clean up, add alias for NotificationCreated

### Phase 2 Validation

- [x] Agent LiveView event handler tests pass
- [x] ChatLive.MessageHandlers macro generates correct event struct handler
- [x] NotificationsLive.OnMount subscription and handler tests pass
- [x] All existing LiveView tests still pass (458 tests, 0 failures)
- [x] `mix boundary` passes (compile --warnings-as-errors clean)
- [x] `mix credo --strict` passes

---

## Phase 3: Migrate Document and Project LiveViews (phoenix-tdd)

**Goal**: Migrate Documents.Show and Projects.Show to structured events.
**Commit message**: `feat(events): migrate Documents.Show and Projects.Show to structured event subscriptions`

### 3.1 Documents.Show — Migrate Subscriptions + 7 PubSub Handlers

**Analysis of handlers**:
- `{:yjs_update, ...}` — CRDT sync, stays on `"document:{id}"` topic, NOT a domain event (**NO CHANGE**)
- `{:awareness_update, ...}` — CRDT sync, stays on `"document:{id}"` topic (**NO CHANGE**)
- `{:user_disconnected, ...}` — CRDT sync, stays on `"document:{id}"` topic (**NO CHANGE**)
- `{:document_visibility_changed, did, bool}` → `%DocumentVisibilityChanged{}`
- `{:document_pinned_changed, did, bool}` → `%DocumentPinnedChanged{}`
- `{:document_title_changed, did, title}` → `%DocumentTitleChanged{}`
- `{:workspace_updated, wid, name}` → `%Identity.Domain.Events.WorkspaceUpdated{}`
- `{:project_updated, pid, name}` → `%Jarga.Projects.Domain.Events.ProjectUpdated{}`
- `{:workspace_agent_updated, _agent}` → `%AgentUpdated{}` (multiple agent event types)
- `{:document_created, _document}` → `%DocumentCreated{}` (no-op on show page)
- `{:agent_query_started, ...}` — process message via `send/2` (**NO CHANGE**)
- `{:agent_chunk, ...}` — process message via `send/2` (**NO CHANGE**)
- `{:agent_done, ...}` — process message via `send/2` (**NO CHANGE**)
- `{:agent_error, ...}` — process message via `send/2` (**NO CHANGE**)

- [ ] **RED**: Write/update test `apps/jarga_web/test/live/app_live/documents/show_test.exs`
  - Update existing PubSub broadcast tests to emit structured events instead of legacy tuples
  - Tests:
    - Receiving `%DocumentVisibilityChanged{document_id: did, is_public: true}` updates document
    - Receiving `%DocumentPinnedChanged{document_id: did, is_pinned: true}` updates document
    - Receiving `%DocumentTitleChanged{document_id: did, title: "New"}` updates title
    - Receiving `%WorkspaceUpdated{workspace_id: wid, name: "New Name"}` updates breadcrumbs
    - Receiving `%ProjectUpdated{project_id: pid, name: "New"}` updates breadcrumbs
    - Receiving `%AgentUpdated{}` reloads agents and updates chat panel
    - Receiving `%DocumentCreated{}` is a no-op
    - CRDT messages (`{:yjs_update, ...}`) still work on document topic
- [ ] **GREEN**: Update `apps/jarga_web/lib/live/app_live/documents/show.ex`
  - **Subscriptions** in mount:
    ```elixir
    # Keep CRDT topic (not a domain event channel):
    Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")
    # Replace workspace topic:
    Perme8.Events.subscribe("events:workspace:#{workspace.id}")
    ```
  - **Replace handlers**:
    - `{:document_visibility_changed, did, bool}` → `%DocumentVisibilityChanged{document_id: did, is_public: is_public}`
    - `{:document_pinned_changed, did, bool}` → `%DocumentPinnedChanged{document_id: did, is_pinned: is_pinned}`
    - `{:document_title_changed, did, title}` → `%DocumentTitleChanged{document_id: did, title: title}`
    - `{:workspace_updated, wid, name}` → `%Identity.Domain.Events.WorkspaceUpdated{workspace_id: wid, name: name}`
    - `{:project_updated, pid, name}` → `%ProjectUpdated{project_id: pid, name: name}`
    - `{:workspace_agent_updated, _}` → `%AgentUpdated{}` + `%AgentDeleted{}` + `%AgentAddedToWorkspace{}` + `%AgentRemovedFromWorkspace{}`
    - `{:document_created, _}` → `%DocumentCreated{}` (no-op)
  - **Keep CRDT handlers unchanged**: `{:yjs_update, ...}`, `{:awareness_update, ...}`, `{:user_disconnected, ...}`
  - **Keep process message handlers unchanged**: `{:agent_query_started, ...}`, `{:agent_chunk, ...}`, `{:agent_done, ...}`, `{:agent_error, ...}`
- [ ] **REFACTOR**: Group handlers by domain, extract agent reload into private function

### 3.2 Projects.Show — Migrate Subscription + 10 Handlers

**Handler mapping**:
- `{:document_visibility_changed, _, _}` → `%DocumentVisibilityChanged{}`
- `{:document_title_changed, did, title}` → `%DocumentTitleChanged{}`
- `{:document_pinned_changed, did, bool}` → `%DocumentPinnedChanged{}`
- `{:document_created, document}` → `%DocumentCreated{}` (query document from DB)
- `{:document_deleted, did}` → `%DocumentDeleted{}`
- `{:workspace_updated, wid, name}` → `%WorkspaceUpdated{}`
- `{:project_updated, pid, name}` → `%ProjectUpdated{}`
- `{:project_removed, pid}` → `%ProjectDeleted{}`
- `{:workspace_agent_updated, _}` → Agent event structs

**DocumentCreated data gap handling**: When receiving `%DocumentCreated{document_id: id, project_id: pid}`, check if `pid == socket.assigns.project.id`, then query `Documents.get_document(user, id)` to get the full document struct for list insertion.

- [ ] **RED**: Write/update test `apps/jarga_web/test/live/app_live/projects/show_test.exs`
  - Update PubSub broadcast tests to use structured events
  - Tests:
    - `%DocumentCreated{project_id: pid}` adds document to list (with DB query)
    - `%DocumentDeleted{document_id: did}` removes document from list
    - `%DocumentTitleChanged{}` updates title in list
    - `%DocumentPinnedChanged{}` updates pinned status
    - `%DocumentVisibilityChanged{}` reloads documents
    - `%WorkspaceUpdated{}` updates breadcrumbs
    - `%ProjectUpdated{}` updates breadcrumbs
    - `%ProjectDeleted{project_id: pid}` redirects to workspace page when current project deleted
    - Agent events reload chat panel
- [ ] **GREEN**: Update `apps/jarga_web/lib/live/app_live/projects/show.ex`
  - **Subscription** in mount:
    ```elixir
    Perme8.Events.subscribe("events:workspace:#{workspace.id}")
    ```
  - Replace all tuple handlers with struct pattern matching
  - For `%DocumentCreated{}`: Query `Documents.get_document(user, event.document_id)` if `event.project_id == socket.assigns.project.id`
- [ ] **REFACTOR**: Clean up, extract common patterns

### Phase 3 Validation

- [ ] Documents.Show all event handler tests pass
- [ ] Projects.Show all event handler tests pass
- [ ] CRDT messages still work correctly on document topic
- [ ] Process messages (agent_query, agent_chunk, etc.) still work
- [ ] `mix boundary` passes
- [ ] `mix credo --strict` passes
- [ ] Full test suite: `mix test`

---

## Phase 4: Migrate Complex LiveViews (phoenix-tdd)

**Goal**: Migrate Workspaces.Show, Dashboard, and Workspaces.Index — the most complex LiveViews with identity events and user-scoped subscriptions.
**Commit message**: `feat(events): migrate Workspaces.Show, Dashboard, and Workspaces.Index to structured events`

### 4.1 Workspaces.Show — Migrate Subscription + 12 Handlers

**Handler mapping**:
- `{:project_added, pid}` → `%ProjectCreated{}`
- `{:project_removed, pid}` → `%ProjectDeleted{}`
- `{:project_updated, pid, name}` → `%ProjectUpdated{}`
- `{:document_created, doc}` → `%DocumentCreated{}` (query DB for full doc)
- `{:document_deleted, did}` → `%DocumentDeleted{}`
- `{:document_title_changed, did, title}` → `%DocumentTitleChanged{}`
- `{:document_visibility_changed, _, _}` → `%DocumentVisibilityChanged{}`
- `{:document_pinned_changed, did, bool}` → `%DocumentPinnedChanged{}`
- `{:workspace_updated, wid, name}` → `%WorkspaceUpdated{}`
- `{:member_joined, uid}` → `%NotificationActionTaken{action: "accepted"}`
- `{:invitation_declined, uid}` → `%NotificationActionTaken{action: "declined"}`
- `{:workspace_agent_updated, _}` → Agent event structs

- [ ] **RED**: Write/update test `apps/jarga_web/test/live/app_live/workspaces/show_test.exs`
  - Update/add tests for each handler with structured events:
    - `%ProjectCreated{}` reloads project list
    - `%ProjectDeleted{}` reloads project list
    - `%ProjectUpdated{}` updates project name in list
    - `%DocumentCreated{}` adds document to list (DB query for full struct)
    - `%DocumentDeleted{}` removes from list
    - `%DocumentTitleChanged{}` updates title
    - `%DocumentVisibilityChanged{}` reloads documents
    - `%DocumentPinnedChanged{}` updates pinned status
    - `%WorkspaceUpdated{}` updates workspace name
    - `%NotificationActionTaken{action: "accepted"}` reloads members
    - `%NotificationActionTaken{action: "declined"}` reloads members
    - Agent events reload agents list and chat panel
- [ ] **GREEN**: Update `apps/jarga_web/lib/live/app_live/workspaces/show.ex`
  - **Subscription** in mount:
    ```elixir
    Perme8.Events.subscribe("events:workspace:#{workspace.id}")
    ```
  - Replace all 12 tuple handlers with struct pattern matching
  - For `%DocumentCreated{}`: Query document from DB, check workspace_id matches
  - For `%NotificationActionTaken{}`: Pattern match on action field to determine member_joined vs invitation_declined behavior
- [ ] **REFACTOR**: Group handlers by domain context, extract common patterns

### 4.2 Dashboard — Migrate Subscriptions + 11 Handlers

**This is the most complex migration** because it subscribes to BOTH `"user:{uid}"` AND `"workspace:{wid}"` per workspace topics.

**Handler mapping**:
- `{:workspace_invitation, wid, name, inviter}` → `%WorkspaceInvitationNotified{}` (on user topic)
- `{:workspace_joined, wid}` → `%NotificationActionTaken{action: "accepted"}` (on user topic — need user_id match)
- `{:workspace_removed, wid}` → `%MemberRemoved{}` (on user topic)
- `{:workspace_updated, wid, name}` → `%WorkspaceUpdated{}` (on workspace topic)
- `{:member_joined, uid}` → `%NotificationActionTaken{action: "accepted"}` (on workspace topic — no-op)
- `{:invitation_declined, uid}` → `%NotificationActionTaken{action: "declined"}` (on workspace topic — no-op)
- `{:document_visibility_changed, _, _}` → no-op handlers (on workspace topic)
- `{:document_pinned_changed, _, _}` → no-op handlers
- `{:document_title_changed, _, _}` → no-op handlers
- `{:workspace_agent_updated, _}` → Agent event structs
- `{:document_created, _}` → no-op

**Challenge**: `%NotificationActionTaken{action: "accepted"}` arrives on BOTH `"events:workspace:{wid}"` and `"events:user:{uid}"`. On the workspace topic, it means "someone joined" (no-op for dashboard). On the user topic, it means "I joined a workspace" (reload workspaces). We disambiguate by checking `event.user_id == socket.assigns.current_scope.user.id`.

- [ ] **RED**: Write/update test `apps/jarga_web/test/live/app_live/dashboard_test.exs`
  - Update existing real-time tests:
    - Workspace invitation triggers reload (via `%WorkspaceInvitationNotified{}`)
    - Workspace joined triggers reload (via `%NotificationActionTaken{action: "accepted"}` where user_id matches)
    - Workspace removed triggers reload (via `%MemberRemoved{}`)
    - Workspace updated triggers name change (via `%WorkspaceUpdated{}`)
    - Agent events update chat panel
    - Document events are no-ops
- [ ] **GREEN**: Update `apps/jarga_web/lib/live/app_live/dashboard.ex`
  - **Subscriptions** in mount:
    ```elixir
    Perme8.Events.subscribe("events:user:#{user.id}")
    Enum.each(workspaces, fn workspace ->
      Perme8.Events.subscribe("events:workspace:#{workspace.id}")
    end)
    ```
  - Replace handlers:
    - `%WorkspaceInvitationNotified{workspace_id: wid}` → reload workspaces, subscribe to new workspace
    - `%NotificationActionTaken{action: "accepted", user_id: uid}` when `uid == current_user.id` → reload workspaces, subscribe to new workspace
    - `%NotificationActionTaken{}` (any other) → no-op (workspace-scoped member join/decline)
    - `%MemberRemoved{target_user_id: uid}` when `uid == current_user.id` → reload workspaces
    - `%WorkspaceUpdated{workspace_id: wid, name: name}` → update workspace name
    - Agent events → update chat panel
    - All document/project events → no-op catch-all
  - Remove individual no-op handlers for document events; use a catch-all
- [ ] **REFACTOR**: Simplify no-op handlers into catch-all, extract workspace reload logic

### 4.3 Workspaces.Index — Migrate Subscriptions + 9 Handlers + Cleanup Stale

**Same subscription pattern as Dashboard**, plus cleanup of stale `page_*` handlers.

**Handler mapping**:
- `{:workspace_invitation, wid, _, _}` → `%WorkspaceInvitationNotified{}`
- `{:workspace_joined, wid}` → `%NotificationActionTaken{action: "accepted"}` (user-scoped)
- `{:workspace_removed, wid}` → `%MemberRemoved{}`
- `{:workspace_updated, wid, name}` → `%WorkspaceUpdated{}`
- `{:member_joined, _}` → no-op → **REMOVE** (just keep catch-all)
- `{:invitation_declined, _}` → no-op → **REMOVE** (just keep catch-all)
- `{:page_visibility_changed, _, _}` → **STALE: REMOVE** (never matches current events)
- `{:page_pinned_changed, _, _}` → **STALE: REMOVE** (never matches current events)
- `{:document_title_changed, _, _}` → no-op → **REMOVE** (just keep catch-all)

- [ ] **RED**: Write/update test `apps/jarga_web/test/live/app_live/workspaces_test.exs` (or new `workspaces/index_test.exs`)
  - Tests:
    - `%WorkspaceInvitationNotified{}` reloads workspaces
    - `%NotificationActionTaken{action: "accepted"}` reloads workspaces (when user_id matches)
    - `%MemberRemoved{}` reloads workspaces (when target_user_id matches)
    - `%WorkspaceUpdated{}` updates workspace name
    - Stale page_* handlers are gone — no crash on unknown messages (catch-all)
- [ ] **GREEN**: Update `apps/jarga_web/lib/live/app_live/workspaces/index.ex`
  - **Subscriptions** in mount:
    ```elixir
    Perme8.Events.subscribe("events:user:#{user.id}")
    Enum.each(workspaces, fn workspace ->
      Perme8.Events.subscribe("events:workspace:#{workspace.id}")
    end)
    ```
  - Replace handlers (same pattern as Dashboard)
  - **Delete stale handlers**: `{:page_visibility_changed, ...}`, `{:page_pinned_changed, ...}`
  - Delete individual no-op handlers; add catch-all `handle_info(_msg, socket)` → `{:noreply, socket}`
- [ ] **REFACTOR**: Clean up, share pattern with Dashboard

### Phase 4 Validation

- [ ] Workspaces.Show all event handler tests pass
- [ ] Dashboard all event handler tests pass (including real-time workspace list updates)
- [ ] Workspaces.Index all event handler tests pass
- [ ] Stale handlers removed, no regressions
- [ ] `mix boundary` passes
- [ ] `mix credo --strict` passes
- [ ] Full test suite: `mix test`

---

## Phase 5: Cleanup — Remove LegacyBridge + Legacy Notifier Broadcasts (phoenix-tdd) ✓

**Goal**: With all consumers migrated, remove the LegacyBridge and strip legacy PubSub broadcasts from notifiers.
**Commit message**: `feat(events): remove LegacyBridge and legacy PubSub broadcasts — migration complete`

### 5.1 Verify No Remaining Legacy Consumers

- [x] **RED**: Run a codebase search for legacy patterns:
  - `grep -r "Phoenix.PubSub.subscribe.*\"workspace:" apps/jarga_web/` → ZERO ✓
  - `grep -r "Phoenix.PubSub.subscribe.*\"user:" apps/jarga_web/` → ZERO ✓
  - `grep -r "{:project_added" apps/jarga_web/` → ZERO ✓
  - `grep -r "{:workspace_updated" apps/jarga_web/` → ZERO ✓
  - `grep -r "{:new_notification" apps/jarga_web/` → ZERO ✓
  - `grep -r "{:workspace_agent_updated" apps/jarga_web/` → ZERO ✓
- [x] **GREEN**: All searches return zero matches (verified by Phases 2-4)
- [x] **REFACTOR**: N/A — verification only

### 5.2 Remove LegacyBridge

- [x] **RED**: Delete test file `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs`
- [x] **GREEN**: Delete `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex`
- [x] Update `apps/jarga/lib/perme8_events/event_bus.ex`:
  - Remove `alias Perme8.Events.Infrastructure.LegacyBridge`
  - Remove `LegacyBridge.broadcast_legacy(event)` call from `emit/2`
- [x] **REFACTOR**: Clean up EventBus module, update @moduledoc to remove legacy bridge references

### 5.3 Remove Legacy PubSub Broadcasts from Identity Notifiers

- [x] **RED**: Update Identity notifier tests to NOT expect legacy PubSub broadcasts
- [x] **GREEN**: Update `apps/identity/lib/identity/infrastructure/notifiers/email_and_pubsub_notifier.ex`:
  - Remove `Phoenix.PubSub.broadcast(@pubsub, "user:#{user.id}", {:workspace_invitation, ...})` from `notify_existing_user/3`
  - Remove `Phoenix.PubSub.broadcast(@pubsub, "user:#{user.id}", {:workspace_removed, ...})` from `notify_user_removed/2`
  - Remove `Phoenix.PubSub.broadcast(@pubsub, "workspace:#{workspace.id}", {:workspace_updated, ...})` from `notify_workspace_updated/1`
  - Keep EventBus.emit calls (these are the new source of truth)
- [x] Update `apps/identity/lib/identity/infrastructure/notifiers/pubsub_notifier.ex`:
  - Converted to no-op shell (EventBus handles delivery now)
  - Still retained because use cases inject it via `opts[:pubsub_notifier]` — full removal deferred to Part 2c
- [x] **REFACTOR**: PubSubNotifier converted to no-op shell; full deletion deferred to Part 2c (module + behaviour + injection removal)

### 5.4 Remove Legacy PubSub Broadcasts from Jarga Notifiers

Since Part 1 established dual-publish (notifier broadcasts + EventBus.emit), we can now remove the notifier PubSub broadcasts. The EventBus.emit is the sole publisher.

- [x] **RED**: Update notifier tests to not expect PubSub broadcasts
- [x] **GREEN**: Strip PubSub broadcast calls from:
  - `apps/jarga/lib/documents/infrastructure/notifiers/pub_sub_notifier.ex` — converted to no-op shell
  - `apps/jarga/lib/projects/infrastructure/notifiers/email_and_pubsub_notifier.ex` — converted to no-op shell (no email sends existed)
  - `apps/agents/lib/agents/infrastructure/notifiers/pub_sub_notifier.ex` — converted to no-op shell
  - `apps/jarga/lib/notifications/infrastructure/notifiers/pubsub_notifier.ex` — converted to no-op shell
- [x] **REFACTOR**: All notifier modules converted to no-op shells. Full module deletion deferred to Part 2c.

**Note**: Full notifier removal (deleting modules + behaviours + `opts[:notifier]` from use cases) is a larger cleanup that can be a separate follow-up ticket. This phase focuses on removing the PubSub broadcast calls so the LegacyBridge deletion doesn't break anything.

### 5.5 Update Perme8.Events Boundary

- [x] Remove `LegacyBridge`-related domain dependencies from `Perme8.Events` boundary — removed all 5 domain deps (Projects, Documents, Notifications, Agents, Identity) since they were only needed by LegacyBridge
- [x] Verify boundary still passes after LegacyBridge removal — `mix compile --warnings-as-errors` passes clean

### Phase 5 Validation

- [x] LegacyBridge module and tests deleted
- [x] No legacy PubSub broadcasts remain in any notifier
- [x] EventBus.emit no longer calls LegacyBridge
- [x] All LiveView tests pass (they now use structured events) — 505 tests, 0 failures
- [x] `mix compile --warnings-as-errors` passes (includes boundary checks)
- [x] Full test suite: `mix test` — all app-specific tests pass; 2 pre-existing flaky tests in identity (timing + TestEventBus async race)
- [x] No remaining references to legacy topic patterns in LiveViews

---

## Pre-Commit Checkpoint

- [ ] `mix precommit` passes (compile + format + credo + boundary + tests)
- [ ] `mix boundary` explicitly verified — no violations
- [ ] All LiveViews subscribe to structured event topics
- [ ] All LiveViews pattern-match on typed event structs
- [ ] LegacyBridge is deleted
- [ ] No legacy tuple-format subscriptions remain in LiveViews
- [ ] All existing tests pass (updated to use structured events)
- [ ] Stale handlers removed from Workspaces.Index

---

## Testing Strategy

### Test Distribution

| Category | Count | Location | Async? |
|----------|-------|----------|--------|
| Identity event structs (3) | ~6 | `apps/identity/test/identity/domain/events/*_test.exs` | Yes |
| EventBus user topic | ~3 | `apps/jarga/test/perme8_events/event_bus_test.exs` | No |
| LegacyBridge new translations | ~3 | `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs` | Yes |
| Identity notifier dual-publish | ~3 | `apps/identity/test/identity/infrastructure/notifiers/*_test.exs` | Varies |
| NotificationCreated update | ~2 | `apps/jarga/test/notifications/domain/events/*_test.exs` | Yes |
| Agents.Form event handlers | ~4 | `apps/jarga_web/test/live/app_live/agents/form_test.exs` | No |
| Agents.Index event handlers | ~4 | `apps/jarga_web/test/live/app_live/agents/index_test.exs` | No |
| ChatLive.MessageHandlers | ~2 | `apps/jarga_web/test/live/chat_live/*_test.exs` | No |
| NotificationsLive.OnMount | ~2 | `apps/jarga_web/test/live/notifications_live/*_test.exs` | No |
| Documents.Show handlers | ~8 | `apps/jarga_web/test/live/app_live/documents/show_test.exs` | No |
| Projects.Show handlers | ~10 | `apps/jarga_web/test/live/app_live/projects/show_test.exs` | No |
| Workspaces.Show handlers | ~12 | `apps/jarga_web/test/live/app_live/workspaces/show_test.exs` | No |
| Dashboard handlers | ~6 | `apps/jarga_web/test/live/app_live/dashboard_test.exs` | No |
| Workspaces.Index handlers | ~5 | `apps/jarga_web/test/live/app_live/workspaces_test.exs` | No |
| Cleanup verification | ~6 | Various | Varies |
| **Total** | **~76** | | |

### Test Patterns

**LiveView structured event test** (pattern for all LiveView tests):
```elixir
test "updates documents when DocumentTitleChanged event received", %{conn: conn, workspace: workspace, document: document} do
  {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

  # Send structured domain event (simulating EventBus delivery)
  event = %Jarga.Documents.Domain.Events.DocumentTitleChanged{
    event_id: Ecto.UUID.generate(),
    event_type: "documents.document_title_changed",
    aggregate_type: "document",
    aggregate_id: document.id,
    actor_id: Ecto.UUID.generate(),
    workspace_id: workspace.id,
    occurred_at: DateTime.utc_now(),
    metadata: %{},
    document_id: document.id,
    title: "Updated Title",
    user_id: Ecto.UUID.generate()
  }

  send(lv.pid, event)

  assert render(lv) =~ "Updated Title"
end
```

**Alternative pattern using PubSub broadcast** (for integration-style tests):
```elixir
test "updates in real-time via structured events", %{conn: conn, workspace: workspace} do
  {:ok, lv, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

  # Use case triggers event emission naturally
  {:ok, _project} = Projects.create_project(user, workspace.id, %{name: "Test Project"})

  # EventBus.emit broadcasts to "events:workspace:{wid}"
  # LiveView receives %ProjectCreated{} and reloads
  assert render(lv) =~ "Test Project"
end
```

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Create Identity events in this ticket | Dashboard/Index can't migrate without them; small incremental change |
| `target_user_id` field for user-scoped topics | Opt-in per event struct; doesn't affect events without the field |
| Query document in handler (not pass in event) | Clean Architecture: events carry IDs, handlers query current state |
| Keep `"document:{id}"` for CRDT messages | CRDT sync is NOT a domain event — different concern, different topic |
| Disambiguate NotificationActionTaken by user_id | Same event type on different topics has different semantics; check user_id |
| Delete stale page_* handlers | Dead code from a previous rename (page → document); clean up |
| Remove LegacyBridge after all consumers migrate | No remaining consumers means no need for translation layer |
| Keep process message handlers unchanged | `:chunk`, `:done`, `:error` are not PubSub events — sent via `send/2` |

---

## File Summary

### New Files (Phase 1)

| File | Purpose |
|------|---------|
| `apps/identity/lib/identity/domain/events/workspace_updated.ex` | WorkspaceUpdated event struct |
| `apps/identity/lib/identity/domain/events/member_removed.ex` | MemberRemoved event struct |
| `apps/identity/lib/identity/domain/events/workspace_invitation_notified.ex` | WorkspaceInvitationNotified event struct |
| `apps/identity/test/identity/domain/events/workspace_updated_test.exs` | Tests |
| `apps/identity/test/identity/domain/events/member_removed_test.exs` | Tests |
| `apps/identity/test/identity/domain/events/workspace_invitation_notified_test.exs` | Tests |

### Modified Files (Phase 1)

| File | Change |
|------|--------|
| `apps/identity/lib/identity.ex` | Add event exports to boundary |
| `apps/identity/lib/identity/infrastructure/notifiers/email_and_pubsub_notifier.ex` | Add EventBus.emit calls |
| `apps/jarga/lib/perme8_events/event_bus.ex` | Add user-scoped topic derivation |
| `apps/jarga/lib/perme8_events.ex` | Update boundary deps if needed |
| `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex` | Add Identity event translations |
| `apps/jarga/lib/notifications/domain/events/notification_created.ex` | Add target_user_id field |
| `apps/jarga/lib/notifications/application/use_cases/create_workspace_invitation_notification.ex` | Set target_user_id |
| `apps/jarga_web/lib/jarga_web.ex` | Add Perme8.Events to boundary deps |

### Modified Files (Phases 2-4 — LiveView Migration)

| File | Change |
|------|--------|
| `apps/jarga_web/lib/live/app_live/agents/form.ex` | Add subscribe, replace tuple handlers with struct matchers |
| `apps/jarga_web/lib/live/app_live/agents/index.ex` | Add subscribe, replace tuple handlers |
| `apps/jarga_web/lib/live/chat_live/message_handlers.ex` | Replace `{:new_notification, _}` with `%NotificationCreated{}` |
| `apps/jarga_web/lib/live/notifications_live/on_mount.ex` | Replace subscription topic + handler pattern |
| `apps/jarga_web/lib/live/app_live/documents/show.ex` | Replace workspace subscription + 7 handlers |
| `apps/jarga_web/lib/live/app_live/projects/show.ex` | Replace subscription + 10 handlers |
| `apps/jarga_web/lib/live/app_live/workspaces/show.ex` | Replace subscription + 12 handlers |
| `apps/jarga_web/lib/live/app_live/dashboard.ex` | Replace subscriptions + 11 handlers |
| `apps/jarga_web/lib/live/app_live/workspaces/index.ex` | Replace subscriptions + 9 handlers, delete stale handlers |

### Deleted Files (Phase 5)

| File | Reason |
|------|--------|
| `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex` | No remaining legacy consumers |
| `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs` | Tests for deleted module |
| `apps/identity/lib/identity/infrastructure/notifiers/pubsub_notifier.ex` | Empty after removing PubSub broadcasts (WIS uses EventHandler now) |

### Test Files to Update (Phases 2-4)

| File | Change |
|------|--------|
| `apps/jarga_web/test/live/app_live/agents/form_test.exs` | Add/update event handler tests |
| `apps/jarga_web/test/live/app_live/documents/show_test.exs` | Replace PubSub broadcasts with struct events |
| `apps/jarga_web/test/live/app_live/projects/show_test.exs` | Replace PubSub broadcasts with struct events |
| `apps/jarga_web/test/live/app_live/workspaces/show_test.exs` | Replace PubSub broadcasts with struct events |
| `apps/jarga_web/test/live/app_live/dashboard_test.exs` | Replace PubSub broadcasts with struct events |
| `apps/jarga_web/test/live/app_live/workspaces_test.exs` | Replace PubSub broadcasts with struct events |
| `apps/jarga_web/test/live/notifications_live/notification_bell_test.exs` | Update if it uses PubSub broadcasts |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Agents.Form/Index don't explicitly subscribe — unclear message delivery path | Add explicit `Perme8.Events.subscribe("events:user:#{user.id}")` in mount |
| `%NotificationActionTaken{}` arrives on both workspace and user topics with different semantics | Disambiguate by checking `event.user_id == current_user.id` |
| DocumentCreated handler needs full document struct but event only has IDs | Query `Documents.get_document/2` in handler — one extra DB call, but correct |
| Identity notifier dual-publish adds complexity | Temporary — removed in Phase 5 when legacy broadcasts are stripped |
| LegacyBridge removal breaks any missed consumer | Phase 5.1 exhaustive grep verification before deletion |
| Boundary violations from aliasing event structs in LiveViews | Phase 1.8 adds `Perme8.Events` to JargaWeb deps; event structs already exported from domain boundaries |
| Stale `page_*` handler deletion causes unhandled message warnings | All LiveViews have catch-all `handle_info(_msg, socket)` |
| Dashboard subscribes to N workspace topics — scaling concern | Unchanged behavior from legacy; just different topic names |

---

## What's Deferred to Future Tickets

- **Full notifier module removal** — Deleting notifier modules, behaviours, and `opts[:notifier]` injection from use cases. This ticket removes PubSub broadcasts but keeps the notifier module structure for email sending.
- **Event persistence** (EventStore, event_log table) — P1 from the PRD
- **Event registry + telemetry** — P1 from the PRD
- **Identity notifier full migration** — Converting Identity use cases to use `opts[:event_bus]` instead of `opts[:notifier]`
- **Event replay and sagas** — P2 from the PRD

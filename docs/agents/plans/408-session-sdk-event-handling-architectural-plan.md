# Feature: Handle OpenCode SDK Events in Session Entity Lifecycle

**Ticket**: [#408](https://github.com/platform-q-ai/perme8/issues/408)
**Parent**: [#400](https://github.com/platform-q-ai/perme8/issues/400) — Session domain entity and lifecycle states
**Status**: ⏳ In Progress

## Overview

The Session domain entity (introduced in #400) models lifecycle states but has no systematic handling for the 32 event types emitted by the OpenCode SDK. This plan creates the bridge between raw SDK events and the Session domain model — classifying events, extending the Session entity with tracking fields, defining new domain events, and establishing a dedicated event handler as the single entry point for SDK-event-to-Session processing.

The work is domain + infrastructure only; UI rendering is out of scope.

## App Ownership

| Artifact | App | Path |
|----------|-----|------|
| **Owning app** | `agents` | `apps/agents/` |
| **Repo** | `Agents.Repo` | — |
| **Migrations** | `agents` | `apps/agents/priv/repo/migrations/` |
| **Domain entities** | `agents` | `apps/agents/lib/agents/sessions/domain/entities/` |
| **Domain policies** | `agents` | `apps/agents/lib/agents/sessions/domain/policies/` |
| **Domain events** | `agents` | `apps/agents/lib/agents/sessions/domain/events/` |
| **Infrastructure handlers** | `agents` | `apps/agents/lib/agents/sessions/infrastructure/` |
| **Tests** | `agents` | `apps/agents/test/agents/sessions/` |
| **Feature files (UI)** | `agents_web` | NOT modified by this ticket |

All artifacts belong to the `agents` app per `docs/app_ownership.md`. No other app's Repo is used.

## UI Strategy

- **LiveView coverage**: 0% — this ticket is domain + infrastructure only
- **TypeScript needed**: None — no UI work in scope

## Affected Boundaries

- **Primary context**: `Agents.Sessions`
- **Dependencies**: `Perme8.Events` (DomainEvent macro, EventBus)
- **Exported schemas**: `Session` entity (already exported via boundary)
- **New context needed?**: No — this extends the existing `Agents.Sessions` context

---

## Phase 1: SDK Event Type Constants and Relevance Classification

**Goal**: Create a module that explicitly classifies all 32 SDK event types as "handled" or "not relevant" to the Session entity. This is the foundation for routing events through the handler.

### 1.1 SdkEventTypes — Event Type Constants and Classification

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/sdk_event_types_test.exs`
  - Tests:
    - `handled_types/0` returns exactly 17 event type strings
    - `ignored_types/0` returns exactly 15 event type strings
    - `handled?/1` returns `true` for all 17 handled types
    - `handled?/1` returns `false` for all 15 ignored types
    - `handled?/1` returns `false` for an unknown event type
    - `all_types/0` returns exactly 32 types (union of handled + ignored)
    - Handled and ignored sets are disjoint (no overlap)
    - Every known SDK event type appears in exactly one list
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/sdk_event_types.ex`
  - Module: `Agents.Sessions.Domain.Policies.SdkEventTypes`
  - Module attribute `@handled_types` with 17 types:
    - `"server.connected"`, `"server.instance.disposed"`
    - `"session.created"`, `"session.updated"`, `"session.deleted"`, `"session.status"`, `"session.idle"`, `"session.compacted"`, `"session.diff"`, `"session.error"`
    - `"message.updated"`, `"message.removed"`, `"message.part.updated"`, `"message.part.removed"`
    - `"permission.updated"`, `"permission.replied"`
    - `"file.edited"`
  - Module attribute `@ignored_types` with 15 types:
    - `"installation.updated"`, `"installation.update-available"`, `"lsp.client.diagnostics"`, `"lsp.updated"`, `"todo.updated"`, `"command.executed"`, `"vcs.branch.updated"`, `"tui.prompt.append"`, `"tui.command.execute"`, `"tui.toast.show"`, `"pty.created"`, `"pty.updated"`, `"pty.exited"`, `"pty.deleted"`, `"file.watcher.updated"`
  - Public functions: `handled_types/0`, `ignored_types/0`, `all_types/0`, `handled?/1`
  - Pure module — no I/O, no Repo
- [x] **REFACTOR**: Ensure @moduledoc documents the classification rationale for ignored types

### Phase 1 Validation
- [x] All tests pass with `mix test apps/agents/test/agents/sessions/domain/policies/sdk_event_types_test.exs` (milliseconds, no I/O)

---

## Phase 2: Error Classification Policy

**Goal**: Create a policy that classifies SDK error categories as recoverable or terminal, determining whether the session should transition to `failed` or remain `running` with retry metadata.

### 2.1 SdkErrorPolicy — Error Category Classification

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/sdk_error_policy_test.exs`
  - Tests:
    - `classify/1` with `"auth"` returns `{:terminal, :auth}`
    - `classify/1` with `"abort"` returns `{:terminal, :abort}`
    - `classify/1` with `"api"` returns `{:recoverable, :api}`
    - `classify/1` with `"output_length"` returns `{:recoverable, :output_length}`
    - `classify/1` with `"rate_limit"` returns `{:recoverable, :rate_limit}`
    - `classify/1` with `nil` returns `{:terminal, :unknown}`
    - `classify/1` with unrecognized string returns `{:terminal, :unknown}` (fail-safe)
    - `terminal?/1` returns `true` for terminal categories, `false` for recoverable
    - `recoverable?/1` returns `true` for recoverable categories, `false` for terminal
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/sdk_error_policy.ex`
  - Module: `Agents.Sessions.Domain.Policies.SdkErrorPolicy`
  - Pure functions — no I/O, no Repo
  - `classify/1` takes an error category string, returns `{:terminal | :recoverable, atom()}`
  - `terminal?/1` and `recoverable?/1` convenience predicates
  - Terminal: `"auth"`, `"abort"`, unknown/nil
  - Recoverable: `"api"`, `"output_length"`, `"rate_limit"`
- [x] **REFACTOR**: Ensure exhaustive @doc for all public functions

### Phase 2 Validation
- [x] All tests pass with `mix test apps/agents/test/agents/sessions/domain/policies/sdk_error_policy_test.exs` (milliseconds, no I/O)

---

## Phase 3: Extend Session Entity with SDK Event Tracking Fields

**Goal**: Add new fields to the Session struct for tracking SDK event state — message counts, streaming, errors, permissions, retry metadata, file edits, compaction, and session metadata.

### 3.1 Session Entity — New SDK Tracking Fields

- [x] **RED**: Write additional tests in `apps/agents/test/agents/sessions/domain/entities/session_test.exs`
  - Tests:
    - `new/1` with SDK tracking fields: `message_count`, `streaming_active`, `active_tool_calls`, `error_category`, `error_recoverable`, `permission_context`, `retry_attempt`, `retry_message`, `retry_next_at`, `file_edits`, `compacted`, `sdk_session_title`, `sdk_share_status`, `last_event_id`
    - Default values: `message_count: 0`, `streaming_active: false`, `active_tool_calls: 0`, `error_category: nil`, `error_recoverable: nil`, `permission_context: nil`, `retry_attempt: 0`, `retry_message: nil`, `retry_next_at: nil`, `file_edits: []`, `compacted: false`, `sdk_session_title: nil`, `sdk_share_status: nil`, `last_event_id: nil`
    - `update/2` creates a new struct with merged fields (immutable update)
    - `update/2` preserves existing fields not included in the update map
    - `track_message/1` increments `message_count` by 1
    - `remove_message/1` decrements `message_count` by 1 (min 0)
    - `start_streaming/1` sets `streaming_active` to `true`
    - `stop_streaming/1` sets `streaming_active` to `false`
    - `increment_tool_calls/1` increments `active_tool_calls`
    - `decrement_tool_calls/1` decrements `active_tool_calls` (min 0)
    - `record_file_edit/2` appends a file path to `file_edits` (deduplicates by path)
    - `mark_compacted/1` sets `compacted` to `true`
- [x] **GREEN**: Extend `apps/agents/lib/agents/sessions/domain/entities/session.ex`
  - Add new fields to `defstruct` with defaults
  - Update `@type t` to include new fields
  - Add `update/2` — `struct(session, attrs)` for immutable updates
  - Add convenience functions: `track_message/1`, `remove_message/1`, `start_streaming/1`, `stop_streaming/1`, `increment_tool_calls/1`, `decrement_tool_calls/1`, `record_file_edit/2`, `mark_compacted/1`
  - All functions are pure — return new Session struct
- [x] **REFACTOR**: Group fields logically in defstruct (existing → message tracking → error → permission → retry → file → metadata → idempotency)

### Phase 3 Validation
- [x] All Session entity tests pass (milliseconds, no I/O)
- [x] Existing `Session.new/1`, `from_task/1`, `from_task/2` tests still pass (backward compatibility)

---

## Phase 4: New Domain Events

**Goal**: Define 10 new domain events for SDK event handling. Each follows the existing `DomainEvent` macro pattern established in #400.

### 4.1 SessionErrorOccurred

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_error_occurred_test.exs`
  - Tests: `event_type/0` returns `"sessions.session_error_occurred"`, `aggregate_type/0` returns `"session"`, `new/1` with valid attrs creates event with `task_id`, `user_id`, `error_message`, `error_category`, `recoverable`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_error_occurred.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, error_message: nil, error_category: nil, recoverable: false], required: [:task_id, :error_message]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.2 SessionPermissionRequested

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_permission_requested_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`, `tool_name`, `action_description`, `permission_id`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_permission_requested.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, tool_name: nil, action_description: nil, permission_id: nil], required: [:task_id, :permission_id]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.3 SessionPermissionResolved

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_permission_resolved_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`, `permission_id`, `outcome` (allowed/denied/always)
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_permission_resolved.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, permission_id: nil, outcome: nil], required: [:task_id, :permission_id, :outcome]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.4 SessionMessageUpdated

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_message_updated_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`, `message_count`, `streaming_active`, `active_tool_calls`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_message_updated.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, message_count: 0, streaming_active: false, active_tool_calls: 0], required: [:task_id]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.5 SessionCompacted

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_compacted_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_compacted.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil], required: [:task_id]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.6 SessionMetadataUpdated

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_metadata_updated_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`, `title`, `share_status`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_metadata_updated.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, title: nil, share_status: nil], required: [:task_id]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.7 SessionFileEdited

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_file_edited_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`, `file_path`, `edit_summary`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_file_edited.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, file_path: nil, edit_summary: nil], required: [:task_id, :file_path]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.8 SessionDiffProduced

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_diff_produced_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`, `diff_summary`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_diff_produced.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, diff_summary: nil], required: [:task_id]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.9 SessionServerConnected

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_server_connected_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_server_connected.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil], required: [:task_id]`
- [x] **REFACTOR**: Ensure @moduledoc

### 4.10 SessionRetrying

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/events/session_retrying_test.exs`
  - Tests: `event_type/0`, `aggregate_type/0`, `new/1` with `task_id`, `user_id`, `attempt`, `message`, `next_at`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/session_retrying.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "session", fields: [task_id: nil, user_id: nil, attempt: 0, message: nil, next_at: nil], required: [:task_id, :attempt]`
- [x] **REFACTOR**: Ensure @moduledoc

### Phase 4 Validation
- [x] All 10 new domain event tests pass (milliseconds, no I/O)
- [x] Existing domain event tests still pass

---

## Phase 5: Session Lifecycle Policy Extensions ✓

**Goal**: Extend `SessionLifecyclePolicy` with new transitions needed for SDK event handling, and add a new `SdkEventPolicy` that maps raw SDK events to Session state transitions and domain events.

### 5.1 SessionLifecyclePolicy — New Transitions

- [x] **RED**: Add tests to `apps/agents/test/agents/sessions/domain/policies/session_lifecycle_policy_test.exs`
  - Tests:
    - `can_transition?(:awaiting_feedback, :running)` returns `true` (permission resolved → back to running)
    - `can_transition?(:awaiting_feedback, :failed)` returns `true` (permission denied terminally)
    - `can_transition?(:awaiting_feedback, :cancelled)` returns `true` (session deleted while awaiting)
    - `can_transition?(:running, :idle)` returns `true` (session completes normally but goes idle not completed)
    - `can_transition?(:idle, :running)` returns `true` (session starts running from idle)
    - `can_transition?(:idle, :completed)` returns `true` (session completed from idle state)
    - `can_transition?(:idle, :failed)` returns `true` (session fails from idle)
    - `can_transition?(:idle, :cancelled)` returns `true` (session cancelled from idle)
    - All existing transitions still valid (backward compatibility)
- [x] **GREEN**: Add new transitions to `@valid_transitions` MapSet in `apps/agents/lib/agents/sessions/domain/policies/session_lifecycle_policy.ex`
  - Add: `{:awaiting_feedback, :running}`, `{:awaiting_feedback, :failed}`, `{:awaiting_feedback, :cancelled}`, `{:running, :idle}`, `{:idle, :running}`, `{:idle, :completed}`, `{:idle, :failed}`, `{:idle, :cancelled}`
- [x] **REFACTOR**: Ensure all transitions are documented in @moduledoc

### 5.2 SdkEventPolicy — SDK Event to Session State Mapping

- [x] **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/sdk_event_policy_test.exs`
  - Tests (each test receives a Session struct and a raw SDK event map, returns `{:ok, updated_session, [domain_events]}` or `{:skip, reason}`):
    - **session.status — busy**: Running session stays running, no new domain events (state confirmation)
    - **session.status — busy**: Non-running session (e.g., starting) → no state change (session not yet in SDK's purview)
    - **session.status — idle (was running)**: Running session → transitions to `:completed`, emits `SessionStateChanged`
    - **session.status — idle (not running)**: Idle session stays idle, no transition
    - **session.status — retry**: Running session stays running, updates retry metadata (`retry_attempt`, `retry_message`, `retry_next_at`), emits `SessionRetrying`
    - **session.error — terminal**: Running session → `:failed`, sets `error`, `error_category`, `error_recoverable: false`, emits `SessionErrorOccurred` + `SessionStateChanged`
    - **session.error — recoverable**: Running session stays `:running`, sets `error`, `error_category`, `error_recoverable: true`, emits `SessionErrorOccurred`
    - **session.error — on terminal session**: Already-failed session → `{:skip, :already_terminal}`
    - **permission.updated**: Running session → `:awaiting_feedback`, sets `permission_context`, emits `SessionPermissionRequested` + `SessionStateChanged`
    - **permission.updated on non-running session**: → `{:skip, :invalid_state}`
    - **permission.replied**: Awaiting feedback → `:running`, clears `permission_context`, emits `SessionPermissionResolved` + `SessionStateChanged`
    - **permission.replied (denied terminally)**: Awaiting feedback → `:cancelled`, emits `SessionPermissionResolved` + `SessionStateChanged`
    - **message.updated**: Increments `message_count`, emits `SessionMessageUpdated`
    - **message.removed**: Decrements `message_count` (min 0), emits `SessionMessageUpdated`
    - **message.part.updated (text delta)**: Sets `streaming_active: true`, no domain event (debounced)
    - **message.part.updated (tool-start)**: Increments `active_tool_calls`, emits `SessionMessageUpdated`
    - **message.part.updated (tool complete)**: Decrements `active_tool_calls`, emits `SessionMessageUpdated`
    - **message.part.removed**: Adjusts counts as needed
    - **session.idle**: If running → `:completed`, stops streaming, emits `SessionStateChanged`; if already idle → no-op
    - **session.created**: Initializes fields from event properties, no state transition (session already exists)
    - **session.updated**: Updates `sdk_session_title`, `sdk_share_status`, emits `SessionMetadataUpdated`
    - **session.deleted**: Any non-terminal state → `:cancelled`, emits `SessionStateChanged`
    - **session.compacted**: Sets `compacted: true`, emits `SessionCompacted`
    - **session.diff**: Emits `SessionDiffProduced` (P1)
    - **server.connected**: No state change, emits `SessionServerConnected`
    - **server.instance.disposed**: Running/awaiting_feedback → `:failed`, emits `SessionStateChanged` + `SessionErrorOccurred`
    - **server.instance.disposed on terminal session**: `{:skip, :already_terminal}`
    - **file.edited**: Appends file path to `file_edits`, emits `SessionFileEdited` (P1)
    - **Unhandled event type**: Returns `{:skip, :not_relevant}`
    - **Terminal state guard**: Any event (except metadata/observability) on a terminal session → `{:skip, :already_terminal}`
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/sdk_event_policy.ex`
  - Module: `Agents.Sessions.Domain.Policies.SdkEventPolicy`
  - Main function: `apply_event(session, sdk_event)` where `sdk_event` is the raw map `%{"type" => ..., "properties" => ...}`
  - Returns `{:ok, updated_session, domain_events}` or `{:skip, reason}`
  - Uses `SdkEventTypes.handled?/1` as a gate
  - Uses `SdkErrorPolicy.classify/1` for error events
  - Uses `SessionLifecyclePolicy.can_transition?/2` before state transitions
  - Uses `SessionLifecyclePolicy.terminal?/1` to guard terminal states
  - Builds domain event structs using the `.new/1` constructors
  - **Pure function** — no I/O, no Repo, no PubSub. Takes session + event, returns session + events.
- [x] **REFACTOR**: Extract private helper functions for each event type group (status events, error events, permission events, message events, metadata events, server events). Ensure each clause is under 15 lines.

### Phase 5 Validation
- [x] All SdkEventPolicy tests pass (milliseconds, no I/O, pure)
- [x] All SessionLifecyclePolicy tests pass (including new transitions)
- [x] No boundary violations (`mix boundary`) *(task unavailable in this environment; validated via `mix compile`)*

---

## Phase 6: SDK Event Handler — Infrastructure Entry Point ✓

**Goal**: Create the single infrastructure entry point that receives raw SDK events, resolves them to a Session, applies the SdkEventPolicy, and emits domain events via EventBus. This module is the bridge between the GenServer world (TaskRunner) and the pure domain model.

### 6.1 SdkEventHandler Module

- [x] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/sdk_event_handler_test.exs`
  - Use `ExUnit.Case, async: true` (pure logic with DI mocks)
  - Tests:
    - `handle/3` with a handled event type calls SdkEventPolicy, receives `{:ok, session, events}`, emits events via event_bus, returns `{:ok, updated_session}`
    - `handle/3` with a skipped event (`{:skip, reason}`) does NOT emit events, returns `{:skip, reason}`
    - `handle/3` with an ignored event type (not in handled list) returns `{:skip, :not_relevant}` without calling policy
    - `handle/3` emits all domain events in order via `event_bus.emit_all/1`
    - `handle/3` extracts `task_id` and `user_id` from the session for event `aggregate_id` and `actor_id`
    - `handle/3` logs unhandled event types at debug level (observability)
    - `handle/3` returns `{:ok, updated_session}` with all SDK tracking fields updated
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/sdk_event_handler.ex`
  - Module: `Agents.Sessions.Infrastructure.SdkEventHandler`
  - `handle(session, sdk_event, opts \\ [])` — main entry point
    - `opts[:event_bus]` defaults to `Perme8.Events.EventBus`
    - Calls `SdkEventTypes.handled?/1` first
    - If handled: calls `SdkEventPolicy.apply_event/2`
    - On `{:ok, session, events}`: enriches events with `aggregate_id` and `actor_id`, calls `event_bus.emit_all/2`, returns `{:ok, session}`
    - On `{:skip, reason}`: returns `{:skip, reason}`
    - If not handled: logs at debug, returns `{:skip, :not_relevant}`
  - **No Repo calls** — this is a thin orchestrator between pure policy and EventBus
  - Depends on: `SdkEventTypes`, `SdkEventPolicy`, `Perme8.Events.EventBus`
- [x] **REFACTOR**: Ensure structured Logger metadata includes `task_id` and `event_type`

### Phase 6 Validation
- [x] All SdkEventHandler tests pass
- [x] Handler has no direct Repo/DB dependencies (verifiable by inspection)

---

## Phase 7: Integrate Handler with TaskRunner

**Goal**: Modify TaskRunner to delegate SDK event processing to the new `SdkEventHandler`, converting the current inline `handle_sdk_event` approach into a delegation pattern. The TaskRunner still owns the GenServer lifecycle (stop on completion/failure), but the Session state tracking and domain event emission is handled by the new module.

### 7.1 TaskRunner State — Add Session Tracking

- [ ] ⏸ **RED**: Write/extend tests in `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs`
  - Tests:
    - When a `session.status` busy event arrives, the TaskRunner's internal session is updated (state stays `:running`)
    - When a `session.error` with terminal category arrives, TaskRunner stops (existing behavior preserved)
    - When a `session.status` idle arrives after running, TaskRunner completes (existing behavior preserved)
    - When a `permission.updated` event arrives, TaskRunner's session transitions to `awaiting_feedback` and a `SessionPermissionRequested` domain event is emitted via TestEventBus
    - When a `permission.replied` event arrives after `permission.updated`, TaskRunner's session transitions back to `running`
    - When `message.updated` events arrive, session `message_count` increments
    - When `session.error` with recoverable category arrives, session stays running, `SessionErrorOccurred` emitted with `recoverable: true`
    - When `server.instance.disposed` arrives, TaskRunner fails the session
    - When `session.updated` arrives with title, `SessionMetadataUpdated` is emitted
    - All existing TaskRunner tests remain green (backward compatibility)
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - Add `session: nil` to TaskRunner defstruct
  - In `init`, create a `Session.new(%{task_id: ..., user_id: ..., lifecycle_state: :starting})` and store in state
  - Modify `process_parent_session_event/2` to:
    1. Call `SdkEventHandler.handle(state.session, event, event_bus: state.event_bus)`
    2. On `{:ok, updated_session}` — update `state.session`, then check if session entered a terminal state to decide GenServer lifecycle action
    3. On `{:skip, _reason}` — continue as normal
  - Preserve existing TaskRunner-specific behavior (output part caching, todo tracking, question handling, permission auto-approve, container lifecycle) — the SdkEventHandler handles Session entity state + domain events, TaskRunner handles everything else
  - Map `handle_sdk_result` return values:
    - If `updated_session.lifecycle_state` is `:completed` → `complete_task/1`
    - If `updated_session.lifecycle_state` is `:failed` → `fail_task/2`
    - If `updated_session.lifecycle_state` is `:awaiting_feedback` → existing permission/question flow
    - Otherwise → `{:noreply, new_state}`
  - Preserve the catch-all for existing events that the SdkEventHandler skips (todo.updated, output caching, etc.)
- [ ] ⏸ **REFACTOR**: Extract the TaskRunner's remaining `handle_sdk_event` clauses that deal with output caching, todo tracking, and question handling into clearly named private functions. The Session lifecycle logic is now delegated, but the TaskRunner-specific state (output_parts, todo_items, etc.) remains in TaskRunner.

### 7.2 Backward Compatibility — Existing Event Flows

- [ ] ⏸ **RED**: Verify existing integration tests still pass:
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/completion_test.exs`
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs`
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/domain_events_test.exs`
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/question_test.exs`
- [ ] ⏸ **GREEN**: Fix any regressions from the TaskRunner refactor
- [ ] ⏸ **REFACTOR**: Remove any dead code from old inline event handling that has been replaced by the handler delegation

### Phase 7 Validation
- [ ] All TaskRunner tests pass (including existing test files)
- [ ] New integration tests for SDK event → Session state → domain event pipeline pass
- [ ] `mix test apps/agents/` passes fully

---

## Phase 8: PubSub Broadcasting for Domain Events ⏳

**Goal**: Ensure all domain events produced by the SdkEventHandler are broadcast over PubSub so the UI layer (out of scope for this ticket) and other subscribers can react.

### 8.1 EventBus Emission Verification

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/sdk_event_handler_integration_test.exs`
  - Use `Agents.DataCase, async: false` (needs PubSub)
  - Tests:
    - When `SdkEventHandler.handle/3` processes a `session.error` event, the `SessionErrorOccurred` event is emitted on `events:sessions` topic
    - When `SdkEventHandler.handle/3` processes a `permission.updated` event, `SessionPermissionRequested` is emitted on `events:sessions:session` topic
    - When `SdkEventHandler.handle/3` processes a state-changing event, `SessionStateChanged` is emitted on `events:sessions:session` topic
    - All domain events include correct `event_type`, `aggregate_type`, `aggregate_id`, `actor_id` base fields
    - Multiple domain events from a single SDK event (e.g., `SessionErrorOccurred` + `SessionStateChanged`) are all emitted
    - Workspace-scoped topic receives events when `workspace_id` is present on the event
- [ ] ⏸ **GREEN**: Verify EventBus integration is working — the `SdkEventHandler` already calls `event_bus.emit_all/1` which routes to the correct topics. This step may require enriching domain events with `workspace_id` if the session has workspace context.
- [ ] ⏸ **REFACTOR**: Ensure `aggregate_id` is consistently set to `task_id` for all session domain events

### 8.2 High-Frequency Event Debouncing

- [x] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/sdk_event_debouncer_test.exs`
  - Tests:
    - `should_emit?/2` with `:message_part_updated` type returns `false` if last emission was < 500ms ago
    - `should_emit?/2` with `:message_part_updated` type returns `true` if last emission was >= 500ms ago
    - `should_emit?/2` with any non-debounced event type always returns `true`
    - `record_emission/2` updates the last emission timestamp for the event type
    - State-changing events (e.g., `SessionStateChanged`) are NEVER debounced
- [x] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/sdk_event_debouncer.ex`
  - Module: `Agents.Sessions.Infrastructure.SdkEventDebouncer`
  - Tracks last emission time per event type
  - `should_emit?/2` — checks if enough time has passed since last emission
  - `record_emission/2` — records current time for event type
  - Debounced event types: `SessionMessageUpdated` (for `message.part.updated` events)
  - Non-debounced: all state-change events, error events, permission events
  - Pure module (takes and returns timestamps/state, does not manage its own state)
- [x] **REFACTOR**: Make debounce interval configurable via options (`:interval`)

### Phase 8 Validation
- [ ] All PubSub integration tests pass
- [ ] Debouncer tests pass
- [ ] Domain events arrive on correct topics

---

## Phase 9: Idempotent Event Processing ✓

**Goal**: Ensure that receiving the same SDK event twice (e.g., due to SSE reconnection) does not produce duplicate state transitions or domain events. Use the `last_event_id` field on Session for tracking.

### 9.1 Idempotency Guard in SdkEventPolicy

- [x] **RED**: Add tests to `apps/agents/test/agents/sessions/domain/policies/sdk_event_policy_test.exs`
  - Tests:
    - `apply_event/2` with an event that has the same derived event key as `session.last_event_id` returns `{:skip, :duplicate}`
    - `apply_event/2` with a new event key processes normally and sets `last_event_id` on the returned session
    - Event key derivation: combination of `type` + relevant identifying properties (e.g., `"session.status:idle"`, `"message.updated:msg-123"`, `"permission.updated:perm-456"`)
    - `apply_event/2` with events that have no identifying properties (e.g., `message.part.updated` streaming) are not subject to idempotency checks (they are inherently idempotent via latest-state overwrite)
    - State-confirming events (e.g., `session.status` busy when already running) are naturally idempotent and don't produce domain events — verify no duplicate emissions
- [x] **GREEN**: Add idempotency logic to `apps/agents/lib/agents/sessions/domain/policies/sdk_event_policy.ex`
  - `derive_event_key/1` — generates a unique key from the event type + identifying properties
  - At the top of `apply_event/2`: if `derive_event_key(event) == session.last_event_id`, return `{:skip, :duplicate}`
  - On successful processing: set `last_event_id` on the returned session
  - Events with no stable identifier (streaming parts) skip the idempotency check
- [x] **REFACTOR**: Extract `derive_event_key/1` as a standalone function with comprehensive pattern matching

### Phase 9 Validation
- [x] All idempotency tests pass
- [x] Duplicate events are silently skipped
- [x] No regression in normal event processing flow

---

## Pre-commit Checkpoint

After all phases:
- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix boundary` — no violations
- [ ] `mix format` — no formatting issues
- [ ] `mix credo --strict` — no issues
- [ ] `mix test apps/agents/` — all tests pass
- [ ] `mix precommit` — full suite green

---

## Testing Strategy

### Test Distribution

| Layer | Test Count (est.) | Test Type | Async |
|-------|------------------|-----------|-------|
| Domain — SdkEventTypes | ~8 | ExUnit.Case | ✅ |
| Domain — SdkErrorPolicy | ~9 | ExUnit.Case | ✅ |
| Domain — Session entity (new) | ~14 | ExUnit.Case | ✅ |
| Domain — Domain events (10 new) | ~30 | ExUnit.Case | ✅ |
| Domain — SessionLifecyclePolicy (new transitions) | ~10 | ExUnit.Case | ✅ |
| Domain — SdkEventPolicy | ~30 | ExUnit.Case | ✅ |
| Infrastructure — SdkEventHandler | ~7 | ExUnit.Case | ✅ |
| Infrastructure — SdkEventHandler integration | ~6 | DataCase | ❌ |
| Infrastructure — SdkEventDebouncer | ~5 | ExUnit.Case | ✅ |
| Infrastructure — TaskRunner integration (new) | ~10 | DataCase | ❌ |
| **Total estimated** | **~129** | | |

### Test Pyramid

- **Domain layer (pure, fast)**: ~101 tests (~78%) — policies, entities, events
- **Infrastructure layer (with DI)**: ~12 tests (~9%) — handler, debouncer
- **Integration layer (DB/PubSub)**: ~16 tests (~13%) — TaskRunner, PubSub

### Test Conventions

- Domain tests: `use ExUnit.Case, async: true` — no DB, no I/O, millisecond execution
- Domain event tests: test `event_type/0`, `aggregate_type/0`, `new/1` with valid attrs, required field enforcement
- Infrastructure tests with DI: `use ExUnit.Case, async: true` — inject mock event_bus
- Integration tests: `use Agents.DataCase, async: false` — real DB, PubSub, TestEventBus

---

## File Summary

### New Files

| File | Layer | Purpose |
|------|-------|---------|
| `apps/agents/lib/agents/sessions/domain/policies/sdk_event_types.ex` | Domain | SDK event type constants and classification |
| `apps/agents/lib/agents/sessions/domain/policies/sdk_error_policy.ex` | Domain | Error category classification (recoverable vs terminal) |
| `apps/agents/lib/agents/sessions/domain/policies/sdk_event_policy.ex` | Domain | SDK event to Session state mapping |
| `apps/agents/lib/agents/sessions/domain/events/session_error_occurred.ex` | Domain | Error domain event |
| `apps/agents/lib/agents/sessions/domain/events/session_permission_requested.ex` | Domain | Permission request domain event |
| `apps/agents/lib/agents/sessions/domain/events/session_permission_resolved.ex` | Domain | Permission resolution domain event |
| `apps/agents/lib/agents/sessions/domain/events/session_message_updated.ex` | Domain | Message tracking domain event |
| `apps/agents/lib/agents/sessions/domain/events/session_compacted.ex` | Domain | Compaction domain event |
| `apps/agents/lib/agents/sessions/domain/events/session_metadata_updated.ex` | Domain | Metadata update domain event |
| `apps/agents/lib/agents/sessions/domain/events/session_file_edited.ex` | Domain | File edit domain event |
| `apps/agents/lib/agents/sessions/domain/events/session_diff_produced.ex` | Domain | Diff domain event |
| `apps/agents/lib/agents/sessions/domain/events/session_server_connected.ex` | Domain | Server connection observability event |
| `apps/agents/lib/agents/sessions/domain/events/session_retrying.ex` | Domain | Retry domain event |
| `apps/agents/lib/agents/sessions/infrastructure/sdk_event_handler.ex` | Infrastructure | Entry point for SDK-event-to-Session processing |
| `apps/agents/lib/agents/sessions/infrastructure/sdk_event_debouncer.ex` | Infrastructure | High-frequency event debouncing |
| `apps/agents/test/agents/sessions/domain/policies/sdk_event_types_test.exs` | Test | SdkEventTypes tests |
| `apps/agents/test/agents/sessions/domain/policies/sdk_error_policy_test.exs` | Test | SdkErrorPolicy tests |
| `apps/agents/test/agents/sessions/domain/policies/sdk_event_policy_test.exs` | Test | SdkEventPolicy tests |
| `apps/agents/test/agents/sessions/domain/events/session_error_occurred_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_permission_requested_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_permission_resolved_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_message_updated_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_compacted_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_metadata_updated_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_file_edited_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_diff_produced_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_server_connected_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/domain/events/session_retrying_test.exs` | Test | Domain event tests |
| `apps/agents/test/agents/sessions/infrastructure/sdk_event_handler_test.exs` | Test | Handler unit tests |
| `apps/agents/test/agents/sessions/infrastructure/sdk_event_handler_integration_test.exs` | Test | Handler PubSub integration tests |
| `apps/agents/test/agents/sessions/infrastructure/sdk_event_debouncer_test.exs` | Test | Debouncer tests |

### Modified Files

| File | Layer | Changes |
|------|-------|---------|
| `apps/agents/lib/agents/sessions/domain/entities/session.ex` | Domain | Add ~14 new fields, `update/2`, convenience functions |
| `apps/agents/lib/agents/sessions/domain/policies/session_lifecycle_policy.ex` | Domain | Add ~8 new valid transitions |
| `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex` | Infrastructure | Add `session` to state, delegate SDK events to SdkEventHandler |
| `apps/agents/test/agents/sessions/domain/entities/session_test.exs` | Test | New tests for SDK tracking fields |
| `apps/agents/test/agents/sessions/domain/policies/session_lifecycle_policy_test.exs` | Test | Tests for new transitions |
| `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs` | Test | Integration tests for handler delegation |

---

## Architectural Notes

### Separation of Concerns

```
Raw SDK Event (map)
       │
       ▼
┌──────────────────┐     ┌────────────────────┐
│   TaskRunner     │────▶│  SdkEventHandler   │ (Infrastructure)
│  (GenServer)     │     │  - Routes event     │
│  - Output cache  │     │  - Calls policy     │
│  - Todo tracking │     │  - Emits events     │
│  - Container     │     └─────────┬──────────┘
│  - Question flow │               │
└──────────────────┘               ▼
                          ┌─────────────────────┐
                          │   SdkEventPolicy    │ (Domain — PURE)
                          │  - State transitions │
                          │  - Event generation  │
                          │  - Idempotency       │
                          └─────────┬───────────┘
                                    │
                          ┌─────────▼───────────┐
                          │ SessionLifecycle     │ (Domain — PURE)
                          │ Policy               │
                          │ SdkErrorPolicy       │
                          │ SdkEventTypes        │
                          └─────────────────────┘
```

### Key Invariants

1. **Session entity is always pure** — no side effects, no GenServer, no I/O
2. **SdkEventPolicy is always pure** — takes (Session, event), returns (Session, domain_events)
3. **SdkEventHandler is the only bridge** — between pure domain and infrastructure (EventBus)
4. **TaskRunner delegates Session state** — but retains ownership of output caching, todo tracking, question handling, container lifecycle, and GenServer lifecycle decisions
5. **Terminal states are irreversible** — once a session reaches completed/failed/cancelled, no further non-observability events are processed
6. **Domain events emit AFTER state change** — the handler emits only after policy returns successfully
7. **Idempotency via last_event_id** — duplicate SDK events (SSE reconnection) produce no duplicate domain events

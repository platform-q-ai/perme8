# Feature: Ticket-Session Linking Refactor

**Ticket**: [#430](https://github.com/platform-q-ai/perme8/issues/430)
**Status**: ✅ Implemented

## Overview

Replace the scattered, ad-hoc ticket-session linking logic in the 3000-line `DashboardLive.Index` with a centralised `TicketSessionLinker` module that owns all link/unlink/refresh operations. Then decompose `index.ex` into focused handler modules by concern. This refactor fixes four known bugs caused by inconsistent linking paths and makes the codebase maintainable.

### Bug Fixes Delivered

1. **Session reappears on ticket after reload** — `remove_ticket_from_queue` cancels task but doesn't clear `task_id` FK
2. **New session on ticket shows as orphan card** — sync path (`handle_task_result`) re-enriches from stale in-memory assigns instead of reloading from DB
3. **Ticket creation via textarea doesn't appear** — investigate form submission path and ensure `create_ticket` handler + `{:tickets_synced}` refresh works
4. **close_ticket doesn't clean up session properly** — uses enrichment regex to find associated session, which no longer works for terminal tasks

## UI Strategy

- **LiveView coverage**: 100% — all changes are server-side Elixir
- **TypeScript needed**: None

## App Ownership

| Artifact | App | Path |
|----------|-----|------|
| **Owning app (domain)** | `agents` | `apps/agents/` |
| **Owning app (interface)** | `agents_web` | `apps/agents_web/` |
| **Repo** | `Agents.Repo` | — |
| **Migrations** | None required | — |
| **Domain entities** | `agents` | `apps/agents/lib/agents/tickets/domain/entities/` |
| **Domain policies** | `agents` | `apps/agents/lib/agents/tickets/domain/policies/` |
| **Infrastructure repositories** | `agents` | `apps/agents/lib/agents/tickets/infrastructure/repositories/` |
| **LiveView interface** | `agents_web` | `apps/agents_web/lib/live/dashboard/` |
| **LiveView tests** | `agents_web` | `apps/agents_web/test/live/dashboard/` |
| **Feature files (UI)** | `agents_web` | `apps/agents_web/test/features/` |

All domain artifacts belong to the `agents` app. All interface artifacts belong to `agents_web`. No cross-app Repo violations. Per `docs/app_ownership.md`:
- `agents` owns: Tickets domain, Sessions domain, repositories, domain events
- `agents_web` owns: Sessions UI, LiveView interface layer

## Affected Boundaries

- **Primary context**: `Agents.Tickets` (link/unlink operations)
- **Secondary context**: `Agents.Sessions` (task lifecycle, delete operations)
- **Dependencies**: `Perme8.Events` (domain event infrastructure)
- **Exported schemas**: `Agents.Tickets.Domain.Entities.Ticket` (already exported)
- **New context needed?**: No — this refactors existing code within existing contexts

---

## Phase 1: Extract `TicketSessionLinker` Module (No Behaviour Change)

**Goal**: Create a pure-function module that centralises all ticket-session link/unlink/refresh socket operations. This phase moves existing logic without changing any behaviour — all existing tests must continue to pass.

The `TicketSessionLinker` is an **interface-layer** module because it operates on `Phoenix.LiveView.Socket` assigns. It lives in `agents_web`.

### 1.1 TicketSessionLinker — Core Functions

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/dashboard/ticket_session_linker_test.exs`
  - Tests (unit-level, using socket-like map assigns or ConnCase):
    - `link_and_refresh/2` — given a socket with `tasks_snapshot` and `tickets`, and a task whose instruction references `#42`:
      - Calls `Tickets.link_ticket_to_task(42, task.id)` (persist FK)
      - Calls `Tickets.list_project_tickets/2` to reload tickets from DB
      - Returns updated socket with fresh `:tickets` and updated `:tasks_snapshot`
    - `link_and_refresh/2` — when task instruction has no ticket reference:
      - Does NOT call `link_ticket_to_task`
      - Still returns socket unchanged (no crash)
    - `unlink_and_refresh/2` — given a socket and a ticket_number:
      - Calls `Tickets.unlink_ticket_from_task(ticket_number)` (clear FK)
      - Reloads tickets from DB
      - Returns updated socket with fresh `:tickets`
    - `cleanup_and_refresh/3` — given a socket and a container_id:
      - Removes tasks for that container from `tasks_snapshot`
      - Re-enriches tickets with the cleaned snapshot
      - Returns `{updated_tasks_snapshot, updated_tickets}`
    - `refresh_tickets/1` — reloads tickets from DB with current tasks_snapshot:
      - Returns updated socket with fresh `:tickets`
    - Error handling: `link_and_refresh/2` rescues exceptions from `link_ticket_to_task` and still returns a valid socket (no crash — matches existing `maybe_link_ticket_to_task` behaviour)
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/ticket_session_linker.ex`
  - Module: `AgentsWeb.DashboardLive.TicketSessionLinker`
  - Functions:
    - `link_and_refresh(socket, task)` — extract ticket number from instruction, persist FK, reload tickets from DB, update `tasks_snapshot`, return updated socket
    - `unlink_and_refresh(socket, ticket_number)` — clear FK, reload tickets from DB, return updated socket
    - `cleanup_and_refresh(tasks_snapshot, tickets, container_id)` — remove tasks for container from snapshot, re-enrich tickets against cleaned snapshot. Returns `{cleaned_snapshot, enriched_tickets}` (pure function matching existing `purge_tasks_and_reenrich/3` signature)
    - `refresh_tickets(socket)` — reload tickets from DB using current `tasks_snapshot`, return updated socket
  - Implementation notes:
    - Extract the logic from `maybe_link_ticket_to_task/1` (line 3024), `purge_tasks_and_reenrich/3` (line 2662), and the inline ticket reload pattern used in `{:new_task_created}` (line 1152) and `{:tickets_synced}` (line 1337)
    - Keep the blanket `rescue` on `link_ticket_to_task` to match existing fault tolerance
    - `link_and_refresh` also upserts the task into `tasks_snapshot` before reloading tickets
- [ ] ⏸ **REFACTOR**: Add `@moduledoc` documenting the module as the single authority for ticket-session linking

### Phase 1 Validation
- [ ] ⏸ All new unit tests pass
- [ ] ⏸ All existing tests pass (no regressions) — `mix test apps/agents_web/`
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Route Handlers Through `TicketSessionLinker` (Fix Bugs 1-2)

**Goal**: Replace all scattered linking logic in `index.ex` with calls to `TicketSessionLinker`. This fixes bugs 1 (remove_ticket_from_queue doesn't clear FK) and 2 (sync path re-enriches from stale assigns).

### 2.1 Fix `remove_ticket_from_queue` — Clear FK on Cancel (Bug 1)

The current handler calls `do_cancel_task/3` which cancels the task and re-enriches from `tasks_snapshot`. But since the cancelled task is now terminal, the enrichment policy's regex fallback correctly ignores it. However, the persisted `task_id` FK is never cleared, so on next page reload the FK-based lookup re-associates the ticket.

- [ ] ⏸ **RED**: Write/update test in `apps/agents_web/test/live/dashboard/index_test.exs`
  - Test: `remove_ticket_from_queue clears persisted task_id FK`
    - Create a task linked to ticket #42 with persisted `task_id` FK
    - Mount the LiveView
    - Fire `"remove_ticket_from_queue"` event with `number: "42"`
    - Assert: ticket DB record has `task_id: nil` after the event
    - Assert: after a simulated `{:tickets_synced}` reload, ticket renders in idle state (no session)
  - Test: `remove_ticket_from_queue returns ticket to triage as idle`
    - Same setup but assert UI state: ticket appears in triage lane with no session indicator
- [ ] ⏸ **GREEN**: Modify `handle_event("remove_ticket_from_queue", ...)` in `index.ex`
  - After `do_cancel_task/3` succeeds, call `TicketSessionLinker.unlink_and_refresh(socket, number)` to clear the FK and reload tickets
  - Alternatively, add the unlink call into `do_cancel_task` when it's invoked from a ticket context — but this risks coupling. Preferred approach: add a post-cancel step specifically in `remove_ticket_from_queue` that unlinks via the `TicketSessionLinker`
  - Implementation approach: the `do_cancel_task/3` returns `{:noreply, socket}`. We need to either:
    - (a) Extract the cancel logic to return the socket (not `{:noreply, socket}`) so we can chain with the unlink, OR
    - (b) After `do_cancel_task`, send self a message like `{:unlink_ticket, number}` and handle it
    - Preferred: (a) — extract a `perform_cancel_task/3` that returns the updated socket, then wrap it in `remove_ticket_from_queue` with the additional unlink step
- [ ] ⏸ **REFACTOR**: Ensure `pause_session` and other callers of `do_cancel_task` are unaffected

### 2.2 Fix `handle_task_result` — Reload from DB (Bug 2)

The sync task creation path (`run_task` → `route_message_submission` → `run_or_resume_task` → `handle_task_result`) persists the FK via `maybe_link_ticket_to_task` but then re-enriches from stale in-memory `socket.assigns.tickets` where `associated_task_id` is still nil. The async path (`start_ticket_session` → `{:new_task_created}`) correctly reloads from DB.

- [ ] ⏸ **RED**: Write/update test in `apps/agents_web/test/live/dashboard/index_test.exs`
  - Test: `run_task for ticket session shows session on ticket (not as orphan)`
    - Create a ticket #55 in DB
    - Mount LiveView, trigger `"run_task"` with instruction `"#55 fix the bug"`
    - Assert: ticket #55 shows the session (not idle) — the ticket's `associated_task_id` is populated from DB, not stale assigns
    - Assert: no orphan session card appears for the new task
- [ ] ⏸ **GREEN**: Replace `handle_task_result/2` inline enrichment with `TicketSessionLinker.link_and_refresh/2`
  - Current code (line 1987-2039): calls `maybe_link_ticket_to_task(task)` then `TicketEnrichmentPolicy.enrich_all(socket.assigns.tickets, tasks_snapshot, ...)`
  - Replace with: `socket = TicketSessionLinker.link_and_refresh(socket, task)` which persists FK AND reloads from DB
  - This makes the sync path consistent with the async path
- [ ] ⏸ **REFACTOR**: Remove the now-dead `maybe_link_ticket_to_task/1` private function from `index.ex`

### 2.3 Replace `{:new_task_created}` Inline Logic

- [ ] ⏸ **RED**: Verify existing tests for `{:new_task_created}` still pass (no new test needed — behaviour unchanged)
- [ ] ⏸ **GREEN**: Replace the inline `maybe_link_ticket_to_task(task)` + `Tickets.list_project_tickets(...)` in `handle_info({:new_task_created, ...})` with `TicketSessionLinker.link_and_refresh(socket, task)`
- [ ] ⏸ **REFACTOR**: Remove duplicated ticket reload logic

### 2.4 Replace `purge_tasks_and_reenrich` Calls

- [ ] ⏸ **RED**: Verify existing `delete_session` and `delete_queued_task` tests still pass
- [ ] ⏸ **GREEN**: Replace calls to `purge_tasks_and_reenrich/3` in `delete_session` and `delete_queued_task` handlers with `TicketSessionLinker.cleanup_and_refresh/3`
- [ ] ⏸ **REFACTOR**: Remove the now-dead `purge_tasks_and_reenrich/3` private function from `index.ex`

### 2.5 Replace `{:tickets_synced}` Inline Reload

- [ ] ⏸ **RED**: Verify existing ticket sync tests still pass
- [ ] ⏸ **GREEN**: Replace the inline reload logic in `handle_info({:tickets_synced, ...})` with `TicketSessionLinker.refresh_tickets(socket)` plus the active_ticket_number derivation
- [ ] ⏸ **REFACTOR**: Consolidate ticket reload patterns

### 2.6 Replace `do_cancel_task` Inline Re-enrichment

- [ ] ⏸ **RED**: Verify existing cancel task tests still pass
- [ ] ⏸ **GREEN**: Replace the inline `TicketEnrichmentPolicy.enrich_all(...)` call in `do_cancel_task/3` with `TicketSessionLinker.cleanup_and_refresh/3` or a simple re-enrichment via the linker
- [ ] ⏸ **REFACTOR**: Ensure consistent re-enrichment pattern across all cancel paths

### Phase 2 Validation
- [ ] ⏸ Bug 1 test passes: `remove_ticket_from_queue` clears FK and ticket is idle on reload
- [ ] ⏸ Bug 2 test passes: sync path `run_task` shows session on ticket, not as orphan
- [ ] ⏸ All existing tests pass (including the ~137 index tests)
- [ ] ⏸ `maybe_link_ticket_to_task/1` removed from `index.ex`
- [ ] ⏸ `purge_tasks_and_reenrich/3` removed from `index.ex`
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 3: Fix `close_ticket` Session Cleanup (Bug 3)

**Goal**: The `close_ticket` handler uses `apply_ticket_closed/2` which finds the associated session via `ticket.associated_container_id`. This field is populated by the enrichment policy at runtime from the in-memory `tasks_snapshot`. For terminal tasks (completed/failed/cancelled), the enrichment policy's regex fallback no longer matches them, so `associated_container_id` is `nil` and the session cleanup is skipped.

The fix: use the persisted `associated_task_id` from the DB (or the in-memory enriched value) to look up the container_id directly from the task, rather than relying on `associated_container_id` from enrichment.

### 3.1 Fix `apply_ticket_closed` Container Resolution

- [ ] ⏸ **RED**: Write test in `apps/agents_web/test/live/dashboard/index_test.exs`
  - Test: `close_ticket destroys session even when task is in terminal state`
    - Create a completed/failed task linked to ticket #99 with persisted `task_id` FK
    - Mount LiveView, trigger `"close_ticket"` event
    - Assert: session for that container is removed from the sessions list
    - Assert: task snapshot is cleaned for that container
    - Assert: ticket is marked closed in UI
  - This should also fix the 2 currently failing `close_ticket` tests
- [ ] ⏸ **GREEN**: Modify `apply_ticket_closed/2` in `index.ex`
  - Instead of: `container_id = ticket && ticket.associated_container_id`
  - Use: Look up the task from `tasks_snapshot` by `ticket.associated_task_id`, then get `container_id` from the task
  - If `associated_task_id` is nil (no persisted FK), fall back to searching `tasks_snapshot` for a task whose instruction references `#number` (one-time regex search — not relying on enrichment)
  - Use `TicketSessionLinker.cleanup_and_refresh/3` for the snapshot cleanup
- [ ] ⏸ **REFACTOR**: Add a helper function `resolve_container_for_ticket/2` that encapsulates the task_id → container_id lookup with fallback

### 3.2 Fix the 2 Failing `close_ticket` Tests

- [ ] ⏸ **RED**: Run the 2 currently failing tests to confirm they fail for the expected reason
  - `close_ticket removes ticket from UI and destroys session` (line 3318)
  - `close_ticket cleans stale task from snapshot so re-opened ticket is idle` (line 3381)
- [ ] ⏸ **GREEN**: The fix in 3.1 should make these tests pass — verify
- [ ] ⏸ **REFACTOR**: If the tests need adjustment (e.g., they were written expecting regex enrichment), update them to use persisted FK setup

### Phase 3 Validation
- [ ] ⏸ 2 previously failing close_ticket tests now pass
- [ ] ⏸ New close_ticket terminal task test passes
- [ ] ⏸ All existing tests pass
- [ ] ⏸ No boundary violations

---

## Phase 4: Fix Ticket Creation Flow (Bug 4)

**Goal**: Investigate and fix the ticket creation via textarea. The `create_ticket` handler exists, the backend `CreateTicket` use case works (unit tests pass), and the use case broadcasts `{:tickets_synced, []}` which triggers a ticket reload. The issue may be in form submission reaching the handler or the ticket appearing in UI after creation.

### 4.1 Investigate and Test Ticket Creation E2E

- [ ] ⏸ **RED**: Write/update test in `apps/agents_web/test/live/dashboard/index_test.exs`
  - Test: `create_ticket via sidebar textarea creates ticket and shows in UI`
    - Mount LiveView
    - Submit the `"sidebar-new-ticket-form"` form with body text
    - Assert: ticket appears in the triage lane after creation
    - Assert: flash message "Ticket created" is shown
  - Test: `create_ticket with empty body shows error`
    - Submit with empty body
    - Assert: flash error "Ticket body is required"
  - Test: `create_ticket broadcasts tickets_synced which refreshes ticket list`
    - Create ticket
    - Assert: `{:tickets_synced, []}` triggers a reload and the new ticket appears
- [ ] ⏸ **GREEN**: Fix the issue (likely one of these):
  - **Form submission**: Check the `.html.heex` template to ensure the form's `phx-submit` event name matches `"create_ticket"` and the parameter name matches `"body"`
  - **Visibility after creation**: The `CreateTicket` use case broadcasts `{:tickets_synced, []}`. The `handle_info({:tickets_synced, ...})` handler reloads tickets. Verify the new ticket has `state: "open"` so it appears in the list
  - **Temporary negative number**: The use case assigns a negative `number` for locally-created tickets. Verify the UI doesn't filter out negative numbers
  - **push_event "clear_input"**: Verify the JS hook handles this event to clear the textarea
- [ ] ⏸ **REFACTOR**: Clean up any template/handler mismatches

### Phase 4 Validation
- [ ] ⏸ Ticket creation tests pass
- [ ] ⏸ All existing tests pass
- [ ] ⏸ No boundary violations

---

## Phase 5: Decompose `index.ex` into Focused Handler Modules

**Goal**: Split the 3034-line `index.ex` into focused modules by concern. Each module is a helper module that the main LiveView delegates to. The main `index.ex` retains `mount`, `handle_params`, and delegates `handle_event`/`handle_info` to the focused modules.

### Architecture Decision: Delegation Pattern

Phoenix LiveView requires all `handle_event` and `handle_info` callbacks to be defined in the LiveView module itself. We use one of two patterns:

**Option A — Private function delegation** (preferred for this codebase):
Each handler module exposes public functions that accept and return `socket`. The `index.ex` `handle_event`/`handle_info` clauses become one-liner delegates:

```elixir
# In index.ex
def handle_event("close_ticket", params, socket) do
  TicketHandlers.close_ticket(params, socket)
end
```

```elixir
# In ticket_handlers.ex
def close_ticket(%{"number" => number_str}, socket) do
  # ... full implementation ...
  {:noreply, socket}
end
```

**Option B — `use` macro with `defoverridable`**: Not recommended — complex and fragile.

We proceed with **Option A**.

### 5.1 Extract `TicketHandlers`

Ticket-related `handle_event` handlers and their private helpers.

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/dashboard/ticket_handlers_test.exs`
  - Test the extracted functions in isolation (using ConnCase)
  - Verify: `start_ticket_session`, `remove_ticket_from_queue`, `close_ticket`, `create_ticket`, `sync_tickets`, `select_ticket`, `toggle_parent_collapse`, `reorder_tickets`, `send_to_top`, `send_to_bottom`
  - Note: Most tests already exist in `index_test.exs`. The RED step here is writing a few targeted unit tests for the module's public API to verify the extraction didn't break signatures.
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/ticket_handlers.ex`
  - Module: `AgentsWeb.DashboardLive.TicketHandlers`
  - Move from `index.ex`:
    - `start_ticket_session/2`
    - `remove_ticket_from_queue/2`
    - `close_ticket/2` (delegates to `apply_ticket_closed/2`)
    - `create_ticket/2`
    - `sync_tickets/2`
    - `select_ticket/2`
    - `toggle_parent_collapse/2`
    - `reorder_tickets/2`
    - `send_ticket_to_top/2`, `send_ticket_to_bottom/2`
  - Plus supporting private functions: `apply_ticket_closed/2`, `find_ticket_by_number/2`, `update_ticket_by_number/3`, `map_ticket_tree/2`, `all_tickets/1`, `maybe_revert_optimistic_ticket/2`, `resolve_container_for_ticket/2`
  - Update `index.ex` to delegate to this module
- [ ] ⏸ **REFACTOR**: Verify all existing ticket-related tests pass through the new delegation

### 5.2 Extract `SessionHandlers`

Session management `handle_event` handlers.

- [ ] ⏸ **RED**: Write minimal test verifying extraction correctness
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/session_handlers.ex`
  - Module: `AgentsWeb.DashboardLive.SessionHandlers`
  - Move from `index.ex`:
    - `new_session/2`
    - `select_session/2`
    - `delete_session/2`
    - `pause_session/2`
    - `delete_queued_task/2`
    - `switch_tab/2`
    - `search_sessions/2`
    - `filter_sessions/2`
    - `select_image/2`
  - Plus supporting private functions: `upsert_session_from_task/2`, `derive_sticky_warm_task_ids/3`, `maybe_clear_active_session/2`
  - Update `index.ex` to delegate
- [ ] ⏸ **REFACTOR**: Verify all session-related tests pass

### 5.3 Extract `TaskExecutionHandlers`

Task run/cancel/restart handlers.

- [ ] ⏸ **RED**: Write minimal test verifying extraction correctness
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/task_execution_handlers.ex`
  - Module: `AgentsWeb.DashboardLive.TaskExecutionHandlers`
  - Move from `index.ex`:
    - `run_task/2` (the handle_event)
    - `cancel_task/2`
    - `restart_session/2`
  - Plus supporting private functions: `route_message_submission/5`, `run_or_resume_task/4`, `handle_task_result/2`, `do_cancel_task/3`, `perform_cancel_task/3`, `fetch_cancelled_task/2`, `recover_instruction/2`, `ensure_ticket_reference/3`
  - Update `index.ex` to delegate
- [ ] ⏸ **REFACTOR**: Verify all task execution tests pass

### 5.4 Extract `PubsubHandlers`

All `handle_info` PubSub message handlers.

- [ ] ⏸ **RED**: Write minimal test verifying extraction correctness
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/pubsub_handlers.ex`
  - Module: `AgentsWeb.DashboardLive.PubsubHandlers`
  - Move from `index.ex`:
    - `handle_task_event/2` (`:task_event`)
    - `handle_task_status_changed/2`
    - `handle_lifecycle_state_changed/2`
    - `handle_new_task_created/2`
    - `handle_tickets_synced/2`
    - `handle_queue_snapshot/2`
    - `handle_task_refreshed/2`
    - `handle_ticket_stage_changed/2`
    - `handle_ticket_sync_finished/2`
  - Plus supporting private functions: `update_task_lifecycle_state/3`, `update_session_lifecycle_state/3`
  - Update `index.ex` to delegate
- [ ] ⏸ **REFACTOR**: Verify all PubSub-related tests pass

### 5.5 Extract `QuestionHandlers`

Question/feedback event handlers.

- [ ] ⏸ **RED**: Verify existing question tests pass
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/question_handlers.ex`
  - Module: `AgentsWeb.DashboardLive.QuestionHandlers`
  - Move: `toggle_question_option`, `submit_question_answer`, `dismiss_question`
  - Plus supporting functions: `handle_question_result_basic/4`, `handle_question_result_chat/4`
- [ ] ⏸ **REFACTOR**: Verify all question tests pass

### 5.6 Extract `AuthRefreshHandlers`

Auth refresh event handlers.

- [ ] ⏸ **RED**: Verify existing auth refresh tests pass
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/auth_refresh_handlers.ex`
  - Module: `AgentsWeb.DashboardLive.AuthRefreshHandlers`
  - Move: `refresh_auth_and_resume`, `refresh_all_auth`, auth refresh `handle_info` clauses
- [ ] ⏸ **REFACTOR**: Verify tests in `index_auth_refresh_test.exs` pass

### 5.7 Extract `FollowUpDispatchHandlers`

Follow-up message dispatch handlers.

- [ ] ⏸ **RED**: Verify existing follow-up tests pass
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/follow_up_dispatch_handlers.ex`
  - Module: `AgentsWeb.DashboardLive.FollowUpDispatchHandlers`
  - Move: `dispatch_follow_up_message`, `follow_up_send_result`, `follow_up_timeout`, `hydrate_optimistic_queue`
- [ ] ⏸ **REFACTOR**: Verify tests in `follow_up_dispatch_test.exs` pass

### 5.8 Extract `SessionDataHelpers`

Shared data manipulation helpers used across multiple handler modules.

- [ ] ⏸ **RED**: Write unit tests for extracted helper functions
  - Test: `upsert_task_snapshot/2` correctly adds/updates tasks in snapshot
  - Test: `remove_tasks_for_container/2` removes matching tasks
  - Test: `subscribe_to_active_tasks/1` subscribes to correct PubSub topics
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/dashboard/session_data_helpers.ex`
  - Module: `AgentsWeb.DashboardLive.SessionDataHelpers`
  - Move from `index.ex`:
    - `upsert_session_from_task/2`
    - `upsert_task_snapshot/2`
    - `remove_tasks_for_container/2`
    - `derive_sticky_warm_task_ids/3`
    - `subscribe_to_active_tasks/1`
    - `merge_unassigned_active_tasks/2`
    - `find_current_task/2`
    - `request_task_refresh/2`
    - `assign_session_state/1`
    - `load_queue_state/1`
    - `default_queue_state/0`
    - `clear_form/1`, `prefill_form/2`
    - `broadcast_optimistic_new_sessions_snapshot/1`
  - These are used by multiple handler modules, so they live in a shared helpers module
- [ ] ⏸ **REFACTOR**: Update all handler modules to import/alias `SessionDataHelpers`

### 5.9 Slim Down `index.ex`

- [ ] ⏸ **RED**: Run full test suite to establish baseline
- [ ] ⏸ **GREEN**: Refactor `index.ex` to be a thin routing module:
  - Keep: `mount/3`, `handle_params/3`, `session_tabs/0`
  - All `handle_event` clauses become one-liner delegates to handler modules
  - All `handle_info` clauses become one-liner delegates to PubSub/follow-up/auth modules
  - Target: `index.ex` under 300 lines (from 3034)
  - Import helper modules for template access
- [ ] ⏸ **REFACTOR**: Final cleanup, ensure all modules have `@moduledoc`

### Phase 5 Validation
- [ ] ⏸ `index.ex` is under 300 lines
- [ ] ⏸ All ~137 index tests pass
- [ ] ⏸ All lifecycle tests pass
- [ ] ⏸ All follow-up dispatch tests pass
- [ ] ⏸ All auth refresh tests pass
- [ ] ⏸ Full test suite passes: `mix test apps/agents_web/`
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 6: Domain Events for Ticket Linking (Optional Follow-up)

**Goal**: Emit `TicketLinkedToTask` and `TicketUnlinkedFromTask` domain events so other tabs/users can react to link changes via PubSub. This is optional and can be a separate ticket.

### 6.1 Define Domain Events

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/events/ticket_linked_to_task_test.exs`
  - Test: event struct has required fields (`ticket_number`, `task_id`, `aggregate_id`, `actor_id`)
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/events/ticket_linked_to_task.ex`
  - `use Perme8.Events.DomainEvent`
  - Fields: `ticket_number`, `task_id`
- [ ] ⏸ **REFACTOR**: Add `@moduledoc`

### 6.2 Define Unlink Event

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/events/ticket_unlinked_from_task_test.exs`
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/events/ticket_unlinked_from_task.ex`
- [ ] ⏸ **REFACTOR**: Add `@moduledoc`

### 6.3 Emit Events from Facade

- [ ] ⏸ **RED**: Write test that `link_ticket_to_task/3` emits `TicketLinkedToTask` via injected `TestEventBus`
- [ ] ⏸ **GREEN**: Update `Agents.Tickets.link_ticket_to_task/2` to accept `opts` with `:event_bus` and emit the event after successful FK update
- [ ] ⏸ **REFACTOR**: Same for `unlink_ticket_from_task/2`

### Phase 6 Validation
- [ ] ⏸ Domain event tests pass
- [ ] ⏸ TestEventBus injection follows AGENTS.md Domain Event Testing Rule
- [ ] ⏸ No boundary violations

---

## Pre-Commit Checkpoint

After all phases:
- [ ] ⏸ `mix precommit` passes (formatting, Credo, boundary, tests)
- [ ] ⏸ `mix boundary` reports no violations
- [ ] ⏸ Full umbrella test suite: `mix test` passes
- [ ] ⏸ All 4 bugs verified fixed
- [ ] ⏸ 2 previously failing close_ticket tests now pass
- [ ] ⏸ `index.ex` reduced from 3034 lines to ~300 lines

---

## Testing Strategy

### Estimated Test Count

| Category | New Tests | Existing (must pass) |
|----------|-----------|---------------------|
| TicketSessionLinker unit | ~8 | — |
| Bug fix integration (Phases 2-4) | ~8 | ~137 (index_test) |
| Handler extraction (Phase 5) | ~6 (smoke tests per module) | ~100+ (lifecycle tests) |
| Domain events (Phase 6, optional) | ~4 | — |
| **Total new** | **~26** | |
| **Total existing** | | **~350+** |

### Test Distribution

- **Domain (pure, no I/O)**: 4 tests (Phase 6 domain events)
- **Application (with mocks)**: 0 (no new use cases)
- **Infrastructure**: 0 (no new repositories/schemas)
- **Interface (ConnCase/LiveViewTest)**: ~22 tests (TicketSessionLinker, bug fixes, extraction smoke tests)

### Test Files

| File | Phase | Purpose |
|------|-------|---------|
| `apps/agents_web/test/live/dashboard/ticket_session_linker_test.exs` | 1 | Unit tests for the extracted linker module |
| `apps/agents_web/test/live/dashboard/index_test.exs` | 2-4 | Bug fix integration tests (added to existing file) |
| `apps/agents_web/test/live/dashboard/ticket_handlers_test.exs` | 5.1 | Extraction smoke tests |
| `apps/agents_web/test/live/dashboard/session_handlers_test.exs` | 5.2 | Extraction smoke tests |
| `apps/agents_web/test/live/dashboard/task_execution_handlers_test.exs` | 5.3 | Extraction smoke tests |
| `apps/agents_web/test/live/dashboard/pubsub_handlers_test.exs` | 5.4 | Extraction smoke tests |
| `apps/agents_web/test/live/dashboard/session_data_helpers_test.exs` | 5.8 | Unit tests for shared helpers |
| `apps/agents/test/agents/tickets/domain/events/ticket_linked_to_task_test.exs` | 6.1 | Domain event struct tests |
| `apps/agents/test/agents/tickets/domain/events/ticket_unlinked_from_task_test.exs` | 6.2 | Domain event struct tests |

---

## Risk Mitigation

1. **Large file refactor risk**: Phase 5 moves code in a 3000-line file. Mitigated by:
   - Phases 1-4 are pure additions/fixes (no code movement)
   - Phase 5 extracts one module at a time, running the full test suite after each
   - Each extraction is a mechanical move — no logic changes
2. **FK cascade reliance**: `purge_tasks_and_reenrich` relies on FK `on_delete: :nilify_all` cascade. This is validated by existing tests and doesn't change.
3. **Race condition in unlink**: A previous version had a `Task.start` calling `unlink_ticket_from_task` which raced with new task creation. We avoid this by making unlink synchronous in the handler.
4. **Phase 6 is optional**: Domain events for linking are nice-to-have for cross-tab consistency but not required for the bug fixes. Can be a separate ticket.

## File Summary

### New Files (created by this plan)

| File | Phase |
|------|-------|
| `apps/agents_web/lib/live/dashboard/ticket_session_linker.ex` | 1 |
| `apps/agents_web/test/live/dashboard/ticket_session_linker_test.exs` | 1 |
| `apps/agents_web/lib/live/dashboard/ticket_handlers.ex` | 5.1 |
| `apps/agents_web/lib/live/dashboard/session_handlers.ex` | 5.2 |
| `apps/agents_web/lib/live/dashboard/task_execution_handlers.ex` | 5.3 |
| `apps/agents_web/lib/live/dashboard/pubsub_handlers.ex` | 5.4 |
| `apps/agents_web/lib/live/dashboard/question_handlers.ex` | 5.5 |
| `apps/agents_web/lib/live/dashboard/auth_refresh_handlers.ex` | 5.6 |
| `apps/agents_web/lib/live/dashboard/follow_up_dispatch_handlers.ex` | 5.7 |
| `apps/agents_web/lib/live/dashboard/session_data_helpers.ex` | 5.8 |
| `apps/agents/lib/agents/tickets/domain/events/ticket_linked_to_task.ex` | 6.1 |
| `apps/agents/lib/agents/tickets/domain/events/ticket_unlinked_from_task.ex` | 6.2 |

### Modified Files

| File | Phase | Changes |
|------|-------|---------|
| `apps/agents_web/lib/live/dashboard/index.ex` | 2-5 | Route through linker, then slim to ~300 lines |
| `apps/agents_web/test/live/dashboard/index_test.exs` | 2-4 | Add bug fix regression tests |
| `apps/agents/lib/agents/tickets.ex` | 6 | Add event_bus opts to link/unlink functions |

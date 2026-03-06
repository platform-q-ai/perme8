# Feature: Harden Session Message Submission & Optimistic UI Architecture

**Ticket:** #369
**Type:** Refactor (existing functionality hardening)
**Status:** ⏸ Not Started

## Overview

A 5-phase refactor of the session message submission and optimistic UI system in `agents_web`. The goal is to extract implicit state management into testable, explicit modules; switch deduplication from fragile content-based matching to `correlation_key`; harden follow-up dispatch with bounded timeouts; fix form pre-fill for `phx-update="ignore"` textareas; and add observability to event processing.

All changes must be backward-compatible with in-flight sessions.

## UI Strategy

- **LiveView coverage**: 100% — all changes are Elixir-side logic or push-event coordination
- **TypeScript needed**: Yes — `session-form-hook.ts` (staleness TTL, push-event handling for pre-fill) and `session-optimistic-state-hook.ts` (staleness TTL for queued messages). No new hooks required, only modifications to existing hooks.

## Affected Boundaries

- **Owning app (interface)**: `agents_web` — owns Sessions LiveView, hooks, and UI logic
- **Owning app (domain)**: `agents` — owns Sessions context, `Agents.Repo`, domain entities
- **Repo**: `Agents.Repo` (no new migrations needed — this is a refactor)
- **Migrations**: None
- **Feature files**: `apps/agents_web/test/features/` (if BDD features are added)
- **Primary context**: `AgentsWeb.SessionsLive` (LiveView module namespace)
- **Dependencies**: `Agents.Sessions` (public facade API), `Agents.Sessions.Domain.Entities.TodoList`
- **Exported schemas**: None changed
- **New context needed?**: No — but extracting `SessionStateMachine` as a new module within `agents_web`

## Key Files

| File | Lines | Role |
|------|-------|------|
| `apps/agents_web/lib/live/sessions/index.ex` | 2164 | Main LiveView — implicit state machine, message submission |
| `apps/agents_web/lib/live/sessions/helpers.ex` | 310 | Pure helper functions — `task_running?`, `active_task?` |
| `apps/agents_web/lib/live/sessions/event_processor.ex` | 534 | Event processing — content-based dedup |
| `apps/agents_web/assets/js/presentation/hooks/session-form-hook.ts` | 167 | Draft persistence, keyboard submit, push events |
| `apps/agents_web/assets/js/presentation/hooks/session-optimistic-state-hook.ts` | 181 | Queue persistence to localStorage |
| `apps/agents_web/test/live/sessions/event_processor_test.exs` | 528 | EventProcessor unit tests |
| `apps/agents_web/test/live/sessions/helpers_test.exs` | 259 | Helpers unit tests |

## Pre-existing Issues (Do Not Fix)

- `index_test.exs:2360` — missing `ProjectTicketRepository.list_by_statuses/1` (unrelated)

---

## Phase 1: Extract Explicit Session State Machine

**Goal:** Model session state transitions as an explicit, unit-tested state machine module. Replace scattered `task_running?` / `active_task?` guards with state machine queries.

### 1.1 SessionStateMachine Module

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/sessions/session_state_machine_test.exs`
  - Tests:
    - Define all valid states: `:idle`, `:pending`, `:starting`, `:running`, `:queued`, `:awaiting_feedback`, `:completed`, `:failed`, `:cancelled`
    - `state_from_status/1` — converts string status to atom state (e.g., `"running"` → `:running`, `nil` → `:idle`)
    - `can_submit_message?/1` — returns true for `:running`, `:queued`, `:awaiting_feedback`
    - `task_running?/1` — returns true for `:pending`, `:starting`, `:running` (matches current behavior)
    - `active?/1` — returns true for `:pending`, `:starting`, `:running`, `:queued`, `:awaiting_feedback`
    - `terminal?/1` — returns true for `:completed`, `:failed`, `:cancelled`
    - `resumable?/1` — returns true for terminal states (with additional context — container_id and session_id must be present)
    - `should_send_as_follow_up?/1` — returns true for `:running` (message goes to running task, not as new task)
    - `should_queue_or_start?/1` — returns true for `:queued` (currently falls through to `run_or_resume_task` — this is the bug fix)
    - Edge case: `"queued"` status currently routes to `run_or_resume_task` because `task_running?` is false — new state machine should route it to `send_message_to_running_task` or queue
  - All tests use `ExUnit.Case, async: true` — pure functions, no I/O
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/sessions/session_state_machine.ex`
  - Pure module with no dependencies
  - `@type state :: :idle | :pending | :starting | :running | :queued | :awaiting_feedback | :completed | :failed | :cancelled`
  - All guard functions as pure predicates
  - `submission_route/1` returning `:follow_up | :queue_or_start | :blocked` based on state
- [ ] ⏸ **REFACTOR**: Clean up — add `@moduledoc`, `@doc`, typespecs

### 1.2 Update Helpers to Delegate to State Machine

- [ ] ⏸ **RED**: Update tests in `apps/agents_web/test/live/sessions/helpers_test.exs`
  - Add test: `task_running?` for `"queued"` status returns false (existing behavior preserved)
  - Add test: `active_task?` for `"queued"` status returns true (existing behavior preserved)
  - Add test: new `submittable_task?/1` predicate that returns true for running AND queued AND awaiting_feedback
  - Verify backward compatibility: all existing tests still pass
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/helpers.ex`
  - Import or alias `SessionStateMachine`
  - `task_running?/1` delegates to `SessionStateMachine.task_running?/1` via `state_from_status/1`
  - `active_task?/1` delegates to `SessionStateMachine.active?/1` via `state_from_status/1`
  - Add `submittable_task?/1` — delegates to `SessionStateMachine.can_submit_message?/1`
- [ ] ⏸ **REFACTOR**: Remove duplicate status string lists from helpers

### 1.3 Update index.ex Message Submission Guard

- [ ] ⏸ **RED**: Write focused unit test for the submission routing logic
  - Test in `apps/agents_web/test/live/sessions/session_state_machine_test.exs`:
    - `submission_route(:queued)` returns `:follow_up` (or `:queue_or_start` — design decision)
    - `submission_route(:running)` returns `:follow_up`
    - `submission_route(:awaiting_feedback)` returns `:follow_up`
    - `submission_route(:completed)` returns `:queue_or_start`
    - `submission_route(:idle)` returns `:queue_or_start`
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex` `handle_event("run_task", ...)`
  - Replace `task_running?(socket.assigns.current_task)` guard with state machine:
    ```elixir
    state = SessionStateMachine.state_from_status(socket.assigns.current_task)
    route = SessionStateMachine.submission_route(state)
    ```
  - Route `:follow_up` → `send_message_to_running_task`
  - Route `:queue_or_start` → `run_or_resume_task`
  - This fixes the "queued" task gap where submissions fell through incorrectly
- [ ] ⏸ **REFACTOR**: Extract the routing cond block into a named function

### Phase 1 Validation

- [ ] ⏸ All state machine tests pass (`mix test apps/agents_web/test/live/sessions/session_state_machine_test.exs`)
- [ ] ⏸ All helpers tests pass (`mix test apps/agents_web/test/live/sessions/helpers_test.exs`)
- [ ] ⏸ Full agents_web test suite passes (`mix test apps/agents_web`)
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ **Commit**: `refactor(agents_web): extract explicit session state machine (#369)`

---

## Phase 2: Switch Deduplication to correlation_key

**Goal:** Replace content-based queued message dedup with `correlation_key` matching as primary strategy, falling back to content match for backward compatibility.

### 2.1 Add correlation_key Matching to EventProcessor

- [ ] ⏸ **RED**: Add tests in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - New `describe "process_event/2 — message.updated (user) correlation_key dedup"`:
    - Test: When user message event has a `correlationKey` field matching a queued message's `correlation_key`, that queued message is removed
    - Test: When user message event has a `correlation_key` field (underscore variant), matching works
    - Test: `correlation_key` match takes priority over content match (if both could match, only one removal happens)
    - Test: Falls back to content match when no `correlationKey` present (backward compat)
    - Test: Falls back to content match when `correlationKey` doesn't match any queued message
    - Test: Handles queued messages without `correlation_key` field gracefully (content fallback)
  - Update existing content-dedup tests to remain passing (backward compat)
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/event_processor.ex`
  - In the `process_event` clause for `"message.updated"` with `"role" => "user"`:
    - Extract `correlation_key` from event info (check `"correlationKey"`, `"correlation_key"`, `"correlationID"` fields)
    - Try `correlation_key` match first via new `remove_matching_queued_message_by_key/2`
    - Fall back to `remove_matching_queued_message/2` (existing content-based) if no key match
  - New private function `remove_matching_queued_message_by_key(socket, correlation_key)`:
    - Finds first queued message where `msg.correlation_key == correlation_key`
    - Removes it from `queued_messages` assign
    - Returns `{socket, matched?}` tuple to control fallback
  - Existing `remove_matching_queued_message/2` unchanged (fallback path)
- [ ] ⏸ **REFACTOR**: Extract correlation key extraction into a reusable helper

### 2.2 Centralize SDK Field Name Resolution

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/sessions/sdk_field_resolver_test.exs`
  - Tests:
    - `resolve_message_id/1` — extracts from `"id"`, `"messageID"`, `"messageId"` (priority order)
    - `resolve_correlation_key/1` — extracts from `"correlationKey"`, `"correlation_key"`, `"correlationID"`
    - `resolve_tool_call_id/1` — extracts from `"id"`, `"toolCallID"`, `"toolCallId"`, `"callID"`
    - `resolve_model_id/1` — extracts from `"modelID"`, `"modelId"`, `"model_id"`
    - Returns nil when no recognized field is present
    - All tests async, pure functions
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/sessions/sdk_field_resolver.ex`
  - Pure module with `@moduledoc`
  - One function per field concept
  - Used by EventProcessor in place of scattered inline fallback chains
- [ ] ⏸ **REFACTOR**: Update `event_processor.ex` to use `SdkFieldResolver`
  - Replace `part["messageID"] || part["messageId"]` patterns
  - Replace `part["toolCallID"] || part["toolCallId"] || part["callID"]` patterns
  - Replace `info["modelID"]` pattern
  - Verify all existing EventProcessor tests still pass

### Phase 2 Validation

- [ ] ⏸ All EventProcessor tests pass (`mix test apps/agents_web/test/live/sessions/event_processor_test.exs`)
- [ ] ⏸ SdkFieldResolver tests pass
- [ ] ⏸ Full agents_web test suite passes
- [ ] ⏸ No boundary violations
- [ ] ⏸ **Commit**: `refactor(agents_web): switch dedup to correlation_key with content fallback (#369)`

---

## Phase 3: Harden Follow-up Dispatch

**Goal:** Replace `Task.start` (fire-and-forget) with `Task.async` + bounded timeout for follow-up message dispatch. Ensure every dispatched message produces a result callback (success or failure) within a configurable time window.

### 3.1 Bounded Follow-up Dispatch

- [ ] ⏸ **RED**: Write test in `apps/agents_web/test/live/sessions/follow_up_dispatch_test.exs`
  - Tests:
    - When dispatch succeeds within timeout, queued message is removed normally
    - When dispatch times out (simulated), queued message status changes to `"timed_out"`
    - When dispatch fails, queued message status changes to `"rolled_back"` (existing behavior)
    - Timeout value is configurable (default 30 seconds)
    - Multiple concurrent follow-ups each get their own timeout tracking
    - Fire-and-forget Task.start is NOT used (safety assertion)
  - Note: These tests may need to use a lightweight approach since we're testing handle_info behavior. Consider testing the dispatch helper as a pure function or use a minimal socket mock.
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex`
  - Replace `handle_info({:dispatch_follow_up_message, ...})`:
    ```elixir
    # BEFORE: Task.start (fire-and-forget)
    Task.start(fn -> ... end)

    # AFTER: Track with Process.send_after timeout
    task_ref = make_ref()
    Task.start(fn ->
      result = Sessions.send_message(...)
      send(caller, {:follow_up_send_result, correlation_key, result})
    end)
    # Schedule a timeout check
    Process.send_after(self(), {:follow_up_timeout, correlation_key, task_ref}, @follow_up_timeout_ms)
    ```
  - Add `@follow_up_timeout_ms 30_000` module attribute
  - Track pending follow-ups in a new assign `:pending_follow_ups` (map of `correlation_key => %{ref: ref, dispatched_at: DateTime}`)
  - Add `handle_info({:follow_up_timeout, correlation_key, ref})`:
    - Check if the follow-up is still pending (hasn't been resolved by success/failure)
    - If still pending, mark queued message as `"timed_out"` and broadcast queue snapshot
    - Log a warning for observability
  - Update `handle_info({:follow_up_send_result, ...})`:
    - Remove from `pending_follow_ups` on success or failure
    - Existing error handling preserved
- [ ] ⏸ **REFACTOR**: Extract follow-up tracking logic into private helper functions

### 3.2 Queued Message Timeout for "pending" State

- [ ] ⏸ **RED**: Add tests for queued message staleness in state machine or helpers
  - Test: `stale_queued_message?/1` returns true for messages pending > 120 seconds
  - Test: `stale_queued_message?/1` returns false for recent messages
  - Test: Integration — when a task status transitions to terminal, all pending queued messages for that task are cleared
- [ ] ⏸ **GREEN**: Add `stale_queued_message?/1` to helpers or state machine
  - Reuse existing `@optimistic_stale_seconds 120` constant pattern
  - Add periodic cleanup in `handle_info({:task_status_changed, ...})` for terminal states (already partially implemented — queued_messages cleared on completed/failed)
- [ ] ⏸ **REFACTOR**: Ensure consistent staleness TTL between Elixir and TypeScript

### Phase 3 Validation

- [ ] ⏸ Follow-up dispatch tests pass
- [ ] ⏸ All existing handle_info tests in index_test.exs still pass
- [ ] ⏸ Full agents_web test suite passes
- [ ] ⏸ No boundary violations
- [ ] ⏸ **Commit**: `refactor(agents_web): harden follow-up dispatch with bounded timeout (#369)`

---

## Phase 4: Fix Form Pre-fill and localStorage Staleness

**Goal:** Ensure server-side form pre-fill reaches the textarea via push events through the hook (working around `phx-update="ignore"`). Add staleness TTL to hydrated queued messages from localStorage.

### 4.1 Push-event Based Form Pre-fill (Elixir side)

- [ ] ⏸ **RED**: Write tests for form pre-fill behavior
  - In `apps/agents_web/test/live/sessions/session_state_machine_test.exs` or a new test file:
    - Test: `needs_draft_restore?/2` returns true when transitioning to a terminal state and there's a user message to restore
    - Test: `needs_draft_restore?/2` returns false when transitioning between active states
  - In EventProcessor or index test:
    - Test: When `restore_draft` push event is needed, the correct text is extracted
- [ ] ⏸ **GREEN**: Verify and clean up push event usage in `index.ex`
  - Audit all places where `assign(:form, to_form(%{"instruction" => message}))` is used alongside `push_event("restore_draft", ...)`:
    - `do_cancel_task/3` (L1731): Already uses `push_event("restore_draft", %{text: instruction})` ✓
    - `handle_question_result_basic({:error, :task_not_running}, ...)` (L1614): Sets form but does NOT push `restore_draft` — **BUG**: textarea won't update due to `phx-update="ignore"`
  - Fix: Add `push_event("restore_draft", %{text: message})` wherever form instruction is set for display
- [ ] ⏸ **REFACTOR**: Extract `set_form_instruction/2` helper that both assigns the form AND pushes the restore event

### 4.2 localStorage Staleness TTL for Queued Messages (TypeScript)

- [ ] ⏸ **RED**: Write Vitest test `apps/agents_web/assets/js/presentation/hooks/__tests__/session-optimistic-state-hook.test.ts`
  - **NOTE**: This requires adding Vitest to `agents_web` `package.json` devDependencies
  - Tests:
    - `isStaleEntry(entry, ttlMs)` returns true when `queued_at` is older than `ttlMs`
    - `isStaleEntry(entry, ttlMs)` returns false for recent entries
    - `isStaleEntry(entry, ttlMs)` returns true when `queued_at` is missing/invalid
    - `filterStaleEntries(entries, ttlMs)` removes stale entries from array
    - Default TTL is 120 seconds (matching Elixir-side `@optimistic_stale_seconds`)
- [ ] ⏸ **GREEN**: Update `apps/agents_web/assets/js/presentation/hooks/session-optimistic-state-hook.ts`
  - Add `private readonly STALE_TTL_MS = 120_000` constant
  - Add `private isStaleEntry(entry: OptimisticQueueEntry): boolean` method
  - In `hydrateFromStorage()`: Filter out stale entries before pushing to server
  - Export `isStaleEntry` and `filterStaleEntries` as standalone pure functions for testability
- [ ] ⏸ **REFACTOR**: Add consistent staleness TTL constant shared between queue and new session logic

### 4.3 localStorage Staleness TTL for Draft Persistence (TypeScript)

- [ ] ⏸ **RED**: Write Vitest test `apps/agents_web/assets/js/presentation/hooks/__tests__/session-form-hook.test.ts`
  - Tests:
    - Draft is restored when it's within staleness TTL
    - Draft is NOT restored (and is cleaned up) when it's older than TTL
    - Draft TTL is longer than queue TTL (e.g., 24 hours) since drafts are user-authored text
    - `readDraft()` returns empty string for stale drafts
- [ ] ⏸ **GREEN**: Update `apps/agents_web/assets/js/presentation/hooks/session-form-hook.ts`
  - Change storage format from plain string to `{ text: string, savedAt: number }` JSON
  - Add staleness check in `readDraft()` — discard drafts older than TTL
  - Backward compat: If stored value is plain string (old format), treat as valid but migrate to new format on next write
- [ ] ⏸ **REFACTOR**: Extract storage utility functions for reuse

### Phase 4 Validation

- [ ] ⏸ TypeScript tests pass (Vitest)
- [ ] ⏸ All Elixir tests pass
- [ ] ⏸ Manual verification: form pre-fill works after cancel/question rejection
- [ ] ⏸ No boundary violations
- [ ] ⏸ **Commit**: `fix(agents_web): form pre-fill via push events and localStorage staleness TTL (#369)`

---

## Phase 5: Add Observability to Event Processing

**Goal:** Log unrecognized SSE events instead of silently dropping them. Add lightweight telemetry for debugging event processing issues.

### 5.1 Log Unrecognized Events

- [ ] ⏸ **RED**: Update tests in `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - New `describe "process_event/2 — unknown events"`:
    - Test: Unknown event type returns socket unchanged (existing behavior preserved)
    - Test: Unknown event type triggers a Logger.debug call (in dev/staging)
    - Test: Known event types do NOT trigger the unknown event log
    - Test: `todo.updated` is explicitly skipped (existing behavior) — not logged as unknown
  - Use `ExUnit.CaptureLog` to assert log output
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/sessions/event_processor.ex`
  - Change the catch-all clause:
    ```elixir
    # BEFORE:
    def process_event(_event, socket), do: socket

    # AFTER:
    def process_event(event, socket) do
      if Application.get_env(:agents_web, :log_unknown_events, true) do
        require Logger
        Logger.debug("EventProcessor: unhandled event type=#{inspect(event["type"])}")
      end
      socket
    end
    ```
  - Keep `todo.updated` as an explicit no-op clause (before catch-all) to avoid logging it
- [ ] ⏸ **REFACTOR**: Consider using structured Logger metadata for machine-readable logs

### 5.2 Event Processing Telemetry (Optional Enhancement)

- [ ] ⏸ **RED**: Write test for event processing metrics
  - Test: Processing a known event emits a telemetry event with type and duration
  - Test: Processing an unknown event emits a telemetry event with `unhandled: true`
  - Use `:telemetry_test` helpers if available, otherwise assert via Logger
- [ ] ⏸ **GREEN**: Add lightweight telemetry wrapper
  - Wrap `process_event/2` calls in `index.ex` `handle_info({:task_event, ...})` with timing:
    ```elixir
    {time_us, socket} = :timer.tc(fn -> EventProcessor.process_event(event, socket) end)
    # Optional: :telemetry.execute([:agents_web, :event_processor, :process], %{duration: time_us}, %{type: event["type"]})
    ```
  - This is low-priority and can be deferred
- [ ] ⏸ **REFACTOR**: Ensure telemetry doesn't add measurable overhead

### Phase 5 Validation

- [ ] ⏸ All EventProcessor tests pass (including new logging assertions)
- [ ] ⏸ Full agents_web test suite passes
- [ ] ⏸ No boundary violations
- [ ] ⏸ **Commit**: `feat(agents_web): log unrecognized SSE events for observability (#369)`

---

## Pre-commit Checkpoint

After all phases are complete:

- [ ] ⏸ `mix precommit` passes (formatting, credo, compilation, tests)
- [ ] ⏸ `mix boundary` passes (no violations)
- [ ] ⏸ Full umbrella test suite: `mix test` from root
- [ ] ⏸ All acceptance criteria from ticket #369 are met

---

## Testing Strategy

### Test Distribution

| Layer | New Tests | Updated Tests | Test Type |
|-------|-----------|---------------|-----------|
| Domain (pure functions) | ~20 | ~5 | `ExUnit.Case, async: true` |
| Application (state machine) | ~15 | 0 | `ExUnit.Case, async: true` |
| Infrastructure (event processor) | ~10 | ~8 | `ExUnit.Case, async: true` |
| Interface (LiveView) | ~5 | ~3 | `AgentsWeb.ConnCase` or focused unit |
| TypeScript (hooks) | ~12 | 0 | Vitest |

**Total estimated new tests:** ~62
**Total estimated test updates:** ~16

### New Test Files

1. `apps/agents_web/test/live/sessions/session_state_machine_test.exs` — Pure state machine logic
2. `apps/agents_web/test/live/sessions/sdk_field_resolver_test.exs` — SDK field name resolution
3. `apps/agents_web/test/live/sessions/follow_up_dispatch_test.exs` — Follow-up dispatch with timeouts
4. `apps/agents_web/assets/js/presentation/hooks/__tests__/session-optimistic-state-hook.test.ts` — Staleness TTL
5. `apps/agents_web/assets/js/presentation/hooks/__tests__/session-form-hook.test.ts` — Draft staleness

### Updated Test Files

1. `apps/agents_web/test/live/sessions/event_processor_test.exs` — correlation_key dedup, unknown event logging
2. `apps/agents_web/test/live/sessions/helpers_test.exs` — Delegation to state machine

### New Source Files

1. `apps/agents_web/lib/live/sessions/session_state_machine.ex` — Explicit state machine
2. `apps/agents_web/lib/live/sessions/sdk_field_resolver.ex` — SDK field name centralization

### Modified Source Files

1. `apps/agents_web/lib/live/sessions/index.ex` — Submission guards, follow-up dispatch, form pre-fill
2. `apps/agents_web/lib/live/sessions/helpers.ex` — Delegate to state machine
3. `apps/agents_web/lib/live/sessions/event_processor.ex` — correlation_key dedup, field resolver, logging
4. `apps/agents_web/assets/js/presentation/hooks/session-form-hook.ts` — Draft staleness TTL
5. `apps/agents_web/assets/js/presentation/hooks/session-optimistic-state-hook.ts` — Queue staleness TTL

---

## Acceptance Criteria Traceability

| Criterion | Phase | Test(s) |
|-----------|-------|---------|
| Session state transitions modeled in explicit state machine | Phase 1 | `session_state_machine_test.exs` |
| `task_running?`, `active_task?` derive from state machine | Phase 1 | `helpers_test.exs` (updated) |
| Dedup uses `correlation_key` primary, content fallback | Phase 2 | `event_processor_test.exs` (new describe) |
| Follow-up dispatch has bounded timeout | Phase 3 | `follow_up_dispatch_test.exs` |
| Pending queued messages have timeout/retry | Phase 3 | `follow_up_dispatch_test.exs`, state machine tests |
| Form pre-fill via push event through hook | Phase 4 | Manual + unit tests |
| localStorage hydration has staleness TTL | Phase 4 | `session-optimistic-state-hook.test.ts` |
| Unrecognized SSE events are logged | Phase 5 | `event_processor_test.exs` (new describe) |
| SDK field name resolution centralized | Phase 2 | `sdk_field_resolver_test.exs` |
| All changes backward-compatible | All | Existing test suite passes |

---

## Architectural Notes

### Why a State Machine Instead of Status String Checks?

The current code has 7+ assigns tracking session state, with `task_running?` and `active_task?` checking status strings in scattered locations. The state machine:

1. **Makes transitions explicit** — all valid states and transitions in one place
2. **Fixes the "queued" gap** — submissions to queued tasks currently fall through to `run_or_resume_task` instead of queuing as follow-ups
3. **Enables testing** — pure function predicates testable in milliseconds
4. **Reduces coupling** — LiveView doesn't need to know about specific status strings

### Why correlation_key Over Content Matching?

Content-based dedup fails when:
- Two identical messages are queued (user sends "fix the bug" twice)
- Message content is modified between send and echo (trimming, encoding)
- Content extraction depends on SDK format variants

`correlation_key` is already generated and flows through the entire pipeline but is never used for dedup. Using it is a strict improvement with content matching as a fallback for in-flight messages.

### Why Not a Supervised Task for Follow-up Dispatch?

`Task.Supervisor` would be the most robust option, but:
1. It requires adding a supervisor to the application tree
2. The follow-up dispatch is tightly coupled to the LiveView process (result callback goes back to `self()`)
3. `Task.start` + `Process.send_after` timeout achieves the bounded guarantee with minimal change

If follow-up reliability becomes critical, a dedicated `FollowUpDispatcher` GenServer can be added in a future iteration.

### TypeScript Test Infrastructure

No Vitest setup exists in `agents_web`. Phase 4 requires:
1. Adding `vitest` to `devDependencies` in `apps/agents_web/assets/package.json`
2. Creating `vitest.config.ts` in `apps/agents_web/assets/`
3. Extracting pure functions from hooks for testability

This is the minimum viable setup — hooks themselves aren't fully testable without DOM mocking, but the staleness/filtering logic can be extracted and tested as pure functions.

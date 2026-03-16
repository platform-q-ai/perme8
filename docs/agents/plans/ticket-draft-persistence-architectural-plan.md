# Feature: Ticket-Scoped Draft Persistence & Explicit Session-Ticket Association

**Ticket**: [#439](https://github.com/platform-q-ai/perme8/issues/439)
**Status**: ⏸ Not Started
**BDD Feature File**: `apps/agents_web/test/features/dashboard/ticket-draft-persistence.browser.feature`

## Overview

Two related problems in the dashboard:

1. **Text area drafts are not ticket-scoped** — draft persistence keys are based on `session:<container_id>` or `task:<task_id>`, so switching between tickets doesn't preserve per-ticket draft state. When a ticket has no associated session yet, drafts go to `session:new` — a single shared key for all tickets without sessions.

2. **Session-ticket association relies on regex parsing** — the system injects `#<number>` into instruction text, then after task creation regex-parses it back out to link the ticket. This causes false associations (any message containing `#N`), lost associations (edited text), and fragile dual-strategy enrichment.

This plan addresses both problems by:
- Making `data-draft-key` ticket-scoped (e.g., `ticket:<number>`) when a ticket is active
- Adding a `switch_draft_key` push event so the hook can save/restore drafts when the key changes (works despite `phx-update="ignore"`)
- Passing `ticket_number` explicitly through `CreateTask` and `link_ticket_to_session` instead of regex extraction
- Removing regex-based linking from `TicketSessionLinker.persist_ticket_link`

## UI Strategy

- **LiveView coverage**: ~85% — all server logic, form handling, and push events
- **TypeScript needed**: Yes — modifications to `SessionFormHook` for ticket-scoped draft key switching via push events and `MutationObserver` fallback

## App Ownership

| Artifact | App | Path |
|----------|-----|------|
| **Owning app (domain)** | `agents` | `apps/agents/` |
| **Owning app (interface)** | `agents_web` | `apps/agents_web/` |
| **Repo** | `Agents.Repo` | — |
| **Migrations** | `agents` | `apps/agents/priv/repo/migrations/` |
| **Domain entities** | `agents` | `apps/agents/lib/agents/sessions/domain/entities/`, `apps/agents/lib/agents/tickets/domain/entities/` |
| **Domain policies** | `agents` | `apps/agents/lib/agents/tickets/domain/policies/` |
| **Use cases** | `agents` | `apps/agents/lib/agents/sessions/application/use_cases/` |
| **Infrastructure repositories** | `agents` | `apps/agents/lib/agents/tickets/infrastructure/repositories/` |
| **LiveView interface** | `agents_web` | `apps/agents_web/lib/live/dashboard/` |
| **LiveView tests** | `agents_web` | `apps/agents_web/test/live/dashboard/` |
| **TS hooks** | `agents_web` | `apps/agents_web/assets/js/presentation/hooks/` |
| **TS tests** | `agents_web` | `apps/agents_web/assets/js/__tests__/presentation/hooks/` |
| **Feature files (UI)** | `agents_web` | `apps/agents_web/test/features/dashboard/` |

## Affected Boundaries

- **Primary context**: `Agents.Sessions` (CreateTask use case — accept `ticket_number`)
- **Secondary context**: `Agents.Tickets` (link operations, enrichment policy)
- **Dependencies**: `Agents.Sessions` → `Agents.Tickets` (public API for linking), `Perme8.Events` (event bus)
- **Exported schemas**: No new exports needed
- **New context needed?**: No — all changes within existing `Sessions` and `Tickets` contexts

## BDD Scenario Coverage

The following BDD scenarios from `ticket-draft-persistence.browser.feature` must pass after implementation:

| # | Scenario | Implementation Phase |
|---|----------|---------------------|
| 1 | Draft text persists across page reloads for a specific ticket | Phase 2 (TS hook) + Phase 2 (LiveView push event) |
| 2 | Switching between tickets preserves each ticket's draft text | Phase 2 (TS hook key switching) |
| 3 | Draft text survives server restart (simulated via page reload) | Phase 2 (localStorage persistence) |
| 4 | Submitting a message clears the draft for that ticket | Phase 2 (TS hook submit handler) |
| 5 | Play button associates the session with the ticket explicitly | Phase 1 (CreateTask + explicit linking) + Phase 2 (TicketHandlers) |
| 6 | Chat tab message with ticket selected creates explicitly linked session | Phase 1 + Phase 2 (TaskExecutionHandlers) |
| 7 | Ticket tab message with ticket selected creates explicitly linked session | Phase 1 + Phase 2 (TaskExecutionHandlers) |
| 8 | False ticket references in message text do not cause wrong associations | Phase 1 (remove regex linking) + Phase 2 |
| 9 | Session-ticket link persists across page reload | Phase 1 (session_id FK on ticket) |
| 10 | All three entry points produce consistent ticket associations | Phase 1 + Phase 2 (all paths unified) |

---

## Phase 1: Domain + Application (phoenix-tdd)

**Goal**: Accept `ticket_number` as a first-class parameter in `CreateTask`, link tickets to sessions explicitly (not via regex), and add a `link_ticket_to_session` function.

### 1.1 TicketLinkingPolicy — Pure validation for ticket linking

New domain policy that validates whether a ticket number is valid for linking (non-nil, positive integer). Pure function, no I/O.

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/policies/ticket_linking_policy_test.exs`
  - Tests:
    - `valid_ticket_number?/1` returns `true` for positive integers
    - `valid_ticket_number?/1` returns `false` for `nil`, `0`, negative, non-integer
    - `should_link?/1` returns `true` when ticket_number is present and valid
    - `should_link?/1` returns `false` when ticket_number is `nil`
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/policies/ticket_linking_policy.ex`
  - Module: `Agents.Tickets.Domain.Policies.TicketLinkingPolicy`
  - Pure functions, no I/O, no Repo
- [ ] ⏸ **REFACTOR**: Clean up

### 1.2 ProjectTicketRepository — Add `link_session/2` and `unlink_session/1`

Add repository functions to set/clear the `session_id` FK on the ticket record. The `session_id` column already exists on `sessions_project_tickets`.

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/repositories/project_ticket_repository_link_session_test.exs`
  - Tests (DataCase):
    - `link_session/2` sets `session_id` on the ticket record matching `ticket_number`
    - `link_session/2` returns `{:ok, updated_ticket}` on success
    - `link_session/2` returns `{:error, :ticket_not_found}` when ticket doesn't exist
    - `unlink_session/1` clears `session_id` on the ticket
    - `unlink_session/1` returns `{:error, :ticket_not_found}` when ticket doesn't exist
- [ ] ⏸ **GREEN**: Implement in `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex`
  - Add `link_session(ticket_number, session_id)` — similar to existing `link_task/2` but sets `session_id`
  - Add `unlink_session(ticket_number)` — similar to existing `unlink_task/1` but clears `session_id`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.3 Tickets Facade — Add `link_ticket_to_session/2` and `unlink_ticket_from_session/1`

Expose session linking through the `Agents.Tickets` public facade.

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets_link_session_test.exs`
  - Tests (DataCase):
    - `link_ticket_to_session/2` delegates to repository
    - `unlink_ticket_from_session/1` delegates to repository
- [ ] ⏸ **GREEN**: Implement in `apps/agents/lib/agents/tickets.ex`
  - Add `link_ticket_to_session(ticket_number, session_id)` delegating to `ProjectTicketRepository.link_session/2`
  - Add `unlink_ticket_from_session(ticket_number)` delegating to `ProjectTicketRepository.unlink_session/1`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.4 CreateTask — Accept `ticket_number` in attrs

Modify the `CreateTask` use case to accept an optional `ticket_number` in `attrs` and persist the ticket-session link atomically during task creation.

- [ ] ⏸ **RED**: Write tests in `apps/agents/test/agents/sessions/application/use_cases/create_task_test.exs` (add new describe block)
  - Tests:
    - When `attrs` includes `ticket_number: 42`, after task creation, the ticket's `session_id` is set to the task's `session_ref_id`
    - When `attrs` does NOT include `ticket_number`, no ticket linking occurs (backward compatible)
    - When `ticket_number` is provided but ticket doesn't exist in DB, task creation still succeeds (linking failure is non-fatal)
    - Linking uses `Tickets.link_ticket_to_session/2` (not regex extraction)
  - Mocks: `ticket_linker` dependency injection for the linking function
- [ ] ⏸ **GREEN**: Implement changes in `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex`
  - After session creation and task insertion, if `attrs[:ticket_number]` is present:
    - Call `Tickets.link_ticket_to_session(ticket_number, session_ref_id)`
    - Rescue/log failures — non-fatal
  - Accept `ticket_linker` in opts for dependency injection in tests
- [ ] ⏸ **REFACTOR**: Clean up — ensure the linking call is after the transaction commits

### 1.5 Sessions Facade — Forward `ticket_number` from `create_task/2`

Ensure the `Agents.Sessions.create_task/2` facade passes `ticket_number` through to `CreateTask.execute/2`.

- [ ] ⏸ **RED**: Add test in `apps/agents/test/agents/sessions_test.exs` (if exists, otherwise alongside existing integration tests)
  - Test: `create_task(%{instruction: "fix bug", user_id: uid, ticket_number: 42})` results in session linked to ticket 42
- [ ] ⏸ **GREEN**: No changes needed to `Sessions.create_task/2` — it already passes all `attrs` through to `CreateTask.execute/2`. Verify this is the case.
- [ ] ⏸ **REFACTOR**: Clean up

### 1.6 TicketEnrichmentPolicy — Add session-based enrichment path

The enrichment policy currently resolves tasks by `associated_task_id` FK or regex fallback. Add a third strategy: resolve by `session_id` on the ticket record, matching against the session's tasks.

- [ ] ⏸ **RED**: Write tests in `apps/agents/test/agents/tickets/domain/policies/ticket_enrichment_policy_test.exs` (add new describe block)
  - Tests:
    - When a ticket has `session_id` set and a task in the snapshot has a matching `session_ref_id`, the ticket is enriched with that task's data
    - Session-based match takes priority over regex fallback
    - Persisted `associated_task_id` still takes highest priority
    - When `session_id` is set but no matching task exists, falls back to regex (backward compat during migration)
- [ ] ⏸ **GREEN**: Implement in `apps/agents/lib/agents/tickets/domain/policies/ticket_enrichment_policy.ex`
  - Add `session_id` field awareness in `resolve_task/3`
  - Priority: `associated_task_id` → `session_id` match → regex fallback
  - Build a `task_by_session_id` index alongside existing indices
- [ ] ⏸ **REFACTOR**: Clean up — document the three strategies clearly

### 1.7 Ticket Entity — Add `session_id` field

Add `session_id` to the Ticket domain entity so enrichment and the UI layer can access it.

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/tickets/domain/entities/ticket_test.exs` (add to existing or create)
  - Test: `from_schema/1` maps `session_id` from schema to entity
  - Test: `new/1` accepts `session_id` attribute
- [ ] ⏸ **GREEN**: Implement in `apps/agents/lib/agents/tickets/domain/entities/ticket.ex`
  - Add `session_id: nil` to `defstruct`
  - Add `session_id` to `@type t`
  - Map `session_id` in `from_schema/1`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1 Validation

- [ ] ⏸ All domain policy tests pass (milliseconds, no I/O)
- [ ] ⏸ All use case tests pass (with mocks/DataCase)
- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Existing test suite passes (`mix test`)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

**Goal**: Wire the explicit ticket linking through all three entry points (play button, chat tab, ticket tab), update draft key generation to be ticket-scoped, and add push event for draft key switching.

### 2.1 TicketSessionLinker — Explicit session linking (replace regex)

Replace `persist_ticket_link/1` (which regex-extracts ticket number from instruction text) with explicit `persist_ticket_link/2` that accepts the ticket number directly.

- [ ] ⏸ **RED**: Write tests in `apps/agents_web/test/live/dashboard/ticket_session_linker_test.exs` (add new describe block)
  - Tests:
    - `link_and_refresh/3` (new arity) — given socket, task, and explicit `ticket_number: 42`:
      - Calls `Tickets.link_ticket_to_session(42, task.session_ref_id)` (NOT `link_ticket_to_task`)
      - Also calls `Tickets.link_ticket_to_task(42, task.id)` for backward compat
      - Returns updated socket with fresh `:tickets`
    - `link_and_refresh/3` — when `ticket_number` is `nil`:
      - Falls back to regex extraction from instruction (backward compat for play button path until fully migrated)
    - `link_and_refresh/3` — when `ticket_number` is provided:
      - Does NOT use regex extraction (explicit parameter takes priority)
- [ ] ⏸ **GREEN**: Implement in `apps/agents_web/lib/live/dashboard/ticket_session_linker.ex`
  - Add `link_and_refresh/3` accepting `(socket, task, opts)` where `opts` can include `ticket_number`
  - When `ticket_number` is provided: call `Tickets.link_ticket_to_session` directly
  - When `ticket_number` is nil: fall back to existing `persist_ticket_link/1` (regex)
  - Keep `link_and_refresh/2` as backward-compat wrapper calling `link_and_refresh/3` with empty opts
- [ ] ⏸ **REFACTOR**: Clean up

### 2.2 TaskExecutionHandlers — Pass `ticket_number` through all paths

Currently `run_task/2` extracts `ticket_number` from form params but only the ticket tab includes the hidden field. The chat tab needs to also pass the active ticket number.

- [ ] ⏸ **RED**: Write tests in `apps/agents_web/test/live/dashboard/task_execution_handlers_test.exs` (add or extend)
  - Tests:
    - `run_task/2` from ticket tab (with `ticket_number` form param): passes ticket_number to `run_or_resume_task`
    - `run_task/2` from chat tab (without `ticket_number` form param but with active ticket): uses socket's `active_ticket_number` assign as fallback
    - `run_task/2` with no active ticket: ticket_number is nil, no linking occurs
- [ ] ⏸ **GREEN**: Implement in `apps/agents_web/lib/live/dashboard/task_execution_handlers.ex`
  - In `run_task/2`: when `ticket_number` is nil from form params, fall back to `socket.assigns.active_ticket_number`
  - Pass `ticket_number` through `route_message_submission` to `run_or_resume_task`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.3 TaskExecutionHelpers — Forward `ticket_number` to `Sessions.create_task`

Wire `ticket_number` from the handler through to the `Sessions.create_task` call.

- [ ] ⏸ **RED**: Write tests (or extend existing) in `apps/agents_web/test/live/dashboard/helpers/task_execution_helpers_test.exs`
  - Tests:
    - `run_or_resume_task/4` when composing_new and ticket_number is present: includes `ticket_number` in `Sessions.create_task` attrs
    - `run_or_resume_task/4` when ticket_number is nil: does not include `ticket_number` in attrs
    - `handle_task_result/2` calls `TicketSessionLinker.link_and_refresh/3` with ticket_number from the active ticket context
- [ ] ⏸ **GREEN**: Implement in `apps/agents_web/lib/live/dashboard/helpers/task_execution_helpers.ex`
  - In `run_or_resume_task/4`: add `ticket_number` to the attrs map passed to `Sessions.create_task/1`:
    ```elixir
    attrs = %{instruction: instruction, user_id: user.id, image: socket.assigns.selected_image}
    attrs = if ticket_number, do: Map.put(attrs, :ticket_number, ticket_number), else: attrs
    ```
  - In `handle_task_result/2`: pass ticket context to `TicketSessionLinker.link_and_refresh/3`
- [ ] ⏸ **REFACTOR**: Clean up — remove `ensure_ticket_reference` call for linking purposes (keep it for agent context injection if needed)

### 2.4 TicketHandlers — Explicit linking in play button flow

The play button in `do_start_ticket_session/2` builds an instruction with `"pick up ticket #<number>"` and later regex-parses it back. Pass `ticket_number` explicitly.

- [ ] ⏸ **RED**: Write tests in `apps/agents_web/test/live/dashboard/ticket_handlers_test.exs` (extend existing)
  - Tests:
    - `start_ticket_session/2` passes `ticket_number` to `Sessions.create_task` attrs
    - After task creation, `handle_info({:new_task_created, ...})` calls `TicketSessionLinker.link_and_refresh/3` with explicit ticket_number
    - No regex extraction is used for linking in the play button path
- [ ] ⏸ **GREEN**: Implement in `apps/agents_web/lib/live/dashboard/ticket_handlers.ex`
  - In `do_start_ticket_session/2`: add `ticket_number: number` to the `Sessions.create_task` attrs
  - Store `ticket_number` in `pending_ticket_starts` map (already done: `Map.put(pending_ticket_starts, client_id, number)`)
  - In the `{:new_task_created, client_id, {:ok, task}}` handler (wherever it lives), use the stored ticket_number to call `TicketSessionLinker.link_and_refresh/3` explicitly
- [ ] ⏸ **REFACTOR**: Clean up

### 2.5 Detail Panel Components — Ticket-scoped `data-draft-key`

Update the `data-draft-key` attribute on the textarea to use a ticket-scoped key when a ticket is active.

- [ ] ⏸ **RED**: Write test (LiveView unit test) for the detail panel component rendering
  - Tests:
    - When `active_ticket_number` is set: `data-draft-key` is `"ticket:<number>"`
    - When no ticket is active and `active_container_id` is set: `data-draft-key` is `"session:<container_id>"` (existing behavior)
    - When no ticket and no container: `data-draft-key` is `"session:new"` (existing behavior)
- [ ] ⏸ **GREEN**: Implement in `apps/agents_web/lib/live/dashboard/components/detail_panel_components.ex`
  - Update the `data-draft-key` computation (lines 675-678):
    ```elixir
    data-draft-key={
      cond do
        is_integer(@active_ticket_number) ->
          "ticket:#{@active_ticket_number}"
        @active_container_id ->
          "session:#{@active_container_id}"
        @current_task ->
          "task:#{@current_task.id}"
        true ->
          "session:new"
      end
    }
    ```
- [ ] ⏸ **REFACTOR**: Clean up

### 2.6 Push `switch_draft_key` event on ticket selection

The textarea is wrapped in `phx-update="ignore"`, so server-side assign changes to `data-draft-key` won't reach the DOM. Push a server event to notify the hook when the draft key changes.

- [ ] ⏸ **RED**: Write LiveView test for ticket selection
  - Tests:
    - Selecting a ticket pushes `"switch_draft_key"` event with `%{key: "ticket:<number>"}`
    - Deselecting a ticket pushes `"switch_draft_key"` event with the appropriate fallback key
    - Switching between tickets pushes the new key
- [ ] ⏸ **GREEN**: Implement in ticket selection handlers
  - In `TicketHandlers.do_select_ticket/2`: add `push_event(socket, "switch_draft_key", %{key: "ticket:#{number}"})`
  - In `TaskExecutionHelpers.clear_form/1`: push appropriate key when clearing
  - In `handle_params` ticket resolution: push key when ticket changes via URL params
- [ ] ⏸ **REFACTOR**: Extract a `push_draft_key/2` helper that computes and pushes the correct key based on current assigns

### 2.7 Hidden `ticket_number` field on chat tab

Currently only the ticket tab includes the hidden `ticket_number` input. The chat tab also needs it when a ticket is active.

- [ ] ⏸ **RED**: Write LiveView test
  - Test: When `active_ticket_number` is set, the hidden `ticket_number` field is rendered regardless of which tab is active (remove the `:if` guard that restricts it to ticket tab)
- [ ] ⏸ **GREEN**: Implement in `apps/agents_web/lib/live/dashboard/components/detail_panel_components.ex`
  - Change line 664 from:
    ```elixir
    :if={@active_session_tab == "ticket" && is_integer(@active_ticket_number)}
    ```
    to:
    ```elixir
    :if={is_integer(@active_ticket_number)}
    ```
  - This ensures all tabs include the ticket_number when a ticket is active
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2 Validation

- [ ] ⏸ All interface tests pass
- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ Migrations run (`mix ecto.migrate`) — no new migrations needed (session_id column already exists)
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)

---

## Phase 3: TypeScript — Draft Key Switching (typescript-tdd)

**Goal**: Modify `SessionFormHook` to handle `switch_draft_key` push events so drafts are saved/restored when switching between tickets, and add a `MutationObserver` fallback for robustness.

### 3.1 Draft key management functions — Pure logic

Extract pure functions for draft key operations that can be unit tested without DOM dependencies.

- [ ] ⏸ **RED**: Write test `apps/agents_web/assets/js/__tests__/presentation/hooks/session-form-hook.test.ts` (extend existing)
  - Tests:
    - `buildStorageKey("ticket:42")` returns `"sessions:draft:ticket:42"`
    - `buildStorageKey("session:abc-123")` returns `"sessions:draft:session:abc-123"`
    - `buildStorageKey("")` returns `"sessions:draft:session-form"` (fallback)
    - `buildStorageKey(undefined)` returns `"sessions:draft:session-form"` (fallback)
- [ ] ⏸ **GREEN**: Export `buildStorageKeyFromScope` as a pure function from `session-form-hook.ts`
  ```typescript
  export function buildStorageKeyFromScope(scopedKey: string | undefined): string {
    return `sessions:draft:${scopedKey || 'session-form'}`
  }
  ```
- [ ] ⏸ **REFACTOR**: Refactor `buildStorageKey()` instance method to use the exported pure function

### 3.2 SessionFormHook — Handle `switch_draft_key` event

Add a `handleEvent('switch_draft_key', ...)` listener that saves the current draft under the old key and restores any draft from the new key.

- [ ] ⏸ **RED**: Write test (extend existing test file)
  - Tests (these test the pure logic; DOM interaction tested via BDD):
    - `switchDraftKey(oldKey, newKey, currentValue)` saves `currentValue` under `oldKey` and returns the draft text from `newKey` (or empty string)
    - When `oldKey === newKey`, no save/restore occurs (returns current value)
    - When new key has a stale draft, returns empty string
    - When new key has a fresh draft, returns the draft text
- [ ] ⏸ **GREEN**: Implement `switchDraftKey` as an exported pure function and wire into the hook:
  ```typescript
  export function switchDraftKey(
    oldKey: string,
    newKey: string,
    currentValue: string,
    storage: Storage = localStorage
  ): string {
    if (oldKey === newKey) return currentValue
    // Save current value under old key
    writeDraftToStorage(oldKey, currentValue, storage)
    // Read from new key
    return readDraftFromStorage(newKey, storage)
  }
  ```
  In `mounted()`:
  ```typescript
  this.handleEvent('switch_draft_key', ({ key }: { key: string }) => {
    const newStorageKey = buildStorageKeyFromScope(key)
    const restoredText = switchDraftKey(this.storageKey, newStorageKey, this.el.value)
    this.storageKey = newStorageKey
    this.el.value = restoredText
  })
  ```
- [ ] ⏸ **REFACTOR**: Extract localStorage read/write into standalone pure functions for testability

### 3.3 SessionFormHook — MutationObserver fallback for `data-draft-key`

Add a `MutationObserver` on the textarea element to detect when `data-draft-key` changes (in case the push event fails or for any programmatic DOM updates).

- [ ] ⏸ **RED**: Write test
  - Test: `onDraftKeyAttributeChange(oldKey, newKey, currentValue)` behaves identically to `switchDraftKey` (delegates to same function)
- [ ] ⏸ **GREEN**: Implement in `mounted()`:
  ```typescript
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      if (mutation.type === 'attributes' && mutation.attributeName === 'data-draft-key') {
        const newScopedKey = this.el.dataset.draftKey || ''
        const newStorageKey = buildStorageKeyFromScope(newScopedKey)
        if (newStorageKey !== this.storageKey) {
          const restoredText = switchDraftKey(this.storageKey, newStorageKey, this.el.value)
          this.storageKey = newStorageKey
          this.el.value = restoredText
        }
      }
    }
  })
  observer.observe(this.el, { attributes: true, attributeFilter: ['data-draft-key'] })
  ```
  Store observer reference for cleanup in `destroyed()`.
- [ ] ⏸ **REFACTOR**: Clean up — ensure observer is disconnected in `destroyed()`

### 3.4 SessionFormHook — Clear draft on submit for ticket-scoped key

The existing submit handler clears the draft and empties the textarea. Verify it works correctly with ticket-scoped keys (it should, since it uses `this.storageKey` which is now ticket-scoped).

- [ ] ⏸ **RED**: Write test
  - Test: After submit with a ticket-scoped key, `localStorage.getItem("sessions:draft:ticket:42")` is `null`
  - Test: After submit, other ticket drafts are NOT cleared (only the active ticket's draft)
- [ ] ⏸ **GREEN**: Existing implementation should work — `clearDraft()` uses `this.storageKey`. Verify and add defensive code if needed.
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3 Validation

- [ ] ⏸ All TypeScript tests pass (`npx vitest run`)
- [ ] ⏸ No TypeScript compilation errors
- [ ] ⏸ Manual smoke test: switching between tickets preserves drafts

---

## Phase 4: Integration & Cleanup (phoenix-tdd)

**Goal**: Remove regex-based linking from the hot path, clean up `ensure_ticket_reference` to only inject agent context (not for linking), and verify all BDD scenarios pass.

### 4.1 Remove regex from `TicketSessionLinker.persist_ticket_link`

Now that all three entry points pass `ticket_number` explicitly, the regex extraction in `persist_ticket_link/1` is no longer needed for the active linking path.

- [ ] ⏸ **RED**: Write test
  - Test: `link_and_refresh/3` with explicit ticket_number does NOT call `Tickets.extract_ticket_number` (no regex)
  - Test: `link_and_refresh/2` (backward compat, no ticket_number) still uses regex as fallback
- [ ] ⏸ **GREEN**: In `TicketSessionLinker`:
  - `link_and_refresh/3` with explicit ticket_number: call `Tickets.link_ticket_to_session` directly
  - `link_and_refresh/2`: keep regex fallback for backward compatibility
- [ ] ⏸ **REFACTOR**: Add deprecation note to `link_and_refresh/2` indicating it should be removed once all callers migrate

### 4.2 Simplify `ensure_ticket_reference` — context injection only

The `ensure_ticket_reference` function currently serves two purposes: (1) inject `#<number>` for regex-based linking, and (2) inject ticket context for the agent. Now that linking is explicit, it only needs to inject the context block.

- [ ] ⏸ **RED**: Write test
  - Test: `ensure_ticket_reference/3` with ticket present: appends context block but does NOT prepend `#<number>` to instruction text
  - Test: `ensure_ticket_reference/3` without ticket: returns instruction unchanged
  - Test: Instruction text containing `#5` is passed through as-is (no modification for linking)
- [ ] ⏸ **GREEN**: Implement in `apps/agents_web/lib/live/dashboard/helpers/ticket_data_helpers.ex`
  - Remove the `##{ticket.number}` prepending logic
  - Keep the `Tickets.build_ticket_context(ticket)` appending logic (agent still needs context)
  - When no ticket object is available, return instruction unchanged (don't prepend `#<number>`)
- [ ] ⏸ **REFACTOR**: Rename to `append_ticket_context/3` for clarity

### 4.3 TicketEnrichmentPolicy — Deprecate regex fallback (document-only)

The regex fallback in `TicketEnrichmentPolicy.resolve_task/3` should be marked for deprecation. It's still needed during the migration period but should eventually be removed.

- [ ] ⏸ **RED**: Write test
  - Test: When both `session_id` and regex would match different tasks, `session_id` wins
  - Test: When `session_id` is nil and `associated_task_id` is nil, regex still works (backward compat)
- [ ] ⏸ **GREEN**: Add `@deprecated` annotation and log warning when regex fallback is used
- [ ] ⏸ **REFACTOR**: Add follow-up ticket reference for full regex removal

### 4.4 Pre-commit Checkpoint

- [ ] ⏸ Run `mix precommit` — all checks pass
- [ ] ⏸ Run `mix boundary` — no violations
- [ ] ⏸ Run full test suite: `mix test`
- [ ] ⏸ Run TypeScript tests: `npx vitest run` (from `apps/agents_web/assets`)
- [ ] ⏸ Verify all 10 BDD scenarios in `ticket-draft-persistence.browser.feature` pass

### Phase 4 Validation

- [ ] ⏸ All cleanup tests pass
- [ ] ⏸ No regressions in existing tests
- [ ] ⏸ All BDD scenarios pass
- [ ] ⏸ No boundary violations

---

## Testing Strategy

### Test Distribution

| Layer | Test Count (est.) | Async? | Category |
|-------|-------------------|--------|----------|
| Domain (TicketLinkingPolicy) | 4 | Yes | Pure function, no I/O |
| Domain (Ticket entity) | 2 | Yes | Pure struct mapping |
| Domain (TicketEnrichmentPolicy) | 6 | Yes | Pure enrichment logic |
| Application (CreateTask) | 4 | Yes (DataCase) | Use case with mocked deps |
| Infrastructure (ProjectTicketRepository) | 5 | No (DataCase) | DB operations |
| Infrastructure (Tickets facade) | 2 | No (DataCase) | Thin delegation |
| Interface (TicketSessionLinker) | 5 | No (ConnCase) | Socket operations |
| Interface (TaskExecutionHandlers) | 3 | No (ConnCase) | Event routing |
| Interface (TaskExecutionHelpers) | 3 | No (ConnCase) | Task creation pipeline |
| Interface (TicketHandlers) | 3 | No (ConnCase) | Play button flow |
| Interface (DetailPanelComponents) | 3 | No (ConnCase) | Template rendering |
| TypeScript (session-form-hook) | 8 | Yes | Pure functions + hook behavior |
| BDD (browser features) | 10 | No | End-to-end browser tests |
| **Total** | **~58** | | |

### Test Pyramid

- **Domain**: ~12 tests (fast, pure, milliseconds)
- **Application**: ~4 tests (mocked deps, fast)
- **Infrastructure**: ~7 tests (DB, slower)
- **Interface**: ~17 tests (LiveView, socket operations)
- **TypeScript**: ~8 tests (unit, fast)
- **BDD**: ~10 scenarios (browser, slowest)

### Key Testing Patterns

1. **Domain Event Testing**: Use `TestEventBus` in CreateTask tests per AGENTS.md rules:
   ```elixir
   @default_opts [event_bus: TestEventBus]
   setup do
     TestEventBus.start_global()
     :ok
   end
   ```

2. **Push Event Verification**: Use `assert_push_event` in LiveView tests to verify `switch_draft_key` events:
   ```elixir
   assert_push_event(view, "switch_draft_key", %{key: "ticket:42"})
   ```

3. **localStorage in TS Tests**: Mock `localStorage` in Vitest tests for draft persistence:
   ```typescript
   const mockStorage = new Map<string, string>()
   const storage = { getItem: (k) => mockStorage.get(k), setItem: (k, v) => mockStorage.set(k, v), removeItem: (k) => mockStorage.delete(k) } as Storage
   ```

---

## Implementation Order Summary

```
Phase 1 (Domain + Application):
  1.1 TicketLinkingPolicy (pure)
  1.2 ProjectTicketRepository.link_session/unlink_session (infra)
  1.3 Tickets facade (link_ticket_to_session)
  1.4 CreateTask (accept ticket_number)
  1.5 Sessions facade (verify passthrough)
  1.6 TicketEnrichmentPolicy (session-based enrichment)
  1.7 Ticket entity (add session_id)

Phase 2 (Infrastructure + Interface):
  2.1 TicketSessionLinker (explicit linking)
  2.2 TaskExecutionHandlers (pass ticket_number)
  2.3 TaskExecutionHelpers (forward to create_task)
  2.4 TicketHandlers (play button explicit linking)
  2.5 Detail Panel Components (ticket-scoped draft key)
  2.6 Push switch_draft_key event
  2.7 Hidden ticket_number on all tabs

Phase 3 (TypeScript):
  3.1 Pure draft key functions
  3.2 switch_draft_key event handler
  3.3 MutationObserver fallback
  3.4 Submit clears ticket-scoped draft

Phase 4 (Integration + Cleanup):
  4.1 Remove regex from hot path
  4.2 Simplify ensure_ticket_reference
  4.3 Deprecate regex fallback
  4.4 Pre-commit checkpoint
```

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Breaking existing ticket-session links during migration | Keep backward-compat regex fallback in Phase 4; session_id column already exists with backfill migration |
| `phx-update="ignore"` prevents draft key update | Push event (`switch_draft_key`) + MutationObserver fallback — dual mechanism |
| Race condition between task creation and ticket linking | Linking happens in the same transaction as session creation in CreateTask; fallback logging on failure |
| False associations from regex still active | Regex fallback only used in deprecated `link_and_refresh/2` path; all new paths use explicit ticket_number |
| localStorage quota exceeded | Existing error handling in `writeDraft` catches and ignores storage errors |

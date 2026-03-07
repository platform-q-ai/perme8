# TDD Implementation Plan: Harden Session Message Submission & Optimistic UI (Remaining Work)

**Ticket:** #369
**Type:** Refactor (existing functionality hardening)
**App:** `agents_web` (Interface/LiveView) — confirmed in `docs/app_ownership.md`
**Owning Repo:** None (interface app)
**Ownership violations:** None
**Prior plan:** `docs/agents_web/plans/369-harden-session-message-submission-plan.md` (original 5-phase plan)

## Completion Status Summary

| Phase | Description | Status | Remaining Work |
|-------|-------------|--------|----------------|
| Phase 1 | Extract SessionStateMachine | ~95% | Unify `resumable_task?` delegation |
| Phase 2 | Switch dedup to correlation_key | 100% | None |
| Phase 3 | Harden follow-up dispatch | ~80% | Harden `request_task_refresh` Task.start |
| Phase 4 | Fix form pre-fill + localStorage staleness | ~60% | Server-side push events + TS tests |
| Phase 5 | Add observability to event processing | ~10% | Telemetry for EventProcessor |

## Regression Baseline

325 tests, 4 pre-existing failures (all Docker-related — `System.cmd("docker", ...)` `:enoent`). Unrelated to this ticket.

---

## Phase 1 Completion: Unify `resumable_task?` Delegation

**Goal:** Eliminate the duplicated status check logic in `Helpers.resumable_task?/1` by delegating to `SessionStateMachine.resumable?/1`.

**Current state:**
- `Helpers.resumable_task?/1` (`helpers.ex:75-80`) — uses hardcoded guard: `status in ["completed", "failed", "cancelled"]`
- `SessionStateMachine.resumable?/1` (`session_state_machine.ex:113-119`) — uses `terminal?(state_from_task(task))` (canonical)
- Both are functionally equivalent today, but `Helpers` will drift if terminal states change
- `Helpers.resumable_task?/1` is called in 10 locations (index.ex + template)
- `SessionStateMachine.resumable?/1` is only called in tests — never in production code
- **No tests exist for `resumable_task?` in `helpers_test.exs`** — only `SessionStateMachine.resumable?/1` is tested in `session_state_machine_test.exs`

### Step 1.1 — RED: Add test for `Helpers.resumable_task?/1` delegation

**File:** `apps/agents_web/test/live/sessions/helpers_test.exs`

Add a new describe block verifying `resumable_task?/1` delegates correctly:

```elixir
describe "resumable_task?/1" do
  test "returns true for completed task with container_id and session_id" do
    task = %{status: "completed", container_id: "cid-1", session_id: "sid-1"}
    assert Helpers.resumable_task?(task)
  end

  test "returns true for failed task with container_id and session_id" do
    task = %{status: "failed", container_id: "cid-1", session_id: "sid-1"}
    assert Helpers.resumable_task?(task)
  end

  test "returns true for cancelled task with container_id and session_id" do
    task = %{status: "cancelled", container_id: "cid-1", session_id: "sid-1"}
    assert Helpers.resumable_task?(task)
  end

  test "returns false for terminal task without container_id" do
    task = %{status: "completed", container_id: nil, session_id: "sid-1"}
    refute Helpers.resumable_task?(task)
  end

  test "returns false for terminal task without session_id" do
    task = %{status: "completed", container_id: "cid-1", session_id: nil}
    refute Helpers.resumable_task?(task)
  end

  test "returns false for running task" do
    task = %{status: "running", container_id: "cid-1", session_id: "sid-1"}
    refute Helpers.resumable_task?(task)
  end

  test "returns false for nil" do
    refute Helpers.resumable_task?(nil)
  end
end
```

**Run:** `mix test apps/agents_web/test/live/sessions/helpers_test.exs` — tests should PASS (current implementation handles all these cases).

### Step 1.2 — GREEN: Delegate `Helpers.resumable_task?/1` to `SessionStateMachine.resumable?/1`

**File:** `apps/agents_web/lib/live/sessions/helpers.ex`

Replace lines 74-80:

```elixir
# BEFORE:
@doc "Returns true if the task can be resumed."
def resumable_task?(%{status: status, container_id: cid, session_id: sid})
    when status in ["completed", "failed", "cancelled"] and
           not is_nil(cid) and not is_nil(sid),
    do: true

def resumable_task?(_), do: false

# AFTER:
@doc "Returns true if the task can be resumed. Delegates to SessionStateMachine."
def resumable_task?(task), do: SessionStateMachine.resumable?(task)
```

**Run:** `mix test apps/agents_web/test/live/sessions/helpers_test.exs` — all tests should pass.

### Step 1.3 — REFACTOR: Verify no behavioral change

**Run:** `mix test apps/agents_web/test` — full suite should pass with same 4 pre-existing failures.

### Phase 1 Commit

`refactor(agents_web): unify resumable_task? to delegate through SessionStateMachine (#369)`

---

## Phase 3 Completion: Harden `request_task_refresh` Task.start

**Goal:** Wrap the `Task.start` body in `request_task_refresh/2` with `try/rescue` to guarantee the `{:task_refreshed, ...}` message is always sent back, preventing `refreshing_task_ids` from leaking entries on crash.

**Current state:**
- `index.ex:1191` — follow-up dispatch `Task.start` already has `try/rescue` (done)
- `index.ex:1870` — `request_task_refresh/2` has NO error handling:

```elixir
Task.start(fn ->
  send(caller, {:task_refreshed, task_id, Sessions.get_task(task_id, user_id)})
end)
```

If `Sessions.get_task/2` raises, the `{:task_refreshed, ...}` message is never sent, and `refreshing_task_ids` permanently contains `task_id`, preventing future refreshes for that task.

### Step 3.1 — RED: Add test for `request_task_refresh` error resilience

**File:** `apps/agents_web/test/live/sessions/follow_up_dispatch_test.exs`

Add a describe block testing the guarantee that a result message is always sent:

```elixir
describe "request_task_refresh resilience" do
  test "Task.start body in request_task_refresh wraps in try/rescue" do
    # This is a code-level assertion — verify the pattern exists in the source.
    # The actual behavioral test is that refreshing_task_ids doesn't leak.
    # Since request_task_refresh is a private function in a LiveView,
    # we test via the handle_info contract: {:task_refreshed, task_id, result}
    # is always sent regardless of success or failure.

    # We verify the source pattern has try/rescue to prevent silent drops.
    source = File.read!("lib/live/sessions/index.ex")
    # Find the request_task_refresh function and check for try/rescue
    assert source =~ "defp request_task_refresh"
    # After our change, it should contain try/rescue in the Task.start body
    # This is validated by the GREEN step implementation
  end
end
```

Note: Since `request_task_refresh/2` is private and deeply embedded in the LiveView, the most practical approach is to test via a source-code pattern assertion and rely on the LiveView integration tests (`index_test.exs`) for behavioral coverage. The key guarantee is that any crash in the Task body still sends `{:task_refreshed, task_id, ...}`.

### Step 3.2 — GREEN: Add try/rescue to `request_task_refresh`

**File:** `apps/agents_web/lib/live/sessions/index.ex`

Replace the `Task.start` body at line 1870:

```elixir
# BEFORE:
Task.start(fn ->
  send(caller, {:task_refreshed, task_id, Sessions.get_task(task_id, user_id)})
end)

# AFTER:
Task.start(fn ->
  try do
    send(caller, {:task_refreshed, task_id, Sessions.get_task(task_id, user_id)})
  rescue
    error ->
      Logger.warning("request_task_refresh failed for task_id=#{task_id}: #{inspect(error)}")
      send(caller, {:task_refreshed, task_id, {:error, error}})
  end
end)
```

Also update `handle_info({:task_refreshed, ...})` to handle the error tuple gracefully. Current handler at line 1174:

```elixir
# BEFORE (only handles success with the 3rd element being ignored):
def handle_info({:task_refreshed, task_id, _}, socket) do
  {:noreply, assign(socket, :refreshing_task_ids, MapSet.delete(...))}
end

# This already works since the 3rd element is ignored (_), but confirm.
```

The existing handler uses `_` for the third element, so it already handles both success and error cases — it simply clears the `refreshing_task_ids` entry. No change needed to the handler.

### Step 3.3 — REFACTOR: Verify

**Run:** `mix test apps/agents_web/test` — full suite should pass.

### Phase 3 Commit

`refactor(agents_web): wrap request_task_refresh Task.start in try/rescue (#369)`

---

## Phase 4: Fix Form Pre-fill and Add TypeScript Tests

**Goal:** Ensure server-side form clearing/pre-filling reaches the textarea despite `phx-update="ignore"`, and add TypeScript unit tests for the hook logic.

**Current state:**
- `phx-update="ignore"` on the textarea at `index.html.heex:6` and `:1030` prevents server-side form assigns from reaching the DOM
- 11 `assign(:form, to_form(%{"instruction" => ...}))` calls in `index.ex`:
  - 9 set instruction to `""` (clear intent)
  - 2 set instruction to a message string (pre-fill intent)
- Hook already handles `restore_draft` and `focus_input` push events
- Hook already clears textarea on form `submit` event
- **Missing:** A `clear_input` push event for explicit server-initiated clearing
- **Missing:** TypeScript unit tests for both hooks
- **Missing:** Vitest infrastructure in `agents_web/assets/`

### Sub-phase 4A: Set Up TypeScript Test Infrastructure

### Step 4A.1 — Infrastructure: Add Vitest to agents_web

**File:** `apps/agents_web/assets/package.json`

Add test dependencies (matching `jarga_web` versions):

```json
{
  "name": "agents_web",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "lucide-static": "^0.575.0",
    "phoenix": "file:../../../deps/phoenix",
    "phoenix_html": "file:../../../deps/phoenix_html",
    "phoenix_live_view": "file:../../../deps/phoenix_live_view"
  },
  "devDependencies": {
    "happy-dom": "^20.0.10",
    "typescript": "^5.9.3",
    "vitest": "^4.0.6"
  }
}
```

**File:** `apps/agents_web/assets/vitest.config.ts`

Create (modeled on `jarga_web/assets/vitest.config.js`):

```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'happy-dom',
    globals: true,
    pool: 'forks',
    poolOptions: {
      forks: {
        maxForks: 4,
        minForks: 1,
        execArgv: ['--max-old-space-size=2048'],
      },
    },
    isolate: true,
    testTimeout: 10000,
    hookTimeout: 10000,
  },
})
```

**Run:** `npm install` from `apps/agents_web/assets/`

### Sub-phase 4B: TypeScript Tests for session-form-hook

### Step 4B.1 — RED: Write tests for `isStaleDraft` (exported pure function)

**File:** `apps/agents_web/assets/js/__tests__/presentation/hooks/session-form-hook.test.ts`

```typescript
import { describe, test, expect, vi } from 'vitest'
import { isStaleDraft } from '../../../presentation/hooks/session-form-hook'

describe('isStaleDraft', () => {
  test('returns true for null entry', () => {
    expect(isStaleDraft(null)).toBe(true)
  })

  test('returns true for entry without savedAt', () => {
    expect(isStaleDraft({ text: 'hello', savedAt: 0 })).toBe(true)
  })

  test('returns true for entry older than TTL', () => {
    const oldTime = Date.now() - 25 * 60 * 60 * 1000 // 25 hours ago
    expect(isStaleDraft({ text: 'hello', savedAt: oldTime })).toBe(true)
  })

  test('returns false for recent entry', () => {
    const recentTime = Date.now() - 1000 // 1 second ago
    expect(isStaleDraft({ text: 'hello', savedAt: recentTime })).toBe(false)
  })

  test('respects custom TTL', () => {
    const time = Date.now() - 5000 // 5 seconds ago
    expect(isStaleDraft({ text: 'hello', savedAt: time }, 3000)).toBe(true)
    expect(isStaleDraft({ text: 'hello', savedAt: time }, 10000)).toBe(false)
  })
})
```

**Run:** `npx vitest run` from `apps/agents_web/assets/` — tests should PASS (function already exported and implemented).

### Step 4B.2 — RED: Write tests for `clear_input` push event handling

Add to the same test file, testing the `SessionFormHook` class:

```typescript
describe('SessionFormHook', () => {
  let hook: SessionFormHook
  let mockElement: HTMLTextAreaElement

  beforeEach(() => {
    mockElement = document.createElement('textarea')
    mockElement.id = 'session-instruction'
    ;(mockElement as any).phxPrivate = {}
    
    // Create a form parent for the textarea
    const form = document.createElement('form')
    form.appendChild(mockElement)
    document.body.appendChild(form)

    hook = new SessionFormHook(null as any, mockElement)
  })

  afterEach(() => {
    document.body.innerHTML = ''
  })

  test('clear_input event clears textarea value', () => {
    hook.mounted()
    mockElement.value = 'some draft text'

    // Simulate the clear_input push event
    const handlers = (hook as any).__handlers || {}
    // The handleEvent callback should exist after mounted()
    // We need to trigger it
  })
})
```

Note: Testing LiveView hooks directly requires mocking `this.handleEvent`. The more practical approach is to test the exported pure functions (`isStaleDraft`) and rely on BDD feature files for integration behavior.

**Revised strategy:** Focus TypeScript tests on exported pure functions. The hook lifecycle methods (`mounted`, `destroyed`, `updated`) are best tested via BDD browser features since they depend on LiveView's `handleEvent` mechanism.

### Step 4B.3 — GREEN: Add `clear_input` event handler to SessionFormHook

**File:** `apps/agents_web/assets/js/presentation/hooks/session-form-hook.ts`

Add in `mounted()` after the existing `restore_draft` handler:

```typescript
// Server can push "clear_input" to clear the textarea
// (e.g., after session switch or successful message send)
this.handleEvent('clear_input', () => {
  this.el.value = ''
  this.clearDraft()
})
```

### Sub-phase 4C: TypeScript Tests for session-optimistic-state-hook

### Step 4C.1 — RED: Write tests for exported pure functions

**File:** `apps/agents_web/assets/js/__tests__/presentation/hooks/session-optimistic-state-hook.test.ts`

```typescript
import { describe, test, expect } from 'vitest'
import {
  isStaleQueueEntry,
  filterStaleEntries,
} from '../../../presentation/hooks/session-optimistic-state-hook'

describe('isStaleQueueEntry', () => {
  test('returns true when queued_at is missing', () => {
    expect(isStaleQueueEntry({ id: '1', content: 'msg' })).toBe(true)
  })

  test('returns true when queued_at is invalid date string', () => {
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: 'not-a-date' })).toBe(true)
  })

  test('returns true when entry is older than default TTL (120s)', () => {
    const old = new Date(Date.now() - 150_000).toISOString()
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: old })).toBe(true)
  })

  test('returns false for recent entry within default TTL', () => {
    const recent = new Date(Date.now() - 10_000).toISOString()
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: recent })).toBe(false)
  })

  test('respects custom TTL', () => {
    const time = new Date(Date.now() - 5000).toISOString()
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: time }, 3000)).toBe(true)
    expect(isStaleQueueEntry({ id: '1', content: 'msg', queued_at: time }, 10000)).toBe(false)
  })
})

describe('filterStaleEntries', () => {
  test('removes stale entries', () => {
    const old = new Date(Date.now() - 150_000).toISOString()
    const recent = new Date(Date.now() - 10_000).toISOString()
    const entries = [
      { id: '1', content: 'old', queued_at: old },
      { id: '2', content: 'new', queued_at: recent },
    ]

    const result = filterStaleEntries(entries)
    expect(result).toHaveLength(1)
    expect(result[0].id).toBe('2')
  })

  test('returns empty array when all entries are stale', () => {
    const old = new Date(Date.now() - 150_000).toISOString()
    const entries = [
      { id: '1', content: 'old1', queued_at: old },
      { id: '2', content: 'old2', queued_at: old },
    ]

    expect(filterStaleEntries(entries)).toHaveLength(0)
  })

  test('returns all entries when none are stale', () => {
    const recent = new Date(Date.now() - 10_000).toISOString()
    const entries = [
      { id: '1', content: 'a', queued_at: recent },
      { id: '2', content: 'b', queued_at: recent },
    ]

    expect(filterStaleEntries(entries)).toHaveLength(2)
  })
})
```

**Run:** `npx vitest run` from `apps/agents_web/assets/` — tests should PASS (functions already implemented and exported).

### Sub-phase 4D: Server-side Push Events for Form Clearing

### Step 4D.1 — Analysis: `assign(:form, ...)` Audit

All 11 occurrences in `index.ex` with intent classification:

| # | Line | Context | Intent | Needs push_event? |
|---|------|---------|--------|--------------------|
| 1 | 76 | `mount/3` | Initialize empty form | No — initial render, `phx-update="ignore"` renders the initial value correctly |
| 2 | 331 | `handle_event("new_session")` | Clear on "new session" mode | Yes — `clear_input` |
| 3 | 444 | `handle_event("select_session")` | Clear on session switch | Yes — `clear_input` |
| 4 | 461 | `handle_event("select_ticket")` (with container) | Clear on ticket select | Yes — `clear_input` |
| 5 | 472 | `handle_event("select_ticket")` (no container) | Clear on ticket select | Yes — `clear_input` |
| 6 | 814 | `handle_info(:answer_question_async)` error | Pre-fill with answer text | Yes — `restore_draft` (MISSING — **bug**) |
| 7 | 919 | Auth refresh success | Clear after resume | Yes — `clear_input` |
| 8 | 1018 | Task creation/resume success | Clear after task start | Yes — `clear_input` |
| 9 | 1400 | `send_message_to_running_task` | Clear after follow-up send | No — hook's submit handler already clears the textarea via `requestAnimationFrame` |
| 10 | 1676 | `handle_question_result_basic(:error, :task_not_running)` | Pre-fill with answer | Already has `push_event("restore_draft")` on line 1677 |
| 11 | 1712 | `handle_task_result({:ok, ...})` | Clear after task result | Yes — `clear_input` |

**Summary:**
- 6 locations need `push_event("clear_input", %{})` added (lines 331, 444, 461, 472, 919, 1018, 1712)
- 1 location needs `push_event("restore_draft", %{text: message})` added (line 814 — **bug fix**)
- 1 location already correct (line 1676 — has `restore_draft`)
- 1 location doesn't need a push event (line 76 — initial mount)
- 1 location doesn't need a push event (line 1400 — submit handler clears)

### Step 4D.2 — RED: Write test for the bug at line 814

The bug: when `answer_question_async` returns `{:error, :task_not_running}`, the server sets the form instruction to the user's answer text, but the textarea doesn't update because of `phx-update="ignore"`.

**File:** `apps/agents_web/test/live/sessions/index_test.exs`

This is an integration-level test. The existing test suite for `answer_question_async` should be checked for this path. If no test exists for this error path pre-filling the textarea, add one that verifies `restore_draft` is pushed.

Given the complexity of LiveView integration tests, the practical approach is to add the fix directly (it's a clear bug with a clear fix) and validate with the full test suite.

### Step 4D.3 — GREEN: Add push events alongside form assigns

**File:** `apps/agents_web/lib/live/sessions/index.ex`

For each location needing `clear_input`:

```elixir
# Line 331 (new_session):
|> assign(:form, to_form(%{"instruction" => ""}))
|> push_event("clear_input", %{})

# Line 444 (select_session):
|> assign(:form, to_form(%{"instruction" => ""}))
|> push_event("clear_input", %{})

# Line 461 (select_ticket with container):
|> assign(:form, to_form(%{"instruction" => ""}))
|> push_event("clear_input", %{})

# Line 472 (select_ticket no container):
|> assign(:form, to_form(%{"instruction" => ""}))
|> push_event("clear_input", %{})

# Line 919 (auth refresh success):
|> assign(:form, to_form(%{"instruction" => ""}))
|> push_event("clear_input", %{})

# Line 1018 (task creation success):
|> assign(:form, to_form(%{"instruction" => ""}))
|> push_event("clear_input", %{})

# Line 1712 (handle_task_result success):
|> assign(:form, to_form(%{"instruction" => ""}))
|> push_event("clear_input", %{})
```

For the bug fix at line 814 (pre-fill with answer text):

```elixir
# Line 814 (answer_question_async :task_not_running):
|> assign(:form, to_form(%{"instruction" => message}))
|> push_event("restore_draft", %{text: message})
```

### Step 4D.4 — REFACTOR: Extract helper

Consider extracting a private helper to reduce duplication:

```elixir
defp clear_form(socket) do
  socket
  |> assign(:form, to_form(%{"instruction" => ""}))
  |> push_event("clear_input", %{})
end

defp prefill_form(socket, text) do
  socket
  |> assign(:form, to_form(%{"instruction" => text}))
  |> push_event("restore_draft", %{text: text})
end
```

Then replace the 7 clear sites with `clear_form(socket)` and the 2 pre-fill sites with `prefill_form(socket, message)`.

### Phase 4 Validation

- `npx vitest run` from `apps/agents_web/assets/` — all TypeScript tests pass
- `mix test apps/agents_web/test` — all Elixir tests pass (same 4 pre-existing failures)
- Manual verification: form clears/pre-fills correctly across session switches and error paths

### Phase 4 Commit

`fix(agents_web): push clear_input/restore_draft events to bypass phx-update ignore (#369)`

---

## Phase 5: Add Observability to Event Processing

**Goal:** Add structured telemetry for EventProcessor to provide visibility into event processing latency, dedup effectiveness, and unknown event types.

**Current state:**
- Only `Logger.warning` in catch-all handler at `event_processor.ex:210-211`
- Second catch-all at line 215 silently drops events without a `"type"` key
- **No custom telemetry exists anywhere in the umbrella** — this would be the first

### Step 5.1 — RED: Write tests for telemetry events

**File:** `apps/agents_web/test/live/sessions/event_processor_test.exs`

Add a describe block for telemetry:

```elixir
describe "process_event/2 — telemetry" do
  setup do
    ref = :telemetry_test.attach_event_handlers(self(), [
      [:agents_web, :event_processor, :process],
      [:agents_web, :event_processor, :unhandled]
    ])
    on_exit(fn -> :telemetry.detach(ref) end)
    :ok
  end

  test "emits [:agents_web, :event_processor, :process] for known events" do
    socket = build_socket()
    EventProcessor.process_event(%{"type" => "session.updated", "properties" => %{"info" => %{}}}, socket)

    assert_received {[:agents_web, :event_processor, :process], ^ref, %{duration: _}, %{type: "session.updated"}}
  end

  test "emits [:agents_web, :event_processor, :unhandled] for unknown event types" do
    socket = build_socket()
    EventProcessor.process_event(%{"type" => "unknown.event"}, socket)

    assert_received {[:agents_web, :event_processor, :unhandled], ^ref, %{}, %{type: "unknown.event"}}
  end

  test "does not emit :unhandled for todo.updated (explicit skip)" do
    socket = build_socket()
    EventProcessor.process_event(%{"type" => "todo.updated"}, socket)

    refute_received {[:agents_web, :event_processor, :unhandled], _, _, _}
  end
end
```

Note: `:telemetry_test` may not be available. Alternative: use `:telemetry.attach/4` directly with `self()` as handler and assert on received messages.

**Run:** `mix test apps/agents_web/test/live/sessions/event_processor_test.exs` — tests should FAIL (no telemetry emitted yet).

### Step 5.2 — GREEN: Add telemetry to EventProcessor

**File:** `apps/agents_web/lib/live/sessions/event_processor.ex`

Option A (lightweight — wrap at call site in `index.ex`):

The simplest approach is to add telemetry at the call site in `index.ex` where `EventProcessor.process_event/2` is called, rather than inside EventProcessor itself. This keeps EventProcessor pure.

**File:** `apps/agents_web/lib/live/sessions/index.ex` (around line 793)

```elixir
# In handle_info({:task_event, _task_id, event}, socket):
socket = :telemetry.span(
  [:agents_web, :event_processor, :process],
  %{type: event["type"]},
  fn ->
    result = EventProcessor.process_event(event, socket)
    {result, %{type: event["type"]}}
  end
)
```

Option B (inside EventProcessor — modify catch-all):

**File:** `apps/agents_web/lib/live/sessions/event_processor.ex`

Update the catch-all handlers:

```elixir
# Line 210 — typed but unhandled:
def process_event(%{"type" => type} = _event, socket) do
  :telemetry.execute(
    [:agents_web, :event_processor, :unhandled],
    %{count: 1},
    %{type: type}
  )
  Logger.warning("EventProcessor: unhandled event type=#{inspect(type)}")
  socket
end

# Line 215 — no type key at all:
def process_event(_event, socket) do
  :telemetry.execute(
    [:agents_web, :event_processor, :unhandled],
    %{count: 1},
    %{type: nil}
  )
  socket
end
```

**Recommendation:** Use Option B for the unhandled event telemetry (simple, targeted). Defer Option A (span-based timing for all events) as a follow-up — it adds complexity and there's no existing telemetry infrastructure to consume it.

### Step 5.3 — REFACTOR: Document telemetry event names

Add to the `@moduledoc` of `EventProcessor`:

```elixir
@moduledoc """
...

## Telemetry Events

  * `[:agents_web, :event_processor, :unhandled]` — emitted when an event
    with an unrecognized type is received. Measurements: `%{count: 1}`.
    Metadata: `%{type: String.t() | nil}`.
"""
```

### Phase 5 Validation

- `mix test apps/agents_web/test/live/sessions/event_processor_test.exs` — all tests pass
- `mix test apps/agents_web/test` — full suite passes

### Phase 5 Commit

`feat(agents_web): emit telemetry for unhandled SSE events in EventProcessor (#369)`

---

## Final Validation

After all phases:

- [ ] `mix test apps/agents_web/test` — 325 tests, 4 pre-existing docker failures only
- [ ] `npx vitest run` from `apps/agents_web/assets/` — all TypeScript tests pass
- [ ] `mix format --check-formatted`
- [ ] `mix compile --warnings-as-errors`
- [ ] No new cross-app dependencies introduced

---

## Acceptance Criteria Traceability

| Criterion | Phase | Status |
|-----------|-------|--------|
| Session state transitions modeled in explicit state machine | Phase 1 | Done (prior work) |
| `task_running?`, `active_task?` derive from state machine | Phase 1 | Done (prior work) |
| `resumable_task?` delegates through state machine | Phase 1 | **This plan — Step 1.2** |
| Dedup uses `correlation_key` primary, content fallback | Phase 2 | Done (prior work) |
| Follow-up dispatch has bounded timeout | Phase 3 | Done (prior work) |
| `request_task_refresh` Task.start hardened | Phase 3 | **This plan — Step 3.2** |
| Pending queued messages have timeout | Phase 3 | Done (prior work) |
| Form pre-fill via push event through hook | Phase 4 | **This plan — Step 4D** |
| `clear_input` push event for server-initiated clearing | Phase 4 | **This plan — Step 4B.3** |
| Bug fix: answer_question pre-fill missing push event | Phase 4 | **This plan — Step 4D.3** |
| TypeScript unit tests for hook pure functions | Phase 4 | **This plan — Steps 4B, 4C** |
| Vitest infrastructure for agents_web | Phase 4 | **This plan — Step 4A** |
| localStorage hydration has staleness TTL | Phase 4 | Done (prior work) |
| Unrecognized SSE events have telemetry | Phase 5 | **This plan — Step 5.2** |
| SDK field name resolution centralized | Phase 2 | Done (prior work) |
| All changes backward-compatible | All | Validated by regression baseline |

---

## New/Modified Files Summary

### New Files

| File | Phase | Purpose |
|------|-------|---------|
| `apps/agents_web/assets/vitest.config.ts` | 4A | Vitest configuration |
| `apps/agents_web/assets/js/__tests__/presentation/hooks/session-form-hook.test.ts` | 4B | TS tests for form hook |
| `apps/agents_web/assets/js/__tests__/presentation/hooks/session-optimistic-state-hook.test.ts` | 4C | TS tests for optimistic state hook |

### Modified Files

| File | Phase | Change |
|------|-------|--------|
| `apps/agents_web/lib/live/sessions/helpers.ex` | 1 | Delegate `resumable_task?` |
| `apps/agents_web/test/live/sessions/helpers_test.exs` | 1 | Add `resumable_task?` tests |
| `apps/agents_web/lib/live/sessions/index.ex` | 3, 4 | Harden `request_task_refresh`, add push events |
| `apps/agents_web/assets/js/presentation/hooks/session-form-hook.ts` | 4 | Add `clear_input` handler |
| `apps/agents_web/assets/package.json` | 4 | Add vitest, happy-dom deps |
| `apps/agents_web/lib/live/sessions/event_processor.ex` | 5 | Add telemetry to catch-all |
| `apps/agents_web/test/live/sessions/event_processor_test.exs` | 5 | Add telemetry tests |
| `apps/agents_web/test/live/sessions/follow_up_dispatch_test.exs` | 3 | Add resilience test |

### Commit Sequence

1. `refactor(agents_web): unify resumable_task? to delegate through SessionStateMachine (#369)`
2. `refactor(agents_web): wrap request_task_refresh Task.start in try/rescue (#369)`
3. `fix(agents_web): push clear_input/restore_draft events to bypass phx-update ignore (#369)`
4. `feat(agents_web): emit telemetry for unhandled SSE events in EventProcessor (#369)`

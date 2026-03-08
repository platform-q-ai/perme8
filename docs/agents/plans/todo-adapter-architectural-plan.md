# Feature: Agent Session Todo Adapter for UI Progress Bar

**GitHub Issue**: [#273](https://github.com/platform-q-ai/perme8/issues/273)
**Sub-Issues**: [#253](https://github.com/platform-q-ai/perme8/issues/253) (progress bar UI)
**Ticket**: `docs/agents/tickets/todo-adapter-ticket.md`
**BDD Feature**: `apps/agents_web/test/features/sessions/todo-progress-bar.browser.feature`

## Overview

Implement passive-mode interception of `todo.updated` SSE events from opencode's built-in TodoWrite tool. Parse the events, cache todo state in TaskRunner, broadcast via PubSub, persist to DB (periodic flush), and render a numbered progress bar component in the Sessions LiveView. Support full state restoration on reconnect.

This covers all P0 requirements. P1 (MCP tool, domain events) and P2 (step pipeline) are documented as future work.

## UI Strategy

- **LiveView coverage**: 100% — progress bar is a pure HEEx function component
- **TypeScript needed**: None — no client-side interactivity beyond what LiveView provides

## App Ownership

- **Owning app**: `agents` (domain context)
- **Owning Repo**: `Agents.Repo`
- **Migration path**: `apps/agents/priv/repo/migrations/`
- **Domain path**: `apps/agents/lib/agents/sessions/`
- **Web path**: `apps/agents_web/lib/agents_web/` (aliased as `apps/agents_web/lib/live/sessions/`)
- **Feature files**: `apps/agents_web/test/features/sessions/`
- **Tests (domain)**: `apps/agents/test/agents/sessions/`
- **Tests (web)**: `apps/agents_web/test/live/sessions/`

## Affected Boundaries

- **Primary context**: `Agents.Sessions`
- **Dependencies**: `perme8_events` (PubSub server)
- **Exported schemas**: `Agents.Sessions.Domain.Entities.TodoItem`, `Agents.Sessions.Domain.Entities.TodoList` (exported for LiveView usage)
- **New context needed?**: No — todo state is intrinsic to session tasks; it belongs within `Agents.Sessions`

## BDD Feature File Coverage

The implementation plan is designed to satisfy all scenarios in `todo-progress-bar.browser.feature`:

| Scenario | Requirements | Covered By |
|----------|-------------|------------|
| Progress bar appears when session has todo list | `todo-progress` testid, summary text, 4 step elements | Phase 2: progress_bar component + LiveView todo_items assign |
| Progress bar shows numbered step names | `todo-step-1` contains "1." and step title | Phase 2: progress_bar component rendering |
| Progress bar shows completed steps and correct summary | "3/7 steps complete", `is-completed` class | Phase 1: TodoList.progress_summary/1 + Phase 2: component |
| Progress bar shows failed steps | `is-failed`, `is-in-progress`, `is-pending` classes | Phase 2: component status-to-CSS-class mapping |
| Progress bar hidden when no todo list | `todo-progress` should not exist | Phase 2: conditional rendering on empty todo_items |
| Progress bar persists after page reload | Summary text matches before/after reload | Phase 1: DB persistence + Phase 2: reconnect restoration |
| Completed session shows final todo state | `todo-progress` exists, summary contains "steps complete" | Phase 1: final flush + Phase 2: reconnect restoration |
| @wip: Live execution updates | Real-time PubSub → LiveView updates | Phase 1: TaskRunner broadcast + Phase 2: LiveView handler |
| @wip: Todo list replacement | Reset to new list | Phase 1: TaskRunner replaces todo_items on new list |

---

## Phase 1: Domain + Application (phoenix-tdd) ✓

Build the pure domain models and the behaviour port. All domain tests run `async: true` with no I/O.

### Step 1.1: TodoItem Domain Entity

- [x] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/todo_item_test.exs`
  - Tests:
    - `new/1` creates a TodoItem struct with required fields (id, title, status, position)
    - Default status is `"pending"`
    - `valid_statuses/0` returns `["pending", "in_progress", "completed", "failed"]`
    - `completed?/1` returns true only for `"completed"` status
    - `terminal?/1` returns true for `"completed"` and `"failed"`
    - `from_map/1` converts a raw map (string keys from SSE JSON) to a TodoItem struct
    - `from_map/1` handles missing keys gracefully (defaults)
    - `to_map/1` serialises TodoItem to a plain map for JSON persistence
  - File: `apps/agents/test/agents/sessions/domain/entities/todo_item_test.exs`
  - Case: `use ExUnit.Case, async: true`

- [x] ⏸ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/entities/todo_item.ex`
  - Pure struct: `defstruct [:id, :title, :position, status: "pending"]`
  - `@type t :: %__MODULE__{id: String.t(), title: String.t(), status: String.t(), position: non_neg_integer()}`
  - Functions: `new/1`, `valid_statuses/0`, `completed?/1`, `terminal?/1`, `from_map/1`, `to_map/1`
  - No Ecto, no I/O

- [x] ⏸ **REFACTOR**: Ensure typespec coverage, add `@moduledoc`

### Step 1.2: TodoList Domain Entity

- [x] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/todo_list_test.exs`
  - Tests:
    - `new/1` creates a TodoList with a list of TodoItem structs
    - `from_sse_event/1` parses a raw SSE `todo.updated` event payload into a TodoList
    - `from_sse_event/1` handles malformed payloads (returns `{:error, :invalid_payload}`)
    - `from_sse_event/1` assigns position based on item order in the list
    - `progress_percentage/1` calculates completed / total * 100 (returns float)
    - `progress_percentage/1` returns 0.0 for empty list
    - `completed_count/1` returns count of completed items
    - `total_count/1` returns total items
    - `progress_summary/1` returns "3/7 steps complete" format string
    - `current_step/1` returns the first `in_progress` item, or first `pending` if none in progress
    - `all_completed?/1` returns true when all items are completed
    - `to_maps/1` serialises the list of TodoItems to a list of plain maps
    - `from_maps/1` deserialises a list of maps back to TodoItems
  - File: `apps/agents/test/agents/sessions/domain/entities/todo_list_test.exs`
  - Case: `use ExUnit.Case, async: true`

- [x] ⏸ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/entities/todo_list.ex`
  - Pure struct: `defstruct items: []`
  - `@type t :: %__MODULE__{items: [TodoItem.t()]}`
  - Functions: `new/1`, `from_sse_event/1`, `progress_percentage/1`, `completed_count/1`, `total_count/1`, `progress_summary/1`, `current_step/1`, `all_completed?/1`, `to_maps/1`, `from_maps/1`
  - `from_sse_event/1` must handle the opencode SSE payload shape. Based on the ticket, the `todo.updated` event has properties containing todo items with id, title, status. The exact shape may need refinement during implementation — log the catch-all events first if needed.
  - No Ecto, no I/O

- [x] ⏸ **REFACTOR**: Extract shared validation, ensure consistent error tuples

### Step 1.3: TodoAdapterBehaviour Port

- [x] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/behaviours/todo_adapter_behaviour_test.exs`
  - Tests:
    - Module defines the behaviour callbacks (compile-time check via `@callback` presence)
    - Verify Mox mock can be defined against the behaviour (ensures callbacks are well-formed)
  - File: `apps/agents/test/agents/sessions/application/behaviours/todo_adapter_behaviour_test.exs`
  - Case: `use ExUnit.Case, async: true`

- [x] ⏸ **GREEN**: Implement `apps/agents/lib/agents/sessions/application/behaviours/todo_adapter_behaviour.ex`
  - Callbacks:
    - `@callback parse_event(event :: map()) :: {:ok, TodoList.t()} | {:error, term()}`
    - `@callback get_todos(task_id :: String.t()) :: TodoList.t() | nil`
    - `@callback store_todos(task_id :: String.t(), TodoList.t()) :: :ok`
    - `@callback clear_todos(task_id :: String.t()) :: :ok`
  - Types: `@type task_id :: String.t()`

- [x] ⏸ **REFACTOR**: Verify callbacks match ticket contract; add `@moduledoc` with usage docs

### Step 1.4: Register Mox Mock for TodoAdapterBehaviour

- [x] ⏸ Register `Agents.Mocks.TodoAdapterMock` in the test support configuration
  - Add `Mox.defmock(Agents.Mocks.TodoAdapterMock, for: Agents.Sessions.Application.Behaviours.TodoAdapterBehaviour)` to the existing mock setup file
  - File: Check existing pattern (likely `apps/agents/test/support/mocks.ex` or similar)

### Step 1.5: Update Domain Boundary Exports

- [x] ⏸ Update `apps/agents/lib/agents/sessions/domain.ex` to export `TodoItem` and `TodoList`:
  ```elixir
  exports: [
    {Entities.Task, []},
    {Entities.TodoItem, []},
    {Entities.TodoList, []},
    ...existing exports...
  ]
  ```

### Phase 1 Validation

- [x] ⏸ All domain entity tests pass (`mix test apps/agents/test/agents/sessions/domain/ --trace`)
- [x] ⏸ All tests run in milliseconds with no I/O
- [x] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Infrastructure (phoenix-tdd) ✓

Wire up persistence (migration, schema changes) and TaskRunner integration.

### Step 2.1: Database Migration — Add `todo_items` Column

- [x] ⏸ Create migration `apps/agents/priv/repo/migrations/YYYYMMDDHHMMSS_add_todo_items_to_sessions_tasks.exs`
  - Adds `todo_items` column of type `:map` (JSONB) to `sessions_tasks` table, default `nil`
  - This is a nullable column — tasks without todos simply have `nil`
  - No index needed (not queried by todo content)

### Step 2.2: TaskSchema — Add `todo_items` Field

- [x] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/schemas/task_schema_todo_test.exs`
  - Tests:
    - `status_changeset/2` accepts a `todo_items` map field
    - `status_changeset/2` stores a list-of-maps value in `todo_items`
    - `status_changeset/2` accepts `nil` for `todo_items`
    - Existing `changeset/2` does NOT accept `todo_items` (immutable on creation)
  - File: `apps/agents/test/agents/sessions/infrastructure/schemas/task_schema_todo_test.exs`
  - Case: `use Agents.DataCase, async: true`

- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex`
  - Add `field(:todo_items, :map)` to the schema
  - Add `:todo_items` to the `status_changeset/2` cast list
  - Update the `@type t` to include `todo_items: map() | nil`

- [x] ⏸ **REFACTOR**: Verify existing changeset tests still pass; clean up typespec

### Step 2.3: Task Domain Entity — Add `todo_items` Field

- [x] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/domain/entities/task_test.exs`
  - Add test: `new/1` accepts `todo_items` field (defaults to nil)
  - Add test: `from_schema/1` converts `todo_items` from schema to entity

- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/domain/entities/task.ex`
  - Add `todo_items: nil` to `defstruct`
  - Add `todo_items: map() | nil` to `@type t`
  - Add `todo_items: schema.todo_items` to `from_schema/1`

- [x] ⏸ **REFACTOR**: Clean up

### Step 2.4: TaskRunner — Add `todo_items` to GenServer State

- [x] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner/todo_test.exs`
  - Tests:
    - TaskRunner initialises with `todo_items: []` in state
    - When a `todo.updated` SSE event arrives, TaskRunner caches parsed todo items in state
    - TaskRunner broadcasts `{:todo_updated, task_id, todo_items}` via PubSub on `"task:#{task_id}"` topic
    - Malformed `todo.updated` event is logged and ignored (no crash)
    - A second `todo.updated` event replaces the entire cached list
    - `flush_output_to_db` includes `todo_items` in the DB flush when present
    - On task completion (`complete_task/1`), `todo_items` are included in the final DB write
    - On task failure (`fail_task/2`), `todo_items` are included in the final DB write
  - File: `apps/agents/test/agents/sessions/infrastructure/task_runner/todo_test.exs`
  - Case: `use Agents.DataCase, async: false` (following existing TaskRunner test pattern)
  - Mocks: `TaskRepositoryMock`, `ContainerProviderMock`, `OpencodeClientMock`

- [x] ⏸ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - Add `todo_items: []` to the `defstruct` (line 29-59)
  - Add new `handle_sdk_event/2` clause before the catch-all (line 703) for `"todo.updated"` events:
    ```elixir
    defp handle_sdk_event(%{"type" => "todo.updated", "properties" => props}, state) do
      case parse_todo_event(props) do
        {:ok, todo_items} ->
          broadcast_todo_update(state.task_id, todo_items, state.pubsub)
          {:continue, %{state | todo_items: todo_items}}
        {:error, _reason} ->
          Logger.warning("TaskRunner: malformed todo.updated event for task #{state.task_id}")
          {:continue, state}
      end
    end
    ```
  - Add private `parse_todo_event/1` that delegates to `TodoList.from_sse_event/1` and returns serialisable maps
  - Add private `broadcast_todo_update/3`:
    ```elixir
    defp broadcast_todo_update(task_id, todo_items, pubsub) do
      Phoenix.PubSub.broadcast(pubsub, "task:#{task_id}", {:todo_updated, task_id, todo_items})
    end
    ```
  - Update `flush_output_to_db/1` to also flush `todo_items`:
    ```elixir
    defp flush_output_to_db(state) do
      attrs = %{}
      attrs = case serialize_output_parts(state.output_parts) do
        nil -> attrs
        json -> Map.put(attrs, :output, json)
      end
      attrs = if state.todo_items != [] do
        Map.put(attrs, :todo_items, TodoList.new(%{items: state.todo_items}) |> TodoList.to_maps() |> then(&%{"items" => &1}))
      else
        attrs
      end
      if attrs != %{}, do: update_task_status(state, attrs)
    end
    ```
  - Update `complete_task/1` and `fail_task/2` to include todo_items in final attrs via a `put_todo_attrs/2` helper (same pattern as `put_output_attrs/2`)

- [x] ⏸ **REFACTOR**: Extract todo parsing into a dedicated private module or keep inline if small. Ensure the catch-all event handler is still the last clause.

### Step 2.5: TaskRunner — Track `todo_items` Flush State

- [x] ⏸ **RED**: Add test to `apps/agents/test/agents/sessions/infrastructure/task_runner/todo_test.exs`
  - Tests:
    - `flush_output` only writes `todo_items` to DB when they've changed since last flush (add `last_flushed_todo_count: 0` to state, similar to `last_flushed_count` for output_parts)
    - Prevent redundant DB writes when todo state hasn't changed

- [x] ⏸ **GREEN**: Add `last_flushed_todo_count: 0` to TaskRunner struct. Update `handle_info(:flush_output, ...)` to track todo flush state.

- [x] ⏸ **REFACTOR**: Clean up flush logic

### Phase 2 Validation

- [x] ⏸ All TaskRunner todo tests pass
- [x] ⏸ Existing TaskRunner tests still pass
- [x] ⏸ Migration runs cleanly (`mix ecto.migrate`)
- [x] ⏸ No boundary violations (`mix boundary`)

---

## Phase 3: Interface — EventProcessor + LiveView + Component (phoenix-tdd) ✓

Wire up the LiveView to receive, display, and restore todo state.

### Step 3.1: EventProcessor — Handle `todo.updated` Events

- [x] **RED**: Write test in `apps/agents_web/test/live/sessions/event_processor_todo_test.exs`
  - Tests:
    - `process_event/2` with a `"todo.updated"` event type updates the `:todo_items` socket assign
    - The `:todo_items` assign is a list of maps with keys: `id`, `title`, `status`, `position`
    - Unknown/malformed todo events fall through to the catch-all (no crash)
    - A second `todo.updated` event replaces the `:todo_items` assign entirely
  - File: `apps/agents_web/test/live/sessions/event_processor_todo_test.exs`
  - Case: `use ExUnit.Case, async: true` (EventProcessor is pure socket transformation, following existing pattern)
  - Setup: Create a mock socket with `Phoenix.LiveViewTest.Helpers` or plain assigns map

- [x] **GREEN**: Update `apps/agents_web/lib/live/sessions/event_processor.ex`
  - Add new `process_event/2` clause before the catch-all:
    ```elixir
    def process_event(%{"type" => "todo.updated", "properties" => props}, socket) do
      case parse_todo_items(props) do
        {:ok, items} -> assign(socket, :todo_items, items)
        {:error, _} -> socket
      end
    end
    ```
  - Add private `parse_todo_items/1` that extracts and normalises the todo list from properties

- [x] **REFACTOR**: Ensure consistent error handling with other event clauses

### Step 3.2: EventProcessor — `maybe_load_todos/2` for Reconnect

- [x] **RED**: Add tests to `apps/agents_web/test/live/sessions/event_processor_todo_test.exs`
  - Tests:
    - `maybe_load_todos/2` with a task that has `todo_items` data restores `:todo_items` assign
    - `maybe_load_todos/2` with a task that has `nil` todo_items leaves `:todo_items` as `[]`
    - `maybe_load_todos/2` with `nil` task returns socket unchanged
    - `maybe_load_todos/2` correctly parses the persisted JSON `%{"items" => [...]}` format

- [x] **GREEN**: Add `maybe_load_todos/2` to `apps/agents_web/lib/live/sessions/event_processor.ex`
  ```elixir
  def maybe_load_todos(socket, %{todo_items: %{"items" => items}}) when is_list(items) do
    parsed = Enum.map(items, &normalize_todo_item/1)
    assign(socket, :todo_items, parsed)
  end

  def maybe_load_todos(socket, _task), do: socket
  ```

- [x] **REFACTOR**: Share parsing logic between `process_event` and `maybe_load_todos`

### Step 3.3: LiveView — Add `:todo_items` Assign and PubSub Handler

- [x] **RED**: Write test in `apps/agents_web/test/live/sessions/index_todo_test.exs`
  - Tests:
    - `:todo_items` assign is initialised to `[]` in `assign_session_state/1`
    - `handle_info({:todo_updated, task_id, items}, socket)` updates `:todo_items` assign when task_id matches current task
    - `handle_info({:todo_updated, other_id, items}, socket)` ignores updates for non-current tasks
    - On mount with a task that has persisted `todo_items`, the assign is restored
    - On session selection (`select_session` event), `todo_items` is restored from the selected task
    - On status change to completed/failed/cancelled, `todo_items` is preserved (not cleared)
  - File: `apps/agents_web/test/live/sessions/index_todo_test.exs`
  - Case: `use AgentsWeb.ConnCase, async: false`

- [x] **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex`
  - Add `todo_items: []` to `assign_session_state/1` (around line 333-343)
  - Add `EventProcessor.maybe_load_todos(current_task)` call in `mount/3` (after `maybe_load_pending_question`)
  - Add `EventProcessor.maybe_load_todos(current_task)` call in `handle_event("select_session", ...)` (after `maybe_load_pending_question`)
  - Add `EventProcessor.maybe_load_todos(task)` call in `handle_event("view_task", ...)` (after `maybe_load_pending_question`)
  - Add new `handle_info/2` clause:
    ```elixir
    @impl true
    def handle_info({:todo_updated, task_id, todo_items}, socket) do
      case socket.assigns.current_task do
        %{id: ^task_id} -> {:noreply, assign(socket, :todo_items, todo_items)}
        _ -> {:noreply, socket}
      end
    end
    ```
  - Place this clause before the catch-all `handle_info(_msg, socket)`

- [x] **REFACTOR**: Ensure no duplication between EventProcessor SSE path and PubSub path for todo updates

### Step 3.4: Progress Bar Component

- [x] **RED**: Write test in `apps/agents_web/test/live/sessions/components/progress_bar_test.exs`
  - Tests:
    - `progress_bar/1` renders nothing when `todo_items` is `[]`
    - `progress_bar/1` renders a container with `data-testid="todo-progress"` when items exist
    - Renders a summary element with `data-testid="todo-progress-summary"` containing "{completed}/{total} steps complete"
    - Renders numbered steps with `data-testid="todo-step-{position}"` (1-indexed)
    - Each step shows "{position}. {title}" text
    - Each step has CSS class `is-{status}` (e.g., `is-pending`, `is-in-progress`, `is-completed`, `is-failed`)
    - Step 1 completed shows "1." and the title and has class `is-completed`
    - Empty list → no `todo-progress` element in the DOM
    - Summary for 3 completed of 7 total reads "3/7 steps complete"
    - Status classes are mutually exclusive per step
  - File: `apps/agents_web/test/live/sessions/components/progress_bar_test.exs`
  - Case: `use ExUnit.Case, async: true` (pure component rendering via `Phoenix.LiveViewTest.render_component/2`)

- [x] **GREEN**: Add `progress_bar/1` to `apps/agents_web/lib/live/sessions/components/session_components.ex`
  - Attrs: `attr(:todo_items, :list, required: true)`
  - Template:
    ```heex
    <div :if={@todo_items != []} data-testid="todo-progress" class="...">
      <div data-testid="todo-progress-summary" class="...">
        {completed_count(@todo_items)}/{length(@todo_items)} steps complete
      </div>
      <%= for item <- @todo_items do %>
        <div
          data-testid={"todo-step-#{item.position + 1}"}
          class={["...", "is-#{item.status}"]}
        >
          {item.position + 1}. {item.title}
        </div>
      <% end %>
    </div>
    ```
  - Private helpers: `completed_count/1` counts items with status `"completed"`
  - CSS classes for status indicators:
    - `is-pending` — muted/grey styling
    - `is-in-progress` — accent/blue styling with optional animation
    - `is-completed` — success/green with checkmark icon
    - `is-failed` — error/red with X icon

- [x] **REFACTOR**: Polish styling (Tailwind classes), add status icons, ensure accessibility

### Step 3.5: Wire Progress Bar into LiveView Template

- [x] **RED**: Add integration test in `apps/agents_web/test/live/sessions/index_todo_test.exs`
  - Tests:
    - When a todo PubSub message arrives, the progress bar appears in the rendered HTML
    - Progress bar is visible between the session header and the output log
    - Progress bar is NOT rendered when `todo_items` is empty (BDD: "hidden when no todo list exists")

- [x] **GREEN**: Update `apps/agents_web/lib/live/sessions/index.html.heex`
  - Add `<.progress_bar todo_items={@todo_items} />` between the stats bar section and the output log section (after line ~116, before line ~143)
  - Position: after the error alert div, before the `#session-log` div

- [x] **REFACTOR**: Verify layout spacing, ensure progress bar doesn't break existing UI

### Step 3.6: Todo Items as Map Structs (normalize for template rendering)

- [x] **RED**: Add test in `apps/agents_web/test/live/sessions/event_processor_todo_test.exs`
  - Tests:
    - Todo items stored in `:todo_items` assign are maps with atom keys (`:id`, `:title`, `:status`, `:position`)
    - This allows template access like `item.position` and `item.status`

- [x] **GREEN**: Ensure `parse_todo_items/1` in EventProcessor returns maps with atom keys (or use TodoItem structs directly if exported)

- [x] **REFACTOR**: Decide between plain maps with atom keys vs TodoItem structs in the socket assign. TodoItem structs are cleaner but require the entity to be exported from the domain boundary.

### Phase 3 Validation

- [x] All EventProcessor todo tests pass
- [x] All LiveView todo tests pass
- [x] All component tests pass
- [x] Existing EventProcessor tests still pass
- [x] Existing LiveView tests still pass
- [x] No boundary violations (`mix boundary`)

---

## Pre-Commit Checkpoint

- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ Pre-commit checks pass (`mix precommit`)
- [ ] ⏸ Boundary checks pass (`mix boundary`)
- [ ] ⏸ Migrations run cleanly in both directions (`mix ecto.migrate` / `mix ecto.rollback`)

---

## Implementation Details

### SSE Event Payload Shape

The exact shape of `todo.updated` events from opencode needs to be captured during implementation. Based on the opencode TodoWrite tool source and the ticket, the expected shape is:

```json
{
  "type": "todo.updated",
  "properties": {
    "todos": [
      {"id": "todo-1", "content": "Plan the implementation", "status": "completed"},
      {"id": "todo-2", "content": "Write the code", "status": "in_progress"},
      {"id": "todo-3", "content": "Run tests", "status": "pending"},
      {"id": "todo-4", "content": "Refactor", "status": "pending"}
    ]
  }
}
```

**Implementation note**: The `from_sse_event/1` parser should be defensive. If the actual payload differs, update the parser and tests accordingly. Log the raw event at debug level to capture the real shape on first encounter.

### Todo State Persistence Format

The `todo_items` column stores a JSON map:

```json
{
  "items": [
    {"id": "todo-1", "title": "Plan the implementation", "status": "completed", "position": 0},
    {"id": "todo-2", "title": "Write the code", "status": "in_progress", "position": 1},
    {"id": "todo-3", "title": "Run tests", "status": "pending", "position": 2}
  ]
}
```

Using a wrapping `%{"items" => [...]}` map allows future extension (e.g., `%{"items" => [...], "created_at" => "...", "version" => 1}`).

### PubSub Message Format

```elixir
{:todo_updated, task_id, todo_items}
```

Where `todo_items` is a list of maps (serialisable). This follows the existing pattern of `{:task_event, task_id, event}` and `{:task_status_changed, task_id, status}`.

### Progress Bar Data Flow

```
SSE "todo.updated" event
  → TaskRunner.handle_info({:opencode_event, event})
    → broadcasts {:task_event, task_id, event} on PubSub (existing, for EventProcessor)
    → handle_sdk_event("todo.updated", ...) caches in GenServer state
    → broadcasts {:todo_updated, task_id, items} on PubSub (new, for LiveView direct)
  → LiveView receives BOTH messages:
    1. {:task_event, ...} → EventProcessor.process_event("todo.updated", socket)
       → updates :todo_items assign from raw SSE event
    2. {:todo_updated, ...} → handle_info directly updates :todo_items assign
  → Template re-renders <.progress_bar />
```

**Design decision**: The todo update reaches the LiveView through TWO paths:
1. The existing `{:task_event, task_id, event}` broadcast (caught by EventProcessor)
2. The new `{:todo_updated, task_id, items}` broadcast (caught by handle_info)

Both update the same `:todo_items` assign. The EventProcessor path handles the raw SSE event (for consistency with other event types), while the direct PubSub path provides already-parsed todo items. Either path arriving first will update the assign; the second will overwrite with identical data.

**Simplification option**: Skip the EventProcessor path entirely and only use the `{:todo_updated, ...}` PubSub message. This is simpler and avoids double-processing. The EventProcessor clause for `todo.updated` would still exist for clarity but could be a no-op if the direct PubSub handler already ran. **Recommendation**: Use ONLY the `{:todo_updated, ...}` direct PubSub path and make the EventProcessor `todo.updated` clause a no-op (just return socket unchanged), since the TaskRunner already parses and validates the todo items before broadcasting.

### Component Test IDs (BDD mapping)

| Test ID | Element | Content |
|---------|---------|---------|
| `todo-progress` | Container div | Wraps entire progress bar |
| `todo-progress-summary` | Summary text | "3/7 steps complete" |
| `todo-step-1` | First step | "1. Plan the implementation" |
| `todo-step-2` | Second step | "2. Write the code" |
| `todo-step-N` | Nth step | "N. Step title" |

### CSS Classes (BDD mapping)

| Class | Status | Used in BDD scenario |
|-------|--------|---------------------|
| `is-pending` | Item not started | "Progress bar shows failed steps" |
| `is-in-progress` | Item currently being worked on | "Progress bar shows failed steps" |
| `is-completed` | Item finished successfully | "Progress bar shows completed steps" |
| `is-failed` | Item failed | "Progress bar shows failed steps" |

---

## Edge Case Handling

| Edge Case | Handling | Phase |
|-----------|----------|-------|
| No `todo.updated` events arrive | `todo_items` stays `[]`, progress bar hidden | Phase 3 (component) |
| Malformed SSE event payload | Log warning, skip, don't crash TaskRunner | Phase 2 (TaskRunner) |
| Agent replaces entire todo list | Overwrite `todo_items` in state and DB | Phase 2 (TaskRunner) |
| LiveView reconnects during active task | Load from DB via `maybe_load_todos/2` | Phase 3 (EventProcessor) |
| Task completes with pending todos | Preserve raw state (don't auto-complete) | Phase 2 (TaskRunner) |
| Empty todo list (`[]`) | Progress bar not rendered | Phase 3 (component) |
| Todo event arrives after task completed | TaskRunner has stopped, event ignored | N/A (GenServer lifecycle) |
| TaskRunner crashes | Last DB flush (≤3s stale) restored on reconnect | Phase 2 (flush) |

---

## Testing Strategy

| Layer | Test Count (est.) | Async? | Test Case |
|-------|-------------------|--------|-----------|
| Domain entities (TodoItem, TodoList) | 18-22 | Yes | `ExUnit.Case, async: true` |
| Domain behaviour (TodoAdapterBehaviour) | 2-3 | Yes | `ExUnit.Case, async: true` |
| Infrastructure (TaskRunner todo) | 8-12 | No | `Agents.DataCase, async: false` |
| Infrastructure (TaskSchema todo) | 4-5 | Yes | `Agents.DataCase, async: true` |
| Interface (EventProcessor todo) | 6-8 | Yes | `ExUnit.Case, async: true` |
| Interface (LiveView todo) | 6-8 | No | `AgentsWeb.ConnCase, async: false` |
| Interface (progress_bar component) | 8-10 | Yes | `ExUnit.Case, async: true` |
| **Total** | **52-68** | | |

### Distribution

- **Domain**: ~23 tests (fast, pure, async)
- **Infrastructure**: ~17 tests (DB + GenServer)
- **Interface**: ~20 tests (socket transforms + LiveView + component)

---

## Future Work (NOT in this plan)

### P1: MCP Tool (Active Mode)

- Create `SessionTodoToolProvider` implementing `ToolProvider` behaviour
- Register `sessions.todo` MCP tool via `Hermes.Server.Component`
- Tool handles `create`, `update_status`, `clear` actions
- Routes through TaskRunner GenServer for serialisation

### P1: Domain Events

- Define `TodoListCreated`, `TodoStepCompleted`, `TodoListCompleted` events
- Emit via `event_bus` in TaskRunner after todo state changes
- Enable cross-concern reactions (step pipeline)

### P2: Step Pipeline

- On `TodoStepCompleted`, evaluate automatic next-step execution
- Configurable mode: fork session vs. new session
- User-configurable pipeline behaviour per session

---

## File Summary

### New Files

| File | Layer | Purpose |
|------|-------|---------|
| `apps/agents/lib/agents/sessions/domain/entities/todo_item.ex` | Domain | Pure TodoItem struct |
| `apps/agents/lib/agents/sessions/domain/entities/todo_list.ex` | Domain | Pure TodoList aggregate |
| `apps/agents/lib/agents/sessions/application/behaviours/todo_adapter_behaviour.ex` | Application | Port/behaviour definition |
| `apps/agents/priv/repo/migrations/*_add_todo_items_to_sessions_tasks.exs` | Infrastructure | DB migration |
| `apps/agents/test/agents/sessions/domain/entities/todo_item_test.exs` | Test | TodoItem tests |
| `apps/agents/test/agents/sessions/domain/entities/todo_list_test.exs` | Test | TodoList tests |
| `apps/agents/test/agents/sessions/application/behaviours/todo_adapter_behaviour_test.exs` | Test | Behaviour contract tests |
| `apps/agents/test/agents/sessions/infrastructure/task_runner/todo_test.exs` | Test | TaskRunner todo tests |
| `apps/agents/test/agents/sessions/infrastructure/schemas/task_schema_todo_test.exs` | Test | Schema todo field tests |
| `apps/agents_web/test/live/sessions/event_processor_todo_test.exs` | Test | EventProcessor todo tests |
| `apps/agents_web/test/live/sessions/index_todo_test.exs` | Test | LiveView todo integration tests |
| `apps/agents_web/test/live/sessions/components/progress_bar_test.exs` | Test | Component rendering tests |

### Modified Files

| File | Layer | Changes |
|------|-------|---------|
| `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex` | Infrastructure | Add `todo_items` to struct, new `handle_sdk_event` clause, update flush/complete/fail |
| `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex` | Infrastructure | Add `todo_items` field + cast |
| `apps/agents/lib/agents/sessions/domain/entities/task.ex` | Domain | Add `todo_items` field |
| `apps/agents/lib/agents/sessions/domain.ex` | Domain | Export TodoItem, TodoList |
| `apps/agents_web/lib/live/sessions/event_processor.ex` | Interface | Add todo event clause + `maybe_load_todos/2` |
| `apps/agents_web/lib/live/sessions/index.ex` | Interface | Add `:todo_items` assign, PubSub handler, reconnect wiring |
| `apps/agents_web/lib/live/sessions/index.html.heex` | Interface | Add `<.progress_bar>` component call |
| `apps/agents_web/lib/live/sessions/components/session_components.ex` | Interface | Add `progress_bar/1` component |

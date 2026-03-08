# Ticket: Agent Session Todo Adapter for UI Progress Bar Pipeline

**GitHub Issue**: [#273](https://github.com/platform-q-ai/perme8/issues/273)
**Sub-Issues**: [#253](https://github.com/platform-q-ai/perme8/issues/253) (progress bar UI)

## Summary

- **Problem**: When an agent session runs, users see only raw streaming output (text, tool calls, reasoning) with no structured view of the agent's plan or progress. The opencode agent uses a built-in `TodoWrite` tool to plan and track work, emitting `todo.updated` SSE events, but perme8 ignores these entirely — they fall through the catch-all clause in `TaskRunner.handle_sdk_event/2` (line 703). The only todo interaction is a passive `todo-check.ts` plugin that prompts the agent to verify completion when idle.
- **Value**: Users gain real-time, structured step-by-step progress visibility for agent sessions — a numbered progress bar showing what the agent plans to do, what it's doing now, and what's complete. This transforms the session experience from watching an opaque stream of tool calls into tracking a clear plan with measurable progress. It also creates the foundation for a step pipeline where todo completion can trigger next-step execution (fork or new session).
- **Users**: Developers monitoring agent sessions via the Sessions LiveView UI; the perme8 system itself (for automated step pipeline orchestration).

## User Stories

### Developer Watching Progress (Primary)

1. As a **developer watching an agent session**, I want to see a **numbered progress bar showing the agent's planned steps**, so that I understand what the agent intends to do and can estimate how long the task will take.
2. As a **developer watching an agent session**, I want to see **each step update in real-time** (pending → in_progress → completed/failed), so that I know exactly where the agent is in its plan.
3. As a **developer reconnecting to a session**, I want the **progress bar to restore from persisted state**, so that I don't lose visibility into the agent's plan after a page reload or disconnection.
4. As a **developer viewing a completed session**, I want to see the **final progress bar state**, so that I can review what steps the agent took and whether they all succeeded.

### System Pipeline Executor (Future)

5. As the **perme8 system**, I want to be **notified when a todo step completes**, so that I can trigger the next step's execution (either by forking the current session or starting a new one).
6. As the **perme8 system**, I want to **create and manage todo lists through an MCP tool** (replacing opencode's built-in `TodoWrite`), so that perme8 has full control over todo creation, status updates, and pipeline orchestration.

## Functional Requirements

### Must Have (P0)

1. **`TodoAdapterBehaviour` port definition** — Define a behaviour in `apps/agents/lib/agents/sessions/application/behaviours/` with callbacks for todo operations:
   - `create_todo_list(task_id, todo_list)` — Store a new todo list for a task
   - `update_todo_status(task_id, todo_id, status)` — Update a single todo item's status
   - `get_todos(task_id)` — Retrieve the current todo list for a task
   - `clear_todos(task_id)` — Clear all todos for a task (on new list creation or task completion)

2. **SSE event interception in TaskRunner** — Handle `todo.updated` events in `TaskRunner.handle_sdk_event/2` (currently the catch-all at line 703). Parse the event payload, transform it into the adapter's domain model, cache the todo state in TaskRunner's GenServer state, and broadcast via PubSub on the existing `task:#{task_id}` topic.

3. **Todo state in TaskRunner GenServer state** — Add a `todo_items` field to the `TaskRunner` struct to cache the current todo list in memory. This enables fast reads without DB round-trips during active streaming.

4. **PubSub broadcast for todo state changes** — Broadcast `{:todo_updated, task_id, todo_items}` messages on the existing `task:#{task_id}` PubSub topic so the LiveView can subscribe and update the progress bar in real-time.

5. **Todo state persistence to DB** — Persist the todo list to the task record (as a JSON column or reuse the existing `output` field pattern) so it survives TaskRunner crashes and LiveView reconnections. Flush periodically (similar to the existing `output_parts` flush pattern at ~5s intervals).

6. **EventProcessor todo handling** — Add a `process_event/2` clause in `AgentsWeb.SessionsLive.EventProcessor` for `todo.updated` events that updates a new `:todo_items` socket assign.

7. **LiveView todo state management** — Add `:todo_items` assign to `AgentsWeb.SessionsLive.Index`, handle the `{:todo_updated, task_id, todo_items}` PubSub message, and restore todo state on mount/reconnect from the persisted task record.

8. **Progress bar component** — Create a `progress_bar/1` component in `AgentsWeb.SessionsLive.Components.SessionComponents` that renders numbered, named steps with real-time status indicators (pending/in_progress/completed/failed).

9. **Todo state restoration on reconnect** — When a LiveView mounts or reconnects, load the cached todo state from the task record (similar to `maybe_load_cached_output/2` and `maybe_load_pending_question/2` patterns).

### Should Have (P1)

10. **Domain entity for TodoItem** — Create a pure domain entity `Agents.Sessions.Domain.Entities.TodoItem` (struct, no Ecto) representing a single todo step with fields: `id`, `title`, `status` (pending/in_progress/completed/failed), `position` (ordering index).

11. **Domain entity for TodoList** — Create a pure domain entity `Agents.Sessions.Domain.Entities.TodoList` wrapping a list of `TodoItem`s with aggregate functions: `progress_percentage/1`, `current_step/1`, `all_completed?/1`, `from_sse_event/1`.

12. **Active mode: MCP tool replacement for TodoWrite** — Create a `sessions.todo` MCP tool (following the `Hermes.Server.Component` pattern) that the opencode agent calls instead of the built-in `TodoWrite`. This gives perme8 full control over todo creation and updates. Implement via `ToolProvider` behaviour.

13. **Domain events for todo lifecycle** — Emit domain events (`TodoListCreated`, `TodoStepCompleted`, `TodoListCompleted`) via the event bus for cross-concern reactions (e.g., the step pipeline).

### Nice to Have (P2)

14. **Step pipeline orchestration** — When a todo step completes, evaluate whether the next step should be executed automatically, with configurable execution mode: fork current session (using `ResumeTask` pattern) or start a new session.

15. **Todo persistence migration** — Add a `todo_items` JSON column to the `sessions_tasks` table for dedicated todo storage (instead of embedding in the existing `output` column).

16. **Step pipeline configuration** — Allow users to configure pipeline behaviour per session: automatic vs. manual step advancement, fork vs. new session mode.

## User Workflows

### Passive Mode (SSE Interception)

1. User creates a task → TaskRunner starts → Agent begins working
2. Agent calls built-in `TodoWrite` → opencode emits `todo.updated` SSE event
3. TaskRunner receives `{:opencode_event, %{"type" => "todo.updated", ...}}` → delegates to new `handle_sdk_event` clause
4. TaskRunner parses todo payload → updates `todo_items` in GenServer state → broadcasts `{:todo_updated, task_id, items}` on PubSub
5. LiveView receives PubSub message → EventProcessor updates `:todo_items` assign → progress bar component re-renders
6. Agent updates todo status (marks step complete) → same flow repeats with updated status
7. On task completion → TodoItems get final flush to DB → progress bar shows final state

### Active Mode (MCP Tool — P1)

1. User creates a task → TaskRunner starts → MCP server registers `sessions.todo` tool
2. Agent calls `sessions.todo` MCP tool (instead of built-in `TodoWrite`) → perme8 receives the call directly
3. MCP tool handler creates/updates todo state → broadcasts via PubSub → same UI flow as passive mode
4. Advantage: perme8 controls the todo format, can validate/enrich, and has full pipeline control

### Reconnection Flow

1. User refreshes page or LiveView reconnects → `mount/3` fires
2. LiveView loads current task from DB → calls `EventProcessor.maybe_load_todos/2`
3. Persisted todo JSON is decoded into `:todo_items` assign → progress bar renders immediately
4. If task is active, PubSub subscription resumes → live updates continue

## Data Requirements

### Capture

| Field | Type | Constraints | Source |
|-------|------|-------------|--------|
| `todo_items` | JSON (list of maps) | Max ~100 items per list | SSE `todo.updated` events or MCP tool calls |
| `todo_item.id` | string | Unique within list | Generated by agent or adapter |
| `todo_item.title` | string | Max 500 chars | Agent-provided step name |
| `todo_item.status` | string | One of: `pending`, `in_progress`, `completed`, `failed` | Updated by agent via SSE or MCP |
| `todo_item.position` | integer | 0-indexed ordering | Determined by list position |

### Display

| Field | Format | Source |
|-------|--------|--------|
| Step number | "1", "2", "3"... | Derived from `position + 1` |
| Step name | Truncated to ~80 chars | `todo_item.title` |
| Step status indicator | Icon + color (⏳ pending, 🔄 in_progress, ✅ completed, ❌ failed) | `todo_item.status` |
| Overall progress | "3/7 steps complete" + percentage bar | Aggregated from todo list |

### Relationships

- **TodoList → Task**: One-to-one. Each task has at most one active todo list. Stored as a JSON column on the `sessions_tasks` table (or in TaskRunner GenServer state for active tasks).
- **TodoItem → TodoList**: One-to-many. Items are ordered by `position`.
- **TodoList → User**: Indirect via Task. Ownership enforced through the existing task ownership model.

## Technical Considerations

### Affected Layers

| Layer | Changes |
|-------|---------|
| **Domain** | New entities: `TodoItem`, `TodoList`. New domain events: `TodoListCreated`, `TodoStepCompleted`, `TodoListCompleted` |
| **Application** | New behaviour: `TodoAdapterBehaviour`. Updated use cases may need awareness of todo state for pipeline orchestration |
| **Infrastructure** | Updated `TaskRunner` to handle `todo.updated` events and cache todo state. New MCP tool for active mode. DB migration for `todo_items` column |
| **Interface** | Updated `EventProcessor`, `SessionsLive.Index`, new `progress_bar` component in `SessionComponents` |

### Integration Points

| Component | Integration |
|-----------|-------------|
| `TaskRunner` (`apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`) | Add `todo_items` to struct, new `handle_sdk_event` clause for `todo.updated`, periodic DB flush of todo state |
| `EventProcessor` (`apps/agents_web/lib/live/sessions/event_processor.ex`) | New `process_event` clause for `todo.updated`, new `maybe_load_todos/2` for reconnection |
| `SessionsLive.Index` (`apps/agents_web/lib/live/sessions/index.ex`) | New `:todo_items` assign, handle `{:todo_updated, ...}` PubSub message |
| `SessionComponents` (`apps/agents_web/lib/live/sessions/components/session_components.ex`) | New `progress_bar/1` component |
| `TaskSchema` (`apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex`) | New `todo_items` field (JSON map column) in `status_changeset/2` |
| `ToolProvider` (`apps/agents/lib/agents/infrastructure/mcp/tool_provider.ex`) | New `SessionTodoToolProvider` for MCP tool registration (P1) |
| PubSub topics | Reuse existing `task:#{task_id}` topic with new message type `{:todo_updated, task_id, items}` |

### Performance

- **Real-time latency**: Todo state updates should reach the LiveView within **100ms** of the SSE event arriving at TaskRunner. This is achievable via the existing PubSub broadcast path (same path as `message.part.updated` events).
- **DB flush frequency**: Persist todo state every **5 seconds** (matching the existing `output_parts` flush interval) to balance durability with write load. Use the same `schedule_output_flush` / `flush_output` timer.
- **Memory**: Todo lists are small (typically 3-15 items, ~2KB JSON). Caching in TaskRunner GenServer state adds negligible memory overhead.
- **Scale**: One active todo list per task. No fan-out concerns — PubSub broadcast to the single LiveView process watching that task.

### Security

- **Authorization**: Todo state inherits the existing task ownership model. Only the task's owner can view its todo progress (enforced by `get_task_for_user/2` in the repository layer).
- **Input validation**: The SSE adapter validates todo payloads before caching. The MCP tool adapter validates input schemas via `Hermes.Server.Component` schema DSL.
- **Data integrity**: Todo state is append-only within a task lifecycle. Status transitions are validated (e.g., cannot go from `completed` back to `pending`).

## Edge Cases & Error Handling

1. **Agent sends `todo.updated` before session is running** → **Expected**: Ignore the event (TaskRunner only caches todo state when `status` is `:running` or later). Log a debug message.

2. **Agent replaces the entire todo list mid-task** → **Expected**: Overwrite the cached todo list entirely. The new list becomes the source of truth. Broadcast the full new list to the LiveView.

3. **Agent sends malformed `todo.updated` payload** → **Expected**: Log a warning, skip the event, continue processing other events. Do not crash the TaskRunner.

4. **TaskRunner crashes while holding cached todo state** → **Expected**: On restart, todo state is restored from the last DB flush (within 5 seconds of staleness). The LiveView reconnects and loads from DB.

5. **LiveView reconnects during active task** → **Expected**: Load persisted todo state from DB on mount. Subscribe to PubSub. Any todo updates that occurred during disconnection are reconciled by the next full todo state broadcast.

6. **Task completes with todos still in `in_progress` or `pending`** → **Expected**: Mark remaining todos as `completed` (assume the agent completed the work without updating the todo). Log this reconciliation for debugging. Alternatively, keep the raw state and let the UI display the discrepancy.

7. **Agent creates multiple todo lists in one session** → **Expected**: Only the latest list is active. Previous lists are overwritten. The progress bar always reflects the current plan.

8. **Todo list has zero items** → **Expected**: Progress bar is hidden (or shows "No plan available"). This is the default state before the agent creates a todo list.

9. **MCP tool receives concurrent create/update calls** → **Expected**: Serialize through the TaskRunner GenServer (single process per task). No race conditions.

10. **SSE `todo.updated` event arrives after task is completed** → **Expected**: Ignore late events. TaskRunner has already stopped.

## Acceptance Criteria

- [ ] A `TodoAdapterBehaviour` defines the contract for todo operations (create, update status, list, clear)
- [ ] `TaskRunner` processes `todo.updated` SSE events through a new `handle_sdk_event` clause, caching todo state in its GenServer struct
- [ ] Todo state changes are broadcast to the LiveView via PubSub on the existing `task:#{task_id}` topic
- [ ] The adapter supports passive mode (intercepting SSE `todo.updated` events)
- [ ] Todo state persists to the DB (flushed periodically, matching the existing output flush pattern)
- [ ] Todo state is restored on LiveView mount/reconnect from the persisted task record
- [ ] `EventProcessor` processes todo-related events and updates the `:todo_items` socket assign
- [ ] A `progress_bar/1` component renders numbered, named steps with real-time status indicators
- [ ] The progress bar shows overall progress (e.g., "3/7 steps complete")
- [ ] Pure domain entities (`TodoItem`, `TodoList`) model the todo data with no Ecto dependencies
- [ ] The architecture supports the step pipeline use case: todo completion can trigger next-step execution (wired to domain events)
- [ ] The adapter supports active mode (MCP tool replacement for TodoWrite) — P1
- [ ] All sub-issues (#253) are completed and pass their individual acceptance criteria

## Non-Functional Requirements

- **Real-time responsiveness**: Todo state updates must propagate from SSE event to rendered progress bar within 200ms (p99), ensuring the progress bar feels "live" to the user.
- **State consistency on reconnect**: After a LiveView disconnection/reconnection (including full page reload), the progress bar must show state no older than 5 seconds (the DB flush interval).
- **Graceful degradation**: If no `todo.updated` events arrive (agent doesn't use TodoWrite), the session UI functions exactly as it does today — the progress bar simply doesn't appear.
- **Zero regression**: All existing session functionality (streaming output, tool calls, reasoning, question cards, session management) must continue to work unchanged.

## Success Metrics

1. **Progress bar visibility**: ≥80% of agent sessions that use TodoWrite display a progress bar with ≥1 step.
2. **Reconnection fidelity**: 100% of reconnections restore the correct todo state within 1 second of mount.
3. **Latency**: p99 todo update propagation (SSE → rendered UI) under 200ms.
4. **No regressions**: Zero new failures in existing session feature tests.

## Codebase Context

### Existing Patterns to Follow

| Pattern | Location | How to Apply |
|---------|----------|-------------|
| SSE event handling | `TaskRunner.handle_sdk_event/2` (line 534-705) | Add new clause for `"todo.updated"` before the catch-all at line 703 |
| GenServer state struct | `TaskRunner` struct (line 29-59) | Add `todo_items: []` field |
| PubSub broadcast | `TaskRunner` broadcasts on `"task:#{task_id}"` | Reuse same topic for `{:todo_updated, task_id, items}` |
| Periodic DB flush | `TaskRunner.flush_output_to_db/1` + `:flush_output` timer | Extend to include todo state in the same flush cycle |
| EventProcessor event dispatch | `EventProcessor.process_event/2` clauses | Add new clause for `"todo.updated"` |
| Reconnect state restoration | `EventProcessor.maybe_load_cached_output/2`, `maybe_load_pending_question/2` | Create `maybe_load_todos/2` following same pattern |
| UI components | `SessionComponents` (question_card, output_part, status_badge) | Add `progress_bar/1` following same attr/component conventions |
| Behaviour/port pattern | `apps/agents/lib/agents/sessions/application/behaviours/*.ex` | New `TodoAdapterBehaviour` alongside existing behaviours |
| Domain entities (pure structs) | `Agents.Sessions.Domain.Entities.Task` | New `TodoItem`, `TodoList` entities with `new/1`, `from_sse_event/1` |
| Domain events | `Agents.Sessions.Domain.Events.TaskCompleted` (DomainEvent macro) | New todo-related domain events |
| MCP tool pattern | `Hermes.Server.Component` with schema DSL + `execute/2` | New `sessions.todo` MCP tool for active mode |
| DI via opts | TaskRunner.init/1 extracts deps from opts | Follow same pattern for todo adapter injection |

### Affected Contexts

- **Agents.Sessions** (domain app) — TodoAdapterBehaviour, domain entities, domain events, TaskRunner changes, DB schema/migration
- **AgentsWeb.SessionsLive** (interface app) — EventProcessor, LiveView, SessionComponents

### Available Infrastructure to Leverage

- **PubSub** (`Perme8.Events.PubSub`) — already wired into TaskRunner and LiveView
- **EventBus** (`Perme8.Events.EventBus`) — for domain events, already injected into TaskRunner
- **DomainEvent macro** (`Perme8.Events.DomainEvent`) — for defining new todo events
- **TaskSchema** (`sessions_tasks` table) — can add a `todo_items` JSON column for persistence
- **Hermes.Server.Component** — for the MCP tool implementation
- **ToolProvider behaviour** — for registering the new MCP tool
- **ResumeTask use case** — pattern for fork/continue session execution (step pipeline foundation)

## Open Questions

- [ ] What is the exact payload shape of `todo.updated` SSE events from opencode? Need to capture a sample event to design the parser. (Can be resolved during implementation by logging the catch-all events.)
- [ ] Should the MCP tool replacement (active mode) completely prevent the agent from using the built-in `TodoWrite`, or should both be supported simultaneously? (Recommendation: support both initially, with MCP tool taking priority when available.)
- [ ] For the step pipeline (P2), should step execution be opt-in per session or a global configuration? (Deferred to pipeline implementation.)
- [ ] Should completed todo state be archived separately from the task's output, or is embedding in the task record sufficient? (Recommendation: embed in task record for simplicity, extract later if needed.)

## Out of Scope

- **Full step pipeline execution engine** — This ticket covers the adapter layer and progress bar. The pipeline orchestrator that automatically triggers next steps based on todo completion is tracked as a separate P2 effort.
- **Custom step definitions by users** — Users cannot manually create or edit todo items. Todos are created by the agent through SSE events or the MCP tool.
- **Historical todo analytics** — No aggregation, dashboards, or reporting on todo completion rates across sessions.
- **Multi-session todo lists** — Each task has its own isolated todo list. Cross-session todo coordination is not supported.
- **Notification system integration** — No push notifications or alerts when todo steps complete. Progress visibility is limited to the active LiveView.
- **Opencode plugin changes** — The existing `todo-check.ts` plugin remains unchanged. It continues to prompt the agent on idle. Future work may replace it entirely once the MCP tool is active.

# Feature: Decompose TaskRunner Monolith into Focused Modules

**Ticket**: #450
**Status**: ⏸ Not Started

## Overview

Extract 6 pure-function modules from the monolithic `TaskRunner` GenServer (1,870 lines, 35 struct fields) into focused single-responsibility modules. The GenServer remains as a thin orchestrator delegating to stateless helper modules. No behavior changes — purely structural refactoring.

## Architectural Decision: Flat State with Module Functions

**Decision**: Keep the **flat struct** in `TaskRunner` and have extracted modules operate as **stateless function libraries** that take relevant state fields as arguments and return updated values.

**Rationale**:
1. **Sub-structs rejected**: Would require updating ALL 12 test files (3,264 lines) to construct nested state objects. This adds risk without proportional benefit for infrastructure-internal code.
2. **Flat + function modules**: Each extracted module takes only the fields it needs as function arguments, keeping functions pure and testable. The GenServer remains the single owner of the flat `%TaskRunner{}` struct and handles all side effects (DB writes, PubSub, timers).
3. **Incremental extraction**: Each phase extracts functions without changing the struct shape. Tests continue to construct state exactly as before — only `alias` lines change.

**Pattern for extracted modules**:
```elixir
# Pure function module — no GenServer, no side effects
defmodule Agents.Sessions.Infrastructure.TaskRunner.OutputCache do
  @doc "Insert or update a part by its ID."
  def upsert_part(parts, part_id, entry) do
    # ... pure logic ...
  end
end
```

**Pattern for GenServer delegation**:
```elixir
# In TaskRunner (GenServer)
alias Agents.Sessions.Infrastructure.TaskRunner.OutputCache

defp handle_sdk_event(%{"type" => "message.part.updated", ...}, state) do
  parts = OutputCache.upsert_part(state.output_parts, part_id, entry)
  {:continue, %{state | output_text: text, output_parts: parts}}
end
```

## UI Strategy
- **LiveView coverage**: N/A (no UI changes — backend refactor only)
- **TypeScript needed**: None

## Affected Boundaries
- **Owning app**: `agents`
- **Repo**: `Agents.Repo` (no Repo changes)
- **Migrations**: None
- **Feature files**: None (no behavior changes)
- **Primary context**: `Agents.Sessions.Infrastructure` (internal, not exported via boundary)
- **Dependencies**: No new cross-context dependencies
- **Exported schemas**: None changed — `TaskRunner` is NOT exported from the boundary
- **New context needed?**: No — all modules stay within `Agents.Sessions.Infrastructure.TaskRunner.*`

## File Structure After Refactoring

```
apps/agents/lib/agents/sessions/infrastructure/
├── task_runner.ex                          # Thin GenServer orchestrator (~600 lines)
└── task_runner/
    ├── task_broadcaster.ex                 # PubSub broadcast functions (~120 lines)
    ├── todo_tracker.ex                     # Todo parse/merge/serialize (~70 lines)
    ├── output_cache.ex                     # Output parts upsert/serialize/restore (~220 lines)
    ├── question_handler.ex                 # Question lifecycle management (~120 lines)
    ├── container_lifecycle.ex              # Container start/health/restart logic (~200 lines)
    └── sse_event_router.ex                 # SDK event dispatch & child session tracking (~250 lines)

apps/agents/test/agents/sessions/infrastructure/
├── task_runner/                            # Existing integration tests (unchanged)
│   ├── completion_test.exs
│   ├── container_lifecycle_test.exs
│   ├── domain_events_test.exs
│   ├── events_test.exs
│   ├── init_test.exs
│   ├── persistence_test.exs
│   ├── question_test.exs
│   ├── resume_test.exs
│   ├── session_tracking_test.exs
│   ├── sse_crash_test.exs
│   ├── timeout_test.exs
│   └── todo_test.exs
└── task_runner_modules/                    # NEW unit tests for extracted modules
    ├── task_broadcaster_test.exs
    ├── todo_tracker_test.exs
    ├── output_cache_test.exs
    ├── question_handler_test.exs
    ├── container_lifecycle_test.exs
    └── sse_event_router_test.exs
```

## Extraction Order (low risk → high risk)

| Phase | Module | Lines | Fields | Risk | Dependencies |
|-------|--------|-------|--------|------|-------------|
| 1 | TaskBroadcaster | ~120 | 0 (stateless) | Very low | None |
| 2 | TodoTracker | ~70 | 4 | Low | None |
| 3 | OutputCache | ~220 | 7 | Medium | None |
| 4 | QuestionHandler | ~120 | 3 | Medium | OutputCache |
| 5 | ContainerLifecycle | ~200 | 6 | High | TaskBroadcaster, OutputCache, TodoTracker |
| 6 | SseEventRouter | ~250 | 3 | High | OutputCache, TaskBroadcaster |

---

## Phase 1: TaskBroadcaster (⏸ Not Started)

**Risk**: Very low — pure stateless functions with no state ownership.

### What to extract
Functions from `task_runner.ex` that wrap `Phoenix.PubSub.broadcast/3`:

| Function | Line | Description |
|----------|------|-------------|
| `broadcast_event/2` | 835-841 | Broadcasts raw SDK events to `task:{id}` |
| `broadcast_status/3` | 1586-1592 | Broadcasts `{:task_status_changed, ...}` |
| `broadcast_status_with_lifecycle/4` | 1594-1609 | Broadcasts status + lifecycle transition |
| `broadcast_lifecycle_transition/5` | 1635-1644 | Broadcasts `{:lifecycle_state_changed, ...}` |
| `broadcast_session_id_set/3` | 1647-1653 | Broadcasts `{:task_session_id_set, ...}` |
| `broadcast_question_replied/1` | 1655-1661 | Broadcasts `{:task_event, ..., "question.replied"}` |
| `broadcast_question_rejected/1` | 1663-1669 | Broadcasts `{:task_event, ..., "question.rejected"}` |
| `broadcast_container_stats/1` | 1671-1699 | Broadcasts `{:container_stats_updated, ...}` |
| `broadcast_todo_update/3` | 1827-1829 | Broadcasts `{:todo_updated, ...}` |
| `lifecycle_target_task/3` | 1612-1623 | Helper for lifecycle broadcast |
| `lifecycle_state_from_task/1` | 1625-1633 | Helper for lifecycle broadcast |

### 1.1: TaskBroadcaster Unit Tests
- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner_modules/task_broadcaster_test.exs`
  - Tests:
    - `broadcast_event/3` calls PubSub with correct topic and payload
    - `broadcast_status/3` sends `{:task_status_changed, task_id, status}`
    - `broadcast_session_id_set/3` sends `{:task_session_id_set, task_id, session_id}`
    - `broadcast_todo_update/3` sends `{:todo_updated, task_id, items}`
    - `broadcast_question_replied/3` sends question.replied event
    - `broadcast_question_rejected/3` sends question.rejected event
    - `broadcast_container_stats/3` computes mem_percent and broadcasts payload
    - `broadcast_container_stats/3` silently handles stats errors
    - `lifecycle_target_task/3` merges attrs into task struct
    - `lifecycle_state_from_task/1` delegates to SessionLifecyclePolicy
  - Use `async: true` — these are pure functions with injected PubSub
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/task_runner/task_broadcaster.ex`
  - All functions accept explicit parameters (task_id, pubsub, etc.) — no state struct dependency
  - `broadcast_container_stats/3` accepts `{container_id, container_provider, task_id, pubsub}`
- [ ] **REFACTOR**: Clean up function signatures; ensure consistent parameter ordering

### 1.2: Wire TaskBroadcaster into TaskRunner
- [ ] **RED**: All 12 existing integration tests must still pass (run `mix test apps/agents/test/agents/sessions/infrastructure/task_runner/`)
- [ ] **GREEN**: Replace all broadcast `defp` functions in `task_runner.ex` with calls to `TaskBroadcaster`
  - Replace `broadcast_event/2` → `TaskBroadcaster.broadcast_event(event, state.task_id, state.pubsub)`
  - Replace `broadcast_status/3` → `TaskBroadcaster.broadcast_status(task_id, status, pubsub)`
  - Replace `broadcast_status_with_lifecycle/4` → `TaskBroadcaster.broadcast_status_with_lifecycle(...)`
  - Replace `broadcast_session_id_set/3` → `TaskBroadcaster.broadcast_session_id_set(...)`
  - Replace `broadcast_question_replied/1` → `TaskBroadcaster.broadcast_question_replied(...)`
  - Replace `broadcast_question_rejected/1` → `TaskBroadcaster.broadcast_question_rejected(...)`
  - Replace `broadcast_container_stats/1` → `TaskBroadcaster.broadcast_container_stats(...)`
  - Replace `broadcast_todo_update/3` → `TaskBroadcaster.broadcast_todo_update(...)`
  - Replace `lifecycle_target_task/3`, `lifecycle_state_from_task/1` → moved to TaskBroadcaster
  - Remove all `defp broadcast_*` and `defp lifecycle_*` from `task_runner.ex`
- [ ] **REFACTOR**: Remove dead private functions from TaskRunner

### Phase 1 Validation
- [ ] All 12 integration test files pass
- [ ] New TaskBroadcaster unit tests pass
- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix boundary` passes
- [ ] Net line reduction in task_runner.ex: ~130 lines

---

## Phase 2: TodoTracker (⏸ Not Started)

**Risk**: Low — 4 fields, clean parse/merge/broadcast cycle. No complex cross-concern deps.

### What to extract
Functions from `task_runner.ex` related to todo lifecycle:

| Function | Line | Description |
|----------|------|-------------|
| `parse_todo_event/1` | 1818-1825 | Parses SSE event via TodoList entity |
| `merge_prior_resume_items/2` | 1837-1850 | Merges prior-run todos with current |
| `put_todo_attrs/2` | 1831-1835 | Serializes todo_items for DB persistence |
| `restore_todo_items/1` | 1868-1869 | Restores cached todos from DB format |

**State fields owned by TodoTracker**: `todo_items`, `prior_resume_items`, `todo_version`, `last_flushed_todo_version`

### 2.1: TodoTracker Unit Tests
- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner_modules/todo_tracker_test.exs`
  - Tests:
    - `parse_event/1` returns `{:ok, items}` for valid todo.updated properties
    - `parse_event/1` returns `{:error, _}` for malformed payload
    - `merge_prior_items/2` returns current items when no prior items
    - `merge_prior_items/2` prepends unique prior items and shifts positions
    - `merge_prior_items/2` deduplicates shared IDs (current wins, prior dropped)
    - `put_attrs/2` returns empty map when todo_items is empty list
    - `put_attrs/2` returns `%{todo_items: %{"items" => items}}` when non-empty
    - `restore_items/1` returns items from `%{"items" => [...]}` format
    - `restore_items/1` returns empty list for nil/invalid input
  - Use `async: true` — all pure functions
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/task_runner/todo_tracker.ex`
  - `parse_event(properties)` — delegates to `TodoList.from_sse_event/1`
  - `merge_prior_items(prior_items, current_items)` — dedup + shift positions
  - `put_attrs(attrs, todo_items)` — conditionally adds todo_items to attrs map
  - `restore_items(raw)` — decode from DB format
- [ ] **REFACTOR**: Ensure function names are clear and consistent

### 2.2: Wire TodoTracker into TaskRunner
- [ ] **RED**: All 12 existing integration tests pass (especially `todo_test.exs`, `resume_test.exs`)
- [ ] **GREEN**: Replace todo `defp` functions in `task_runner.ex` with calls to `TodoTracker`
  - Replace `parse_todo_event/1` → `TodoTracker.parse_event(properties)`
  - Replace `merge_prior_resume_items/2` → `TodoTracker.merge_prior_items(prior, current)`
  - Replace `put_todo_attrs/2` → `TodoTracker.put_attrs(attrs, state.todo_items)`
  - Replace `restore_todo_items/1` → `TodoTracker.restore_items(raw)`
  - Remove all replaced `defp` functions from `task_runner.ex`
- [ ] **REFACTOR**: Clean up dead code

### Phase 2 Validation
- [ ] All 12 integration test files pass
- [ ] New TodoTracker unit tests pass
- [ ] `todo_test.exs` (268 lines, 7 tests) — all pass
- [ ] `resume_test.exs` (418 lines, 5 tests) — all pass (resume path uses merge_prior_items)
- [ ] Net line reduction in task_runner.ex: ~50 lines

---

## Phase 3: OutputCache (⏸ Not Started)

**Risk**: Medium — 7 fields, most complex data manipulation. Core to output persistence.

### What to extract
Functions from `task_runner.ex` related to output part management:

| Function | Line | Description |
|----------|------|-------------|
| `upsert_output_part/3` | 1547-1556 | Insert or update part by ID |
| `serialize_output_parts/1` | 1558-1562 | Encode parts to JSON |
| `restore_output_parts/1` | 1856-1866 | Decode parts from DB |
| `put_output_attrs/2` | 1524-1530 | Merge output into attrs for DB write |
| `cache_subtask_part/2` | 885-911 | Cache subtask part entry |
| `mark_subtask_done/2` | 913-927 | Mark subtask status as done |
| `cache_user_message_part/2` | 985-1002 | Cache user message part |
| `cache_queued_user_message/2-3` | 1004-1034 | Cache queued follow-up with pending flag |
| `maybe_cache_resume_prompt_message/2` | 1040-1048 | Optionally cache resume prompt |
| `promote_pending_user_part/3` | 1050-1065 | Replace pending part with confirmed |
| `maybe_put_payload_field/3` | 1036-1038 | Conditional field insertion |
| `cache_answer_message/4` | 1757-1777 | Cache answer text as user part |
| `format_answers_for_cache/1` | 1779-1789 | Format answer list as text |
| `build_tool_entry/3` | 1278-1289 | Build tool part from SDK event |
| `normalize_tool_status/1` | 1291-1293 | Normalize tool status strings |
| `serialize_error/1` | 1572-1584 | Serialize error value to string |

**State fields owned by OutputCache**: `output_text`, `output_parts`, `last_flushed_count`, `user_message_ids`, `subtask_message_ids`, `flush_ref` (timer — stays in GenServer), + tracking helpers

### 3.1: OutputCache Unit Tests
- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner_modules/output_cache_test.exs`
  - Tests:
    - `upsert_part/3` appends new parts
    - `upsert_part/3` replaces existing parts by ID
    - `upsert_part/3` appends when part_id is nil
    - `serialize_parts/1` returns nil for empty list
    - `serialize_parts/1` returns JSON string for non-empty list
    - `restore_parts/1` returns empty list for nil/empty
    - `restore_parts/1` decodes JSON array
    - `restore_parts/1` wraps plain text as text part
    - `put_output_attrs/2` adds output when parts exist
    - `put_output_attrs/2` falls back to output_text
    - `put_output_attrs/2` returns attrs unchanged when no output
    - `build_subtask_entry/1` builds correct subtask map
    - `mark_subtask_done/2` marks matching part as done
    - `mark_subtask_done/2` returns unchanged when no match
    - `build_user_message_entry/2` builds user part map
    - `promote_pending_user_part/3` replaces matching pending part
    - `promote_pending_user_part/3` returns false when no match
    - `build_queued_user_entry/2` builds pending user part with optional payload fields
    - `build_queued_user_entry/2` skips empty messages
    - `build_answer_entry/3` formats answer text
    - `format_answers_for_cache/1` joins multi-answer lists
    - `build_tool_entry/3` merges tool state into existing
    - `normalize_tool_status/1` maps completed→done, error→error, default→running
    - `serialize_error/1` handles string, map with data.message, map with message, other map
  - Use `async: true` — all pure functions
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/task_runner/output_cache.ex`
- [ ] **REFACTOR**: Group public API functions logically; add module doc

### 3.2: Wire OutputCache into TaskRunner
- [ ] **RED**: All 12 existing integration tests pass (especially `events_test.exs`, `persistence_test.exs`)
- [ ] **GREEN**: Replace output `defp` functions in `task_runner.ex` with `OutputCache` calls
  - Replace `upsert_output_part/3` → `OutputCache.upsert_part/3`
  - Replace `serialize_output_parts/1` → `OutputCache.serialize_parts/1`
  - Replace `restore_output_parts/1` → `OutputCache.restore_parts/1`
  - Replace `put_output_attrs/2` → `OutputCache.put_output_attrs/2`
  - Replace `cache_subtask_part/2` → `OutputCache.cache_subtask_part/2` (returns updated output_parts)
  - Replace `mark_subtask_done/2` → `OutputCache.mark_subtask_done/2`
  - Replace `cache_user_message_part/2` → `OutputCache.cache_user_message_part/2`
  - Replace `cache_queued_user_message/2-3` → `OutputCache.cache_queued_user_message/3`
  - Replace `maybe_cache_resume_prompt_message/2` → `OutputCache.maybe_cache_resume_prompt/2`
  - Replace `promote_pending_user_part/3` → `OutputCache.promote_pending_user_part/3`
  - Replace `cache_answer_message/4` → `OutputCache.cache_answer_message/4`
  - Replace `format_answers_for_cache/1` → `OutputCache.format_answers/1`
  - Replace `build_tool_entry/3` → `OutputCache.build_tool_entry/3`
  - Replace `normalize_tool_status/1` → `OutputCache.normalize_tool_status/1`
  - Replace `serialize_error/1` → `OutputCache.serialize_error/1`
  - Replace `maybe_put_payload_field/3` → `OutputCache.maybe_put_payload_field/3`
  - Note: `flush_output_to_db/1` remains in TaskRunner (it calls `update_task_status` which is a side effect)
  - Note: `schedule_output_flush/0` and `cancel_flush_timer/1` remain in TaskRunner (timer side effects)
  - Remove all replaced `defp` functions from `task_runner.ex`
- [ ] **REFACTOR**: Ensure TaskRunner only has thin delegation calls

### Phase 3 Validation
- [ ] All 12 integration test files pass
- [ ] New OutputCache unit tests pass
- [ ] `events_test.exs` (637 lines) — all pass
- [ ] `persistence_test.exs` (258 lines) — all pass
- [ ] `resume_test.exs` — all pass (uses restore_output_parts, cache_resume_prompt)
- [ ] Net line reduction in task_runner.ex: ~200 lines

---

## Phase 4: QuestionHandler (⏸ Not Started)

**Risk**: Medium — 3 fields, timeout lifecycle, handle_call delegation.

### What to extract
Functions from `task_runner.ex` related to question management:

| Function | Line | Description |
|----------|------|-------------|
| `clear_pending_question/1` → returns state updates | 1701-1711 | Clears question state fields |
| `mark_question_rejected/1` → returns state updates | 1737-1755 | Marks question as rejected |
| `auto_reject_empty_question/2` | 1713-1733 | Auto-reject empty questions |
| `cancel_question_timeout/1` | 1791-1792 | Cancel timer (stays as side effect) |
| `extract_tool_name/1` | 1300-1303 | Extract tool name from props |
| `valid_session_summary?/1` | 1409-1416 | Validate session summary format |

**Note**: The `handle_call` patterns for `answer_question`, `reject_question` stay in TaskRunner (they are GenServer callbacks). The extracted module provides pure functions for state transformations.

**State fields owned by QuestionHandler**: `pending_question_request_id`, `pending_question_data`, `question_timeout_ref`

### 4.1: QuestionHandler Unit Tests
- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner_modules/question_handler_test.exs`
  - Tests:
    - `clear_pending_question_fields/1` returns map with nil fields
    - `build_question_data/1` builds question data map from props
    - `mark_rejected_fields/1` returns map with nil fields
    - `build_rejected_data/1` adds rejected flag to question data
    - `extract_tool_name/1` returns string tool name from various field shapes
    - `extract_tool_name/1` returns "unknown" for missing/non-string fields
    - `valid_session_summary?/1` returns true for valid summary
    - `valid_session_summary?/1` returns false for invalid/extra keys
    - `sanitize_fresh_start_reason/1` sanitizes docker error (no raw output)
    - `sanitize_fresh_start_reason/1` sanitizes auth refresh error
    - `sanitize_fresh_start_reason/1` returns generic message for unknown errors
  - Use `async: true` — all pure functions
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/task_runner/question_handler.ex`
- [ ] **REFACTOR**: Clean up

### 4.2: Wire QuestionHandler into TaskRunner
- [ ] **RED**: All 12 existing integration tests pass (especially `question_test.exs`)
- [ ] **GREEN**: Replace question `defp` functions in `task_runner.ex` with `QuestionHandler` calls
  - `handle_call({:answer_question, ...})` uses `QuestionHandler.clear_pending_question_fields/0`
  - `handle_call({:reject_question, ...})` uses `QuestionHandler.mark_rejected_fields/0`, `QuestionHandler.build_rejected_data/1`
  - `handle_sdk_event(%{"type" => "question.asked", ...})` uses `QuestionHandler.build_question_data/1`
  - Replace `extract_tool_name/1` → `QuestionHandler.extract_tool_name/1`
  - Replace `valid_session_summary?/1` → `QuestionHandler.valid_session_summary?/1`
  - Replace `sanitize_fresh_start_reason/1` → `QuestionHandler.sanitize_fresh_start_reason/1`
  - Note: `cancel_question_timeout/1` stays in TaskRunner (side effect: `Process.cancel_timer`)
  - Note: `auto_reject_empty_question/2` stays in TaskRunner (side effect: calls opencode_client)
  - Remove all replaced `defp` functions from `task_runner.ex`
- [ ] **REFACTOR**: Verify thin GenServer callbacks

### Phase 4 Validation
- [ ] All 12 integration test files pass
- [ ] New QuestionHandler unit tests pass
- [ ] `question_test.exs` (398 lines, 6 tests) — all pass
- [ ] `events_test.exs` — session.updated summary tests pass
- [ ] `init_test.exs` — fresh start preparation test passes (sanitize_fresh_start_reason)
- [ ] Net line reduction in task_runner.ex: ~80 lines

---

## Phase 5: ContainerLifecycle (⏸ Not Started)

**Risk**: High — 6 fields, state machine, 7 handle_info messages.

### What to extract
Pure helper functions from the container lifecycle management. The `handle_info` callbacks stay in TaskRunner (they are GenServer callbacks with side effects), but the helper logic is extracted.

| Function | Line | Description |
|----------|------|-------------|
| `initialize_lifecycle/7` | 1329-1373 | Decide resume vs cold-start vs prewarmed |
| `maybe_start_from_prewarmed/4` | 1376-1393 | Prewarmed container routing |
| `continue_after_health/4` | 1314-1327 | Health check retry logic |
| `subscribe_to_events/1` | 1305-1312 | SSE subscription (side effect — stays partially) |
| `cleanup_container/1` | 1532-1543 | Container cleanup on terminate |
| `should_reconnect_sse?/2` | 1396-1399 | Reconnection decision |
| `current_sse_process?/2` | 1402-1403 | SSE process identity check |
| `task_active_for_sse_reconnect?/1` | 1405-1407 | Active state check |

**State fields conceptually owned by ContainerLifecycle**: `container_id`, `container_port`, `image`, `health_retries`, `fresh_warm_container`, `auth_refresher`

### 5.1: ContainerLifecycle Unit Tests
- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner_modules/container_lifecycle_test.exs`
  - Tests:
    - `determine_start_strategy/3` returns `:cold_start` when no prewarmed container
    - `determine_start_strategy/3` returns `:restart_prewarmed` when prewarmed container exists but not healthy
    - `determine_start_strategy/3` returns `:prepare_fresh_start` when prewarmed and already healthy
    - `should_reconnect_sse?/3` returns true when current SSE pid, not reconnecting, and active status
    - `should_reconnect_sse?/3` returns false when different pid
    - `should_reconnect_sse?/3` returns false when already reconnecting
    - `should_reconnect_sse?/3` returns false when not in active status
    - `active_for_reconnect?/2` returns true for :prompting and :running
    - `active_for_reconnect?/2` returns false for other statuses
    - `build_resume_state/4` sets container_id, session_id, and restores output/todos from task
    - `build_initial_state_updates/1` returns start message and state updates for each strategy
  - Use `async: true` — all pure functions (decision logic, not actual container operations)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/task_runner/container_lifecycle.ex`
  - Extract only the pure decision/routing logic
  - The actual `handle_info` callbacks with side effects remain in TaskRunner
- [ ] **REFACTOR**: Ensure clear separation between decision logic and side effects

### 5.2: Wire ContainerLifecycle into TaskRunner
- [ ] **RED**: All 12 existing integration tests pass (especially `init_test.exs`, `container_lifecycle_test.exs`, `timeout_test.exs`, `resume_test.exs`)
- [ ] **GREEN**: Replace container lifecycle helpers in `task_runner.ex` with `ContainerLifecycle` calls
  - Replace `initialize_lifecycle/7` routing logic → `ContainerLifecycle.determine_start_strategy/3` + `ContainerLifecycle.build_resume_state/4`
  - Replace `maybe_start_from_prewarmed/4` → `ContainerLifecycle.determine_start_strategy/3`
  - Replace `should_reconnect_sse?/2` → `ContainerLifecycle.should_reconnect_sse?/3`
  - Replace `current_sse_process?/2` → inline or `ContainerLifecycle.current_sse_process?/2`
  - Replace `task_active_for_sse_reconnect?/1` → `ContainerLifecycle.active_for_reconnect?/2`
  - Note: `handle_info` callbacks (:start_container, :restart_container, :wait_for_health, etc.) stay in TaskRunner
  - Note: `cleanup_container/1` stays in TaskRunner (called from `terminate/2`)
  - Note: `subscribe_to_events/1` stays in TaskRunner (side effect)
  - Remove all replaced `defp` functions from `task_runner.ex`
- [ ] **REFACTOR**: Simplify `init/1` using ContainerLifecycle helpers

### Phase 5 Validation
- [ ] All 12 integration test files pass
- [ ] New ContainerLifecycle unit tests pass
- [ ] `init_test.exs` (267 lines, 5 tests) — all pass
- [ ] `container_lifecycle_test.exs` (219 lines, 5 tests) — all pass
- [ ] `timeout_test.exs` (75 lines, 1 test) — passes
- [ ] `resume_test.exs` (418 lines, 5 tests) — all pass
- [ ] `sse_crash_test.exs` (282 lines, 3 tests) — all pass
- [ ] Net line reduction in task_runner.ex: ~80 lines

---

## Phase 6: SseEventRouter (⏸ Not Started)

**Risk**: High — Central dispatch with most cross-concern dependencies. Must be done last because it depends on OutputCache being available.

### What to extract
Functions from `task_runner.ex` related to SDK event routing and child session tracking:

| Function | Line | Description |
|----------|------|-------------|
| `extract_event_session_id/1` | 828-833 | Extract session ID from event properties |
| `track_subtask_message_id/2` | 848-875 | Register subtask message and child session |
| `subtask_part?/1` | 877-883 | Check if event is a subtask part |
| `track_user_message_id/2` | 931-953 | Register user message IDs |
| `user_message_part?/2` | 959-983 | Check if event is a user message part |
| `handle_sdk_event/2` (all clauses) | 1070-1276 | SDK event dispatch — the core routing logic |

**State fields conceptually owned by SseEventRouter**: `sse_pid`, `sse_reconnecting`, `child_session_ids`

### 6.1: SseEventRouter Unit Tests
- [ ] **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/task_runner_modules/sse_event_router_test.exs`
  - Tests:
    - `extract_session_id/1` returns session ID from properties.sessionID
    - `extract_session_id/1` returns session ID from properties.session_id
    - `extract_session_id/1` returns session ID from properties.part.sessionID
    - `extract_session_id/1` returns nil for missing/non-map properties
    - `track_subtask_message_id/2` adds message ID to subtask_message_ids
    - `track_subtask_message_id/2` registers child session ID
    - `track_subtask_message_id/2` is a no-op for non-subtask events
    - `subtask_part?/1` returns true for subtask type events
    - `subtask_part?/1` returns false for non-subtask events
    - `track_user_message_id/2` adds user message ID (skips subtask messages)
    - `track_user_message_id/2` is a no-op for non-user messages
    - `user_message_part?/2` returns true for parts matching user message IDs (messageID)
    - `user_message_part?/2` returns true for parts matching user message IDs (messageId)
    - `user_message_part?/2` returns false for subtask message parts
    - `user_message_part?/2` returns false for non-matching parts
    - `route_event/2` returns `{:completed, state}` for idle after running
    - `route_event/2` returns `{:error, msg, state}` for session.error
    - `route_event/2` returns `{:permission, ...}` for permission.asked
    - `route_event/2` returns `{:question, state}` for question.asked with valid questions
    - `route_event/2` auto-rejects empty/nil/missing questions
    - `route_event/2` returns `{:continue, state}` for text parts (updates output_parts)
    - `route_event/2` returns `{:continue, state}` for tool parts
    - `route_event/2` returns `{:continue, state}` for unknown event types
    - `route_event/2` handles session.updated with valid/invalid summaries
  - Use `async: true` — all pure functions (event routing returns tuples, no side effects)
- [ ] **GREEN**: Implement `apps/agents/lib/agents/sessions/infrastructure/task_runner/sse_event_router.ex`
  - `extract_session_id/1` — pure extraction
  - `track_subtask_message_id/2` — returns updated sets/maps
  - `subtask_part?/1` — predicate
  - `track_user_message_id/2` — returns updated MapSet
  - `user_message_part?/2` — predicate
  - `route_event/2` — the full `handle_sdk_event` dispatch, returns tagged tuples
  - Uses `OutputCache` for part manipulation functions
- [ ] **REFACTOR**: Group by concern; document the tagged return tuples

### 6.2: Wire SseEventRouter into TaskRunner
- [ ] **RED**: All 12 existing integration tests pass (especially `events_test.exs`, `session_tracking_test.exs`)
- [ ] **GREEN**: Replace event routing in `task_runner.ex` with `SseEventRouter` calls
  - Replace `extract_event_session_id/1` → `SseEventRouter.extract_session_id/1`
  - Replace `track_subtask_message_id/2` → `SseEventRouter.track_subtask_message_id/2`
  - Replace `subtask_part?/1` → `SseEventRouter.subtask_part?/1`
  - Replace `track_user_message_id/2` → `SseEventRouter.track_user_message_id/2`
  - Replace `user_message_part?/2` → `SseEventRouter.user_message_part?/2`
  - Replace `handle_sdk_event/2` (all clauses) → `SseEventRouter.route_event/2`
  - Replace `handle_sdk_result/2` to use `SseEventRouter.route_event/2` return values
  - Note: `process_parent_session_event/2`, `process_child_session_event/3` stay in TaskRunner (they call broadcast + side effects)
  - Note: `handle_info({:opencode_event, ...})` stays in TaskRunner (GenServer callback)
  - Note: `update_session_from_sdk_event/2` stays in TaskRunner (calls SdkEventHandler with side effects)
  - Remove all replaced `defp` functions from `task_runner.ex`
- [ ] **REFACTOR**: Final cleanup of TaskRunner — verify it's a thin orchestrator

### Phase 6 Validation
- [ ] All 12 integration test files pass
- [ ] New SseEventRouter unit tests pass
- [ ] `events_test.exs` (637 lines) — all pass
- [ ] `session_tracking_test.exs` (153 lines) — all pass
- [ ] `sse_crash_test.exs` (282 lines) — all pass
- [ ] Net line reduction in task_runner.ex: ~250 lines

---

## Final Validation (⏸ Not Started)

### Pre-commit Checkpoint
- [ ] `mix compile --warnings-as-errors` — zero warnings
- [ ] `mix boundary` — zero violations
- [ ] `mix format --check-formatted` — all formatted
- [ ] `mix credo --strict` — no new issues
- [ ] `mix precommit` — passes
- [ ] All 1520 existing tests pass: `mix test apps/agents/test/agents/sessions/infrastructure/task_runner/ --trace`
- [ ] New unit tests pass: `mix test apps/agents/test/agents/sessions/infrastructure/task_runner_modules/ --trace`
- [ ] Full test suite passes: `mix test`

### Final Size Audit
- [ ] `task_runner.ex` is ~600 lines (down from 1,870)
- [ ] Each extracted module is <250 lines
- [ ] Each extracted module has a `@moduledoc` explaining its responsibility
- [ ] No circular dependencies between extracted modules
- [ ] PubSub message format/naming is unchanged (verified by agents_web integration)

---

## Testing Strategy

### Existing Tests (unchanged — integration/GenServer level)
| File | Lines | Tests | What it covers |
|------|-------|-------|---------------|
| `init_test.exs` | 267 | 5 | GenServer init, container start, task_not_found |
| `completion_test.exs` | 61 | 1 | Cancel flow |
| `container_lifecycle_test.exs` | 219 | 5 | Container stop on complete/fail/cancel/terminate |
| `domain_events_test.exs` | 228 | 3 | TaskCompleted/TaskFailed/TaskCancelled events |
| `events_test.exs` | 637 | 7 | SSE events, output caching, session.updated |
| `persistence_test.exs` | 258 | 3 | session_id persistence, output caching on failure |
| `question_test.exs` | 398 | 6 | Question persist, timeout, answer, reject, empty |
| `resume_test.exs` | 418 | 5 | Resume path, SSE fail, todo merge, prompt cache |
| `session_tracking_test.exs` | 153 | 4 | Session entity tracking, domain events from SDK |
| `sse_crash_test.exs` | 282 | 3 | SSE crash/reconnect/normal exit |
| `timeout_test.exs` | 75 | 1 | Health check exhaustion |
| `todo_test.exs` | 268 | 7 | Todo parse, broadcast, persist, flush |

### New Tests (unit level — pure functions)
| File | Est. Tests | What it covers |
|------|-----------|---------------|
| `task_broadcaster_test.exs` | ~12 | All broadcast functions |
| `todo_tracker_test.exs` | ~10 | Parse, merge, serialize, restore |
| `output_cache_test.exs` | ~24 | Upsert, serialize, restore, subtask, user, tool |
| `question_handler_test.exs` | ~10 | Question state transforms, validation, extraction |
| `container_lifecycle_test.exs` | ~10 | Start strategy, reconnect decisions, resume state |
| `sse_event_router_test.exs` | ~20 | Event routing, session tracking, all event types |

### Test Distribution
- **Total estimated NEW tests**: ~86
- **Total existing tests**: 50 (in 12 files)
- **Distribution**: Domain pure (86 new async unit tests) + Integration (50 existing GenServer tests)
- **Key invariant**: Every extraction phase ends with ALL existing tests passing

---

## Cross-concern Function Map

These functions are called from multiple concern areas. The plan assigns each to the most appropriate module:

| Function | Called from | Assigned to | Rationale |
|----------|------------|-------------|-----------|
| `upsert_output_part/3` | SDK events, question answer, queued messages, subtasks | OutputCache | Core output concern |
| `update_task_status/2` | complete, fail, cancel, flush, question, lifecycle | TaskRunner (stays) | Side effect: DB write |
| `broadcast_status/3` | complete, fail, cancel, init lifecycle | TaskBroadcaster | Pure broadcast |
| `broadcast_status_with_lifecycle/4` | complete, fail, cancel, container start | TaskBroadcaster | Pure broadcast |
| `cancel_flush_timer/1` | complete, fail, cancel | TaskRunner (stays) | Side effect: cancel timer |
| `cancel_question_timeout/1` | complete, fail, answer, reject | TaskRunner (stays) | Side effect: cancel timer |
| `flush_output_to_db/1` | periodic flush, queued message, answer | TaskRunner (stays) | Side effect: DB write |
| `put_output_attrs/2` | complete_task, fail_task | OutputCache | Pure data transform |
| `put_todo_attrs/2` | complete_task, fail_task, flush | TodoTracker | Pure data transform |
| `serialize_error/1` | fail_task | OutputCache | Pure transform |
| `notify_queue_terminal/2` | complete, fail, cancel | TaskRunner (stays) | Side effect: callback |

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| State coupling: `complete_task/1` and `fail_task/1` call 4 concern areas | These stay in TaskRunner as orchestration; they call extracted modules' pure functions |
| SSE reconnection depends on both SseEventRouter and Core state | `should_reconnect_sse?` is pure — takes explicit fields, no implicit state |
| Subtask/child tracking bridges SseEventRouter and OutputCache | SseEventRouter calls OutputCache for part manipulation — explicit dependency |
| Resume path touches OutputCache, TodoTracker, and ContainerLifecycle | `initialize_lifecycle` decomposed: ContainerLifecycle handles strategy, OutputCache handles part restore, TodoTracker handles todo restore |
| Tests use `:sys.get_state/1` to inspect state | State struct shape is unchanged — tests need no modification |
| PubSub message format changes would break agents_web consumers | No format changes — TaskBroadcaster produces identical messages |

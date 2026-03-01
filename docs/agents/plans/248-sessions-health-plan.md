# Feature: #248 — Improve Agents Sessions Codebase Health

## Overview

Comprehensive refactoring of the Agents Sessions bounded context to improve code health across 5 areas: LiveView component extraction, dead code removal, domain event emission, typespec coverage, and facade test coverage. This is a pure refactoring ticket — no new features, no schema changes, no migrations.

## UI Strategy

- **LiveView coverage**: 100% — no new UI, only extraction/reorganisation of existing code
- **TypeScript needed**: None — no client-side changes

## Affected Boundaries

- **Owning app**: `agents` (domain) + `agents_web` (interface)
- **Repo**: `Agents.Repo`
- **Migrations**: None required
- **Feature files**: None — refactoring with no behavioral changes
- **Primary context**: `Agents.Sessions`
- **Dependencies**: `perme8_events` (for `Perme8.Events.DomainEvent` macro and `EventBus`)
- **Exported schemas**: No changes
- **New context needed?**: No — all work is within the existing `Agents.Sessions` context

## Pre-Implementation Baseline

- [ ] ⏸ Run full test suite and confirm all 672 tests pass (639 agents + 33 agents_web)
- [ ] ⏸ Run `mix boundary` and confirm no violations
- [ ] ⏸ Confirm `index.ex` is 1,763 lines

---

## Phase 1: Domain Events (phoenix-tdd) ✓

Domain events must exist before use cases can emit them. Build bottom-up: define event structs first, then wire emission into use cases.

### Step 1.1: TaskCreated Domain Event

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/domain/events/task_created_test.exs`
  - Tests: struct creation via `new/1` with required fields, `event_type/0` returns `"sessions.task_created"`, `aggregate_type/0` returns `"task"`, auto-generates `event_id` and `occurred_at`, raises on missing `:aggregate_id` or `:actor_id`
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/task_created.ex`
  - Uses `use Perme8.Events.DomainEvent, aggregate_type: "task", fields: [task_id: nil, user_id: nil, instruction: nil], required: [:task_id, :user_id, :instruction]`
- [x] ✓ **REFACTOR**: Verify module follows the `Agents.Domain.Events.AgentCreated` pattern

### Step 1.2: TaskCompleted Domain Event

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/domain/events/task_completed_test.exs`
  - Tests: struct creation, `event_type/0` returns `"sessions.task_completed"`, auto fields
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/task_completed.ex`
  - Fields: `[task_id: nil, user_id: nil]`, required: `[:task_id, :user_id]`
- [x] ✓ **REFACTOR**: Clean up

### Step 1.3: TaskFailed Domain Event

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/domain/events/task_failed_test.exs`
  - Tests: struct creation, `event_type/0` returns `"sessions.task_failed"`, includes `error` field
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/task_failed.ex`
  - Fields: `[task_id: nil, user_id: nil, error: nil]`, required: `[:task_id, :user_id]`
- [x] ✓ **REFACTOR**: Clean up

### Step 1.4: TaskCancelled Domain Event

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/domain/events/task_cancelled_test.exs`
  - Tests: struct creation, `event_type/0` returns `"sessions.task_cancelled"`
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/events/task_cancelled.ex`
  - Fields: `[task_id: nil, user_id: nil]`, required: `[:task_id, :user_id]`
- [x] ✓ **REFACTOR**: Clean up

### Step 1.5: Update Domain Boundary Exports

- [x] ✓ Update `apps/agents/lib/agents/sessions/domain.ex` to export the 4 new event modules:
  ```
  exports: [
    Entities.Task,
    Policies.TaskPolicy,
    Events.TaskCreated,
    Events.TaskCompleted,
    Events.TaskFailed,
    Events.TaskCancelled
  ]
  ```

### Step 1.6: Wire Event Emission into CreateTask Use Case

- [x] ✓ **RED**: Update test `apps/agents/test/agents/sessions/application/use_cases/create_task_test.exs`
  - Add new test: "emits TaskCreated domain event on success" — inject `event_bus: Perme8.Events.TestEventBus`, assert `TestEventBus.get_events()` contains a `%TaskCreated{}` with correct `task_id`, `user_id`, `instruction`
  - Add new test: "does not emit event on validation failure" — pass blank instruction, assert `TestEventBus.get_events()` is `[]`
- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex`
  - Add `@default_event_bus Perme8.Events.EventBus`
  - Extract `event_bus` from `opts`
  - After successful `task_repo.create_task/1`, emit `TaskCreated.new(...)` via `event_bus.emit/1`
  - Emit AFTER the DB insert (not inside a transaction — CreateTask doesn't use one)
- [x] ✓ **REFACTOR**: Ensure event is only emitted on the happy path (after `{:ok, schema}`)

### Step 1.7: Wire Event Emission into TaskRunner (complete_task, fail_task, cancel)

The TaskRunner manages completion/failure/cancellation and does NOT go through use cases for these state transitions. Domain events should be emitted from the TaskRunner after DB writes.

- [x] ✓ **RED**: Update existing TaskRunner tests to verify event emission
  - In `apps/agents/test/agents/sessions/infrastructure/task_runner/completion_test.exs`: add assertion that `TaskCompleted` event is emitted when a task completes (inject `event_bus` via opts)
  - In `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs` (or a new file): add assertions for `TaskFailed` and `TaskCancelled` emission
- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - Add `event_bus` to the struct fields and `init/1` — extract from opts, default to `Perme8.Events.EventBus`
  - In `complete_task/1`: after `update_task_status` and `broadcast_status`, call `state.event_bus.emit(TaskCompleted.new(...))`
  - In `fail_task/2`: after `update_task_status` and `broadcast_status`, call `state.event_bus.emit(TaskFailed.new(...))`
  - In `handle_info(:cancel, ...)`: after `update_task_status` and `broadcast_status`, call `state.event_bus.emit(TaskCancelled.new(...))`
  - Note: existing PubSub broadcasts for real-time UI remain unchanged — domain events are a separate layer for cross-context communication
- [x] ✓ **REFACTOR**: Ensure `aggregate_id` and `actor_id` are set correctly (`task_id` and `user_id` from state)

### Phase 1 Validation

- [x] ✓ All domain event tests pass (pure, fast, no I/O)
- [x] ✓ All updated use case / TaskRunner tests pass
- [x] ✓ No boundary violations (`mix compile` clean — only pre-existing AuthRefresher warning)
- [x] ✓ Full `mix test` passes in `apps/agents` (666 tests, 0 failures)

---

## Phase 2: Dead Code Removal (phoenix-tdd) ✓

Remove unused functions rather than implementing unplanned enforcement logic. This simplifies the codebase.

### Step 2.1: Remove `SessionsConfig.max_concurrent_tasks/0`

- [x] ✓ **RED**: Remove the test for `max_concurrent_tasks/0` from `apps/agents/test/agents/sessions/application/sessions_config_test.exs`
- [x] ✓ **GREEN**: Remove `max_concurrent_tasks/0` function from `apps/agents/lib/agents/sessions/application/sessions_config.ex`
- [x] ✓ **REFACTOR**: Verify no callers remain (`grep` for `max_concurrent_tasks` across codebase)

### Step 2.2: Remove `TaskRepository.running_task_count_for_user/1`

- [x] ✓ **RED**: Remove the test for `running_task_count_for_user/1` from `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs`
- [x] ✓ **GREEN**: Remove `running_task_count_for_user/1` from `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex`
- [x] ✓ **REFACTOR**: Also remove the `@callback running_task_count_for_user(user_id)` from `apps/agents/lib/agents/sessions/application/behaviours/task_repository_behaviour.ex`

### Step 2.3: Remove `TaskQueries.running_count_for_user/1`

- [x] ✓ **RED**: Remove the test for `running_count_for_user/1` from `apps/agents/test/agents/sessions/infrastructure/queries/task_queries_test.exs`
- [x] ✓ **GREEN**: Remove `running_count_for_user/1` and `@active_statuses` (if only used by that function) from `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex`
- [x] ✓ **REFACTOR**: Verify `@active_statuses` isn't used elsewhere in the module; if not, remove it

### Step 2.4: Remove `TaskPolicy.valid_status_transition?/2`

- [x] ✓ **RED**: Remove the `describe "valid_status_transition?/2"` block from `apps/agents/test/agents/sessions/domain/policies/task_policy_test.exs`
- [x] ✓ **GREEN**: Remove `valid_status_transition?/2` from `apps/agents/lib/agents/sessions/domain/policies/task_policy.ex`
- [x] ✓ **REFACTOR**: Verify no callers remain; ensure policy is still clean and focused

### Phase 2 Validation

- [x] ✓ All remaining tests pass (648 tests, 0 failures)
- [x] ✓ No references to removed functions remain (`mix compile --warnings-as-errors` clean)
- [x] ✓ No boundary violations

---

## Phase 3: Add @spec to Use Case execute Functions (phoenix-tdd) ✓

Adding typespecs is a non-breaking change that improves documentation and enables Dialyzer. No tests needed for typespecs themselves — verify via `mix compile` (no warnings).

### Step 3.1: Add @spec to CreateTask.execute/2

- [x] ✓ Add to `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex`:
  ```elixir
  @spec execute(map(), keyword()) :: {:ok, Agents.Sessions.Domain.Entities.Task.t()} | {:error, term()}
  ```

### Step 3.2: Add @spec to CancelTask.execute/3

- [x] ✓ Add to `apps/agents/lib/agents/sessions/application/use_cases/cancel_task.ex`:
  ```elixir
  @spec execute(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  ```

### Step 3.3: Add @spec to DeleteTask.execute/3

- [x] ✓ Add to `apps/agents/lib/agents/sessions/application/use_cases/delete_task.ex`:
  ```elixir
  @spec execute(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  ```

### Step 3.4: Add @spec to DeleteSession.execute/3

- [x] ✓ Add to `apps/agents/lib/agents/sessions/application/use_cases/delete_session.ex`:
  ```elixir
  @spec execute(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  ```

### Step 3.5: Add @spec to ResumeTask.execute/3

- [x] ✓ Add to `apps/agents/lib/agents/sessions/application/use_cases/resume_task.ex`:
  ```elixir
  @spec execute(String.t(), map(), keyword()) :: {:ok, Agents.Sessions.Domain.Entities.Task.t()} | {:error, term()}
  ```

### Step 3.6: Add @spec to GetTask.execute/3

- [x] ✓ Add to `apps/agents/lib/agents/sessions/application/use_cases/get_task.ex`:
  ```elixir
  @spec execute(String.t(), String.t(), keyword()) :: {:ok, Agents.Sessions.Domain.Entities.Task.t()} | {:error, :not_found}
  ```

### Step 3.7: Add @spec to ListTasks.execute/2

- [x] ✓ Add to `apps/agents/lib/agents/sessions/application/use_cases/list_tasks.ex`:
  ```elixir
  @spec execute(String.t(), keyword()) :: [Agents.Sessions.Domain.Entities.Task.t()]
  ```

### Step 3.8: Add @spec to RefreshAuthAndResume.execute/3

- [x] ✓ Add to `apps/agents/lib/agents/sessions/application/use_cases/refresh_auth_and_resume.ex`:
  ```elixir
  @spec execute(String.t(), String.t(), keyword()) :: {:ok, Agents.Sessions.Domain.Entities.Task.t()} | {:error, term()}
  ```

### Step 3.9: Add @spec to TaskRunner public API

- [x] ✓ Add to `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`:
  ```elixir
  @spec start_link({String.t(), keyword()}) :: GenServer.on_start()
  @spec via_tuple(String.t()) :: {:via, module(), {module(), String.t()}}
  ```

### Phase 3 Validation

- [x] ✓ `mix compile --warnings-as-errors` passes in `apps/agents`
- [x] ✓ All tests still pass

---

## Phase 4: Facade Test Coverage (phoenix-tdd) ✓

Add direct tests for the 8 facade functions currently lacking coverage. These test the `Agents.Sessions` public API with mocked/injected dependencies.

### Step 4.1: Test `list_sessions/2`

- [x] ✓ **RED**: Add `describe "list_sessions/2"` to `apps/agents/test/agents/sessions_test.exs`
  - Test: "returns sessions grouped by container_id" — create 2 tasks with same container_id, 1 with different; assert returns 2 session groups with correct `:container_id`, `:task_count`, `:title`, `:latest_status`
  - Test: "returns empty list for user with no sessions" — assert `[]`
  - Test: "excludes tasks without container_id" — create task with nil container_id, assert not in results
- [x] ✓ **GREEN**: Tests pass using existing implementation (no code changes needed — just adding test coverage)
- [x] ✓ **REFACTOR**: Ensure tests are isolated and async-safe

### Step 4.2: Test `get_container_stats/2`

- [x] ✓ **RED**: Add `describe "get_container_stats/2"` to `apps/agents/test/agents/sessions_test.exs`
  - Test: "delegates to container provider" — inject a mock container_provider module that returns `{:ok, %{cpu_percent: 25.0, memory_usage: 100, memory_limit: 200}}`; assert facade returns same result
  - Test: "returns error for unknown container" — inject mock returning `{:error, :not_found}`; assert error propagated
- [x] ✓ **GREEN**: Tests pass using existing implementation with mock injection
- [x] ✓ **REFACTOR**: Clean up mock module

### Step 4.3: Test `answer_question/3`

- [x] ✓ **RED**: Add `describe "answer_question/3"` to `apps/agents/test/agents/sessions_test.exs`
  - Test: "returns :task_not_running when no runner registered" — call with a random task_id, assert `{:error, :task_not_running}`
- [x] ✓ **GREEN**: Tests pass (function already handles this case)
- [x] ✓ **REFACTOR**: Clean up

### Step 4.4: Test `reject_question/2`

- [x] ✓ **RED**: Add `describe "reject_question/2"` to `apps/agents/test/agents/sessions_test.exs`
  - Test: "returns :task_not_running when no runner registered" — call with random task_id, assert `{:error, :task_not_running}`
- [x] ✓ **GREEN**: Tests pass
- [x] ✓ **REFACTOR**: Clean up

### Step 4.5: Test `send_message/2`

- [x] ✓ **RED**: Add `describe "send_message/2"` to `apps/agents/test/agents/sessions_test.exs`
  - Test: "returns :task_not_running when no runner registered" — call with random task_id, assert `{:error, :task_not_running}`
- [x] ✓ **GREEN**: Tests pass
- [x] ✓ **REFACTOR**: Clean up

### Step 4.6: Test `delete_session/3`

- [x] ✓ **RED**: Add `describe "delete_session/3"` to `apps/agents/test/agents/sessions_test.exs`
  - Test: "deletes all tasks for a container" — create 2 tasks with same container_id (both completed), call `delete_session`, assert tasks are gone (verify via `list_sessions`)
  - Test: "returns error for non-existent container" — call with unknown container_id, assert `{:error, :not_found}`
  - Inject `container_provider: MockContainerProvider` that returns `:ok` for `remove/1`
- [x] ✓ **GREEN**: Tests pass with mock container provider
- [x] ✓ **REFACTOR**: Clean up

### Step 4.7: Test `resume_task/3`

- [x] ✓ **RED**: Add `describe "resume_task/3"` to `apps/agents/test/agents/sessions_test.exs`
  - Test: "creates a new task linked to parent" — create a completed task with container_id and session_id, call `resume_task` with mock runner starter, assert returns `{:ok, %Task{}}` with correct `parent_task_id`, `container_id`, `session_id`
  - Test: "returns error for active parent" — create running task, assert `{:error, :not_resumable}`
  - Test: "returns error for non-existent parent" — call with random UUID, assert `{:error, :not_found}`
  - Test: "returns error for parent without container" — create completed task with nil container_id, assert `{:error, :no_container}`
- [x] ✓ **GREEN**: Tests pass with mock runner starter
- [x] ✓ **REFACTOR**: Clean up

### Step 4.8: Test `refresh_auth_and_resume/3`

- [x] ✓ **RED**: Add `describe "refresh_auth_and_resume/3"` to `apps/agents/test/agents/sessions_test.exs`
  - Test: "returns error for non-existent task" — call with unknown task_id, assert `{:error, :not_found}`
  - Test: "returns error for non-failed task" — create completed task, assert `{:error, :not_resumable}`
  - Test: "returns error for failed task without container" — create failed task with nil container_id, assert `{:error, :no_container}`
  - (Note: full happy path requires mocking container_provider, opencode_client, and auth_refresher — keep to error-path coverage for now as integration testing lives in feature files)
- [x] ✓ **GREEN**: Tests pass
- [x] ✓ **REFACTOR**: Clean up

### Phase 4 Validation

- [x] ✓ All new facade tests pass (17 new tests, 30 total in sessions_test.exs)
- [x] ✓ All 8 previously untested facade functions now have coverage
- [x] ✓ Full `mix test` passes in `apps/agents` (665 tests, 0 failures)

---

## Phase 5: LiveView Component Extraction (phoenix-tdd)

Extract components and template from the 1,763-line `index.ex` to bring it under 500 lines. This is a mechanical refactoring — no behavioral changes.

### Step 5.1: Extract Session Components Module

Extract component functions (lines 1383-1762, ~380 lines) into a dedicated `SessionComponents` module following the `JargaWeb.ChatLive.Components.Message` pattern.

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/agents_web/live/sessions/components/session_components_test.exs`
  - Tests: `output_part/1` renders text (streaming and frozen), reasoning (streaming and frozen), tool cards, question_card renders
  - Tests: `status_badge/1` renders correct badge classes for each status
  - Tests: `status_dot/1` renders correct dot colours
  - Tests: `container_stats_bars/1` renders CPU/MEM bars
  - Use `Phoenix.LiveViewTest.render_component/2` or `Phoenix.Component` test helpers
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/sessions/components/session_components.ex`
  - `use Phoenix.Component`
  - Move from `index.ex`: `output_part/1` (all clauses), `question_card/1`, `status_badge/1`, `status_dot/1`, `container_stats_bars/1`, `tool_icon/1`, `tool_icon_name/1`, `format_tool_input/1`, `truncate_output/1`, `format_mem_short/1`
  - Declare proper `attr` declarations for each public component
  - Keep `render_markdown/1` as a helper within this module (needed by `output_part` and `question_card`)
- [ ] ⏸ **REFACTOR**: Update `index.ex` to `import AgentsWeb.SessionsLive.Components.SessionComponents` and remove all moved functions

### Step 5.2: Extract Event Processing Module

Extract event processing logic (lines 564-776, ~212 lines) and cached output decoding (lines 780-917, ~137 lines) into a helper module.

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/agents_web/live/sessions/event_processor_test.exs`
  - Tests: `process_event/2` returns correct socket assigns for each event type:
    - `session.updated` sets `session_title`, `session_summary`
    - `message.updated` (assistant) sets `session_model`, `session_tokens`, `session_cost`
    - `message.updated` (user) tracks `user_message_ids`
    - `message.part.updated` (text) upserts `output_parts`
    - `message.part.updated` (reasoning) upserts `output_parts`
    - `message.part.updated` (tool-start, tool-result, tool with state) upserts tool entries
    - `question.asked` sets `pending_question`
    - `question.replied` clears `pending_question`
    - `question.rejected` marks `pending_question` as rejected
  - Tests: `decode_cached_output/1` parses JSON output into parts tuples, handles legacy format, handles plain text fallback
  - Tests: `maybe_load_cached_output/2` assigns output_parts from task.output
  - Tests: `maybe_load_pending_question/2` restores pending question from task data
  - Use pure unit tests — create mock socket assigns as plain maps, test return values
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/sessions/event_processor.ex`
  - Module: `AgentsWeb.SessionsLive.EventProcessor`
  - Move from `index.ex`:
    - `process_event/2` (all 13 clauses)
    - `handle_tool_event/5`
    - `user_message_part?/2`
    - `has_streaming_parts?/1`
    - `maybe_assign/3`
    - `upsert_part/2`
    - `freeze_streaming/1`
    - `format_model/1`
    - `maybe_load_cached_output/2`
    - `maybe_load_pending_question/2`
    - `restore_question_card/5`
    - `extract_question_from_output_parts/1`
    - `extract_questions_from_detail/1`
    - `question_tool?/1`
    - `decode_cached_output/1`
    - `decode_output_part/1`
    - `safe_tool_status/1`
  - Make `process_event/2`, `maybe_load_cached_output/2`, `maybe_load_pending_question/2`, `has_streaming_parts?/1`, `freeze_streaming/1` public
  - Keep other functions private within this module
- [ ] ⏸ **REFACTOR**: Update `index.ex` to call `EventProcessor.process_event/2`, `EventProcessor.maybe_load_cached_output/2`, etc. Remove all moved functions.

### Step 5.3: Extract HEEx Template

Extract the inline `render/1` template (~300 lines) into a co-located `.html.heex` file.

- [ ] ⏸ **GREEN**: Move the template content from the `~H"""..."""` block in `render/1` to `apps/agents_web/lib/live/sessions/index.html.heex`
  - Remove the `render/1` function from `index.ex` — Phoenix automatically uses the co-located `.html.heex` file
  - Update component function calls in the template to use the imported `SessionComponents` module (e.g., `<.output_part>` still works if imported)
- [ ] ⏸ **REFACTOR**: Verify the LiveView still renders correctly — no test changes needed since behavior is identical

### Step 5.4: Final Index.ex Cleanup

- [ ] ⏸ **REFACTOR**: Review `index.ex` — should now contain:
  - Module declaration + `use` + `alias` (~10 lines)
  - `mount/3` + `handle_params/3` (~40 lines)
  - 10 `handle_event/3` clauses (~220 lines)
  - Event helpers: `send_message_to_running_task/2`, `toggle_selection/3`, `build_question_answers/1`, `format_question_answer_as_message/2`, `submit_rejected_question/3`, `submit_active_question/3`, `run_or_resume_task/2`, `handle_task_result/2`, `task_error_message/1`, `do_cancel_task/2` (~140 lines)
  - PubSub `handle_info/2` clauses (~90 lines)
  - State management helpers: `maybe_update_task_status/4`, `assign_session_state/1` (~30 lines)
  - Utility helpers: `find_current_task/2`, `session_tasks/2`, `update_task_in_list/3`, `reload_all/2`, `active_task?/1`, `task_running?/1`, `session_deletable?/2`, `resumable_task?/1`, `relative_time/1`, `subscribe_to_active_tasks/1`, `schedule_stats_poll/0`, `poll_running_session_stats/1`, `fetch_container_stats/1`, `format_token_count/1`, `truncate_instruction/2`, `auth_error?/1`, `format_error/1` (~80 lines)
  - **Estimated total: ~410 lines** (under 500 target)
  - Add imports at top: `import AgentsWeb.SessionsLive.Components.SessionComponents` and `alias AgentsWeb.SessionsLive.EventProcessor`
- [ ] ⏸ Verify no functions are accidentally duplicated between modules
- [ ] ⏸ Verify all private functions are accessible from their new locations

### Phase 5 Validation

- [ ] ⏸ `index.ex` is under 500 lines
- [ ] ⏸ `SessionComponents` module compiles and its tests pass
- [ ] ⏸ `EventProcessor` module compiles and its tests pass
- [ ] ⏸ Template renders identically (verify via existing agents_web tests or manual inspection)
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full `mix test` passes across both `apps/agents` and `apps/agents_web`

---

## Phase 6: Final Validation & Pre-commit

- [ ] ⏸ `mix compile --warnings-as-errors` — no warnings
- [ ] ⏸ `mix boundary` — no violations
- [ ] ⏸ `mix format` — all files formatted
- [ ] ⏸ `mix credo` — no issues
- [ ] ⏸ `mix test` in `apps/agents` — all tests pass
- [ ] ⏸ `mix test` in `apps/agents_web` — all tests pass
- [ ] ⏸ `mix precommit` — all green
- [ ] ⏸ Verify `index.ex` line count < 500
- [ ] ⏸ Verify no unused public functions remain (removed in Phase 2)
- [ ] ⏸ Verify domain events emit for task lifecycle (Phase 1)
- [ ] ⏸ Verify all use case `execute` functions have `@spec` (Phase 3)
- [ ] ⏸ Verify all 8 previously untested facade functions have tests (Phase 4)

---

## Testing Strategy

- **Total estimated new tests**: ~55-65
  - Domain events: ~16 (4 events × 4 tests each)
  - Event emission in use cases/TaskRunner: ~6
  - Facade coverage: ~18 (8 functions × ~2-3 tests each)
  - SessionComponents: ~12
  - EventProcessor: ~15
- **Tests removed** (dead code): ~8 (valid_status_transition tests, max_concurrent_tasks test, running_count tests)
- **Net change**: ~+50 tests
- **Distribution**:
  - Domain: ~16 (event struct tests — pure, fast, no I/O)
  - Application: ~6 (use case event emission — mocked via TestEventBus)
  - Infrastructure: ~6 (TaskRunner event emission)
  - Facade: ~18 (integration with injected deps)
  - Interface: ~27 (SessionComponents + EventProcessor)

## Architectural Notes

### Domain Event Placement

Domain events for the Sessions context go in `apps/agents/lib/agents/sessions/domain/events/` — NOT in `apps/agents/lib/agents/domain/events/`. The Sessions context is a bounded context within the agents app with its own `domain/` layer. Existing agent events (AgentCreated, etc.) live in `apps/agents/lib/agents/domain/events/` because they belong to the top-level Agents context, not the Sessions sub-context.

### PubSub vs Domain Events

The TaskRunner currently uses raw PubSub broadcasts (`{:task_event, task_id, event}` and `{:task_status_changed, task_id, status}`) for real-time UI communication. These are **not** domain events — they are UI notification messages. Domain events (`TaskCreated`, `TaskCompleted`, etc.) emitted via `EventBus.emit/1` serve a different purpose: cross-context communication, audit trails, and eventual consistency. Both mechanisms coexist.

### Component Module Pattern

Following the jarga_web pattern (`JargaWeb.ChatLive.Components.Message`):
- Components live in a `components/` subdirectory adjacent to the LiveView
- Use `use Phoenix.Component`
- Declare `attr` for each public component function
- Are imported by the LiveView module

### EventProcessor Module Pattern

The EventProcessor is a plain Elixir module (not a Component, not a GenServer). It contains pure socket-transformation functions that take a socket (or assigns) and an event, and return updated assigns. This keeps the LiveView thin and makes the event processing logic independently testable.

## Implementation Order Summary

| Phase | Focus | Apps Modified | Approx. Steps |
|-------|-------|---------------|----------------|
| 1 | Domain Events | agents | 7 steps |
| 2 | Dead Code Removal | agents | 4 steps |
| 3 | Typespecs | agents | 9 steps |
| 4 | Facade Tests | agents | 8 steps |
| 5 | LiveView Extraction | agents_web | 4 steps |
| 6 | Final Validation | both | 1 step |

Phases 1-4 modify only `apps/agents`. Phase 5 modifies only `apps/agents_web`. Phase 6 validates everything together. This ordering minimizes cross-app conflicts and allows incremental commits.

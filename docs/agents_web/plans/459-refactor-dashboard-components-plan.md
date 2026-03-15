# Feature: #459 — Refactor Dashboard Index LiveView into Smaller Components

## Overview

Split the monolithic dashboard LiveView files into smaller, focused modules to improve
maintainability, readability, and testability. This is a **pure structural refactor** —
zero behaviour changes. All 477 existing tests must continue to pass after every phase.

## UI Strategy
- **LiveView coverage**: 100% — no TypeScript changes
- **TypeScript needed**: None — this is a server-side structural refactor only

## Affected Boundaries
- **Owning app**: `agents_web` (Interface/LiveView — no Repo, no domain logic)
- **Repo**: None — `agents_web` is a pure interface app
- **Migrations**: None
- **Feature files**: None (no behaviour changes)
- **Primary context**: `AgentsWeb.DashboardLive` (interface layer)
- **Dependencies**: `agents` (domain), `identity` (auth) — unchanged
- **Exported schemas**: None
- **New context needed?**: No — this is within the existing dashboard LiveView namespace

## Constraints
- NO behaviour changes — pure structural refactor
- All 477 existing tests must pass (2 pre-existing failures unrelated to this work)
- Phoenix component conventions must be followed
- Each phase is a single atomic commit with all tests passing
- Backward-compatible delegation must be maintained for `session_data_helpers.ex`
  so the 9 importing modules continue to work without changes

---

## Phase 1: Extract Shared Test Helpers ⏸

**Risk**: Lowest — test infrastructure only, no production code changes.

**Goal**: Extract `FakeTaskRunner` and `send_queue_state` from `index_test.exs` into
a shared test support module so all split test files can reuse them.

### 1.1 — Create shared test support module

- [ ] **RED**: Verify that `FakeTaskRunner` and `send_queue_state` are currently defined
  inside `AgentsWeb.DashboardLive.IndexTest` and used in 15+ and 17+ call sites respectively.
  Confirm that extracting them into a separate module would cause compilation errors if
  done incorrectly (e.g., mismatched module references).

- [ ] **GREEN**: Create `apps/agents_web/test/support/dashboard_test_helpers.ex` containing:
  - `AgentsWeb.DashboardTestHelpers.FakeTaskRunner` — GenServer that registers in
    `Agents.Sessions.TaskRegistry` and replies `:ok` to `send_message`, `answer_question`
    (extracted from lines 14–46 of `index_test.exs`)
  - `AgentsWeb.DashboardTestHelpers.send_queue_state/3` — helper function that builds a
    `QueueSnapshot` from a legacy map and sends it to the LiveView process
    (extracted from lines 54–125 of `index_test.exs`)

- [ ] **REFACTOR**: Update `apps/agents_web/test/live/dashboard/index_test.exs`:
  - Remove the inline `FakeTaskRunner` defmodule (lines 14–46)
  - Remove the inline `send_queue_state/3` defp (lines 54–125)
  - Add `alias AgentsWeb.DashboardTestHelpers.FakeTaskRunner` at the top
  - Add `import AgentsWeb.DashboardTestHelpers, only: [send_queue_state: 3]` at the top

### Phase 1 Validation
- [ ] All 477 tests pass (`mix test apps/agents_web/`)
- [ ] No production code changed
- [ ] `FakeTaskRunner` and `send_queue_state` are importable from the shared module

---

## Phase 2: Split `session_components.ex` into Focused Component Modules ⏸

**Risk**: Low-medium — component modules are self-contained with clear boundaries.

**Goal**: Split the 1,540-line `session_components.ex` into 5 focused component modules.
The original module becomes a thin delegation hub that imports/re-exports all public
functions so existing callers (`index.ex`, test files) don't need changes.

### Current Public Functions by Group

| Group | Functions | Lines |
|-------|-----------|-------|
| Tab bar | `tab_bar/1` | 31–59 |
| Question card | `question_card/1` | 69–158 |
| Queued message | `queued_message/1` | 160–218 |
| Output parts | `progress_bar/1`, `compact_progress_bar/1`, `chat_part/1`, `output_part/1` | 220–607 |
| Status components | `status_badge/1`, `status_dot/1` | 668–720 |
| Queue panel | `queue_panel/1` | 722–776 |
| Container stats | `container_stats_bars/1` | 778–817 |
| Helpers (public) | `format_tool_input/1`, `truncate_output/1`, `format_mem_short/1`, `render_markdown/1` | 821–869 |
| Ticket card | `ticket_card/1` | 871–1246 + private helpers 1248–1483 |
| Label picker | `label_picker/1`, `toggle_label/2` | 1485–1540 |
| Lifecycle timeline | `lifecycle_timeline/1` | 1427–1462 |

### 2.1 — Extract Chat Output Components

- [ ] **RED**: Write test `apps/agents_web/test/live/dashboard/components/chat_output_components_test.exs`
  - Tests: Verify `chat_part/1` renders user, user_pending, answer_submitted, subtask,
    and assistant part variants correctly. Verify `output_part/1` renders text (streaming/frozen),
    reasoning (streaming/frozen), tool cards (5-tuple, legacy 4-tuple, 3-tuple), and fallback.
    Verify `queued_message/1` renders with pending/rolled_back status.
  - These tests can be adapted from existing `session_components_test.exs` patterns.

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/components/chat_output_components.ex`
  - Module: `AgentsWeb.DashboardLive.Components.ChatOutputComponents`
  - `use Phoenix.Component`, `import AgentsWeb.CoreComponents`
  - Move: `chat_part/1` (all clauses), `output_part/1` (all clauses), `queued_message/1`,
    `progress_bar/1`, `compact_progress_bar/1`
  - Move private helpers: `tool_icon/1`, `tool_icon_name/1`, `completed_count/1`,
    `display_position/1`, `status_class/1`, `segment_bg/1`, `tooltip_colors/1`,
    `tooltip_status_text/1`, `tooltip_arrow/1`, `format_status/1`,
    `queued_message_label/1`, `queued_message_badge/1`, `queued_message_status_text/1`
  - Move public helpers: `render_markdown/1`, `format_tool_input/1`, `truncate_output/1`,
    `format_mem_short/1`

- [ ] **REFACTOR**: Clean up, ensure no duplicate code between old and new modules.

### 2.2 — Extract Ticket Card Component

- [ ] **RED**: Write test `apps/agents_web/test/live/dashboard/components/ticket_card_component_test.exs`
  - Tests: Verify `ticket_card/1` renders correctly for each variant
    (`:triage`, `:triage_session`, `:queued`, `:warm`, `:in_progress`, `:failed`, `:optimistic`).
    Verify data attributes, status dots, action strips, and card styling.

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/components/ticket_card_component.ex`
  - Module: `AgentsWeb.DashboardLive.Components.TicketCardComponent`
  - `use Phoenix.Component`, `import AgentsWeb.CoreComponents`
  - Move: `ticket_card/1` and all its private helpers (`normalize_session/1`,
    `card_test_id/3`, `card_click_event/1`, `card_title/2`, `short_container_id/1`,
    `card_status/2`, `ticket_closed?/1`, `blocked_data_attr/1`, `duration_timer_id/3`,
    `slot_state/2`, `ticket_card_classes/8`, `status_color_classes/1`, `variant_classes/6`,
    `lifecycle_stage_badge_class/1`, `ticket_card_cold?/4`, `has_real_container?/1`,
    `compute_file_stats/1`, `ticket_data_id/1`)
  - Import from Helpers: `ticket_label_class/1`, `format_file_stats/1`, `image_label/1`,
    `relative_time/1`, `slugify/1`, `truncate_instruction/2`, `auth_error?/1`,
    `auth_refreshing?/2`, `session_todo_items/1`
  - Also move `label_picker/1`, `toggle_label/2`, `lifecycle_timeline/1` into this module
    (they are ticket-related display components)
  - Import `status_badge/1`, `status_dot/1`, `compact_progress_bar/1`, `container_stats_bars/1`
    from `ChatOutputComponents` (or keep in a shared status module)

- [ ] **REFACTOR**: Ensure clean imports, no circular dependencies.

### 2.3 — Extract Status and Queue Components

- [ ] **RED**: Verify existing tests in `session_components_test.exs` and `progress_bar_test.exs`
  still pass when `status_badge/1`, `status_dot/1`, `queue_panel/1`, `container_stats_bars/1`
  are referenced from new module paths.

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/components/status_components.ex`
  - Module: `AgentsWeb.DashboardLive.Components.StatusComponents`
  - `use Phoenix.Component`, `import AgentsWeb.CoreComponents`
  - Move: `status_badge/1`, `status_dot/1`, `queue_panel/1`, `container_stats_bars/1`,
    `tab_bar/1`, `question_card/1`
  - Move private: `format_badge_label/1`
  - Import `render_markdown/1` from `ChatOutputComponents` (for question_card)

- [ ] **REFACTOR**: Clean up.

### 2.4 — Update `session_components.ex` as Delegation Hub

- [ ] **GREEN**: Rewrite `apps/agents_web/lib/live/dashboard/components/session_components.ex`
  to become a thin delegation module:
  ```elixir
  defmodule AgentsWeb.DashboardLive.Components.SessionComponents do
    @moduledoc """
    Re-exports all dashboard component functions for backward compatibility.
    
    Callers that `import AgentsWeb.DashboardLive.Components.SessionComponents`
    get access to all component functions without needing to know which
    sub-module defines them.
    """
    
    # Re-export all component functions
    defdelegate tab_bar(assigns), to: AgentsWeb.DashboardLive.Components.StatusComponents
    defdelegate question_card(assigns), to: AgentsWeb.DashboardLive.Components.StatusComponents
    defdelegate status_badge(assigns), to: AgentsWeb.DashboardLive.Components.StatusComponents
    defdelegate status_dot(assigns), to: AgentsWeb.DashboardLive.Components.StatusComponents
    defdelegate queue_panel(assigns), to: AgentsWeb.DashboardLive.Components.StatusComponents
    defdelegate container_stats_bars(assigns), to: AgentsWeb.DashboardLive.Components.StatusComponents
    
    defdelegate chat_part(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    defdelegate output_part(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    defdelegate queued_message(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    defdelegate progress_bar(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    defdelegate compact_progress_bar(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    defdelegate render_markdown(text), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    defdelegate format_tool_input(input), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    defdelegate truncate_output(text), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    defdelegate format_mem_short(bytes), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
    
    defdelegate ticket_card(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent
    defdelegate label_picker(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent
    defdelegate toggle_label(labels, label), to: AgentsWeb.DashboardLive.Components.TicketCardComponent
    defdelegate lifecycle_timeline(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent
  end
  ```

- [ ] **REFACTOR**: Verify all existing callers work through delegation without changes.

### Phase 2 Validation
- [ ] All 477 tests pass
- [ ] `session_components_test.exs` passes unchanged
- [ ] `progress_bar_test.exs` passes unchanged
- [ ] `index.ex` import statement unchanged: `import AgentsWeb.DashboardLive.Components.SessionComponents`
- [ ] No boundary violations (`mix boundary`)
- [ ] Full test suite passes (`mix test apps/agents_web/`)

---

## Phase 3: Split `session_data_helpers.ex` into Focused Helper Modules ⏸

**Risk**: Medium — 9 modules import this file. The backward-compatible delegation
strategy must be bulletproof.

**Goal**: Split the 1,393-line module into 5 focused helper modules. The original
module becomes a delegation hub so the 9 importing modules require zero changes.

### Current Function Groupings (by domain)

| Group | Approx Lines | Function Count | Description |
|-------|-------------|----------------|-------------|
| Session/Tab Resolution | ~100 | 8 | `session_tabs/0`, `resolve_active_tab/2`, `resolve_selected_container_id/2`, `default_container_id/1`, `resolve_current_task/2`, `resolve_active_ticket_number/5`, `parse_ticket_number_param/1`, `ensure_ticket_reference/3` |
| Task Execution | ~150 | 10 | `run_or_resume_task/4`, `handle_task_result/2`, `do_cancel_task/3`, `perform_cancel_task/2`, `fetch_cancelled_task/2`, `recover_instruction/2`, `route_message_submission/5`, `send_message_to_running_task/2`, `clear_form/1`, `prefill_form/2` |
| Session State | ~300 | 18 | `assign_session_state/1`, `upsert_session_from_task/2`, `build_session_from_task/3`, `drop_default_fields/2`, `derive_container_id/2`, `split_matching_sessions/3`, `matches_container?/2`, `sort_sessions_for_sidebar/1`, `running_session?/1`, `latest_at_unix/1`, `merge_unassigned_active_tasks/2`, `has_real_container?/1`, `hydrate_task_for_session/2`, `resolve_new_task_ack_task/3`, `find_task_by_instruction/2`, `subscribe_to_active_tasks/1`, `update_session_todo_items/3`, `update_session_lifecycle_state/2` |
| Optimistic Queue | ~250 | 15 | `normalize_hydrated_queue_entry/1`, `parse_hydrated_datetime/1`, `normalize_hydrated_new_session_entry/1`, `merge_optimistic_new_sessions/2`, `remove_optimistic_new_session/2`, `stale_optimistic_entry?/1`, `already_has_real_session?/2`, `merge_queued_messages/2`, `broadcast_optimistic_queue_snapshot/1`, `clear_optimistic_queue_snapshot/2`, `maybe_sync_optimistic_queue_snapshot/2`, `serialize_queued_messages/1`, `serialize_optimistic_new_sessions/1`, `serialize_queued_datetime/1`, `broadcast_optimistic_new_sessions_snapshot/1`, `clear_new_task_monitor/2`, `maybe_flash_new_task_down/2`, `normalize_ordered_ticket_numbers/1` |
| Ticket Management | ~300 | 25+ | `reload_tickets/1`, `apply_ticket_closed/2`, `resolve_container_for_ticket/2`, `resolve_container_from_task_id/2`, `map_ticket_tree/2`, `all_tickets/1`, `find_ticket_by_number/2`, `maybe_revert_optimistic_ticket/2`, `update_ticket_lifecycle_assigns/4`, `update_ticket_by_number/3`, `lifecycle_ticket_match?/2`, `find_parent_ticket/2`, `upsert_task_snapshot/2`, `remove_tasks_for_container/2`, `maybe_delete_session/2`, `maybe_remove_tasks/2`, `maybe_reject_session/2`, `tab_after_ticket_close/2`, `maybe_clear_active_session/2`, `update_task_lifecycle_state/3`, `lifecycle_state_to_string/1`, `lifecycle_state_for_task_status/2`, `find_ticket_number_for_container/2`, `find_ticket_number_for_selected_session/3`, `extract_ticket_number_from_session/3`, `next_active_ticket_number/2`, `ticket_owns_current_task?/2` |
| Question/UI Interaction | ~80 | 8 | `toggle_selection/3`, `build_question_answers/1`, `format_question_answer_as_message/2`, `submit_rejected_question/3`, `submit_active_question/3`, `handle_question_result_basic/4`, `append_optimistic_user_message/2`, `append_answer_submitted_message/2`, `append_optimistic_part/3`, `remove_answer_submitted_part/2` |
| Queue/Warm | ~100 | 4 | `load_queue_state/1`, `default_queue_state/0`, `derive_sticky_warm_task_ids/3`, `resolve_changed_task/5`, `apply_status_change_to_ui/4`, `maybe_sync_status_from_session_event/3`, `request_task_refresh/2` |

### 3.1 — Extract Optimistic Queue Helpers

- [ ] **RED**: Write test `apps/agents_web/test/live/dashboard/optimistic_queue_helpers_test.exs`
  - Tests: Pure function tests for `normalize_hydrated_queue_entry/1`,
    `merge_queued_messages/2`, `merge_optimistic_new_sessions/2`,
    `stale_optimistic_entry?/1`, `already_has_real_session?/2`,
    `serialize_queued_messages/1`, `normalize_ordered_ticket_numbers/1`

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/helpers/optimistic_queue_helpers.ex`
  - Module: `AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers`
  - Move all optimistic queue functions listed above

- [ ] **REFACTOR**: Clean up.

### 3.2 — Extract Ticket Data Helpers

- [ ] **RED**: Write test `apps/agents_web/test/live/dashboard/ticket_data_helpers_test.exs`
  - Tests: Pure function tests for `map_ticket_tree/2`, `all_tickets/1`,
    `find_ticket_by_number/2`, `update_ticket_by_number/3`, `find_parent_ticket/2`,
    `next_active_ticket_number/2`, `lifecycle_ticket_match?/2`,
    `ticket_owns_current_task?/2`, `ensure_ticket_reference/3`

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/helpers/ticket_data_helpers.ex`
  - Module: `AgentsWeb.DashboardLive.Helpers.TicketDataHelpers`
  - Move all ticket management functions listed above

- [ ] **REFACTOR**: Clean up.

### 3.3 — Extract Session State Helpers

- [ ] **RED**: Write test `apps/agents_web/test/live/dashboard/session_state_helpers_test.exs`
  - Tests: Pure function tests for `build_session_from_task/3`, `derive_container_id/2`,
    `split_matching_sessions/3`, `matches_container?/2`, `sort_sessions_for_sidebar/1`,
    `running_session?/1`, `latest_at_unix/1`, `has_real_container?/1`,
    `drop_default_fields/2`

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/helpers/session_state_helpers.ex`
  - Module: `AgentsWeb.DashboardLive.Helpers.SessionStateHelpers`
  - Move all session state functions listed above

- [ ] **REFACTOR**: Clean up.

### 3.4 — Extract Task Execution Helpers

- [ ] **RED**: Verify existing tests in `index_test.exs` that exercise `run_or_resume_task`,
  `handle_task_result`, `do_cancel_task` continue to pass.

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/helpers/task_execution_helpers.ex`
  - Module: `AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers`
  - Move task execution functions and question/UI interaction functions

- [ ] **REFACTOR**: Clean up.

### 3.5 — Update `session_data_helpers.ex` as Delegation Hub

- [ ] **GREEN**: Rewrite `apps/agents_web/lib/live/dashboard/session_data_helpers.ex` to
  delegate all public functions to the new sub-modules. Use `defdelegate` for each function.
  This ensures the 9 modules that `import AgentsWeb.DashboardLive.SessionDataHelpers`
  continue to work without any changes.

  **Important**: Functions like `run_or_resume_task/4` that import Phoenix helpers
  (`assign/2`, `push_event/3`, etc.) need those imports in the new module.
  The delegation hub only delegates — it doesn't need those imports.

- [ ] **REFACTOR**: Verify the delegation hub is under ~100 lines.

### Phase 3 Validation
- [ ] All 477 tests pass
- [ ] All 9 importing modules compile without changes
- [ ] `helpers_test.exs` passes unchanged
- [ ] No boundary violations
- [ ] Full test suite passes (`mix test apps/agents_web/`)

---

## Phase 4: Split `index_test.exs` into Focused Test Files ⏸

**Risk**: Medium — must split carefully to avoid losing test isolation.

**Goal**: Split the 4,538-line test file into 7 focused test files, one per
logical test grouping. Each file uses the shared test helpers from Phase 1.

### Current describe blocks → Target files

| # | Describe Block | Tests | Target File |
|---|---------------|-------|-------------|
| 1 | "mount and rendering" | 9 | `index_mount_test.exs` |
| 2 | "form submission" | 20 | `index_form_submission_test.exs` |
| 3 | "real-time PubSub events" | 20 | `index_pubsub_test.exs` |
| 4 | "queue_snapshot v2 handling" | 2 | `index_queue_test.exs` |
| 5 | "container_stats_updated handler" | 1 | `index_queue_test.exs` |
| 6 | "session management" | 33 | `index_session_management_test.exs` |
| 7 | "restart session button" | 3 | `index_session_management_test.exs` |
| 8 | "close ticket" | 3 | `index_ticket_lifecycle_test.exs` |
| 9 | "start ticket session" | 7 | `index_ticket_lifecycle_test.exs` |
| 10 | "ticket card real-time session state updates" | 2 | `index_ticket_lifecycle_test.exs` |
| 11 | "ticket-centric build lane lifecycle" | 9 | `index_ticket_lifecycle_test.exs` |
| 12 | "session search and filtering" | 11 | `index_search_filter_test.exs` |
| 13 | "ticket hierarchy rendering" | 2 | `index_ticket_lifecycle_test.exs` |
| 14 | "session card duration and file stats rendering" | 8 | `index_session_management_test.exs` |
| — | "pause restores instruction to chat input" | 4 | `index_session_management_test.exs` |
| — | "ticket context propagation in run_task" | 1 | `index_form_submission_test.exs` |
| — | "ensure_ticket_reference edge cases in run_task" | 2 | `index_form_submission_test.exs` |
| — | "run_task with ticket_number for unrelated active session" | 1 | `index_form_submission_test.exs` |
| — | "ticket label picker" | 2 | `index_ticket_lifecycle_test.exs` |

### 4.1 — Create split test files

For each target file below, the pattern is:

```elixir
defmodule AgentsWeb.DashboardLive.Index<Topic>Test do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures
  import AgentsWeb.DashboardTestHelpers, only: [send_queue_state: 3]

  alias AgentsWeb.DashboardTestHelpers.FakeTaskRunner
  # ... other aliases as needed per file
end
```

- [ ] **RED**: Create empty test files that will fail because they have no tests yet.

- [ ] **GREEN**: Move tests from `index_test.exs` into the new files:

  - [ ] `apps/agents_web/test/live/dashboard/index_mount_test.exs`
    — "mount and rendering" (9 tests)

  - [ ] `apps/agents_web/test/live/dashboard/index_form_submission_test.exs`
    — "form submission" (20 tests)
    — "ticket context propagation in run_task" (1 test)
    — "ensure_ticket_reference edge cases in run_task" (2 tests)
    — "run_task with ticket_number for unrelated active session" (1 test)
    — Total: 24 tests

  - [ ] `apps/agents_web/test/live/dashboard/index_pubsub_test.exs`
    — "real-time PubSub events" (20 tests)

  - [ ] `apps/agents_web/test/live/dashboard/index_queue_test.exs`
    — "queue_snapshot v2 handling" (2 tests)
    — "container_stats_updated handler" (1 test, including `LabelTestGithubClient` if needed)
    — Total: 3 tests

  - [ ] `apps/agents_web/test/live/dashboard/index_session_management_test.exs`
    — "session management" (33 tests)
    — "restart session button" (3 tests)
    — "session card duration and file stats rendering" (8 tests)
    — "pause restores instruction to chat input" (4 tests)
    — Total: 48 tests

  - [ ] `apps/agents_web/test/live/dashboard/index_ticket_lifecycle_test.exs`
    — "close ticket" (3 tests)
    — "start ticket session" (7 tests)
    — "ticket card real-time session state updates" (2 tests — was 4, 2 per block)
    — "ticket-centric build lane lifecycle" (9 tests)
    — "ticket hierarchy rendering" (2 tests)
    — "ticket label picker" (2 tests, including `LabelTestGithubClient`)
    — Total: 25 tests

  - [ ] `apps/agents_web/test/live/dashboard/index_search_filter_test.exs`
    — "session search and filtering" (11 tests)

- [ ] **REFACTOR**: Remove all moved tests from `index_test.exs`. The original file
  should be **empty/deleted** after this phase. All tests now live in focused files.

  **Note**: The `LabelTestGithubClient` defmodule in `index_test.exs` (lines 4455–4474)
  must move to the file that contains the label picker tests (`index_ticket_lifecycle_test.exs`).

  **Note**: The `task_with_timestamps/2` defp helper (lines 4195–4201) must move to the
  file that contains the duration/file stats tests (`index_session_management_test.exs`).

### Phase 4 Validation
- [ ] Test count is preserved: sum of all new files = original 141 tests
- [ ] All tests pass: `mix test apps/agents_web/test/live/dashboard/`
- [ ] No duplicate test modules or test names
- [ ] Original `index_test.exs` is deleted
- [ ] Full test suite passes (`mix test apps/agents_web/`)

---

## Phase 5: Extract Template into Function Components ⏸

**Risk**: Medium-high — template changes affect rendering. Must be done carefully
with tests verifying each extraction.

**Goal**: Split the 1,384-line `index.html.heex` into focused template sections
using function components with embedded HEEx, reducing the template to ~200 lines
of component calls.

### Current Template Structure

| Section | Lines | Description |
|---------|-------|-------------|
| Layout + left panel open | 1–4 | Outer layout wrapper |
| Sidebar header (new ticket form, auth refresh) | 5–34 | Top of left panel |
| Empty state | 37–42 | No sessions fallback |
| Search/filter controls | 43–175 | Search input + status filter pills |
| Template-local computations | 176–368 | ~190 lines of inline EEx logic |
| Triage column | 370–532 | Left column with idle tickets |
| Build column | 534–699 | Right column with active sessions |
| Queue panel | 704–709 | Bottom of left panel |
| Right panel header | 719–813 | Session detail header bar |
| Tab bar | 815–819 | Tab switching |
| Chat tab | 821–986 | Output log, stats, alerts |
| Ticket tab | 988–1275 | Ticket detail panel |
| Input form | 1277–1368 | Bottom input area |
| Empty right panel | 1369–1381 | No session selected |
| Close | 1382–1384 | Layout close |

### 5.1 — Extract Left Panel Sidebar Component

- [ ] **RED**: Verify all sidebar-related tests pass before extraction. Count tests
  that assert sidebar elements (search, filter, session list, ticket cards).

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/components/sidebar_components.ex`
  - Module: `AgentsWeb.DashboardLive.Components.SidebarComponents`
  - `use Phoenix.Component`, `import AgentsWeb.CoreComponents`
  - Extract function components:
    - `sidebar_header/1` — new ticket form + auth refresh button (lines 5–34)
    - `search_and_filter/1` — search input + status filter pills (lines 57–175)
    - `triage_column/1` — triage lane with ticket list (lines 371–532)
    - `build_column/1` — build lane with session cards (lines 534–699)
  - These components receive assigns as attrs and render the corresponding HEEx.
  - The inline EEx computations (lines 44–368) move into the component functions
    as assigns preparation logic.

- [ ] **REFACTOR**: Update `index.html.heex` to call the new components instead of
  inlining the markup. The template should shrink to component calls:
  ```heex
  <.sidebar_header sessions={@sessions} auth_refreshing={@auth_refreshing} syncing_tickets={@syncing_tickets} />
  <.search_and_filter session_search={@session_search} status_filter={@status_filter} />
  <.triage_column tickets={...} sessions={...} ... />
  <.build_column tickets={...} sessions={...} queue_state={@queue_state} ... />
  ```

### 5.2 — Extract Right Panel Detail Components

- [ ] **RED**: Verify all right-panel tests pass before extraction. Count tests that
  assert detail header, chat log, ticket detail, input form elements.

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/components/detail_panel_components.ex`
  - Module: `AgentsWeb.DashboardLive.Components.DetailPanelComponents`
  - `use Phoenix.Component`, `import AgentsWeb.CoreComponents`
  - Extract function components:
    - `session_detail_header/1` — header bar with status badge, lifecycle state, title,
      docker image, delete/cancel buttons (lines 720–813)
    - `chat_tab_panel/1` — stats bar, error/cancelled alerts, output log, queued messages,
      question card (lines 821–986)
    - `ticket_tab_panel/1` — ticket detail with body, labels, sub-issues, dependencies,
      lifecycle timeline (lines 988–1275)
    - `session_input_form/1` — image picker + instruction textarea + submit/cancel buttons
      (lines 1277–1368)

- [ ] **REFACTOR**: Update `index.html.heex` to call the new components. The right panel
  section should become:
  ```heex
  <.session_detail_header current_task={@current_task} ... />
  <.tab_bar active_tab={@active_session_tab} tabs={detail_tabs} />
  <.chat_tab_panel :if={@active_session_tab == "chat"} ... />
  <.ticket_tab_panel :if={@active_session_tab == "ticket"} ... />
  <.session_input_form ... />
  ```

### 5.3 — Final Template Cleanup

- [ ] **REFACTOR**: The final `index.html.heex` should be ~150-250 lines:
  - Layout wrapper
  - Left panel: sidebar_header, empty state check, search/filter, triage/build columns, queue panel
  - Right panel: session_detail_header, tab_bar, chat/ticket panels, input form, empty state
  - All inline EEx computations moved into component functions

### Phase 5 Validation
- [ ] All 477 tests pass
- [ ] `index.html.heex` is under 300 lines
- [ ] All extracted components follow Phoenix function component conventions
- [ ] No boundary violations
- [ ] Full test suite passes (`mix test apps/agents_web/`)

---

## Phase 6: Import Cleanup and Direct Imports ⏸

**Risk**: Low — now that everything is extracted, update imports to use direct
module references instead of going through delegation hubs.

**Goal**: Optionally update callers to import directly from the new focused modules
rather than through the delegation hubs. This makes the dependency graph explicit.

### 6.1 — Update `index.ex` imports

- [ ] **GREEN**: Update `apps/agents_web/lib/live/dashboard/index.ex`:
  - Replace `import AgentsWeb.DashboardLive.Components.SessionComponents` with
    direct imports from the 3 new component modules
  - Replace `import AgentsWeb.DashboardLive.SessionDataHelpers` with direct imports
    from the 4 new helper modules (only import what's actually used in index.ex)

- [ ] **REFACTOR**: Clean up unused imports.

### 6.2 — Update handler modules (optional — can be deferred)

- [ ] **GREEN**: For each of the 8 handler modules that import `SessionDataHelpers`,
  update to import directly from the focused helper module:
  - `ticket_handlers.ex` → mostly ticket_data_helpers + task_execution_helpers
  - `task_execution_handlers.ex` → task_execution_helpers + session_state_helpers
  - `session_handlers.ex` → session_state_helpers + optimistic_queue_helpers
  - `question_handlers.ex` → task_execution_helpers (question-related)
  - `pub_sub_handlers.ex` → session_state_helpers + ticket_data_helpers
  - `follow_up_dispatch_handlers.ex` → optimistic_queue_helpers
  - `dependency_handlers.ex` → ticket_data_helpers
  - `ticket_session_linker.ex` → already selective import, update target

- [ ] **REFACTOR**: Remove the delegation hubs if all callers have been updated.
  **Note**: This step is optional — the delegation hubs can remain indefinitely
  for backward compatibility with no performance cost.

### Phase 6 Validation
- [ ] All 477 tests pass
- [ ] Imports are explicit and minimal
- [ ] No unused imports
- [ ] No boundary violations
- [ ] Full test suite passes (`mix test apps/agents_web/`)

---

## Pre-Commit Checkpoint

After all phases are complete:

- [ ] `mix precommit` passes
- [ ] `mix boundary` shows no violations
- [ ] `mix test apps/agents_web/` — all 477 tests pass (2 pre-existing failures allowed)
- [ ] No production behaviour changes

---

## Testing Strategy

- **Total estimated tests**: 477 (unchanged — this is a refactor)
- **New test files**: 7 split test files from `index_test.exs` + 1 shared helper module
- **New component test files**: 2-3 unit tests for extracted components (optional, as existing
  integration tests in the split files already cover rendering)
- **Distribution**: All tests are interface layer (LiveView ConnCase)
- **Key invariant**: Every phase produces a green test suite

## File Summary

### New files created:

| Phase | File | Purpose |
|-------|------|---------|
| 1 | `test/support/dashboard_test_helpers.ex` | Shared FakeTaskRunner + send_queue_state |
| 2 | `lib/live/dashboard/components/chat_output_components.ex` | Chat parts, output parts, progress bars, markdown |
| 2 | `lib/live/dashboard/components/ticket_card_component.ex` | Ticket card, label picker, lifecycle timeline |
| 2 | `lib/live/dashboard/components/status_components.ex` | Status badge/dot, tab bar, queue panel, question card |
| 3 | `lib/live/dashboard/helpers/optimistic_queue_helpers.ex` | Optimistic queue state management |
| 3 | `lib/live/dashboard/helpers/ticket_data_helpers.ex` | Ticket tree operations, lookups |
| 3 | `lib/live/dashboard/helpers/session_state_helpers.ex` | Session state derivation, sorting |
| 3 | `lib/live/dashboard/helpers/task_execution_helpers.ex` | Task create/resume/cancel, question handling |
| 4 | `test/live/dashboard/index_mount_test.exs` | Mount and rendering tests (9) |
| 4 | `test/live/dashboard/index_form_submission_test.exs` | Form submission tests (24) |
| 4 | `test/live/dashboard/index_pubsub_test.exs` | PubSub event tests (20) |
| 4 | `test/live/dashboard/index_queue_test.exs` | Queue + container stats tests (3) |
| 4 | `test/live/dashboard/index_session_management_test.exs` | Session mgmt + restart + duration (48) |
| 4 | `test/live/dashboard/index_ticket_lifecycle_test.exs` | Ticket close/start/lifecycle (25) |
| 4 | `test/live/dashboard/index_search_filter_test.exs` | Search and filter tests (11) |
| 5 | `lib/live/dashboard/components/sidebar_components.ex` | Left panel template components |
| 5 | `lib/live/dashboard/components/detail_panel_components.ex` | Right panel template components |

### Files modified:

| Phase | File | Change |
|-------|------|--------|
| 1 | `test/live/dashboard/index_test.exs` | Remove FakeTaskRunner + send_queue_state, add imports |
| 2 | `lib/live/dashboard/components/session_components.ex` | Becomes delegation hub (~80 lines) |
| 3 | `lib/live/dashboard/session_data_helpers.ex` | Becomes delegation hub (~120 lines) |
| 4 | `test/live/dashboard/index_test.exs` | Deleted (all tests moved to split files) |
| 5 | `lib/live/dashboard/index.html.heex` | Reduced from 1,384 to ~200-300 lines |
| 6 | `lib/live/dashboard/index.ex` | Updated imports (optional) |
| 6 | `lib/live/dashboard/*.ex` (8 handlers) | Updated imports (optional) |

### Files deleted:

| Phase | File |
|-------|------|
| 4 | `test/live/dashboard/index_test.exs` (replaced by 7 focused files) |

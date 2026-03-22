# Ticket #505: Pipeline Kanban Row UI Architectural Plan

## App Ownership

- Owning app: `agents`
- Owning Repo: `Agents.Repo`
- Domain path: `apps/agents/lib/agents/pipeline/`
- Web path: `apps/agents_web/lib/live/dashboard/`
- Migration path: `apps/agents/priv/repo/migrations/`
- Tests path: `apps/agents/test/agents/pipeline/` and `apps/agents_web/test/live/dashboard/`

## Scope

Replace the dashboard build sidebar column with a bottom-of-screen pipeline kanban row that groups ticket work by stage, supports collapsible and accordion interactions, and updates live when pipeline stage events arrive.

## Current Baseline

- The sessions dashboard currently renders a split left sidebar with `triage_column/1` and `build_column/1` from `apps/agents_web/lib/live/dashboard/components/sidebar_components.ex`.
- The dashboard already has event-handler modules (`TicketHandlers`, `SessionHandlers`, `PubSubHandlers`) and fixture-driven visual states through `AgentsWeb.DashboardLive.TicketLifecycleFixtures`.
- Ticket lifecycle stages already exist in the tickets domain (`open`, `ready`, `in_progress`, `in_review`, `ci_testing`, `deployed`, `closed`) and the UI already reacts to `TicketStageChanged` events.
- Pipeline runs already persist `task_id`, `session_id`, `current_stage_id`, `remaining_stage_ids`, and emit `Agents.Pipeline.Domain.Events.PipelineStageChanged`.
- The pipeline repository currently supports `create_run/2`, `get_run/2`, and `update_run/2`, but not list/query operations for dashboard aggregation.

## Ambiguity To Resolve In Code

- The ticket says kanban columns are derived from `perme8-pipeline.yml`, but the current YAML only exposes `warm-pool`, `test`, and `deploy`, while the acceptance language and existing dashboard lifecycle UI use ticket-facing stages such as `open`, `ready`, `in_progress`, `in_review`, `ci_testing`, and `deployed`.
- To keep the implementation minimal and consistent with the existing dashboard, treat the kanban as a ticket-facing view first: derive visible columns from the existing ticket lifecycle stages, and enrich those stages with pipeline-backed activity where available.
- The new `GetPipelineKanban` use case should still consult `perme8-pipeline.yml` so downstream pipeline-backed stages (`ci_testing`, `deployed`) stay aligned with config, but it should not block the UI on the current YAML's narrower stage list.

## Proposed Additions

- New UI components:
  - `AgentsWeb.DashboardLive.Components.PipelineKanbanComponents`
- New event handlers:
  - `AgentsWeb.DashboardLive.PipelineKanbanHandlers`
- New application use case:
  - `Agents.Pipeline.Application.UseCases.GetPipelineKanban`
- Repository extension:
  - `list_active_runs/2` on `PipelineRunRepositoryBehaviour` and `PipelineRunRepository`
- Dashboard assigns/state:
  - `:pipeline_kanban`
  - `:pipeline_kanban_collapsed`
  - `:collapsed_kanban_columns`
- Fixture support for kanban-specific browser states in `TicketLifecycleFixtures`

## Data Shape Recommendation

Return a normalized kanban payload from `GetPipelineKanban`:

- `stages`: ordered list of maps with:
  - `id`
  - `label`
  - `count`
  - `aggregate_status`
  - `tickets`
- `collapsed?`: UI-owned and kept in LiveView assigns, not the use case

Each ticket item should include only dashboard-facing display fields:

- `number`
- `title`
- `stage_id`
- `status`
- `task_id`
- `session_id`
- `container_id`

## RED / GREEN / REFACTOR Plan

### Phase 1: Query and aggregation baseline

- [ ] RED: add use-case tests for grouping active ticket work into ordered kanban stages
- [ ] RED: add repository tests for listing active pipeline runs without returning terminal runs
- [ ] GREEN: extend `PipelineRunRepositoryBehaviour` and `PipelineRunRepository` with `list_active_runs/2`
- [ ] GREEN: implement `GetPipelineKanban` to normalize active ticket work into stage buckets
- [ ] REFACTOR: isolate stage-label/order mapping in private helpers so UI modules stay presentation-only

### Phase 2: Dashboard state and handlers

- [ ] RED: add LiveView tests proving the build column is gone, the triage panel spans the full left column, and the kanban row renders at the bottom
- [ ] RED: add handler tests for collapse/expand, per-column accordion toggles, and selecting a kanban ticket
- [ ] GREEN: add `PipelineKanbanHandlers` and route new `handle_event/3` clauses from `Index`
- [ ] GREEN: initialize kanban assigns during `mount/3` and refresh them during `handle_params/3` and data reload points
- [ ] REFACTOR: keep ticket-selection behavior delegated to existing ticket/session selection logic rather than duplicating navigation rules

### Phase 3: Component extraction and layout rewrite

- [ ] RED: add component/LiveView assertions for column headers, count badges, aggregate status, and accordion rollups
- [ ] GREEN: create `PipelineKanbanComponents` with `pipeline_kanban/1`, `kanban_column/1`, `kanban_ticket_card/1`, and `kanban_status_bar/1`
- [ ] GREEN: remove `build_column/1` from `SidebarComponents` and update `index.html.heex` to render triage full-width plus a bottom kanban row
- [ ] GREEN: ensure clicking a kanban ticket delegates to the existing ticket selection patch flow
- [ ] REFACTOR: centralize shared CSS/test ids in the new component module so the template stays small

### Phase 4: Live updates and fixture coverage

- [ ] RED: add LiveView tests proving `PipelineStageChanged` moves a ticket between kanban columns without reload
- [ ] RED: add fixture-driven tests for collapsed status bar and accordion-expanded columns
- [ ] GREEN: subscribe the dashboard to pipeline stage-change events and refresh/update kanban assigns when they arrive
- [ ] GREEN: extend `TicketLifecycleFixtures` with kanban-specific fixture states used by the browser feature file and local previews
- [ ] REFACTOR: keep PubSub update logic thin by funneling stage-change messages through a single kanban refresh helper

## Testing Strategy

- Add focused use-case tests for `GetPipelineKanban` using in-memory fake tickets/runs and a stub pipeline parser.
- Extend pipeline repository tests to cover active-run listing semantics.
- Add LiveView tests around `AgentsWeb.DashboardLive.Index` for:
  - build column removal
  - bottom kanban rendering
  - accordion rollups
  - collapsed status bar
  - ticket click -> selection/navigation
  - live movement after stage-change messages
- Keep browser feature coverage fixture-driven through `?fixture=pipeline_kanban_*` states.

## Suggested Implementation Order

1. Add repository listing support and `GetPipelineKanban`
2. Add dashboard assigns/helpers and new handler module
3. Extract and render the new kanban components
4. Wire live updates and kanban fixtures
5. Run targeted `agents` and `agents_web` tests, then broader regression checks

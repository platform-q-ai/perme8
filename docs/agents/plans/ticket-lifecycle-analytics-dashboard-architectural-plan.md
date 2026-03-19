# Feature: Ticket Lifecycle Analytics Dashboard

**Ticket**: #496 — Build an analytics dashboard for agents which appears in the sidebar  
**Status**: ⏸ Not Started  
**Owning App**: `agents` (domain) / `agents_web` (interface)

---

## App Ownership

| Artifact | App | Path |
|----------|-----|------|
| **Repo** | `agents` | `Agents.Repo` |
| **Migrations** | `agents` | `apps/agents/priv/repo/migrations/` |
| **Domain entities** | `agents` | `apps/agents/lib/agents/tickets/domain/entities/` |
| **Domain policies** | `agents` | `apps/agents/lib/agents/tickets/domain/policies/` |
| **Use cases** | `agents` | `apps/agents/lib/agents/tickets/application/use_cases/` |
| **Infrastructure queries** | `agents` | `apps/agents/lib/agents/tickets/infrastructure/queries/` |
| **Infrastructure repositories** | `agents` | `apps/agents/lib/agents/tickets/infrastructure/repositories/` |
| **Public facade** | `agents` | `apps/agents/lib/agents/tickets.ex` |
| **LiveViews** | `agents_web` | `apps/agents_web/lib/live/analytics/` |
| **Components** | `agents_web` | `apps/agents_web/lib/live/analytics/components/` |
| **Feature files (browser)** | `agents_web` | `apps/agents_web/test/features/analytics/` |
| **Feature files (security)** | `agents_web` | `apps/agents_web/test/features/analytics/` |

---

## Overview

Build a full-page analytics dashboard accessible from the agents_web sidebar that visualises ticket lifecycle event data. The dashboard displays:

1. **Summary counter cards** — total tickets, open tickets, average cycle time, tickets completed in period
2. **Stage distribution bar chart** — SVG bar chart showing ticket counts per lifecycle stage
3. **Throughput trend chart** — SVG line chart showing stage entries over time
4. **Cycle time trend chart** — SVG line chart showing average stage durations over time
5. **Time granularity toggle** — Daily / Weekly / Monthly bucketing
6. **Date range filter** — start/end date inputs constraining all metrics
7. **Real-time updates** — TicketStageChanged events update distribution + counters live
8. **Empty states** — meaningful messaging when no data exists

## Key Design Decisions

### 1. Charting Approach: Server-Rendered SVG
All charts are pure HEEx SVG rendered server-side. No JavaScript charting library needed.

**Justification**: The chart types are simple (bar chart, line charts). Server-rendered SVG:
- Aligns with LiveView's server-side rendering philosophy
- Requires no new JS dependencies
- Updates in real-time via LiveView patches
- Is DaisyUI-theme-aware via CSS custom properties
- Is fully testable via LiveView test assertions on `data-testid` attributes

### 2. Workspace Scoping: Deferred (All Tickets)
The current data model has **no workspace_id on project tickets**. Tickets are synced from a single GitHub repo and scoped globally. The existing dashboard (`DashboardLive.Index`) loads all tickets via `ProjectTicketRepository.list_all()` without workspace filtering.

**Decision**: The analytics dashboard will follow the same pattern — show analytics for **all tickets** in the system. This matches current reality: there is one set of tickets for the platform.

**Future**: When workspace scoping is added to tickets (a separate ticket), the analytics queries will add a WHERE clause. The query module is designed to accept optional filters to make this straightforward.

### 3. Data Aggregation: On-the-fly Queries
All metrics are computed from the raw `sessions_ticket_lifecycle_events` table using Ecto aggregation queries. No rollup tables, no materialized views.

### 4. New Context: No
This feature extends the existing `Agents.Tickets` bounded context. Analytics are a read concern over existing ticket lifecycle data — not a separate domain concept.

## UI Strategy
- **LiveView coverage**: 100%
- **TypeScript needed**: None. All charts are server-rendered SVG. Date inputs use native HTML5 `<input type="date">`. Granularity toggle uses standard LiveView events.

## Affected Boundaries
- **Owning app**: `agents` (domain logic) + `agents_web` (UI)
- **Repo**: `Agents.Repo`
- **Migrations**: None needed (all data exists in `sessions_ticket_lifecycle_events` and `sessions_project_tickets`)
- **Feature files**: `apps/agents_web/test/features/analytics/`
- **Primary context**: `Agents.Tickets`
- **Dependencies**: None (all data is within the Tickets context)
- **Exported schemas**: None new
- **New context needed?**: No — analytics are a read view over existing Tickets data

---

## Phase 1: Domain + Application (phoenix-tdd)

### 1.1 AnalyticsPolicy — Pure Aggregation Logic

This policy contains pure functions for computing analytics metrics from raw data. No I/O, no Repo.

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/policies/analytics_policy_test.exs`
  - Tests:
    - `count_by_stage/1` — given a list of tickets with lifecycle_stage, returns a map of stage → count
    - `summarize/3` — given tickets and events within a date range, returns summary map: `%{total: int, open: int, avg_cycle_time_seconds: int | nil, completed: int}`
    - `avg_cycle_time_seconds/1` — given lifecycle events grouped by ticket, computes average open→closed time (nil when no closed tickets)
    - `completed_in_range/2` — counts tickets that entered "closed" stage within the date range
    - `bucket_transitions/3` — groups lifecycle events into time buckets (daily/weekly/monthly) for throughput chart, returns `[%{bucket: Date.t(), stage: String.t(), count: integer()}]`
    - `bucket_cycle_times/3` — groups lifecycle events into time buckets for cycle time chart, returns `[%{bucket: Date.t(), stage: String.t(), avg_seconds: float()}]`
    - `time_buckets/3` — generates a list of bucket start dates between start_date and end_date at given granularity
    - `bucket_key/2` — returns the bucket start date for a given datetime at given granularity (`:daily` → date, `:weekly` → Monday of that week, `:monthly` → first of month)
    - Edge cases: empty events list returns empty results; single-event tickets; rapid successive transitions
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/policies/analytics_policy.ex`
  - Pure functions operating on domain entity lists and event lists
  - Uses `Date.beginning_of_week/2` and calendar math for bucketing
  - Delegates to existing `TicketLifecyclePolicy.valid_stage?/1` for stage validation
- [ ] ⏸ **REFACTOR**: Extract shared duration formatting from `Ticket.View.format_duration/1` if reuse is warranted; ensure policy remains pure

### 1.2 AnalyticsView — Display Helpers for SVG Charts

Pure functions for computing SVG chart coordinates from aggregated data.

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/entities/analytics_view_test.exs`
  - Tests:
    - `distribution_bars/2` — given stage counts map and max_height, returns list of `%{stage: str, count: int, label: str, color: str, bar_height: float, y_offset: float}` for SVG bar rendering
    - `trend_line_points/3` — given bucketed data, chart dimensions, returns SVG polyline point strings for each stage
    - `chart_x_labels/2` — given time buckets and granularity, returns formatted labels for x-axis
    - `summary_display/1` — formats summary metrics for display (e.g., avg_cycle_time_seconds → "2d 4h" using existing format_duration)
    - Handles empty data gracefully (zero-height bars, no points)
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/entities/analytics_view.ex`
  - Uses `TicketLifecyclePolicy.stage_label/1` and `stage_color/1` for consistent stage presentation
  - Uses `Ticket.View.format_duration/1` for duration display
- [ ] ⏸ **REFACTOR**: Clean up, ensure all chart math is well-documented

### 1.3 GetAnalytics Use Case — Orchestrates Query + Policy

The use case coordinates infrastructure queries and domain policies to produce a complete analytics payload for the LiveView.

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/application/use_cases/get_analytics_test.exs`
  - Tests:
    - `execute/1` with default options returns analytics for last 30 days, daily granularity
    - `execute/1` with custom date range and granularity
    - `execute/1` with no lifecycle events returns empty/zero analytics
    - `execute/1` with no tickets returns empty/zero analytics
    - Dependency injection: `:analytics_repo` option overrides default repository
  - Mocks: Analytics repository module via Mox
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/application/use_cases/get_analytics.ex`
  - Accepts opts: `date_from`, `date_to`, `granularity` (`:daily` | `:weekly` | `:monthly`), `analytics_repo`
  - Calls analytics repository for raw data
  - Delegates aggregation to AnalyticsPolicy
  - Returns `{:ok, %{summary: map, distribution: list, throughput: list, cycle_times: list, buckets: list, granularity: atom, date_from: Date, date_to: Date}}`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1 Validation
- [ ] ⏸ All domain tests pass (`mix test apps/agents/test/agents/tickets/domain/policies/analytics_policy_test.exs apps/agents/test/agents/tickets/domain/entities/analytics_view_test.exs` — milliseconds, no I/O)
- [ ] ⏸ All application tests pass (`mix test apps/agents/test/agents/tickets/application/use_cases/get_analytics_test.exs` — with mocks)
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### 2.1 AnalyticsQueries — Ecto Query Objects

Composable query functions that return queryables for analytics aggregation.

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/queries/analytics_queries_test.exs`
  - Tests (all use `Agents.DataCase`):
    - `ticket_stage_distribution/0` — returns `[%{lifecycle_stage: str, count: int}]` for all tickets
    - `lifecycle_events_in_range/2` — returns events within a date range, ordered by transitioned_at
    - `tickets_with_events_in_range/2` — returns tickets that have lifecycle events within the date range, with events preloaded
    - `completed_tickets_in_range/2` — returns count of tickets where a "closed" transition exists in range
    - `total_ticket_count/0` — returns total count of all tickets
    - `open_ticket_count/0` — returns count of tickets with lifecycle_stage != "closed"
    - Correct filtering by date range
    - Returns empty results when no data
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/infrastructure/queries/analytics_queries.ex`
  - Uses `import Ecto.Query`
  - References `ProjectTicketSchema` and `TicketLifecycleEventSchema`
  - All functions return queryables or delegate to Repo for aggregate queries
  - Date range filtering on `transitioned_at` field
- [ ] ⏸ **REFACTOR**: Ensure queries are composable and index-friendly (existing indexes: `ticket_id`, `[ticket_id, transitioned_at]`)

### 2.2 AnalyticsRepository — Data Access

Thin wrapper that executes analytics queries via `Agents.Repo`.

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/repositories/analytics_repository_test.exs`
  - Tests (all use `Agents.DataCase`):
    - `get_analytics_data/1` — integration test: creates tickets + lifecycle events, calls with date range/granularity, returns expected raw data structure
    - Returns correctly structured data with: `stage_distribution`, `lifecycle_events`, `total_count`, `open_count`, `completed_count`
    - Handles empty database
    - Date range filtering works correctly (boundary conditions)
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/infrastructure/repositories/analytics_repository.ex`
  - Calls `AnalyticsQueries` functions
  - Executes via `Agents.Repo`
  - Injectable repo parameter for testing
  - Returns structured map of raw data for the use case to process
- [ ] ⏸ **REFACTOR**: Optimize query structure if N+1 detected

### 2.3 Facade Extension — Add Analytics to Agents.Tickets

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets_analytics_test.exs`
  - Tests:
    - `Agents.Tickets.get_analytics/1` delegates to `GetAnalytics.execute/1` with correct options
    - Returns expected structure with summary, distribution, throughput, cycle_times
- [ ] ⏸ **GREEN**: Add `get_analytics/1` to `apps/agents/lib/agents/tickets.ex`
  - Delegates to `GetAnalytics.execute/1`
  - Passes through options: `date_from`, `date_to`, `granularity`
- [ ] ⏸ **REFACTOR**: Ensure facade remains thin

### 2.4 SVG Chart Components — Function Components

Reusable function components for rendering SVG charts in HEEx.

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/agents_web/live/analytics/components/chart_components_test.exs`
  - Tests (use `AgentsWeb.ConnCase`):
    - `render_component(&ChartComponents.distribution_bar_chart/1, ...)` renders SVG with `data-testid="stage-distribution-chart"` and per-stage bars `data-testid="stage-bar-{stage}"`
    - `render_component(&ChartComponents.throughput_trend_chart/1, ...)` renders SVG with `data-testid="throughput-trend-chart"`
    - `render_component(&ChartComponents.cycle_time_trend_chart/1, ...)` renders SVG with `data-testid="cycle-time-trend-chart"`
    - `render_component(&ChartComponents.summary_cards/1, ...)` renders 4 cards with correct `data-testid` attributes: `summary-card-total-tickets`, `summary-card-open-tickets`, `summary-card-avg-cycle-time`, `summary-card-completed`
    - Empty data renders empty state message ("No lifecycle data yet")
    - Chart accessibility: SVG has `role="img"` and `aria-label`
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/analytics/components/chart_components.ex`
  - Module: `AgentsWeb.AnalyticsLive.Components.ChartComponents`
  - `use AgentsWeb, :html`
  - Function components:
    - `summary_cards/1` — 4 DaisyUI stat cards in a grid
    - `distribution_bar_chart/1` — SVG bar chart with stage-colored bars, x-axis labels, y-axis scale
    - `throughput_trend_chart/1` — SVG multi-line chart with legend
    - `cycle_time_trend_chart/1` — SVG multi-line chart with legend
    - `granularity_toggle/1` — 3-button toggle group (Daily/Weekly/Monthly) with `aria-pressed`
    - `date_range_filter/1` — Two date inputs with `data-testid` attributes
    - `empty_state/1` — "No lifecycle data yet" message
  - SVG charts use DaisyUI theme colours via `oklch()` CSS values (matching `stage_color/1` semantics)
  - All interactive elements have proper `data-testid` attributes per BDD feature file
- [ ] ⏸ **REFACTOR**: Extract shared SVG helpers (axis rendering, gridlines, scaling) into private functions

### 2.5 AnalyticsLive — The Dashboard LiveView

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/agents_web/live/analytics/index_test.exs`
  - Tests (use `AgentsWeb.ConnCase`):
    - **Mount**: Authenticated user can access `/analytics`, page renders with all data-testid elements
    - **Unauthenticated**: Redirects to login page
    - **Summary cards**: Cards display correct values from fixture data
    - **Distribution chart**: Renders SVG with stage bars
    - **Trend charts**: Render with correct data-testid attributes
    - **Granularity toggle**: Clicking "Weekly" updates assigns and re-renders trend charts; toggle has `aria-pressed="true"` on active option
    - **Date range filter**: Changing dates triggers re-computation and chart update
    - **Empty state**: When no lifecycle events, shows "No lifecycle data yet"
    - **Real-time update**: Sending `%TicketStageChanged{}` event updates distribution chart and summary cards
    - **Default date range**: Loads with last 30 days as default range
    - **Layout**: Renders within admin layout with sidebar
  - Fixtures: Create tickets + lifecycle events in setup block via `Agents.Repo` and existing schemas
- [ ] ⏸ **GREEN**: Implement `apps/agents_web/lib/live/analytics/index.ex`
  - Module: `AgentsWeb.AnalyticsLive.Index`
  - `use AgentsWeb, :live_view`
  - `mount/3`:
    - Requires authenticated user (via `on_mount`)
    - Computes default date range (today - 30 days to today)
    - Calls `Agents.Tickets.get_analytics/1` to load initial data
    - Subscribes to `"sessions:tickets"` PubSub topic for `TicketStageChanged` events
    - Assigns: `analytics`, `granularity` (`:daily`), `date_from`, `date_to`, `page_title`, `empty?`
  - `handle_event("change_granularity", %{"granularity" => g}, socket)`:
    - Updates granularity assign
    - Re-fetches analytics with new granularity
  - `handle_event("filter_dates", %{"date_from" => from, "date_to" => to}, socket)`:
    - Parses dates, validates range
    - Re-fetches analytics with new date range
    - Shows error flash if dates are invalid
  - `handle_info(%TicketStageChanged{} = _event, socket)`:
    - Re-fetches analytics data (full refresh — simple and correct)
    - Updates assigns
  - Template: `render/1` in the module or an embedded HEEx
    - Wraps in `<Layouts.admin>` layout
    - Summary cards at top
    - Granularity toggle + date range filter
    - Distribution bar chart
    - Throughput trend chart
    - Cycle time trend chart
    - Conditional empty state
- [ ] ⏸ **REFACTOR**: Extract render helpers, keep LiveView module thin

### 2.6 Router — Add Analytics Route

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/agents_web/live/analytics/routing_test.exs`
  - Tests:
    - `GET /analytics` for authenticated user returns 200
    - `GET /analytics` for unauthenticated user redirects to login
    - Analytics link appears in sidebar when navigating to `/sessions`
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/router.ex`
  - Add `live("/analytics", AnalyticsLive.Index, :index)` to the `:sessions` live_session (which requires authentication)
  - This places it in the same `live_session` as `/sessions`, sharing the `on_mount: [{AgentsWeb.UserAuth, :require_authenticated}]` callback
- [ ] ⏸ **REFACTOR**: Consider renaming the live_session from `:sessions` to `:authenticated` if it now covers more than sessions (optional)

### 2.7 Sidebar — Add Analytics Navigation Link

- [ ] ⏸ **RED**: Write test to verify sidebar contains analytics link (covered by BDD feature + LiveView tests above)
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/components/layouts.ex`
  - Add Analytics nav item between Sessions and Log out:
    ```heex
    <li>
      <.link navigate={~p"/analytics"} class="flex items-center gap-3">
        <.icon name="hero-chart-bar-square" class="size-5" />
        <span>Analytics</span>
      </.link>
    </li>
    ```
- [ ] ⏸ **REFACTOR**: Ensure active state highlighting for current route (if pattern exists)

### 2.8 Boundary Configuration Updates

- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/agents_web.ex`
  - Add `AgentsWeb.AnalyticsLive.Index` to the `exports` list in the Boundary configuration
- [ ] ⏸ **GREEN**: Verify `Agents.Tickets` boundary already covers the new query/repository modules (they are internal to the context, so no export changes needed)

### Phase 2 Validation
- [ ] ⏸ All infrastructure tests pass (`mix test apps/agents/test/agents/tickets/infrastructure/`)
- [ ] ⏸ All interface tests pass (`mix test apps/agents_web/test/agents_web/live/analytics/`)
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)

---

## Pre-Commit Checkpoint

- [ ] ⏸ `mix precommit` passes (compilation, formatting, credo, boundary, tests)
- [ ] ⏸ `mix boundary` reports no new violations
- [ ] ⏸ All BDD feature file scenarios are covered by implementation:
  - [ ] Analytics link visible in sidebar → Layouts.ex nav item + route
  - [ ] Clicking link navigates to `/analytics` → Router + LiveView mount
  - [ ] Summary counter cards displayed → `summary_cards` component with 4 data-testid cards
  - [ ] Stage distribution bar chart → `distribution_bar_chart` component with 7 stage bars
  - [ ] Throughput trend chart → `throughput_trend_chart` component
  - [ ] Cycle time trend chart → `cycle_time_trend_chart` component
  - [ ] Granularity toggle visible (Daily/Weekly/Monthly) → `granularity_toggle` component
  - [ ] Clicking Weekly updates toggle state → `change_granularity` event handler
  - [ ] Clicking Monthly updates toggle state → `change_granularity` event handler
  - [ ] Date range filter visible → `date_range_filter` component
  - [ ] Empty state shows "No lifecycle data yet" → conditional rendering
  - [ ] Default date range of last 30 days → mount assigns

---

## BDD Feature Coverage Matrix

### Browser Feature (`ticket-lifecycle-analytics.browser.feature`)

| Scenario | Implementation Point | Test File |
|----------|---------------------|-----------|
| Analytics link in sidebar | Layouts.ex nav item | `routing_test.exs` + BDD |
| Clicking link navigates to /analytics | Router + LiveView | `routing_test.exs` + BDD |
| Summary counter cards displayed | ChartComponents.summary_cards | `chart_components_test.exs` + `index_test.exs` |
| Stage distribution bar chart | ChartComponents.distribution_bar_chart | `chart_components_test.exs` + `index_test.exs` |
| Throughput trend chart | ChartComponents.throughput_trend_chart | `chart_components_test.exs` + `index_test.exs` |
| Cycle time trend chart | ChartComponents.cycle_time_trend_chart | `chart_components_test.exs` + `index_test.exs` |
| Granularity toggle visible | ChartComponents.granularity_toggle | `index_test.exs` |
| Weekly granularity click | handle_event("change_granularity") | `index_test.exs` |
| Monthly granularity click | handle_event("change_granularity") | `index_test.exs` |
| Date range filter visible | ChartComponents.date_range_filter | `index_test.exs` |
| Empty state messaging | Conditional render + empty_state component | `index_test.exs` |
| Default 30-day range | mount/3 date computation | `index_test.exs` |

### Security Feature (`ticket-lifecycle-analytics.security.feature`)

| Scenario | Implementation Point | Test File |
|----------|---------------------|-----------|
| Unauthenticated → redirect to login | UserAuth on_mount + require_authenticated_user plug | `routing_test.exs` |
| Workspace isolation | Currently all tickets are global; future enhancement | N/A (deferred) |
| Standard security headers | `Perme8.Plugs.SecurityHeaders` plug in pipeline | Existing plug tests |
| No internal details in errors | LiveView error handling + Phoenix error views | Existing error view tests |

---

## File Inventory

### New Files (to be created)

| # | File | Layer | Description |
|---|------|-------|-------------|
| 1 | `apps/agents/lib/agents/tickets/domain/policies/analytics_policy.ex` | Domain | Pure aggregation logic |
| 2 | `apps/agents/test/agents/tickets/domain/policies/analytics_policy_test.exs` | Domain Test | |
| 3 | `apps/agents/lib/agents/tickets/domain/entities/analytics_view.ex` | Domain | SVG chart data preparation |
| 4 | `apps/agents/test/agents/tickets/domain/entities/analytics_view_test.exs` | Domain Test | |
| 5 | `apps/agents/lib/agents/tickets/application/use_cases/get_analytics.ex` | Application | Orchestrates analytics retrieval |
| 6 | `apps/agents/test/agents/tickets/application/use_cases/get_analytics_test.exs` | Application Test | |
| 7 | `apps/agents/lib/agents/tickets/infrastructure/queries/analytics_queries.ex` | Infrastructure | Ecto query objects |
| 8 | `apps/agents/test/agents/tickets/infrastructure/queries/analytics_queries_test.exs` | Infrastructure Test | |
| 9 | `apps/agents/lib/agents/tickets/infrastructure/repositories/analytics_repository.ex` | Infrastructure | Thin Repo wrapper |
| 10 | `apps/agents/test/agents/tickets/infrastructure/repositories/analytics_repository_test.exs` | Infrastructure Test | |
| 11 | `apps/agents/test/agents/tickets_analytics_test.exs` | Facade Test | |
| 12 | `apps/agents_web/lib/live/analytics/index.ex` | Interface | Analytics LiveView |
| 13 | `apps/agents_web/lib/live/analytics/components/chart_components.ex` | Interface | SVG chart function components |
| 14 | `apps/agents_web/test/agents_web/live/analytics/index_test.exs` | Interface Test | |
| 15 | `apps/agents_web/test/agents_web/live/analytics/components/chart_components_test.exs` | Interface Test | |
| 16 | `apps/agents_web/test/agents_web/live/analytics/routing_test.exs` | Interface Test | |

### Modified Files

| # | File | Change |
|---|------|--------|
| 1 | `apps/agents/lib/agents/tickets.ex` | Add `get_analytics/1` facade function |
| 2 | `apps/agents_web/lib/router.ex` | Add `/analytics` route to `:sessions` live_session |
| 3 | `apps/agents_web/lib/components/layouts.ex` | Add Analytics nav item to sidebar |
| 4 | `apps/agents_web/lib/agents_web.ex` | Add `AnalyticsLive.Index` to boundary exports |

---

## Testing Strategy

| Layer | Test Count (est.) | Async? | I/O? |
|-------|-------------------|--------|------|
| Domain (AnalyticsPolicy) | 12-15 | ✅ Yes | ❌ None |
| Domain (AnalyticsView) | 8-10 | ✅ Yes | ❌ None |
| Application (GetAnalytics) | 4-5 | ✅ Yes | Mocked |
| Infrastructure (Queries) | 6-8 | ❌ No (DataCase) | ✅ DB |
| Infrastructure (Repository) | 4-5 | ❌ No (DataCase) | ✅ DB |
| Facade | 2-3 | ❌ No (DataCase) | ✅ DB |
| Interface (LiveView) | 10-12 | ❌ No (ConnCase) | ✅ DB |
| Interface (Components) | 6-8 | ✅ Yes | ❌ None |
| Interface (Routing) | 3-4 | ❌ No (ConnCase) | ✅ DB |
| **Total** | **55-70** | | |

**Distribution**: ~35% Domain (pure, fast), ~15% Application (mocked), ~20% Infrastructure (DB), ~30% Interface (LiveView + components)

### Test Data Factory Pattern

Tests that need lifecycle event data should create them via direct schema insertion (not through the use case, to avoid event bus side effects):

```elixir
defp create_lifecycle_event(ticket_id, from_stage, to_stage, transitioned_at) do
  Agents.Repo.insert!(%TicketLifecycleEventSchema{
    ticket_id: ticket_id,
    from_stage: from_stage,
    to_stage: to_stage,
    transitioned_at: transitioned_at,
    trigger: "system"
  })
end
```

### Domain Event Testing Rule

The `GetAnalytics` use case is **read-only** — it does not emit domain events. Therefore, `TestEventBus` injection is not required for this use case's tests. However, the LiveView tests that simulate `TicketStageChanged` events should use `send(view.pid, event)` to test the `handle_info` handler directly, avoiding the need for real PubSub infrastructure.

---

## Implementation Notes

### SVG Chart Architecture

The SVG charts follow a data-driven approach:

1. **Domain layer** (AnalyticsPolicy) computes raw aggregated numbers
2. **Domain layer** (AnalyticsView) transforms aggregated numbers into SVG-ready coordinates
3. **Interface layer** (ChartComponents) renders SVG elements from the coordinate data

This separation ensures chart logic is testable without rendering, and rendering is testable without data computation.

### SVG Bar Chart Structure
```html
<svg data-testid="stage-distribution-chart" viewBox="0 0 700 300" role="img" aria-label="Stage distribution">
  <!-- Y-axis -->
  <!-- Bars -->
  <rect data-testid="stage-bar-open" x="50" y="..." width="70" height="..." fill="..." />
  <rect data-testid="stage-bar-ready" ... />
  <!-- ... 7 bars total -->
  <!-- X-axis labels -->
</svg>
```

### SVG Line Chart Structure
```html
<svg data-testid="throughput-trend-chart" viewBox="0 0 700 300" role="img" aria-label="Throughput trend">
  <!-- Grid lines -->
  <!-- Polylines per stage (only active stages shown) -->
  <polyline points="..." stroke="..." fill="none" stroke-width="2" />
  <!-- X-axis labels (dates) -->
  <!-- Legend -->
</svg>
```

### Granularity Toggle HTML Structure
```html
<div data-testid="granularity-toggle" class="join" role="group">
  <button class="join-item btn" aria-pressed="true" phx-click="change_granularity" phx-value-granularity="daily">Daily</button>
  <button class="join-item btn" aria-pressed="false" ...>Weekly</button>
  <button class="join-item btn" aria-pressed="false" ...>Monthly</button>
</div>
```

### Date Range Filter HTML Structure
```html
<div data-testid="date-range-filter" class="flex gap-4">
  <input data-testid="date-range-start" type="date" name="date_from" value="..." phx-change="filter_dates" />
  <input data-testid="date-range-end" type="date" name="date_to" value="..." phx-change="filter_dates" />
</div>
```

### Real-Time Updates

The LiveView subscribes to `"sessions:tickets"` PubSub topic (same as `DashboardLive.Index`). When a `%TicketStageChanged{}` event is received:

1. Re-fetch analytics data via `Agents.Tickets.get_analytics/1`
2. Update all assigns
3. LiveView diffs the SVG — only changed bars/points re-render

This is intentionally a full re-fetch (not incremental update) because:
- Analytics aggregations cannot be reliably incrementally updated from a single event
- The query is lightweight (aggregation over indexed columns)
- Simplicity over premature optimization

### PubSub Topic

The existing `TicketStageChanged` event is broadcast to `"events:tickets"` and `"events:tickets:ticket"` via the EventBus. The dashboard subscribes to `"sessions:tickets"` which receives ticket sync events. The analytics LiveView should subscribe to both:
- `"sessions:tickets"` — for sync events that may create/update tickets
- `Perme8.Events.subscribe("events:tickets")` — for structured `TicketStageChanged` domain events

### Route Placement

The `/analytics` route goes in the existing `:sessions` live_session block inside the authenticated scope:

```elixir
live_session :sessions,
  on_mount: [{AgentsWeb.UserAuth, :require_authenticated}] do
  live("/sessions", DashboardLive.Index, :index)
  live("/analytics", AnalyticsLive.Index, :index)
end
```

This ensures:
- Authentication is enforced (both plug and on_mount)
- Same session cookie sharing with Identity app
- Users can navigate between sessions and analytics without full page reload (shared live_session)

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Large dataset performance | Slow queries for workspaces with 10k+ events | Existing indexes on `[ticket_id, transitioned_at]` cover the main query patterns. Add `EXPLAIN ANALYZE` in integration tests. Consider index on `transitioned_at` alone if needed. |
| SVG rendering complexity | Charts look broken or have alignment issues | Thorough component tests with known data. Use viewBox for responsive scaling. Start with simple charts and iterate. |
| Workspace scoping gap | Ticket says "workspace scoped" but no workspace_id exists | Documented as deferred. All queries are structured to accept optional filters. |
| PubSub event flood | Many rapid transitions cause excessive re-fetches | Debounce in handle_info (e.g., `Process.send_after` with `:refresh_analytics` + cancel previous timer). Consider implementing in refactor step if needed. |

---

## Out of Scope

Per ticket #496:
- Per-agent filtering or agent-level analytics
- Pre-aggregated rollup tables or materialized views
- Export/download of analytics data (CSV, PDF)
- Custom date range presets beyond manual date picker
- Analytics for session-level events (task created, task failed, etc.)
- Mobile-optimised layout (responsive down to tablet is sufficient)
- P2 features: hover tooltips on chart data points, click-to-drill-down on stages

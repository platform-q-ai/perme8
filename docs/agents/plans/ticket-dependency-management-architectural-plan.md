# Feature: Ticket Dependency Management (Blocks/Blocked-by)

**Ticket**: [#442](https://github.com/platform-q-ai/perme8/issues/442)
**Status**: ⏸ Not Started

## App Ownership

| Artifact | App | Path |
|----------|-----|------|
| **Owning app** | `agents` | `apps/agents/` |
| **Repo** | `Agents.Repo` | — |
| **Migrations** | `agents` | `apps/agents/priv/repo/migrations/` |
| **Domain entities** | `agents` | `apps/agents/lib/agents/tickets/domain/entities/` |
| **Domain policies** | `agents` | `apps/agents/lib/agents/tickets/domain/policies/` |
| **Domain events** | `agents` | `apps/agents/lib/agents/tickets/domain/events/` |
| **Use cases** | `agents` | `apps/agents/lib/agents/tickets/application/use_cases/` |
| **Schemas** | `agents` | `apps/agents/lib/agents/tickets/infrastructure/schemas/` |
| **Repositories** | `agents` | `apps/agents/lib/agents/tickets/infrastructure/repositories/` |
| **Facade** | `agents` | `apps/agents/lib/agents/tickets.ex` |
| **LiveViews** | `agents_web` | `apps/agents_web/lib/live/dashboard/` |
| **Components** | `agents_web` | `apps/agents_web/lib/live/dashboard/components/` |
| **Feature files (UI)** | `agents_web` | `apps/agents_web/test/features/dashboard/` |

## Overview

Add directional dependency relationships between tickets ("A blocks B" / "B is blocked by A") with:
- A join table for the many-to-many directional relationship
- DFS-based circular dependency detection
- Blocked indicators on ticket cards with active/resolved distinction
- Session start prevention for blocked tickets
- Searchable typeahead for adding dependencies
- Triage sidebar filtering by blocked status
- Dependency resilience across GitHub sync cycles (cascade delete handles pruned tickets)

## UI Strategy

- **LiveView coverage**: 100% — all dependency UI handled by LiveView
- **TypeScript needed**: None — the typeahead search can be a phx-change driven LiveView component with debounce, no client-side JS required

## Affected Boundaries

- **Owning app**: `agents`
- **Repo**: `Agents.Repo`
- **Migrations**: `apps/agents/priv/repo/migrations/`
- **Feature files**: `apps/agents_web/test/features/dashboard/`
- **Primary context**: `Agents.Tickets`
- **Dependencies**: None (self-contained within Tickets context)
- **Exported schemas**: None new (dependency schema is internal)
- **New context needed?**: No — dependencies are a lateral relationship within the Tickets bounded context

## Architecture Decisions

1. **Join table**: `ticket_dependencies(blocker_ticket_id, blocked_ticket_id)` with FKs to `sessions_project_tickets(id)` and `on_delete: :delete_all` — cascade handles ticket pruning during sync.
2. **No Ecto many-to-many**: Use explicit join schema with `has_many` + `through` for clarity and direct query control.
3. **Circular detection**: DFS with visited set in a pure policy (not parent-chain walk, since dependencies form a directed graph, not a tree).
4. **Dependencies are local-only**: No interaction with GitHub sync. Ticket IDs are stable across syncs so dependencies survive.
5. **PubSub refresh**: Broadcast on `"sessions:tickets"` topic after add/remove dependency.
6. **Blocked derivation**: Computed at the domain entity level — `blocked_by` list populated from preloaded associations, `blocked?` derived as a boolean. Distinguish "actively blocked" (at least one open blocker) from "all resolved" (all blockers closed).
7. **Domain event**: Emit `TicketDependencyChanged` after add/remove for real-time UI updates.

---

## Phase 1: Domain + Application (phoenix-tdd)

### 1.1 Domain Entity: Ticket (extend with dependency fields)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/entities/ticket_test.exs`
  - Add tests for new fields: `blocks`, `blocked_by`, derived `blocked?` and `blocked_status`
  - Test `from_schema/1` converts preloaded dependency associations to domain entity lists
  - Test `blocked?/1` returns true when `blocked_by` is non-empty and at least one blocker is open
  - Test `blocked_status/1` returns `:none`, `:active`, or `:resolved`
  - Test `open_blocker_count/1` returns count of open blockers
- [ ] ⏸ **GREEN**: Implement changes in `apps/agents/lib/agents/tickets/domain/entities/ticket.ex`
  - Add `blocks: [t()]`, `blocked_by: [t()]` to type and defstruct (default `[]`)
  - Add `blocked?/1` — true when any `blocked_by` entry has `state == "open"`
  - Add `blocked_status/1` — `:none` when `blocked_by == []`, `:active` when any blocker open, `:resolved` when all closed
  - Add `open_blocker_count/1` — count of `blocked_by` entries with `state == "open"`
  - Update `from_schema/1` to convert `blocking` and `blocked_by` associations
- [ ] ⏸ **REFACTOR**: Extract dependency conversion helpers, ensure clean separation

### 1.2 Domain Policy: TicketDependencyPolicy (pure cycle detection + validation)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/policies/ticket_dependency_policy_test.exs`
  - Test `circular_dependency?/3` — given existing edges as list of `{blocker_id, blocked_id}`, plus a proposed new edge, detects cycles via DFS
    - Simple cycle: A→B exists, detect B→A creates cycle
    - Transitive cycle: A→B, B→C exist, detect C→A creates cycle
    - Long chain: A→B→C→D, detect D→A creates cycle
    - No cycle: A→B exists, C→A is valid (no cycle)
    - Self-reference: A→A is always a cycle
  - Test `duplicate_dependency?/2` — checks if edge already exists in list
  - Test `valid_dependency?/2` — ensures blocker_id != blocked_id
  - Test `describe_cycle/3` — returns human-readable cycle description (list of ticket IDs in the cycle path)
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/policies/ticket_dependency_policy.ex`
  - `circular_dependency?(existing_edges, blocker_id, blocked_id)` — DFS from blocked_id following edges, detect if blocker_id is reachable
  - `duplicate_dependency?(existing_edges, {blocker_id, blocked_id})` — simple membership check
  - `valid_dependency?(blocker_id, blocked_id)` — not equal
  - `describe_cycle(existing_edges, blocker_id, blocked_id)` — returns path string for error message
- [ ] ⏸ **REFACTOR**: Ensure all functions are pure, no I/O, well-documented

### 1.3 Domain Event: TicketDependencyChanged

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/events/ticket_dependency_changed_test.exs`
  - Test `new/1` creates event with required fields: `blocker_ticket_id`, `blocked_ticket_id`, `action` (`:added` or `:removed`)
  - Test struct has standard domain event fields (aggregate_id, actor_id, etc.)
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/events/ticket_dependency_changed.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "ticket", fields: [blocker_ticket_id: nil, blocked_ticket_id: nil, action: nil], required: [:blocker_ticket_id, :blocked_ticket_id, :action]`
- [ ] ⏸ **REFACTOR**: Ensure naming consistency with existing events

### 1.4 Use Case: AddTicketDependency

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/application/use_cases/add_ticket_dependency_test.exs`
  - Uses `Agents.DataCase, async: true` with `TestEventBus`
  - Test success: inserts dependency record, emits `TicketDependencyChanged` event with `action: :added`
  - Test circular dependency rejection: returns `{:error, :circular_dependency, cycle_description}`
  - Test duplicate dependency rejection: returns `{:error, :duplicate_dependency}`
  - Test self-dependency rejection: returns `{:error, :self_dependency}`
  - Test non-existent blocker ticket: returns `{:error, :blocker_not_found}`
  - Test non-existent blocked ticket: returns `{:error, :blocked_not_found}`
  - Test PubSub broadcast fires after success
  - Mocks: inject `event_bus: TestEventBus`, `dependency_repo` for repository
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/application/use_cases/add_ticket_dependency.ex`
  - `execute(blocker_ticket_id, blocked_ticket_id, opts \\ [])`
  - Validate both tickets exist (via repo)
  - Check self-dependency, duplicate, circular (via policy)
  - Insert dependency record (via repo)
  - Emit domain event after insert
  - Broadcast tickets refresh on `"sessions:tickets"` topic
- [ ] ⏸ **REFACTOR**: Clean up, ensure consistent error tuples

### 1.5 Use Case: RemoveTicketDependency

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/application/use_cases/remove_ticket_dependency_test.exs`
  - Uses `Agents.DataCase, async: true` with `TestEventBus`
  - Test success: deletes dependency record, emits `TicketDependencyChanged` event with `action: :removed`
  - Test non-existent dependency: returns `{:error, :dependency_not_found}`
  - Test PubSub broadcast fires after success
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/application/use_cases/remove_ticket_dependency.ex`
  - `execute(blocker_ticket_id, blocked_ticket_id, opts \\ [])`
  - Find and delete the dependency record
  - Emit domain event after delete
  - Broadcast tickets refresh
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1 Validation

- [ ] ⏸ All domain tests pass (`mix test apps/agents/test/agents/tickets/domain/` — fast, no I/O for policies)
- [ ] ⏸ All application tests pass (`mix test apps/agents/test/agents/tickets/application/` — with TestEventBus)
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### 2.1 Migration: Create ticket_dependencies join table

- [ ] ⏸ Create `apps/agents/priv/repo/migrations/20260314000000_create_ticket_dependencies.exs`
  - Table: `ticket_dependencies`
  - Columns: `id` (bigserial primary key), `blocker_ticket_id` (references `sessions_project_tickets`, on_delete: delete_all), `blocked_ticket_id` (references `sessions_project_tickets`, on_delete: delete_all), `inserted_at` (utc_datetime)
  - Unique index on `[:blocker_ticket_id, :blocked_ticket_id]` — prevents duplicates at DB level
  - Index on `blocked_ticket_id` — for efficient "who blocks me?" queries
  - Index on `blocker_ticket_id` — for efficient "who do I block?" queries

### 2.2 Schema: TicketDependencySchema

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/schemas/ticket_dependency_schema_test.exs`
  - Test changeset validates required fields: `blocker_ticket_id`, `blocked_ticket_id`
  - Test changeset rejects self-referencing (blocker == blocked)
  - Test unique constraint on `{blocker_ticket_id, blocked_ticket_id}`
  - Test foreign key constraints
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/infrastructure/schemas/ticket_dependency_schema.ex`
  - `use Ecto.Schema` with `schema "ticket_dependencies"`
  - `belongs_to :blocker_ticket, ProjectTicketSchema`
  - `belongs_to :blocked_ticket, ProjectTicketSchema`
  - Changeset with `validate_required`, `foreign_key_constraint`, `unique_constraint`
  - Custom validation: blocker_ticket_id != blocked_ticket_id
- [ ] ⏸ **REFACTOR**: Clean up

### 2.3 Schema: ProjectTicketSchema (extend with dependency associations)

- [ ] ⏸ **RED**: Write test additions in `apps/agents/test/agents/tickets/infrastructure/schemas/project_ticket_schema_test.exs`
  - Test that `blocking` association preloads correctly
  - Test that `blocked_by` association preloads correctly
  - Test cascade delete: when a ticket is deleted, its dependencies are removed
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex`
  - Add `has_many :blocking_dependencies, TicketDependencySchema, foreign_key: :blocker_ticket_id`
  - Add `has_many :blocked_by_dependencies, TicketDependencySchema, foreign_key: :blocked_ticket_id`
  - Add `has_many :blocking, through: [:blocking_dependencies, :blocked_ticket]`
  - Add `has_many :blocked_by, through: [:blocked_by_dependencies, :blocker_ticket]`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.4 Repository: TicketDependencyRepository

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/repositories/ticket_dependency_repository_test.exs`
  - Uses `Agents.DataCase, async: true`
  - Test `add_dependency/2` — inserts a dependency record, returns `{:ok, schema}`
  - Test `add_dependency/2` — returns `{:error, changeset}` for duplicate
  - Test `remove_dependency/2` — deletes a dependency record, returns `:ok`
  - Test `remove_dependency/2` — returns `{:error, :not_found}` for non-existent
  - Test `list_edges/0` — returns all `{blocker_id, blocked_id}` tuples
  - Test `list_blocking/1` — returns tickets blocked by a given ticket
  - Test `list_blocked_by/1` — returns tickets blocking a given ticket
  - Test `ticket_exists?/1` — checks if a ticket ID exists
  - Test `search_tickets/2` — returns tickets matching number or title (excluding a given ticket ID)
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/tickets/infrastructure/repositories/ticket_dependency_repository.ex`
  - `add_dependency(blocker_ticket_id, blocked_ticket_id)` — insert via changeset
  - `remove_dependency(blocker_ticket_id, blocked_ticket_id)` — find and delete
  - `list_edges()` — `select([d], {d.blocker_ticket_id, d.blocked_ticket_id})`
  - `list_blocking(ticket_id)` — query via blocker_ticket_id
  - `list_blocked_by(ticket_id)` — query via blocked_ticket_id
  - `ticket_exists?(ticket_id)` — `Repo.exists?(where(ProjectTicketSchema, id: ^ticket_id))`
  - `search_tickets(query_string, exclude_ticket_id)` — search by number (exact) or title (ilike), excluding the given ticket
- [ ] ⏸ **REFACTOR**: Clean up

### 2.5 Repository: ProjectTicketRepository (extend with dependency preloading)

- [ ] ⏸ **RED**: Write test additions in `apps/agents/test/agents/tickets/infrastructure/repositories/project_ticket_repository_test.exs`
  - Test `list_all/0` now preloads `blocking` and `blocked_by` associations (through the dependency join)
  - Test that dependencies survive a simulated sync cycle (upsert + prune leaves dependencies intact)
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex`
  - Add `blocking` and `blocked_by` preloads to `list_all/0` query
  - Add `blocking` and `blocked_by` preloads to `get_by_id/1`
- [ ] ⏸ **REFACTOR**: Clean up, ensure no N+1 queries

### 2.6 Domain Entity: Ticket `from_schema/1` (update for dependency conversion)

- [ ] ⏸ **RED**: Add integration test in `apps/agents/test/agents/tickets/domain/entities/ticket_test.exs`
  - Test `from_schema/1` with preloaded `blocking` and `blocked_by` associations converts to `Ticket.t()` with populated lists
  - Test `from_schema/1` handles `%Ecto.Association.NotLoaded{}` gracefully (returns `[]`)
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/tickets/domain/entities/ticket.ex`
  - In `from_schema/1`, convert `schema.blocking` and `schema.blocked_by` associations to lists of `Ticket.t()` (similar to `convert_sub_tickets`)
  - Handle `%Ecto.Association.NotLoaded{}` → `[]`
- [ ] ⏸ **REFACTOR**: Clean up conversion helpers

### 2.7 Boundary Updates

- [ ] ⏸ Update `apps/agents/lib/agents/tickets/domain.ex`
  - Add `Policies.TicketDependencyPolicy` to exports
  - Add `Events.TicketDependencyChanged` to exports
- [ ] ⏸ Update `apps/agents/lib/agents/tickets/application.ex`
  - Add `UseCases.AddTicketDependency` to exports
  - Add `UseCases.RemoveTicketDependency` to exports
- [ ] ⏸ Update `apps/agents/lib/agents/tickets/infrastructure.ex`
  - Add `Schemas.TicketDependencySchema` to exports
  - Add `Repositories.TicketDependencyRepository` to exports

### 2.8 Facade: Agents.Tickets (extend public API)

- [ ] ⏸ **RED**: Write test additions in `apps/agents/test/agents/tickets_test.exs` (if exists, else integration tests via use case tests suffice)
  - Test `add_dependency/3` delegates to use case
  - Test `remove_dependency/3` delegates to use case
  - Test `search_tickets_for_dependency/2` delegates to repository
  - Test `list_project_tickets/2` now returns tickets with `blocks`, `blocked_by`, `blocked?` fields populated
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/tickets.ex`
  - Add `add_dependency(blocker_ticket_id, blocked_ticket_id, opts \\ [])` — delegates to `AddTicketDependency.execute/3`
  - Add `remove_dependency(blocker_ticket_id, blocked_ticket_id, opts \\ [])` — delegates to `RemoveTicketDependency.execute/3`
  - Add `search_tickets_for_dependency(query, exclude_ticket_id)` — delegates to `TicketDependencyRepository.search_tickets/2`
  - Update Boundary `deps` to include new use cases/repos as needed
- [ ] ⏸ **REFACTOR**: Keep facade thin, just delegation

### 2.9 LiveView: Ticket Detail Panel — Dependency Sections

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/dashboard/ticket_dependency_live_test.exs`
  - Uses `AgentsWeb.ConnCase, async: true`
  - Test "Blocks" section appears when ticket has blocking dependencies
  - Test "Blocked by" section appears when ticket has blocked_by dependencies
  - Test dependency ticket links are clickable (navigate to that ticket)
  - Test "Add dependency" button opens the dependency form
  - Test dependency search input filters tickets by number and title
  - Test current ticket is excluded from search results
  - Test selecting "blocks" direction and confirming adds a dependency
  - Test selecting "blocked by" direction and confirming adds a dependency
  - Test removing a dependency removes it from the list
  - Test circular dependency shows error flash
  - Test duplicate dependency shows error flash
  - Test `data-testid` attributes match BDD feature expectations:
    - `ticket-detail-panel`, `add-dependency-button`, `dependency-search-input`
    - `dependency-search-results`, `dependency-search-result`
    - `dependency-direction-blocks`, `dependency-direction-blocked-by`
    - `dependency-confirm-button`
    - `ticket-blocks-section`, `ticket-blocked-by-section`
    - `remove-dependency-button`
- [ ] ⏸ **GREEN**: Implement in `apps/agents_web/lib/live/dashboard/`
  - Create `apps/agents_web/lib/live/dashboard/dependency_handlers.ex` — new handler module for dependency events
    - `handle_event("add_dependency_start", ...)` — opens search UI, assigns `:dependency_search_mode` and `:dependency_search_results`
    - `handle_event("dependency_search", %{"query" => query}, ...)` — calls `Tickets.search_tickets_for_dependency/2`, assigns results
    - `handle_event("select_dependency_target", %{"ticket_id" => id}, ...)` — assigns `:selected_dependency_target`
    - `handle_event("set_dependency_direction", %{"direction" => dir}, ...)` — assigns `:dependency_direction` (`:blocks` or `:blocked_by`)
    - `handle_event("confirm_dependency", ...)` — calls `Tickets.add_dependency/3`, handles error tuples, reloads tickets
    - `handle_event("remove_dependency", %{"blocker_id" => bid, "blocked_id" => bid2}, ...)` — calls `Tickets.remove_dependency/3`, reloads tickets
  - Update `apps/agents_web/lib/live/dashboard/index.ex` to:
    - Add dependency assigns to mount: `dependency_search_mode: false`, `dependency_search_results: []`, `dependency_search_query: ""`, `selected_dependency_target: nil`, `dependency_direction: nil`
    - Route dependency events to `DependencyHandlers`
  - Update `apps/agents_web/lib/live/dashboard/index.html.heex` (ticket detail panel area):
    - Add "Blocks" section with `data-testid="ticket-blocks-section"` showing linked tickets
    - Add "Blocked by" section with `data-testid="ticket-blocked-by-section"` showing blocking tickets
    - Add "Add dependency" button with `data-testid="add-dependency-button"`
    - Add dependency search overlay with typeahead input, direction selector, confirm button
    - Each dependency item has a remove button with `data-testid="remove-dependency-button"`
    - Each dependency ticket link navigates via `phx-click="select_ticket"`
- [ ] ⏸ **REFACTOR**: Extract dependency UI into a function component for reuse

### 2.10 LiveView: Ticket Card — Blocked Indicator

- [ ] ⏸ **RED**: Write test additions in `apps/agents_web/test/live/dashboard/ticket_blocked_indicator_test.exs`
  - Test blocked ticket card has `data-blocked="active"` attribute when actively blocked
  - Test blocked ticket card has `data-blocked="resolved"` attribute when all blockers closed
  - Test blocked ticket card has `data-testid="blocked-indicator"` element
  - Test unblocked ticket card has no `data-blocked` attribute
  - Test blocked-by count badge shows "Blocked by N" text
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/dashboard/components/session_components.ex`
  - In `ticket_card/1`:
    - Add `data-blocked` attribute: `"active"` when `Ticket.blocked_status(ticket) == :active`, `"resolved"` when `:resolved`, absent when `:none`
    - Add blocked indicator element with `data-testid="blocked-indicator"` — icon/badge showing blocked state
    - Add count badge "Blocked by N" when `Ticket.open_blocker_count(ticket) > 0`
    - Style: active = red/warning indicator, resolved = muted/ghost indicator
- [ ] ⏸ **REFACTOR**: Clean up component, ensure indicator doesn't degrade rendering performance

### 2.11 LiveView: Session Start Prevention for Blocked Tickets

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/dashboard/ticket_blocked_session_start_test.exs`
  - Test that "Start session" button is not rendered for actively blocked tickets
  - Test that blocker ticket links are shown with `data-testid="blocker-ticket-link"`
  - Test "Blocked by" message is visible with links to blocking tickets
  - Test unblocked tickets still show the start button
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/live/dashboard/ticket_handlers.ex`
  - In `do_start_ticket_session/2`: add guard — if `Ticket.blocked?(ticket)` is true, return flash error with blocker list
  - Update template (ticket detail panel): conditionally hide "Start session" button when ticket is actively blocked
  - Show "Blocked by: [ticket links]" message with `data-testid="blocker-ticket-link"` on each blocker
  - The `data-testid="start-ticket-session-button"` element should not exist for blocked tickets
- [ ] ⏸ **REFACTOR**: Clean up conditional rendering

### 2.12 LiveView: Triage Sidebar Filtering by Blocked Status

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/dashboard/ticket_blocked_filter_test.exs`
  - Test "All" filter shows all tickets
  - Test "Blocked" filter shows only actively blocked tickets
  - Test "Unblocked" filter shows only non-blocked tickets
  - Test filter buttons have `data-testid` attributes: `filter-all`, `filter-blocked-only`, `filter-unblocked-only`
- [ ] ⏸ **GREEN**: Implement
  - Update `apps/agents_web/lib/live/dashboard/helpers.ex`:
    - Add `filter_tickets_by_status(tickets, :blocked)` — returns tickets where `Ticket.blocked_status(ticket) == :active`
    - Add `filter_tickets_by_status(tickets, :unblocked)` — returns tickets where `Ticket.blocked_status(ticket) != :active`
  - Update `apps/agents_web/lib/live/dashboard/index.html.heex`:
    - Add filter buttons in the triage sidebar header: "All" (`data-testid="filter-all"`), "Blocked" (`data-testid="filter-blocked-only"`), "Unblocked" (`data-testid="filter-unblocked-only"`)
    - Wire to `phx-click="filter_triage_tickets"` with value param
  - Update `apps/agents_web/lib/live/dashboard/index.ex`:
    - Add assign `:triage_blocked_filter` (default `:all`)
    - Handle `filter_triage_tickets` event
    - Apply blocked filter in addition to existing status/search filters
- [ ] ⏸ **REFACTOR**: Ensure filter state integrates cleanly with existing filter logic

### 2.13 LiveView: Dependency Navigation (clicking dependency links)

- [ ] ⏸ **RED**: Write test addition in ticket dependency live test
  - Test clicking a ticket link in the "Blocks" section navigates to that ticket's detail
  - Test clicking a ticket link in the "Blocked by" section navigates to that ticket's detail
- [ ] ⏸ **GREEN**: Ensure dependency ticket links use `phx-click="select_ticket" phx-value-number={dep_ticket.number}`
  - This reuses the existing `select_ticket` event handler
- [ ] ⏸ **REFACTOR**: Verify navigation works bidirectionally

### Phase 2 Validation

- [ ] ⏸ All infrastructure tests pass (`mix test apps/agents/test/agents/tickets/infrastructure/`)
- [ ] ⏸ All interface tests pass (`mix test apps/agents_web/test/`)
- [ ] ⏸ Migration runs cleanly (`mix ecto.migrate`)
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)

---

## Pre-commit Checkpoint

- [ ] ⏸ `mix precommit` passes (formatting, credo, compilation warnings, boundary, tests)
- [ ] ⏸ `mix boundary` has no violations
- [ ] ⏸ BDD feature file scenarios are addressable by the implementation:
  - All `data-testid` attributes in the feature file are present in the templates
  - `data-blocked` attribute set on ticket cards (`active`, `resolved`)
  - Blocked indicator badge rendered
  - Session start prevention works
  - Filter buttons present and functional

---

## Testing Strategy

### Test Distribution

| Layer | Test File | Count | Async |
|-------|-----------|-------|-------|
| **Domain Entity** | `ticket_test.exs` (additions) | ~8 | `ExUnit.Case, async: true` |
| **Domain Policy** | `ticket_dependency_policy_test.exs` | ~10 | `ExUnit.Case, async: true` |
| **Domain Event** | `ticket_dependency_changed_test.exs` | ~3 | `ExUnit.Case, async: true` |
| **Use Case (Add)** | `add_ticket_dependency_test.exs` | ~8 | `Agents.DataCase, async: true` |
| **Use Case (Remove)** | `remove_ticket_dependency_test.exs` | ~4 | `Agents.DataCase, async: true` |
| **Schema** | `ticket_dependency_schema_test.exs` | ~5 | `Agents.DataCase, async: true` |
| **Repository** | `ticket_dependency_repository_test.exs` | ~9 | `Agents.DataCase, async: true` |
| **Repository (extend)** | `project_ticket_repository_test.exs` (additions) | ~3 | `Agents.DataCase, async: true` |
| **LiveView (deps)** | `ticket_dependency_live_test.exs` | ~12 | `AgentsWeb.ConnCase, async: true` |
| **LiveView (blocked indicator)** | `ticket_blocked_indicator_test.exs` | ~5 | `AgentsWeb.ConnCase, async: true` |
| **LiveView (session start)** | `ticket_blocked_session_start_test.exs` | ~4 | `AgentsWeb.ConnCase, async: true` |
| **LiveView (filter)** | `ticket_blocked_filter_test.exs` | ~4 | `AgentsWeb.ConnCase, async: true` |
| **Total** | | **~75** | |

### Test Pyramid

- **Domain (pure, fast)**: ~21 tests — policies, entities, events (milliseconds, no I/O)
- **Application (mocked deps)**: ~12 tests — use cases with TestEventBus
- **Infrastructure (DB)**: ~17 tests — schemas, repositories, preloading
- **Interface (LiveView)**: ~25 tests — UI interactions, navigation, filtering

### Testing Patterns

- **Domain tests**: `use ExUnit.Case, async: true` — pure functions, no DB
- **Use case tests**: `use Agents.DataCase, async: true` — inject `TestEventBus` via `@default_opts [actor_id: @actor_id, event_bus: TestEventBus]`, call `TestEventBus.start_global()` in setup
- **LiveView tests**: `use AgentsWeb.ConnCase, async: true` — create test tickets via `ProjectTicketRepository.sync_remote_ticket/1`, add dependencies via `TicketDependencyRepository.add_dependency/2`

---

## File Inventory (New Files)

| File | Type |
|------|------|
| `apps/agents/priv/repo/migrations/20260314000000_create_ticket_dependencies.exs` | Migration |
| `apps/agents/lib/agents/tickets/domain/policies/ticket_dependency_policy.ex` | Domain Policy |
| `apps/agents/lib/agents/tickets/domain/events/ticket_dependency_changed.ex` | Domain Event |
| `apps/agents/lib/agents/tickets/infrastructure/schemas/ticket_dependency_schema.ex` | Infra Schema |
| `apps/agents/lib/agents/tickets/infrastructure/repositories/ticket_dependency_repository.ex` | Infra Repository |
| `apps/agents/lib/agents/tickets/application/use_cases/add_ticket_dependency.ex` | Use Case |
| `apps/agents/lib/agents/tickets/application/use_cases/remove_ticket_dependency.ex` | Use Case |
| `apps/agents_web/lib/live/dashboard/dependency_handlers.ex` | LiveView Handlers |
| **Test Files** | |
| `apps/agents/test/agents/tickets/domain/policies/ticket_dependency_policy_test.exs` | Domain Test |
| `apps/agents/test/agents/tickets/domain/events/ticket_dependency_changed_test.exs` | Domain Test |
| `apps/agents/test/agents/tickets/infrastructure/schemas/ticket_dependency_schema_test.exs` | Infra Test |
| `apps/agents/test/agents/tickets/infrastructure/repositories/ticket_dependency_repository_test.exs` | Infra Test |
| `apps/agents/test/agents/tickets/application/use_cases/add_ticket_dependency_test.exs` | Use Case Test |
| `apps/agents/test/agents/tickets/application/use_cases/remove_ticket_dependency_test.exs` | Use Case Test |
| `apps/agents_web/test/live/dashboard/ticket_dependency_live_test.exs` | LiveView Test |
| `apps/agents_web/test/live/dashboard/ticket_blocked_indicator_test.exs` | LiveView Test |
| `apps/agents_web/test/live/dashboard/ticket_blocked_session_start_test.exs` | LiveView Test |
| `apps/agents_web/test/live/dashboard/ticket_blocked_filter_test.exs` | LiveView Test |

## File Inventory (Modified Files)

| File | Changes |
|------|---------|
| `apps/agents/lib/agents/tickets/domain/entities/ticket.ex` | Add `blocks`, `blocked_by` fields; `blocked?/1`, `blocked_status/1`, `open_blocker_count/1`; update `from_schema/1` |
| `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex` | Add `has_many` through associations for dependencies |
| `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex` | Add preloads for `blocking`, `blocked_by` in `list_all/0` and `get_by_id/1` |
| `apps/agents/lib/agents/tickets.ex` | Add `add_dependency/3`, `remove_dependency/3`, `search_tickets_for_dependency/2` facade functions |
| `apps/agents/lib/agents/tickets/domain.ex` | Export new policy and event |
| `apps/agents/lib/agents/tickets/application.ex` | Export new use cases |
| `apps/agents/lib/agents/tickets/infrastructure.ex` | Export new schema and repository |
| `apps/agents_web/lib/live/dashboard/index.ex` | Add dependency assigns, route dependency events |
| `apps/agents_web/lib/live/dashboard/index.html.heex` | Add dependency sections in ticket detail panel, blocked filter buttons, blocked indicators |
| `apps/agents_web/lib/live/dashboard/ticket_handlers.ex` | Add blocked check in `do_start_ticket_session/2` |
| `apps/agents_web/lib/live/dashboard/helpers.ex` | Add `:blocked` and `:unblocked` filter clauses |
| `apps/agents_web/lib/live/dashboard/components/session_components.ex` | Add blocked indicator to `ticket_card/1` |

## BDD Feature Coverage Mapping

| BDD Scenario | Implementation Step |
|-------------|-------------------|
| Adding a "blocks" dependency | 2.9 (DependencyHandlers + template) |
| Adding a "blocked by" dependency | 2.9 (DependencyHandlers + template) |
| Searching for tickets via typeahead | 2.9 (dependency_search handler + TicketDependencyRepository.search_tickets) |
| Current ticket excluded from search | 2.9 (search_tickets excludes ticket_id) |
| Removing existing dependency | 2.9 (remove_dependency handler) |
| Blocked indicator on sidebar cards | 2.10 (ticket_card component) |
| Blocked indicator active vs resolved | 2.10 (data-blocked attribute) |
| Blocked count badge | 2.10 (open_blocker_count) |
| Circular dependency prevented | 1.2 + 1.4 (policy + use case) → 2.9 (error flash) |
| Duplicate dependency prevented | 1.2 + 1.4 (policy + use case) → 2.9 (error flash) |
| Session start prevented for blocked | 2.11 (ticket_handlers guard) |
| Filter: blocked only | 2.12 (helpers filter + template) |
| Filter: unblocked only | 2.12 (helpers filter + template) |
| Filter: all | 2.12 (helpers filter + template) |
| Detail shows Blocks + Blocked-by | 2.9 (template sections) |
| Clicking dependency navigates | 2.13 (select_ticket reuse) |
| Dependencies survive sync | 2.1 (cascade delete) + 2.5 (preloading) — tested in 2.5 |
| Blocker closed updates indicator | 2.10 (blocked_status derives from state) — automatic via sync |

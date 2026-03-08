# Feature: Ticket Domain Entity with Subticket Hierarchy and GitHub Sub-Issue Sync (#382)

## Status: ⏳ In Progress

## App Ownership

| Artifact | Owning App | Path |
|----------|-----------|------|
| Domain entity | `agents` | `apps/agents/lib/agents/sessions/domain/entities/ticket.ex` |
| Domain policy | `agents` | `apps/agents/lib/agents/sessions/domain/policies/ticket_hierarchy_policy.ex` |
| Ecto schema | `agents` | `apps/agents/lib/agents/sessions/infrastructure/schemas/project_ticket_schema.ex` |
| Migration | `agents` | `apps/agents/priv/repo/migrations/YYYYMMDDHHMMSS_add_parent_ticket_id_to_project_tickets.exs` |
| Repository | `agents` | `apps/agents/lib/agents/sessions/infrastructure/repositories/project_ticket_repository.ex` |
| GitHub client | `agents` | `apps/agents/lib/agents/sessions/infrastructure/clients/github_project_client.ex` |
| Sync server | `agents` | `apps/agents/lib/agents/sessions/infrastructure/ticket_sync_server.ex` |
| Facade | `agents` | `apps/agents/lib/agents/sessions.ex` |
| LiveView | `agents_web` | `apps/agents_web/lib/live/sessions/index.ex` |
| Template | `agents_web` | `apps/agents_web/lib/live/sessions/index.html.heex` |
| Components | `agents_web` | `apps/agents_web/lib/live/sessions/components/session_components.ex` |
| DnD Hook | `agents_web` | `apps/agents_web/assets/js/presentation/hooks/triage-lane-dnd-hook.ts` |
| Feature files (BDD) | `agents_web` | `apps/agents_web/test/features/sessions/ticket-subticket-hierarchy.browser.feature` |
| **Repo** | **`Agents.Repo`** | — |

## Overview

This feature introduces a proper `Ticket` domain entity (following the established `Task` entity pattern), adds a self-referencing `parent_ticket_id` foreign key for subticket hierarchy, syncs GitHub sub-issue relationships via the existing `TicketSyncServer`, and renders the hierarchy in the triage column and ticket detail panel.

The work decomposes into four major areas:
1. **Domain entity** — Pure `Ticket` struct with hierarchy query functions
2. **Schema + migration** — `parent_ticket_id` FK, `belongs_to`/`has_many` associations
3. **Sync pipeline** — GitHub sub-issue fetch → parent resolution → persistence
4. **UI** — Hierarchical rendering in triage column + detail panel

## UI Strategy

- **LiveView coverage**: 95%+ — all rendering, state management, and event handling in LiveView/HEEx
- **TypeScript needed**: Minor update to existing `TriageLaneDndHook` to support `data-ticket-depth` awareness for subticket drag-and-drop within parent groups. No new hooks.

## Affected Boundaries

- **Owning app**: `agents` (domain, infrastructure) + `agents_web` (interface)
- **Repo**: `Agents.Repo`
- **Migrations**: `apps/agents/priv/repo/migrations/`
- **Feature files**: `apps/agents_web/test/features/sessions/`
- **Primary context**: `Agents.Sessions`
- **Dependencies**: None — this is internal to the Sessions bounded context
- **Exported schemas**: `Agents.Sessions.Domain.Entities.Ticket` (add to `exports` in `Agents.Sessions`)
- **New context needed?**: No — tickets are part of the existing Sessions context

## BDD Scenarios to Satisfy

The implementation must pass all 10 scenarios in `ticket-subticket-hierarchy.browser.feature`:

1. **Root tickets display at top level** — `data-ticket-depth='0'` on root tickets, no depth-1 at top level
2. **Parent ticket shows subticket count indicator** — "3 sub-issues" text visible
3. **Subtickets render nested under parent** — `data-ticket-depth='1'` with `subticket-card` class
4. **Collapsible parent ticket** — Toggle `triage-parent-toggle` hides/shows `triage-subticket-list`
5. **Viewing parent ticket detail shows subticket list** — Detail panel with `ticket-detail-subissues`
6. **Clicking subticket in detail navigates to its detail** — `ticket-subissue-item-*` click → `data-ticket-type='subticket'`
7. **Closed parent ticket shows subticket state summary** — "2/3 closed" text
8. **Subticket drag-and-drop within parent group** — `draggable="true"` on depth-1 tickets
9. **Viewing subticket shows breadcrumb to parent** — `ticket-detail-parent-breadcrumb`
10. **Ticket hierarchy reflects GitHub sub-issue sync** — After sync, hierarchy data attributes exist

---

## Phase 1: Domain + Application (phoenix-tdd)

### 1.1 Ticket Domain Entity

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/ticket_test.exs`
  - Tests `new/1` creates a Ticket struct with all fields from PRD: `id`, `number`, `external_id`, `title`, `body`, `status`, `state`, `priority`, `size`, `labels`, `url`, `position`, `sync_state`, `last_synced_at`, `last_sync_error`, `remote_updated_at`, `parent_ticket_id`, `sub_tickets`, `created_at`, `inserted_at`, `updated_at`
  - Tests `new/1` defaults: `state` defaults to `"open"`, `labels` defaults to `[]`, `sub_tickets` defaults to `[]`, `position` defaults to `0`, `sync_state` defaults to `"synced"`
  - Tests `new/1` allows overriding defaults
  - Tests `from_schema/1` converts a mock schema struct to `Ticket` entity, mapping all fields explicitly
  - Tests `from_schema/1` recursively converts preloaded `sub_tickets` association (list of schema structs → list of Ticket entities)
  - Tests `from_schema/1` handles `sub_tickets` as `%Ecto.Association.NotLoaded{}` → defaults to `[]`
  - Tests `from_schema/1` handles nil `parent_ticket_id` correctly
  - Tests domain query functions: `open?/1`, `closed?/1`, `has_sub_tickets?/1`, `root_ticket?/1`, `sub_ticket?/1`
  - Tests `valid_states/0` returns `["open", "closed"]`
  - All tests use `use ExUnit.Case, async: true` — no DB, no I/O

- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/entities/ticket.ex`
  - Pure struct with `defstruct` — no `use Ecto.Schema`, no infrastructure deps
  - `@type t` typespec with all fields
  - `new/1` — `struct(__MODULE__, attrs)` with defaults
  - `from_schema/1` — explicit field mapping, recursive sub_tickets conversion
  - `open?/1` — `ticket.state == "open"`
  - `closed?/1` — `ticket.state == "closed"`
  - `has_sub_tickets?/1` — `ticket.sub_tickets != [] and ticket.sub_tickets != nil`
  - `root_ticket?/1` — `is_nil(ticket.parent_ticket_id)`
  - `sub_ticket?/1` — `not is_nil(ticket.parent_ticket_id)`
  - `valid_states/0` — `["open", "closed"]`

- [x] ✓ **REFACTOR**: Extract shared conversion helper if needed; ensure typespec completeness matches all schema fields

### 1.2 Ticket Hierarchy Policy

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/ticket_hierarchy_policy_test.exs`
  - Tests `build_tree/1` — given flat list of Ticket entities (some with `parent_ticket_id`), returns list of root-only tickets with `sub_tickets` populated
  - Tests `build_tree/1` — tickets with `parent_ticket_id` pointing to non-existent parent are treated as root
  - Tests `build_tree/1` — preserves original ordering (position-based) within each level
  - Tests `circular_reference?/2` — detects when setting a parent_ticket_id would create a cycle (A→B→A)
  - Tests `circular_reference?/2` — returns false for valid parent assignment
  - Tests `sub_ticket_summary/1` — given a Ticket with sub_tickets, returns `{closed_count, total_count}` e.g. `{2, 3}`
  - Tests `sub_ticket_summary/1` — returns `{0, 0}` for tickets with no sub_tickets
  - Tests `sub_ticket_summary_text/1` — returns formatted string like "2/3 closed" or "3 sub-issues"
  - Tests `max_depth/0` — returns 2 (UI nesting cap)
  - All tests use `use ExUnit.Case, async: true` — pure functions, no I/O

- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/ticket_hierarchy_policy.ex`
  - `build_tree/1` — groups tickets by parent_ticket_id, assembles tree, returns root-level list
  - `circular_reference?/2` — walks parent chain to detect cycles
  - `sub_ticket_summary/1` — counts closed vs total sub_tickets
  - `sub_ticket_summary_text/1` — formats the count string for UI
  - `max_depth/0` — returns `2`

- [x] ✓ **REFACTOR**: Ensure `build_tree/1` handles large flat lists efficiently (single pass with Map grouping)

### 1.3 Ticket Enrichment Service

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/ticket_enrichment_policy_test.exs`
  - Tests `enrich/2` — given a `Ticket` entity and a list of `Task` entities, enriches the ticket with `associated_task_id`, `associated_container_id`, `session_state`, `task_status`, `task_error` by matching ticket number to task instruction
  - Tests `enrich/2` — returns ticket unchanged when no matching task found (`session_state` = `"idle"`)
  - Tests `enrich_all/2` — applies enrichment to a list of tickets, preserving tree structure (enriches sub_tickets recursively)
  - Tests `task_status_to_session_state/1` mapping: nil→"idle", "running"→"running", "completed"→"completed", "cancelled"→"paused"
  - All tests use `use ExUnit.Case, async: true`

- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/sessions/domain/policies/ticket_enrichment_policy.ex`
  - `enrich/2` — adds enrichment fields to a Ticket entity struct, matching ticket.number against tasks via `Sessions.extract_ticket_number/1`
  - `enrich_all/2` — maps over tickets and their sub_tickets recursively
  - `task_status_to_session_state/1` — consolidates the mapping currently duplicated in Sessions facade and LiveView

- [ ] ⏸ **REFACTOR**: Remove duplicated `task_status_to_session_state/1` from `Sessions` facade and `index.ex` LiveView

### Phase 1 Validation

- [x] ✓ All domain tests pass (`mix test apps/agents/test/agents/sessions/domain/ --no-start`, milliseconds, no I/O)
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### 2.1 Migration: Add parent_ticket_id to sessions_project_tickets

- [x] ✓ Create `apps/agents/priv/repo/migrations/YYYYMMDDHHMMSS_add_parent_ticket_id_to_project_tickets.exs`
  ```elixir
  defmodule Agents.Repo.Migrations.AddParentTicketIdToProjectTickets do
    use Ecto.Migration

    def change do
      alter table(:sessions_project_tickets) do
        add(:parent_ticket_id, references(:sessions_project_tickets, on_delete: :nilify_all))
      end

      create(index(:sessions_project_tickets, [:parent_ticket_id]))
    end
  end
  ```
  Note: Uses default integer type (not `type: :binary_id`) because `sessions_project_tickets` uses auto-incrementing integer primary keys.

### 2.2 ProjectTicketSchema: Add parent_ticket_id and associations

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/schemas/project_ticket_schema_test.exs`
  - Tests changeset accepts `parent_ticket_id` as a castable field
  - Tests `parent_ticket_id` can be nil (root ticket)
  - Tests `parent_ticket_id` can be set to an existing ticket's id
  - Tests `belongs_to :parent_ticket` association is defined
  - Tests `has_many :sub_tickets` association is defined
  - Uses `Agents.DataCase, async: true`

- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/schemas/project_ticket_schema.ex`
  - Add `belongs_to :parent_ticket, __MODULE__` to schema block
  - Add `has_many :sub_tickets, __MODULE__, foreign_key: :parent_ticket_id` to schema block
  - Add `:parent_ticket_id` to the typespec
  - Add `:parent_ticket_id` to the cast list in `changeset/2`

- [x] ✓ **REFACTOR**: Update existing schema typespec to include `parent_ticket_id`

### 2.3 ProjectTicketRepository: Hierarchy support

- [x] ✓ **RED**: Add tests to `apps/agents/test/agents/sessions/infrastructure/project_ticket_repository_test.exs`
  - Tests `list_all/0` preloads `sub_tickets` association (1 level deep)
  - Tests `list_all/0` returns only root tickets (where `parent_ticket_id` is nil) at top level, with `sub_tickets` populated
  - Tests `sync_remote_ticket/2` accepts and persists `parent_ticket_id`
  - Tests `sync_remote_ticket/2` updates `parent_ticket_id` on re-sync (reparenting)
  - Tests `sync_remote_ticket/2` clears `parent_ticket_id` to nil when ticket is promoted to top-level
  - Tests `link_sub_tickets/1` — given a map of `%{child_number => parent_number}`, resolves parent ticket IDs and updates children
  - Tests `link_sub_tickets/1` — skips entries where parent doesn't exist yet (deferred linking)
  - Tests `delete_not_in/1` — subtickets whose parent is pruned get `parent_ticket_id` set to nil by FK constraint
  - Uses `Agents.DataCase, async: true`

- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/repositories/project_ticket_repository.ex`
  - Update `list_all/0` to preload `:sub_tickets` and filter to root tickets only (`where parent_ticket_id is nil`), with sub_tickets ordered by position
  - Add `list_all_flat/0` that returns all tickets without hierarchy filtering (for sync operations)
  - Update `sync_remote_ticket/2` to accept `parent_ticket_id` in attrs
  - Add `link_sub_tickets/1` — bulk-updates `parent_ticket_id` for child tickets by resolving parent numbers to IDs
  - Add `:parent_ticket_id` to `@remote_attr_keys` in `normalize_remote_attrs/1`

- [x] ✓ **REFACTOR**: Extract preload/ordering logic into a composable query pattern

### 2.4 GithubProjectClient: Fetch sub-issue relationships

- [x] ✓ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/clients/github_project_client_test.exs`
  - Tests `fetch_tickets/1` response includes `sub_issue_numbers` field (list of integers) for each ticket
  - Tests `parse_issue/1` (via `fetch_tickets`) extracts sub-issue numbers from the REST sub-issues endpoint data
  - Tests graceful handling when sub-issue fetch fails (parent ticket still returned, sub_issue_numbers = [])
  - Uses mock HTTP responses (Req test adapter or Mox)

- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/clients/github_project_client.ex`
  - Add `fetch_sub_issues/3` — calls `GET /repos/{owner}/{repo}/issues/{issue_number}/sub_issues` REST endpoint
  - Update `fetch_tickets/1` to also call `fetch_sub_issues/3` for each issue that may have sub-issues
  - Add `sub_issue_numbers` field to the `@type ticket` spec
  - Update `parse_issue/1` to include `sub_issue_numbers: []` default
  - Batch sub-issue fetches to minimize API calls (only fetch for issues that have sub-issue indicators)

- [x] ✓ **REFACTOR**: Consider rate-limiting/batching strategy; add `@sub_issues_per_page` config

### 2.5 TicketSyncServer: Resolve parent-child relationships

- [x] ✓ **RED**: Add tests to existing test file or create `apps/agents/test/agents/sessions/infrastructure/ticket_sync_server_test.exs`
  - Tests `poll_tickets/1` syncs sub-issue relationships by calling `link_sub_tickets/1` after individual ticket upserts
  - Tests parent resolution: when parent ticket exists locally, child gets `parent_ticket_id` set
  - Tests deferred linking: when parent not yet synced, child has `parent_ticket_id = nil`
  - Tests reparenting: when a sub-issue moves to a different parent on GitHub, `parent_ticket_id` updates accordingly
  - Tests orphan handling: when parent is deleted from GitHub, `on_delete: :nilify_all` promotes children to root
  - Tests circular reference guard: detects and skips cycle-creating parent assignments
  - Uses Mox for `client` and `ticket_repo` dependencies

- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/ticket_sync_server.ex`
  - After syncing individual tickets, build `parent_child_map` from fetched ticket data (`%{child_number => parent_number}`)
  - Call `state.ticket_repo.link_sub_tickets(parent_child_map)` to resolve and persist relationships
  - Clear `parent_ticket_id` for tickets not in any sub-issue list (promoted to top-level)
  - Use `TicketHierarchyPolicy.circular_reference?/2` before setting parent relationships
  - Guard against empty sync results wiping parent relationships (same guard as existing prune logic)

- [x] ✓ **REFACTOR**: Extract parent resolution logic into a helper function for testability

### 2.6 Sessions Facade: Return Ticket domain entities

- [x] ✓ **RED**: Update tests in `apps/agents/test/agents/sessions_test.exs`
  - Tests `list_project_tickets/2` returns `%Ticket{}` domain entities (not maps or schema structs)
  - Tests returned tickets have `sub_tickets` populated as nested `%Ticket{}` entities
  - Tests enrichment fields (`associated_task_id`, `session_state`, etc.) are present on returned entities
  - Tests enrichment is applied recursively to sub_tickets
  - Tests tree structure: returned list contains only root tickets, with sub_tickets nested
  - Uses `Agents.DataCase, async: true`

- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/sessions.ex`
  - Update `list_project_tickets/2` to:
    1. Call `ProjectTicketRepository.list_all()` (which now returns root tickets with preloaded sub_tickets)
    2. Convert schemas to `Ticket` entities via `Ticket.from_schema/1` (recursive)
    3. Enrich via `TicketEnrichmentPolicy.enrich_all/2`
  - Export `Ticket` entity in `Agents.Sessions` boundary exports
  - Remove duplicated `task_status_to_session_state/1` (now in `TicketEnrichmentPolicy`)
  - Remove ad-hoc `Map.merge` enrichment logic (replaced by `TicketEnrichmentPolicy`)

- [x] ✓ **REFACTOR**: Ensure existing `Sessions` tests still pass; verify Boundary exports are correct

### 2.7 LiveView: Update index.ex for Ticket entities and hierarchy

- [x] ✓ **RED**: Update tests in `apps/agents_web/test/live/sessions/index_test.exs`
  - Tests `re_enrich_tickets/2` replacement works with `%Ticket{}` entities (preserving sub_tickets)
  - Tests `handle_info({:tickets_synced, _})` reloads and assigns hierarchical ticket data
  - Tests `handle_event("select_ticket")` works with ticket entities
  - Tests `handle_event("reorder_triage_tickets")` works with hierarchical ticket list
  - Uses `AgentsWeb.ConnCase`

- [x] ✓ **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex`
  - Replace `re_enrich_tickets/2` with call to `TicketEnrichmentPolicy.enrich_all/2`
  - Update all 10 call sites of `re_enrich_tickets/2` to use the new domain function
  - Remove `task_status_to_session_state/1` (delegated to enrichment policy)
  - Update `reload_tickets/1` to work with the new `Sessions.list_project_tickets/2` that returns entities
  - Ensure `assign(:tickets, ...)` stores `%Ticket{}` entities
  - Add `assign(:collapsed_parents, MapSet.new())` for collapsible parent state
  - Add `handle_event("toggle_parent_collapse", ...)` handler

- [x] ✓ **REFACTOR**: Remove duplicated enrichment logic from LiveView; keep LiveView thin

### 2.8 Template: Hierarchical triage column rendering

- [x] ✓ **RED**: Write/update tests in `apps/agents_web/test/live/sessions/index_test.exs`
  - Tests root tickets render with `data-ticket-depth="0"` attribute
  - Tests subtickets render with `data-ticket-depth="1"` and `subticket-card` CSS class
  - Tests parent tickets show subticket count (e.g., "3 sub-issues")
  - Tests collapsible toggle: `data-testid="triage-parent-toggle"` exists on parent tickets
  - Tests collapse/expand: clicking toggle hides/shows `data-testid="triage-subticket-list"`
  - Tests ticket detail panel shows "Sub-issues" section with `data-testid="ticket-detail-subissues"` for parent tickets
  - Tests subticket items in detail panel: `data-testid="ticket-subissue-item-{number}"`
  - Tests clicking subticket in detail panel selects it (shows detail with `data-ticket-type="subticket"`)
  - Tests closed parent ticket shows "2/3 closed" summary text
  - Tests subticket detail shows breadcrumb: `data-testid="ticket-detail-parent-breadcrumb"` with "Parent ticket" text
  - Uses `AgentsWeb.ConnCase`

- [x] ✓ **GREEN**: Update `apps/agents_web/lib/live/sessions/index.html.heex`
  - **Triage column** (around line 430-455): Replace flat `idle_tickets` iteration with hierarchical rendering:
    - Root tickets (`Ticket.root_ticket?/1`): render with `data-ticket-depth="0"`, `data-has-subissues` attribute
    - Parent tickets: add toggle button `data-testid="triage-parent-toggle"`, subticket count badge
    - Subtickets: render inside `data-testid="triage-subticket-list"` container, with `data-ticket-depth="1"`, `subticket-card` class
    - Collapse state: use `@collapsed_parents` MapSet to show/hide subticket lists
  - **Ticket detail panel** (around line 1084-1112): Add:
    - `data-testid="ticket-detail-panel"` on the detail container
    - `data-testid="ticket-detail-body"` on the body section
    - `data-testid="ticket-detail-labels"` on the labels section
    - "Sub-issues" section (`data-testid="ticket-detail-subissues"`) when `Ticket.has_sub_tickets?/1`
    - Individual subticket items: `data-testid="ticket-subissue-item-{number}"` with click handler
    - `data-ticket-type="subticket"` when viewing a subticket
    - `data-ticket-state` attribute on ticket cards
    - Breadcrumb `data-testid="ticket-detail-parent-breadcrumb"` when viewing a subticket
    - Closed parent summary: "2/3 closed" via `TicketHierarchyPolicy.sub_ticket_summary_text/1`

- [x] ✓ **REFACTOR**: Extract ticket tree rendering into a reusable component if template gets too complex

### 2.9 Components: ticket_card subticket variant

- [x] ✓ **RED**: Write tests in `apps/agents_web/test/live/sessions/components/session_components_test.exs`
  - Tests `ticket_card/1` renders `data-ticket-depth` attribute based on new `depth` assign
  - Tests `ticket_card/1` applies `subticket-card` class when `depth > 0`
  - Tests `ticket_card/1` renders subticket count indicator when `Ticket.has_sub_tickets?/1`
  - Tests `ticket_card/1` renders indented styling for depth > 0

- [x] ✓ **GREEN**: Update `apps/agents_web/lib/live/sessions/components/session_components.ex`
  - Add `attr(:depth, :integer, default: 0)` to `ticket_card/1`
  - Add `data-ticket-depth={@depth}` attribute to the card wrapper div
  - Add `data-has-subissues={Ticket.has_sub_tickets?(@ticket) || nil}` attribute
  - Add `data-ticket-state={@ticket.state}` attribute
  - Add `subticket-card` class when `@depth > 0`
  - Add subticket count badge: "N sub-issues" text when `has_sub_tickets?`
  - Apply indentation styling for subtickets (e.g., `ml-4` for depth 1)
  - Reduce visual prominence for subtickets (smaller text, lighter border)

- [x] ✓ **REFACTOR**: Ensure no regression in existing ticket_card variants (:triage, :queued, :warm, :in_progress)

### 2.10 TriageLaneDnd Hook: Subticket drag-and-drop awareness

- [x] ✓ **RED**: Write test (manual verification via BDD feature file scenario 8)
  - Subtickets at `data-ticket-depth='1'` have `draggable="true"` attribute
  - Dragging a subticket reorders within its parent group only
  - `reorder_triage_tickets` event includes both root and sub ticket numbers in correct order

- [x] ✓ **GREEN**: Update `apps/agents_web/assets/js/presentation/hooks/triage-lane-dnd-hook.ts`
  - Update `collectTicketOrder` to include subticket ordering within parent groups
  - Ensure subticket cards (`data-ticket-depth='1'`) are draggable within their parent's `triage-subticket-list` container
  - Prevent subtickets from being dragged to root level or to a different parent group
  - Update drop logic to respect parent-child grouping boundaries

- [x] ✓ **REFACTOR**: Ensure existing flat drag-and-drop still works for root tickets

### 2.11 Boundary Export Update

- [ ] ⏸ Update `apps/agents/lib/agents/sessions.ex` boundary exports to include `Ticket` entity:
  ```elixir
  exports: [
    {Domain.Entities.Task, []},
    {Domain.Entities.Ticket, []}
  ]
  ```

### Phase 2 Validation

- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ All interface tests pass
- [ ] ⏸ Migration runs successfully (`mix ecto.migrate`)
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ Pre-commit checks pass (`mix precommit`)

---

## Phase 3: Integration Verification (no TypeScript domain/application phases needed)

### 3.1 BDD Feature File Verification

- [ ] ⏸ All 10 BDD scenarios in `ticket-subticket-hierarchy.browser.feature` pass:
  1. Root tickets display at top level in triage column
  2. Parent ticket shows subticket count indicator
  3. Subtickets render nested under parent ticket
  4. Collapsible parent ticket in triage column
  5. Viewing parent ticket detail shows subticket list
  6. Clicking a subticket in detail panel navigates to its detail
  7. Closed parent ticket shows subticket state summary
  8. Subticket drag-and-drop within parent group
  9. Viewing a subticket shows breadcrumb to parent
  10. Ticket hierarchy reflects GitHub sub-issue sync

### 3.2 Regression Verification

- [ ] ⏸ Existing ticket tests pass unchanged or with minimal updates
- [ ] ⏸ Existing drag-and-drop (flat reorder) continues to work for root tickets
- [ ] ⏸ Existing ticket sync (TicketSyncServer polls) continues to work
- [ ] ⏸ Existing ticket detail panel renders correctly for non-parent tickets
- [ ] ⏸ Existing enrichment (task↔ticket matching) continues to work

---

## Testing Strategy

### Test Distribution

| Layer | Files | Estimated Tests |
|-------|-------|----------------|
| **Domain: Entities** | `ticket_test.exs` | ~15 tests |
| **Domain: Policies** | `ticket_hierarchy_policy_test.exs` | ~10 tests |
| **Domain: Policies** | `ticket_enrichment_policy_test.exs` | ~8 tests |
| **Infrastructure: Schema** | `project_ticket_schema_test.exs` | ~5 tests (new) |
| **Infrastructure: Repository** | `project_ticket_repository_test.exs` | ~8 tests (added) |
| **Infrastructure: Client** | `github_project_client_test.exs` | ~5 tests |
| **Infrastructure: Sync** | `ticket_sync_server_test.exs` | ~7 tests |
| **Facade** | `sessions_test.exs` | ~5 tests (updated) |
| **Interface: LiveView** | `index_test.exs` | ~12 tests (updated/new) |
| **Interface: Components** | `session_components_test.exs` | ~5 tests (new) |
| **Total** | | **~80 tests** |

### Test Characteristics

- **Domain tests (33 tests)**: Pure functions, async: true, millisecond execution, no DB
- **Infrastructure tests (25 tests)**: DataCase, async: true, DB interactions
- **Interface tests (17 tests)**: ConnCase, LiveView rendering + events
- **Integration tests (5 tests)**: End-to-end facade tests with DB

### Test Pyramid Adherence

```
         /  Interface (17)  \
        / Infrastructure (25) \
       /     Domain (33)        \
      /__________________________\
```

Most tests are in the domain layer (fast, pure), with progressively fewer in outer layers.

---

## Implementation Notes

### Data Model Details

The `parent_ticket_id` self-reference uses integer IDs (not binary_id) because `sessions_project_tickets` uses auto-incrementing integer primary keys. This differs from the `parent_task_id` pattern which uses `type: :binary_id`.

```sql
ALTER TABLE sessions_project_tickets
  ADD COLUMN parent_ticket_id INTEGER REFERENCES sessions_project_tickets(id) ON DELETE SET NULL;
CREATE INDEX sessions_project_tickets_parent_ticket_id_index ON sessions_project_tickets(parent_ticket_id);
```

### Enrichment Consolidation

Currently enrichment logic is duplicated in:
1. `Sessions.list_project_tickets/2` (facade, ~25 lines)
2. `AgentsWeb.SessionsLive.Index.re_enrich_tickets/2` (LiveView, ~25 lines)

This plan consolidates both into `TicketEnrichmentPolicy.enrich_all/2` (domain policy, pure function). The LiveView's `re_enrich_tickets/2` is replaced by `TicketEnrichmentPolicy.enrich_all(tickets, tasks)`, preserving the in-memory re-enrichment pattern without DB round-trips.

### GitHub Sub-Issue Fetch Strategy

Use the REST sub-issues endpoint (`GET /repos/{owner}/{repo}/issues/{issue_number}/sub_issues`) because:
1. It's already available via REST (no new GraphQL queries needed)
2. It returns sub-issue numbers directly
3. It can be fetched per-parent-issue after the main issue list

Flow:
1. `fetch_tickets/1` returns flat list with `sub_issue_numbers` per ticket
2. `TicketSyncServer.poll_tickets/1` upserts all tickets flat
3. After upsert, builds `%{child_number => parent_number}` map from `sub_issue_numbers`
4. Calls `link_sub_tickets/1` to resolve and persist `parent_ticket_id` relationships

### Collapse State Management

Parent collapse state is managed client-side via a LiveView assign (`@collapsed_parents` MapSet). No persistence needed — collapse state resets on page load, which is acceptable for this feature's scope.

### Position Ordering with Hierarchy

Subticket positions are scoped within their parent group. The existing `reorder_positions/1` function continues to work for flat ordering. For subtickets within a parent:
- Subtickets maintain their own position values
- Drag-and-drop within a parent group sends only that parent's subticket numbers to `reorder_triage_tickets`
- The `TriageLaneDnd` hook is updated to scope drag-and-drop to within `triage-subticket-list` containers

---

## Pre-Commit Checkpoint

After completing Phase 2:

- [ ] ⏸ `mix format` passes
- [ ] ⏸ `mix credo --strict` passes
- [ ] ⏸ `mix boundary` passes (no violations)
- [ ] ⏸ `mix test` passes (all apps)
- [ ] ⏸ `mix precommit` passes

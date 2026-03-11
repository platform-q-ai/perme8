# Feature: Ticket Lifecycle Time Tracking (#402)

## App Ownership

| Artifact | Owning App | Repo | Path |
|----------|-----------|------|------|
| Domain entity (`TicketLifecycleEvent`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/domain/entities/ticket_lifecycle_event.ex` |
| Domain entity (`Ticket`) — update | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/domain/entities/ticket.ex` |
| Domain entity view (`Ticket.View`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/domain/entities/ticket/view.ex` |
| Domain policy (`TicketLifecyclePolicy`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/domain/policies/ticket_lifecycle_policy.ex` |
| Domain event (`TicketStageChanged`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/domain/events/ticket_stage_changed.ex` |
| Application use case (`RecordStageTransition`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/application/use_cases/record_stage_transition.ex` |
| Infrastructure schema (`TicketLifecycleEventSchema`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/infrastructure/schemas/ticket_lifecycle_event_schema.ex` |
| Infrastructure schema update (`ProjectTicketSchema`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex` |
| Infrastructure repository (`TicketLifecycleEventRepository`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/infrastructure/repositories/ticket_lifecycle_event_repository.ex` |
| Infrastructure repository update (`ProjectTicketRepository`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex` |
| Infrastructure sync update (`TicketSyncServer`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/infrastructure/ticket_sync_server.ex` |
| Facade update (`Agents.Tickets`) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets.ex` |
| Boundary updates (Domain, Application, Infrastructure) | `agents` | `Agents.Repo` | `apps/agents/lib/agents/tickets/{domain,application,infrastructure}.ex` |
| Migrations (2) | `agents` | `Agents.Repo` | `apps/agents/priv/repo/migrations/` |
| UI components update (`SessionComponents`) | `agents_web` | — | `apps/agents_web/lib/live/dashboard/components/session_components.ex` |
| LiveView update (`DashboardLive.Index`) | `agents_web` | — | `apps/agents_web/lib/live/dashboard/index.ex` |
| Template update (`index.html.heex`) | `agents_web` | — | `apps/agents_web/lib/live/dashboard/index.html.heex` |
| Feature files (BDD) | `agents_web` | — | `apps/agents_web/test/features/dashboard/` |
| Unit tests (entity) | `agents` | — | `apps/agents/test/agents/tickets/domain/entities/` |
| Unit tests (policy) | `agents` | — | `apps/agents/test/agents/tickets/domain/policies/` |
| Unit tests (event) | `agents` | — | `apps/agents/test/agents/tickets/domain/events/` |
| Unit tests (use case) | `agents` | — | `apps/agents/test/agents/tickets/application/use_cases/` |
| Unit tests (schema/repo) | `agents` | — | `apps/agents/test/agents/tickets/infrastructure/` |
| Unit tests (view) | `agents` | — | `apps/agents/test/agents/tickets/domain/entities/ticket/` |
| LiveView tests | `agents_web` | — | `apps/agents_web/test/live/dashboard/` |

## Overview

There is no visibility into how long tickets spend at each lifecycle stage (Open → Ready → In Progress → In Review → CI Testing → Deployed → Closed). This feature introduces a `TicketLifecycleEvent` entity, a `TicketLifecyclePolicy` for stage validation and duration calculation, a `RecordStageTransition` use case, and dashboard UI updates to display lifecycle stage badges, durations, and timeline visualisations.

**Critical architectural note**: The ticket domain lives at `Agents.Tickets` — a **separate bounded context** from `Agents.Sessions`. All new artifacts (entities, policies, events, use cases, schemas, repositories) are placed under `apps/agents/lib/agents/tickets/`, NOT under `agents/sessions/`. The `Agents.Tickets` facade at `apps/agents/lib/agents/tickets.ex` is the public API entry point.

## UI Strategy

- **LiveView coverage**: 100% — lifecycle stage badge, duration, and timeline are all server-rendered HEEx
- **TypeScript needed**: None — no client-side computation required. Duration display uses existing `DurationTimer` hook pattern or server-computed relative time strings

## Affected Boundaries

- **Owning app**: `agents`
- **Repo**: `Agents.Repo`
- **Migrations**: `apps/agents/priv/repo/migrations/`
- **Feature files**: `apps/agents_web/test/features/dashboard/`
- **Primary context**: `Agents.Tickets`
- **Dependencies**: `Agents.Sessions` (for task/session enrichment, already a dependency), `Perme8.Events` (for domain event emission)
- **Exported schemas**: `Entities.Ticket` (already exported), `Entities.TicketLifecycleEvent` (new export)
- **New context needed?**: No — this belongs within `Agents.Tickets`, which is already its own bounded context

## Lifecycle Stages

The 7 lifecycle stages as an ordered enum:

| Stage | Label | Description |
|-------|-------|-------------|
| `open` | Open | Newly synced from GitHub, not yet triaged |
| `ready` | Ready | Triaged and ready for work |
| `in_progress` | In Progress | Actively being worked on (task running) |
| `in_review` | In Review | Work completed, under review |
| `ci_testing` | CI Testing | CI/CD pipeline running |
| `deployed` | Deployed | Deployed to production |
| `closed` | Closed | Issue closed |

## BDD Scenario Coverage

The feature file at `apps/agents_web/test/features/dashboard/ticket-lifecycle-tracking.browser.feature` defines 10 scenarios. The implementation must satisfy all of them:

| # | Scenario | Key Assertions | Drives |
|---|----------|---------------|--------|
| 1 | Unauthenticated redirect | URL contains `/users/log-in` | Auth (pre-existing) |
| 2 | Invalid credentials error | "Invalid email or password" visible | Auth (pre-existing) |
| 3 | Stage badge display | `[data-testid='ticket-lifecycle-stage']` shows "In Progress" | `Ticket.View.lifecycle_stage_label/1`, ticket card component |
| 4 | Duration display | `[data-testid='ticket-lifecycle-duration']` contains "2h" | `Ticket.View.current_stage_duration/2`, ticket card component |
| 5 | All 7 stage labels | Each `[data-lifecycle-stage='X']` card shows correct label | `Ticket.View.lifecycle_stage_label/1`, `data-lifecycle-stage` attr |
| 6 | Lifecycle timeline in detail tab | `[data-testid='ticket-lifecycle-timeline']` visible with 3 stages | Timeline component in ticket detail tab |
| 7 | Relative duration bars | `[data-testid='ticket-lifecycle-duration-bar']` with `data-relative-width` | `TicketLifecyclePolicy.calculate_relative_durations/1`, timeline bars |
| 8 | Real-time stage transition | Stage changes from "In Progress" to "In Review", duration resets | PubSub `handle_info`, stage transition broadcast |
| 9 | Newly synced ticket default | Shows "Open" with duration | Initial lifecycle event on sync |
| 10 | Closed ticket final stage | Shows "Closed" with duration | Stage tracking for closed state |
| (implied by 10) | No lifecycle events default | Shows "Open" | Default `lifecycle_stage: "open"` on Ticket entity |

### BDD DOM Requirements

The feature file selectors require these new data attributes and test IDs on ticket cards:

- `data-testid="triage-ticket-item"` — **NOTE**: The BDD selectors use `triage-ticket-item` WITHOUT the number suffix for `:first-child` selectors. The existing `ticket_card_test_id/2` generates `"triage-ticket-item-#{number}"`. The template wrapper `<li>` already has `data-triage-ticket-item` but the feature expects `data-testid="triage-ticket-item"` on the parent element. **Resolution**: Add `data-testid="triage-ticket-item"` to the `<li>` wrapper element in the template.
- `data-lifecycle-stage="open|ready|in_progress|..."` — New attribute on the ticket card or its wrapper
- `data-ticket-id="ticket-402"` / `data-ticket-id="newly-synced-ticket"` — New attribute for specific ticket identification (fixture-driven)
- `data-testid="ticket-lifecycle-stage"` — Span element showing the human-readable stage label
- `data-testid="ticket-lifecycle-duration"` — Span element showing the time in current stage
- `data-testid="ticket-lifecycle-timeline"` — Container for the lifecycle timeline in the ticket detail tab
- `data-testid="ticket-lifecycle-timeline-stage"` — Individual stage entries in the timeline
- `data-testid="ticket-lifecycle-timeline-stage-duration"` — Duration label within a timeline stage
- `data-testid="ticket-lifecycle-duration-bar"` — Visual duration bar with `data-stage` and `data-relative-width` attributes
- `data-testid="simulate-ticket-transition-in-progress-to-in-review"` — Fixture-driven button for real-time transition testing

---

## Phase 1: Domain + Application (phoenix-tdd) ✓

### 1.1 TicketLifecycleEvent Entity

- [x] ✓ **RED**: Write test `apps/agents/test/agents/tickets/domain/entities/ticket_lifecycle_event_test.exs`
  - Tests:
    - `new/1` creates a struct with all fields from attributes map
    - `new/1` handles nil fields gracefully
    - `from_schema/1` converts a schema-like struct to the domain entity
    - `from_schema/1` maps all fields correctly (id, ticket_id, from_stage, to_stage, transitioned_at, trigger, inserted_at)
    - Default trigger is `"system"`
  - Use `ExUnit.Case, async: true` — no database needed
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/entities/ticket_lifecycle_event.ex`
  - Module: `Agents.Tickets.Domain.Entities.TicketLifecycleEvent`
  - Pure struct with `defstruct`: `:id`, `:ticket_id`, `:from_stage`, `:to_stage`, `:transitioned_at`, `trigger: "system"`, `:inserted_at`
  - `@type t` typespec
  - `new/1` — creates struct from attributes
  - `from_schema/1` — converts infrastructure schema to domain entity
- [x] ✓ **REFACTOR**: Extract shared attribute mapping logic if applicable

### 1.2 Ticket Entity Update — Add Lifecycle Fields

- [x] ✓ **RED**: Write/update test `apps/agents/test/agents/tickets/domain/entities/ticket_test.exs`
  - Tests:
    - `new/1` includes `lifecycle_stage` defaulting to `"open"`
    - `new/1` includes `lifecycle_stage_entered_at` defaulting to nil
    - `new/1` includes `lifecycle_events` defaulting to `[]`
    - `from_schema/1` maps `lifecycle_stage`, `lifecycle_stage_entered_at`, and preloaded `lifecycle_events` (converting via `TicketLifecycleEvent.from_schema/1`)
    - Existing tests continue to pass with new fields
  - Use `ExUnit.Case, async: true`
- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/tickets/domain/entities/ticket.ex`
  - Add to `defstruct`: `lifecycle_stage: "open"`, `:lifecycle_stage_entered_at`, `lifecycle_events: []`
  - Add to `@type t`: `lifecycle_stage: String.t()`, `lifecycle_stage_entered_at: DateTime.t() | nil`, `lifecycle_events: [TicketLifecycleEvent.t()]`
  - Update `from_schema/1` to map `lifecycle_stage`, `lifecycle_stage_entered_at`, and convert `lifecycle_events` association (handling `%Ecto.Association.NotLoaded{}` gracefully → default `[]`)
- [x] ✓ **REFACTOR**: Ensure `from_schema/1` handles `Ecto.Association.NotLoaded` → `[]` for lifecycle_events

### 1.3 TicketLifecyclePolicy — Stage Validation and Duration Calculation

- [x] ✓ **RED**: Write test `apps/agents/test/agents/tickets/domain/policies/ticket_lifecycle_policy_test.exs`
  - Tests:
    - `valid_stage?/1` returns true for all 7 stages ("open", "ready", "in_progress", "in_review", "ci_testing", "deployed", "closed")
    - `valid_stage?/1` returns false for invalid strings ("unknown", "", nil)
    - `valid_transition?/2` rejects same-stage transitions (returns `{:error, :same_stage}`)
    - `valid_transition?/2` accepts any valid-stage to valid-stage transition (stages are not strictly ordered — they record what actually happened)
    - `valid_transition?/2` rejects transitions involving invalid stage names
    - `calculate_stage_durations/1` computes time in each stage from ordered lifecycle events
    - `calculate_stage_durations/1` returns `[]` for empty event list
    - `calculate_stage_durations/1` handles single event (current stage has duration from `transitioned_at` to now)
    - `calculate_stage_durations/2` accepts optional `now` parameter for deterministic testing
    - `calculate_stage_durations/1` returns `[{stage, duration_seconds}]` tuples ordered by occurrence
    - `calculate_relative_durations/1` converts absolute durations to percentage-based relative widths (0-100 scale)
    - `calculate_relative_durations/1` returns `[]` for empty input
    - `stage_label/1` returns human-readable label for each stage ("Open", "Ready", "In Progress", "In Review", "CI Testing", "Deployed", "Closed")
    - `stage_color/1` returns a color identifier for each stage (for UI badge rendering)
  - Use `ExUnit.Case, async: true` — ALL pure functions, zero I/O
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/policies/ticket_lifecycle_policy.ex`
  - Module: `Agents.Tickets.Domain.Policies.TicketLifecyclePolicy`
  - `@valid_stages ["open", "ready", "in_progress", "in_review", "ci_testing", "deployed", "closed"]`
  - `valid_stage?/1` — returns boolean
  - `valid_transition?/2` — returns `:ok` or `{:error, reason}` (`:same_stage`, `:invalid_from_stage`, `:invalid_to_stage`)
  - `calculate_stage_durations/1` and `calculate_stage_durations/2` — computes `[{stage_name, duration_seconds}]` from ordered lifecycle events
  - `calculate_relative_durations/1` — takes `[{stage, seconds}]`, returns `[{stage, relative_width}]` where widths are percentages (0-100)
  - `stage_label/1` — returns human-readable label for a stage string
  - `stage_color/1` — returns CSS-friendly color identifier for each stage
- [x] ✓ **REFACTOR**: Extract helper for duration arithmetic if needed

### 1.4 Ticket.View — Pure Display Formatting

- [x] ✓ **RED**: Write test `apps/agents/test/agents/tickets/domain/entities/ticket/view_test.exs`
  - Tests:
    - `lifecycle_stage_label/1` returns formatted label from ticket's `lifecycle_stage` (delegates to `TicketLifecyclePolicy.stage_label/1`)
    - `lifecycle_stage_color/1` returns color identifier from ticket's `lifecycle_stage`
    - `current_stage_duration/2` returns human-readable duration string ("2h 15m", "0m", "3d 4h") from ticket's `lifecycle_stage_entered_at` and a reference `now` timestamp
    - `current_stage_duration/2` returns "0m" when `lifecycle_stage_entered_at` is nil (or very recent)
    - `lifecycle_summary/1` returns ordered list of `%{stage: stage, duration_seconds: seconds, label: label}` maps
    - `lifecycle_timeline_data/1` returns data for rendering timeline bars including relative widths
    - `format_duration/1` formats seconds into human-readable strings ("2h 15m", "3d", "45m", "0m")
  - Use `ExUnit.Case, async: true` — pure functions
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/entities/ticket/view.ex`
  - Module: `Agents.Tickets.Domain.Entities.Ticket.View`
  - `lifecycle_stage_label/1` — accepts ticket, returns label string
  - `lifecycle_stage_color/1` — accepts ticket, returns color string
  - `current_stage_duration/2` — accepts ticket + now, returns formatted duration
  - `lifecycle_summary/1` — accepts ticket with lifecycle_events, returns stage duration summary
  - `lifecycle_timeline_data/1` — returns timeline bars with relative widths
  - `format_duration/1` — pure seconds-to-string formatter
  - All functions delegate to `TicketLifecyclePolicy` for calculations, then format for display
- [x] ✓ **REFACTOR**: Ensure consistent duration formatting

### 1.5 TicketStageChanged Domain Event

- [x] ✓ **RED**: Write test `apps/agents/test/agents/tickets/domain/events/ticket_stage_changed_test.exs`
  - Tests:
    - Event struct can be created with required fields
    - Required fields: `:ticket_id`, `:from_stage`, `:to_stage`
    - Optional fields include `:trigger`
    - Event has `aggregate_type: "ticket"`
    - Follows `Perme8.Events.DomainEvent` macro pattern (has `event_id`, `event_type`, `occurred_at`, `metadata`)
  - Use `ExUnit.Case, async: true`
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/tickets/domain/events/ticket_stage_changed.ex`
  - Module: `Agents.Tickets.Domain.Events.TicketStageChanged`
  - ```elixir
    use Perme8.Events.DomainEvent,
      aggregate_type: "ticket",
      fields: [ticket_id: nil, from_stage: nil, to_stage: nil, trigger: "system"],
      required: [:ticket_id, :from_stage, :to_stage]
    ```
- [x] ✓ **REFACTOR**: Verify event matches patterns in `Agents.Sessions.Domain.Events.*`

### 1.6 RecordStageTransition Use Case

- [x] ✓ **RED**: Write test `apps/agents/test/agents/tickets/application/use_cases/record_stage_transition_test.exs`
  - Tests:
    - Successfully records a stage transition: creates lifecycle event + updates ticket's `lifecycle_stage` and `lifecycle_stage_entered_at`
    - Rejects same-stage transition (returns `{:error, :same_stage}`)
    - Rejects invalid stage names (returns `{:error, :invalid_from_stage}` or `{:error, :invalid_to_stage}`)
    - Emits `TicketStageChanged` domain event after successful transaction
    - Does NOT emit event on failure
    - Accepts dependency injection: `ticket_repo`, `lifecycle_repo`, `event_bus` via opts
    - Creates lifecycle event with correct `from_stage`, `to_stage`, `transitioned_at`, `trigger`
    - Default trigger is `"system"`, accepts `"sync"` and `"manual"` overrides
    - Returns `{:ok, %{ticket: updated_ticket, lifecycle_event: event}}`
    - Handles ticket not found gracefully (returns `{:error, :ticket_not_found}`)
  - Use `Agents.DataCase, async: true` with Mox mocks for repos and event bus
  - Mock setup: define `MockTicketRepo`, `MockLifecycleRepo`, `MockEventBus` behaviours
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/tickets/application/use_cases/record_stage_transition.ex`
  - Module: `Agents.Tickets.Application.UseCases.RecordStageTransition`
  - Pattern:
    ```elixir
    @default_ticket_repo Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
    @default_lifecycle_repo Agents.Tickets.Infrastructure.Repositories.TicketLifecycleEventRepository
    @default_event_bus Perme8.Events.EventBus

    def execute(ticket_id, to_stage, opts \\ []) do
      ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
      lifecycle_repo = Keyword.get(opts, :lifecycle_repo, @default_lifecycle_repo)
      event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
      trigger = Keyword.get(opts, :trigger, "system")
      now = Keyword.get(opts, :now, DateTime.utc_now() |> DateTime.truncate(:second))

      # 1. Load ticket, validate transition
      # 2. Wrap in Repo.transaction: insert lifecycle event + update ticket
      # 3. Emit TicketStageChanged event AFTER transaction commits
    end
    ```
- [x] ✓ **REFACTOR**: Extract validation logic into policy calls

### Phase 1 Validation

- [x] ✓ All domain tests pass (`mix test apps/agents/test/agents/tickets/domain/` — milliseconds, no I/O)
- [x] ✓ All application tests pass (`mix test apps/agents/test/agents/tickets/application/` — with mocks)
- [x] ✓ No boundary violations (`mix boundary`)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd) ⏳

### 2.1 Migration — Create `sessions_ticket_lifecycle_events` Table

- [x] ✓ Create `apps/agents/priv/repo/migrations/YYYYMMDDHHMMSS_create_sessions_ticket_lifecycle_events.exs`
  - Table: `sessions_ticket_lifecycle_events`
  - Columns: `id` (bigserial PK), `ticket_id` (bigint NOT NULL, FK → `sessions_project_tickets(id)` ON DELETE CASCADE), `from_stage` (varchar, nullable), `to_stage` (varchar NOT NULL), `transitioned_at` (utc_datetime NOT NULL), `trigger` (varchar NOT NULL, default "system"), `inserted_at` (utc_datetime NOT NULL)
  - Indexes: `index(:sessions_ticket_lifecycle_events, [:ticket_id])`, `index(:sessions_ticket_lifecycle_events, [:ticket_id, :transitioned_at])`

### 2.2 Migration — Add Lifecycle Columns to `sessions_project_tickets`

- [x] ✓ Create `apps/agents/priv/repo/migrations/YYYYMMDDHHMMSS_add_lifecycle_stage_to_project_tickets.exs`
  - Add column `lifecycle_stage` (varchar, NOT NULL, default "open")
  - Add column `lifecycle_stage_entered_at` (utc_datetime, nullable)

### 2.3 TicketLifecycleEventSchema

- [x] ✓ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/schemas/ticket_lifecycle_event_schema_test.exs`
  - Tests:
    - Valid changeset with all required fields (ticket_id, to_stage, transitioned_at)
    - Invalid changeset when `to_stage` is missing
    - Invalid changeset when `ticket_id` is missing
    - `trigger` defaults to `"system"` when not provided
    - Accepts valid trigger values: `"system"`, `"sync"`, `"manual"`
  - Use `Agents.DataCase, async: true`
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/tickets/infrastructure/schemas/ticket_lifecycle_event_schema.ex`
  - Module: `Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema`
  - ```elixir
    use Ecto.Schema
    import Ecto.Changeset

    schema "sessions_ticket_lifecycle_events" do
      field(:from_stage, :string)
      field(:to_stage, :string)
      field(:transitioned_at, :utc_datetime)
      field(:trigger, :string, default: "system")
      belongs_to(:ticket, Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema)
      timestamps(type: :utc_datetime, updated_at: false)
    end

    def changeset(event, attrs) do
      event
      |> cast(attrs, [:ticket_id, :from_stage, :to_stage, :transitioned_at, :trigger])
      |> validate_required([:ticket_id, :to_stage, :transitioned_at])
      |> validate_inclusion(:trigger, ["system", "sync", "manual"])
      |> foreign_key_constraint(:ticket_id)
    end
    ```
- [x] ✓ **REFACTOR**: Clean up

### 2.4 ProjectTicketSchema Update — Add Lifecycle Fields + Association

- [x] ✓ **RED**: Write/update test `apps/agents/test/agents/tickets/infrastructure/schemas/project_ticket_schema_test.exs`
  - Tests:
    - Schema includes `lifecycle_stage` field with default `"open"`
    - Schema includes `lifecycle_stage_entered_at` field (nullable)
    - Schema has `has_many :lifecycle_events` association
    - Changeset accepts `lifecycle_stage` and `lifecycle_stage_entered_at`
    - Changeset validates `lifecycle_stage` is one of the 7 valid stages
  - Use `Agents.DataCase, async: true`
- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex`
  - Add fields: `field(:lifecycle_stage, :string, default: "open")`, `field(:lifecycle_stage_entered_at, :utc_datetime)`
  - Add association: `has_many(:lifecycle_events, Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema, foreign_key: :ticket_id)`
  - Update `changeset/2` to cast `[:lifecycle_stage, :lifecycle_stage_entered_at]`
  - Add validation: `validate_inclusion(:lifecycle_stage, @lifecycle_stages)` where `@lifecycle_stages ["open", "ready", "in_progress", "in_review", "ci_testing", "deployed", "closed"]`
  - Update `@type t` to include new fields
- [x] ✓ **REFACTOR**: Keep changeset clean, extract stage constants if shared

### 2.5 TicketLifecycleEventRepository

- [x] ✓ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/repositories/ticket_lifecycle_event_repository_test.exs`
  - Tests:
    - `create/1` inserts a lifecycle event and returns `{:ok, schema}`
    - `list_for_ticket/1` returns ordered lifecycle events for a ticket (oldest first)
    - `list_for_ticket/1` returns `[]` for ticket with no events
    - `latest_for_ticket/1` returns the most recent event or nil
  - Use `Agents.DataCase` (requires DB)
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/tickets/infrastructure/repositories/ticket_lifecycle_event_repository.ex`
  - Module: `Agents.Tickets.Infrastructure.Repositories.TicketLifecycleEventRepository`
  - `create/1` — inserts a `TicketLifecycleEventSchema` changeset
  - `list_for_ticket/1` — queries events ordered by `transitioned_at` ASC
  - `latest_for_ticket/1` — returns most recent event
- [x] ✓ **REFACTOR**: Clean up

### 2.6 ProjectTicketRepository Update — Preload Lifecycle Events

- [x] ✓ **RED**: Write/update test `apps/agents/test/agents/tickets/infrastructure/repositories/project_ticket_repository_test.exs`
  - Tests:
    - `list_all/0` preloads `lifecycle_events` ordered by `transitioned_at`
    - `get_by_id/1` (new function) returns ticket with preloaded lifecycle events, or nil
    - `update_lifecycle_stage/3` atomically updates `lifecycle_stage` and `lifecycle_stage_entered_at`
  - Use `Agents.DataCase`
- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex`
  - Update `list_all/0` to preload `:lifecycle_events` ordered by `transitioned_at`
  - Add `get_by_id/1` — loads a single ticket by ID with preloaded lifecycle events
  - Add `update_lifecycle_stage/3` — updates `lifecycle_stage` and `lifecycle_stage_entered_at` on a ticket
- [x] ✓ **REFACTOR**: Ensure preload is efficient (single query)

### 2.7 Boundary Updates

- [x] ✓ Update `apps/agents/lib/agents/tickets/domain.ex` — Add exports:
  - `Entities.TicketLifecycleEvent`
  - `Entities.Ticket.View`
  - `Policies.TicketLifecyclePolicy`
  - `Events.TicketStageChanged`
- [x] ✓ Update `apps/agents/lib/agents/tickets/application.ex` — Add deps:
  - `Agents.Tickets.Infrastructure` (use cases need repos)
  - `Perme8.Events` (for event bus)
  - Add export: `UseCases.RecordStageTransition`
- [x] ✓ Update `apps/agents/lib/agents/tickets/infrastructure.ex` — Add exports:
  - `Schemas.TicketLifecycleEventSchema`
  - `Repositories.TicketLifecycleEventRepository`
- [x] ✓ Update `apps/agents/lib/agents/tickets.ex` (facade) — Add deps:
  - `Perme8.Events` (if not already present, for domain event types)

### 2.8 Facade Update — Agents.Tickets

- [x] ✓ **RED**: Write/update test `apps/agents/test/agents/tickets_test.exs`
  - Tests:
    - `record_ticket_stage_transition/3` delegates to `RecordStageTransition.execute/3`
    - `get_ticket_lifecycle/1` returns ticket with lifecycle events
    - `list_project_tickets/2` returns tickets with lifecycle fields populated
  - Use `Agents.DataCase`
- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/tickets.ex`
  - Add `record_ticket_stage_transition/3` — delegates to `RecordStageTransition.execute/3`
  - Add `get_ticket_lifecycle/1` — loads ticket by ID with preloaded lifecycle events, converts to domain entity
  - Ensure `list_project_tickets/2` returns tickets with `lifecycle_stage`, `lifecycle_stage_entered_at`, and `lifecycle_events` populated
- [x] ✓ **REFACTOR**: Keep facade thin

### 2.9 TicketSyncServer Update — Record Lifecycle Events on Sync

- [x] ✓ **RED**: Write/update test `apps/agents/test/agents/tickets/infrastructure/ticket_sync_server_test.exs`
  - Tests:
    - When a new ticket is synced for the first time, a lifecycle event with `from_stage: nil, to_stage: "open", trigger: "sync"` is created
    - When a ticket's state changes during sync (e.g., "open" → "closed"), a lifecycle event is recorded with `trigger: "sync"`
    - Existing ticket synced with same state does NOT create a duplicate lifecycle event
  - Use `Agents.DataCase`
- [x] ✓ **GREEN**: Update `apps/agents/lib/agents/tickets/infrastructure/ticket_sync_server.ex`
  - After `sync_remote_ticket/2` succeeds, check if the ticket is new (was just inserted) → record initial lifecycle event `{nil, "open", "sync"}`
  - After `sync_remote_ticket/2` succeeds on existing ticket, check if `state` changed → record lifecycle event `{old_stage, new_stage, "sync"}`
  - Use the `RecordStageTransition` use case or directly call the lifecycle event repository (since TicketSyncServer is in infrastructure, it can call repos directly; alternatively, call through the facade)
- [x] ✓ **REFACTOR**: Minimise changes to sync flow, keep lifecycle recording as a post-sync step

### 2.10 UI Component Updates — Ticket Card Lifecycle Badge + Duration

- [x] ✓ **RED**: Write test `apps/agents_web/test/live/dashboard/lifecycle_display_test.exs`
  - Tests:
    - Ticket card renders `[data-testid="ticket-lifecycle-stage"]` with correct stage label
    - Ticket card renders `[data-testid="ticket-lifecycle-duration"]` with formatted duration
    - Ticket card has `data-lifecycle-stage` attribute matching the ticket's lifecycle stage
    - Ticket wrapper has `data-testid="triage-ticket-item"` (without number suffix)
    - Ticket wrapper has `data-ticket-id` attribute for fixture identification
    - Ticket with `lifecycle_stage: "open"` and no `lifecycle_stage_entered_at` shows "Open" badge and "0m" duration
    - Each of the 7 stages renders the correct human-readable label
    - Duration formatting: "2h 15m", "3d 4h", "45m", "0m"
  - Use `AgentsWeb.ConnCase`
- [x] ✓ **GREEN**: Update `apps/agents_web/lib/live/dashboard/components/session_components.ex`
  - Update `ticket_card/1` to render lifecycle stage badge:
    ```heex
    <span
      :if={@ticket.lifecycle_stage}
      data-testid="ticket-lifecycle-stage"
      class={["badge badge-xs whitespace-nowrap shrink-0", lifecycle_stage_badge_class(@ticket.lifecycle_stage)]}
    >
      {Ticket.View.lifecycle_stage_label(@ticket)}
    </span>
    ```
  - Add lifecycle duration element:
    ```heex
    <span
      data-testid="ticket-lifecycle-duration"
      class="text-[0.6rem] text-base-content/40"
    >
      {Ticket.View.current_stage_duration(@ticket, DateTime.utc_now())}
    </span>
    ```
  - Add private helper `lifecycle_stage_badge_class/1` for stage-specific colors
  - Import or alias `Agents.Tickets.Domain.Entities.Ticket.View`
- [x] ✓ **REFACTOR**: Extract lifecycle display into sub-component if it grows too large

### 2.11 Template Updates — Data Attributes for BDD

- [x] ✓ **RED**: Verify BDD selectors require specific data attributes (already defined above)
- [x] ✓ **GREEN**: Update `apps/agents_web/lib/live/dashboard/index.html.heex`
  - Add `data-testid="triage-ticket-item"` to the `<li>` wrapper around each triage ticket card
  - Add `data-lifecycle-stage={ticket.lifecycle_stage}` to the `<li>` wrapper
  - Add `data-ticket-id` attribute for fixture identification (e.g., `data-ticket-id={"ticket-#{ticket.number}"}`)
  - These attributes enable the BDD selectors like `[data-testid='triage-ticket-item'][data-lifecycle-stage='open']`
- [x] ✓ **REFACTOR**: Ensure attributes don't conflict with existing data attributes

### 2.12 Lifecycle Timeline Component — Ticket Detail Tab

- [x] ✓ **RED**: Write test `apps/agents_web/test/live/dashboard/lifecycle_timeline_test.exs`
  - Tests:
    - Timeline is visible when ticket has lifecycle events and detail tab is active
    - Timeline renders correct number of `[data-testid='ticket-lifecycle-timeline-stage']` elements
    - Each stage has a `[data-testid='ticket-lifecycle-timeline-stage-duration']` element
    - Duration bars have `data-stage` and `data-relative-width` attributes
    - `data-relative-width` values sum approximately to 100 (or are proportionally correct)
    - Timeline is hidden when ticket has no lifecycle events
  - Use `AgentsWeb.ConnCase`
- [x] ✓ **GREEN**: Add `lifecycle_timeline/1` component to `apps/agents_web/lib/live/dashboard/components/session_components.ex`
  - Component accepts a ticket assign with lifecycle_events preloaded
  - Renders `[data-testid="ticket-lifecycle-timeline"]` container
  - For each completed stage: renders `[data-testid="ticket-lifecycle-timeline-stage"]` with stage label and duration
  - For each stage: renders `[data-testid="ticket-lifecycle-duration-bar"]` with `data-stage` and `data-relative-width` attributes
  - Uses `Ticket.View.lifecycle_timeline_data/1` for data derivation
  - Duration bars use Tailwind width classes or inline styles based on `data-relative-width`
- [x] ✓ **GREEN**: Update ticket detail tab in `index.html.heex` or `index.ex` to render `lifecycle_timeline/1` when the "ticket" tab is active and a ticket is selected
- [x] ✓ **REFACTOR**: Extract timeline data preparation to keep component thin

### 2.13 LiveView PubSub — Real-Time Stage Transition Updates

- [x] ✓ **RED**: Write test `apps/agents_web/test/live/dashboard/lifecycle_realtime_test.exs`
  - Tests:
    - When a `TicketStageChanged` event is broadcast, the LiveView updates the ticket's lifecycle stage in the assign
    - The ticket card re-renders with the new stage label and reset duration
    - Multiple tickets can receive independent stage transitions
  - Use `AgentsWeb.ConnCase`
- [x] ✓ **GREEN**: Update `apps/agents_web/lib/live/dashboard/index.ex`
  - Subscribe to ticket lifecycle events (already subscribes to `"sessions:tickets"`)
  - Add `handle_info/2` clause for `{:ticket_stage_changed, ticket_id, to_stage, transitioned_at}` (or pattern match on the `TicketStageChanged` domain event struct)
  - Update the matching ticket in `socket.assigns.tickets` with the new `lifecycle_stage` and `lifecycle_stage_entered_at`
  - Optionally broadcast via the existing PubSub topic or a new `"tickets:lifecycle"` topic
- [x] ✓ **REFACTOR**: Use `EventProcessor` pattern if the LiveView already uses it for event delegation

### 2.14 BDD Fixture Support

- [x] ✓ **RED**: The BDD feature file uses `?fixture=ticket_lifecycle_*` query params. These require fixture handling in the LiveView or test setup.
- [x] ✓ **GREEN**: Implement fixture handling for BDD scenarios
  - The fixture system uses query params (e.g., `?fixture=ticket_lifecycle_in_progress`) to seed the LiveView with test data
  - In `handle_params/3`, detect fixture params and override `tickets` assign with fixture data
  - This follows the pattern established by `session-lifecycle-state.browser.feature` which uses `?fixture=session_lifecycle_*`
  - Create fixture helper module or inline fixture data for each lifecycle scenario:
    - `ticket_lifecycle_in_progress` — single ticket with `lifecycle_stage: "in_progress"`
    - `ticket_lifecycle_in_progress_duration` — ticket in progress for ~2 hours
    - `ticket_lifecycle_all_stages` — 7 tickets, one per stage
    - `ticket_lifecycle_timeline` — ticket with 3 lifecycle events
    - `ticket_lifecycle_relative_durations` — ticket with 3 stages: open (10%), ready (30%), in_progress (60%)
    - `ticket_lifecycle_realtime_transition` — ticket at "in_progress" + transition simulation button
    - `ticket_lifecycle_newly_synced` — newly synced ticket at "open"
    - `ticket_lifecycle_closed` — closed ticket
    - `ticket_lifecycle_no_events` — ticket with no lifecycle events (defaults to "open")
  - Add `data-testid="simulate-ticket-transition-in-progress-to-in-review"` button (only rendered in test/fixture mode)
- [x] ✓ **REFACTOR**: Extract fixture data into a shared module if pattern grows

### Phase 2 Validation

- [x] ✓ All infrastructure tests pass (`mix test apps/agents/test/agents/tickets/infrastructure/`)
- [ ] ⏸ All interface tests pass (`mix test apps/agents_web/test/live/dashboard/`)
- [x] ✓ Migrations run (`mix ecto.migrate`)
- [x] ✓ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)

---

## Pre-Commit Checkpoint

- [ ] ⏸ Run `mix precommit` — all checks pass (compile, format, credo, boundary, tests)
- [ ] ⏸ Run `mix boundary` — no violations
- [ ] ⏸ BDD feature file scenarios pass against implemented fixtures

---

## Testing Strategy

### Total Estimated Tests: ~65-75

| Layer | Test File | Est. Tests | Async? |
|-------|-----------|-----------|--------|
| **Domain** | `ticket_lifecycle_event_test.exs` | 5 | Yes |
| **Domain** | `ticket_test.exs` (update) | 5 | Yes |
| **Domain** | `ticket_lifecycle_policy_test.exs` | 14 | Yes |
| **Domain** | `ticket/view_test.exs` | 8 | Yes |
| **Domain** | `ticket_stage_changed_test.exs` | 4 | Yes |
| **Application** | `record_stage_transition_test.exs` | 10 | Yes (mocked) |
| **Infrastructure** | `ticket_lifecycle_event_schema_test.exs` | 5 | Yes |
| **Infrastructure** | `project_ticket_schema_test.exs` (update) | 4 | Yes |
| **Infrastructure** | `ticket_lifecycle_event_repository_test.exs` | 4 | No (DB) |
| **Infrastructure** | `project_ticket_repository_test.exs` (update) | 3 | No (DB) |
| **Infrastructure** | `ticket_sync_server_test.exs` (update) | 3 | No (DB) |
| **Infrastructure** | `tickets_test.exs` (facade) | 3 | No (DB) |
| **Interface** | `lifecycle_display_test.exs` | 8 | No (ConnCase) |
| **Interface** | `lifecycle_timeline_test.exs` | 6 | No (ConnCase) |
| **Interface** | `lifecycle_realtime_test.exs` | 3 | No (ConnCase) |

### Distribution

- **Domain**: ~36 tests (pure, fast, no I/O) — ~50%
- **Application**: ~10 tests (mocked, fast) — ~14%
- **Infrastructure**: ~22 tests (DB required) — ~30%
- **Interface**: ~17 tests (ConnCase) — ~23%

---

## Key Design Decisions

1. **Lifecycle events are append-only**: Once recorded, never modified. Duration calculation derives from the ordered list of transitions.

2. **Stages are NOT strictly ordered**: A ticket can skip stages (e.g., "open" → "in_progress" directly). The only validation is rejecting same-stage transitions and invalid stage names.

3. **`Ticket.View` lives in the domain app**: It contains pure formatting functions with no Phoenix dependencies. The web layer imports and calls these functions. This keeps display logic testable without a web server.

4. **`lifecycle_events` preload is opt-in**: The `list_all/0` repository method will preload lifecycle events. For list views where only `lifecycle_stage` is needed, the column on `sessions_project_tickets` provides instant access without joining.

5. **TicketSyncServer is the initial event source**: When tickets are first synced from GitHub, the sync server records the initial "open" lifecycle event. Subsequent state changes during sync also generate events.

6. **Domain events follow existing patterns**: `TicketStageChanged` uses the same `Perme8.Events.DomainEvent` macro as `TaskCreated`, enabling future subscribers to react to lifecycle changes.

7. **BDD fixtures use query params**: Following the established pattern from `session-lifecycle-state.browser.feature`, fixtures are loaded via `?fixture=ticket_lifecycle_*` query params in `handle_params/3`.

---

## File Summary

### New Files (13)

| File | Module |
|------|--------|
| `apps/agents/lib/agents/tickets/domain/entities/ticket_lifecycle_event.ex` | `Agents.Tickets.Domain.Entities.TicketLifecycleEvent` |
| `apps/agents/lib/agents/tickets/domain/entities/ticket/view.ex` | `Agents.Tickets.Domain.Entities.Ticket.View` |
| `apps/agents/lib/agents/tickets/domain/policies/ticket_lifecycle_policy.ex` | `Agents.Tickets.Domain.Policies.TicketLifecyclePolicy` |
| `apps/agents/lib/agents/tickets/domain/events/ticket_stage_changed.ex` | `Agents.Tickets.Domain.Events.TicketStageChanged` |
| `apps/agents/lib/agents/tickets/application/use_cases/record_stage_transition.ex` | `Agents.Tickets.Application.UseCases.RecordStageTransition` |
| `apps/agents/lib/agents/tickets/infrastructure/schemas/ticket_lifecycle_event_schema.ex` | `Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema` |
| `apps/agents/lib/agents/tickets/infrastructure/repositories/ticket_lifecycle_event_repository.ex` | `Agents.Tickets.Infrastructure.Repositories.TicketLifecycleEventRepository` |
| `apps/agents/priv/repo/migrations/*_create_sessions_ticket_lifecycle_events.exs` | Migration |
| `apps/agents/priv/repo/migrations/*_add_lifecycle_stage_to_project_tickets.exs` | Migration |
| `apps/agents/test/agents/tickets/domain/entities/ticket_lifecycle_event_test.exs` | Test |
| `apps/agents/test/agents/tickets/domain/policies/ticket_lifecycle_policy_test.exs` | Test |
| `apps/agents/test/agents/tickets/domain/events/ticket_stage_changed_test.exs` | Test |
| `apps/agents/test/agents/tickets/domain/entities/ticket/view_test.exs` | Test |
| `apps/agents/test/agents/tickets/application/use_cases/record_stage_transition_test.exs` | Test |
| `apps/agents/test/agents/tickets/infrastructure/schemas/ticket_lifecycle_event_schema_test.exs` | Test |
| `apps/agents/test/agents/tickets/infrastructure/repositories/ticket_lifecycle_event_repository_test.exs` | Test |
| `apps/agents_web/test/live/dashboard/lifecycle_display_test.exs` | Test |
| `apps/agents_web/test/live/dashboard/lifecycle_timeline_test.exs` | Test |
| `apps/agents_web/test/live/dashboard/lifecycle_realtime_test.exs` | Test |

### Modified Files (10)

| File | Changes |
|------|---------|
| `apps/agents/lib/agents/tickets/domain/entities/ticket.ex` | Add `lifecycle_stage`, `lifecycle_stage_entered_at`, `lifecycle_events` fields; update `from_schema/1` |
| `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex` | Add `lifecycle_stage`, `lifecycle_stage_entered_at` fields; `has_many :lifecycle_events` |
| `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex` | Preload lifecycle events; add `get_by_id/1`, `update_lifecycle_stage/3` |
| `apps/agents/lib/agents/tickets/infrastructure/ticket_sync_server.ex` | Record lifecycle events on new ticket sync and state changes |
| `apps/agents/lib/agents/tickets.ex` | Add `record_ticket_stage_transition/3`, `get_ticket_lifecycle/1` |
| `apps/agents/lib/agents/tickets/domain.ex` | Export new entities, policy, events, view |
| `apps/agents/lib/agents/tickets/application.ex` | Add deps and exports for use cases |
| `apps/agents/lib/agents/tickets/infrastructure.ex` | Export new schema and repository |
| `apps/agents_web/lib/live/dashboard/components/session_components.ex` | Lifecycle stage badge, duration, timeline component |
| `apps/agents_web/lib/live/dashboard/index.ex` | PubSub handling for stage transitions; fixture support |
| `apps/agents_web/lib/live/dashboard/index.html.heex` | `data-testid`, `data-lifecycle-stage`, `data-ticket-id` attributes |

---

## Edge Cases

| Edge Case | Expected Behaviour | Where Handled |
|-----------|-------------------|---------------|
| Same-stage transition | Rejected with `{:error, :same_stage}`, no event created | `TicketLifecyclePolicy.valid_transition?/2` |
| New ticket with no lifecycle history | Initial event `{nil, "open", "sync"}` recorded on first sync | `TicketSyncServer` |
| Ticket deleted (cascade) | Lifecycle events deleted via FK CASCADE | Migration |
| Stage skipping (e.g., "open" → "in_progress") | Valid — stages are not strictly sequential | `TicketLifecyclePolicy.valid_transition?/2` |
| Missing `lifecycle_stage_entered_at` | Duration shows "0m" | `Ticket.View.current_stage_duration/2` |
| `lifecycle_events` not preloaded | `from_schema/1` returns `[]` for `NotLoaded` | `Ticket.from_schema/1` |
| Concurrent transitions | Last write wins (append-only events are safe) | DB-level |
| Ticket with no associated task | Lifecycle tracking still works | `RecordStageTransition` |

---

## Out of Scope

- Aggregate analytics/reporting dashboard
- GitHub Actions integration for CI/deploy stage detection
- Historical backfill for existing tickets
- Notifications/alerts for stale tickets
- Kanban board view organized by lifecycle stage
- Manual stage override from the dashboard (P2)
- Automatic stage inference from task status changes (P1 — separate follow-up)

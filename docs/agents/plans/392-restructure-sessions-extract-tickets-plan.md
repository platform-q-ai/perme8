# Feature: #392 — Restructure Sessions: Extract Tickets, Promote Dashboard

## Overview

Pure structural refactoring with **zero runtime behaviour changes**. Three objectives:

1. **Extract Tickets bounded context** — Move all ticket-related code from `Agents.Sessions` into a new `Agents.Tickets` bounded context within the `agents` app
2. **Trim Sessions** — Remove ticket exports/modules from Sessions boundaries so it owns only session/task/queue operations
3. **Promote Dashboard** — Rename `AgentsWeb.SessionsLive.*` → `AgentsWeb.DashboardLive.*` and move files from `live/sessions/` → `live/dashboard/`

## UI Strategy
- **LiveView coverage**: 100% (no new UI — pure rename/reorganisation)
- **TypeScript needed**: None

## Affected Boundaries
- **Owning app**: `agents` (domain) and `agents_web` (interface)
- **Repo**: `Agents.Repo` (unchanged — no new Repo)
- **Migrations**: None (database table `sessions_project_tickets` stays unchanged)
- **Feature files**: `apps/agents_web/test/features/sessions/` → ticket features move to `apps/agents_web/test/features/dashboard/`
- **Primary context**: `Agents.Tickets` (new), `Agents.Sessions` (trimmed)
- **Dependencies**: `Agents.Tickets.Domain` needs no external deps; `Agents.Tickets.Infrastructure` depends on `Agents.Tickets.Domain`, `Agents.Tickets.Application`, `Agents.Repo`
- **Exported schemas**: `Agents.Tickets.Domain.Entities.Ticket` replaces `Agents.Sessions.Domain.Entities.Ticket`
- **New context needed?**: Yes — Tickets is a distinct bounded context being extracted from Sessions

## Constraints
- Zero runtime behaviour changes — all tests must produce identical results
- No data migrations — `sessions_project_tickets` table name stays
- Database unchanged — only code structure changes
- Incremental safety — each phase compiles and passes tests before the next
- Regression baseline: 435 tests passing, 4 pre-existing Docker-related failures (unrelated)

---

## Phase 1: Create Tickets Bounded Context — Domain + Application Layer ⏸

**Goal**: Create the new `Agents.Tickets` namespace with all ticket domain entities, policies, and config. Move test files to match. Old modules remain as thin re-export wrappers to avoid breaking downstream code until Phase 3.

### 1.1 Create Tickets Domain Entity

- [ ] **RED**: Create test `apps/agents/test/agents/tickets/domain/entities/ticket_test.exs`
  - Copy from `apps/agents/test/agents/sessions/domain/entities/ticket_test.exs`
  - Update module name: `Agents.Tickets.Domain.Entities.TicketTest`
  - Update alias: `Agents.Tickets.Domain.Entities.Ticket`
  - All existing test cases must pass unchanged (struct creation, `from_schema/1`, predicates, defaults)
- [ ] **GREEN**: Create `apps/agents/lib/agents/tickets/domain/entities/ticket.ex`
  - Copy from `apps/agents/lib/agents/sessions/domain/entities/ticket.ex`
  - Update module: `Agents.Tickets.Domain.Entities.Ticket`
  - No internal logic changes — pure struct copy
- [ ] **REFACTOR**: Verify all ticket entity tests pass with `mix test apps/agents/test/agents/tickets/domain/entities/ticket_test.exs`

### 1.2 Create Tickets Domain Policies

#### TicketHierarchyPolicy

- [ ] **RED**: Create test `apps/agents/test/agents/tickets/domain/policies/ticket_hierarchy_policy_test.exs`
  - Copy from `apps/agents/test/agents/sessions/domain/policies/ticket_hierarchy_policy_test.exs`
  - Update module name: `Agents.Tickets.Domain.Policies.TicketHierarchyPolicyTest`
  - Update aliases: `Agents.Tickets.Domain.Entities.Ticket`, `Agents.Tickets.Domain.Policies.TicketHierarchyPolicy`
- [ ] **GREEN**: Create `apps/agents/lib/agents/tickets/domain/policies/ticket_hierarchy_policy.ex`
  - Copy from `apps/agents/lib/agents/sessions/domain/policies/ticket_hierarchy_policy.ex`
  - Update module: `Agents.Tickets.Domain.Policies.TicketHierarchyPolicy`
  - Update alias: `Agents.Tickets.Domain.Entities.Ticket`
- [ ] **REFACTOR**: Verify tests pass

#### TicketEnrichmentPolicy

- [ ] **RED**: Create test `apps/agents/test/agents/tickets/domain/policies/ticket_enrichment_policy_test.exs`
  - Copy from `apps/agents/test/agents/sessions/domain/policies/ticket_enrichment_policy_test.exs`
  - Update module name: `Agents.Tickets.Domain.Policies.TicketEnrichmentPolicyTest`
  - Update aliases: `Agents.Tickets.Domain.Entities.Ticket`, `Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy`
  - **Note**: TicketEnrichmentPolicy references `Agents.Sessions.Domain.Policies.SessionLifecyclePolicy` — this cross-context dependency is acceptable since Sessions still owns lifecycle policies; keep the reference as-is using the full module path
- [ ] **GREEN**: Create `apps/agents/lib/agents/tickets/domain/policies/ticket_enrichment_policy.ex`
  - Copy from `apps/agents/lib/agents/sessions/domain/policies/ticket_enrichment_policy.ex`
  - Update module: `Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy`
  - Update internal aliases to `Agents.Tickets.Domain.Entities.Ticket`
  - **Keep** the alias to `Agents.Sessions.Domain.Policies.SessionLifecyclePolicy` — this is a legitimate cross-context dep
- [ ] **REFACTOR**: Verify tests pass

### 1.3 Create Tickets Domain Boundary

- [ ] **GREEN**: Create `apps/agents/lib/agents/tickets/domain.ex`
  ```elixir
  defmodule Agents.Tickets.Domain do
    use Boundary,
      top_level?: true,
      deps: [Agents.Sessions.Domain],  # for SessionLifecyclePolicy (used by TicketEnrichmentPolicy)
      exports: [
        Entities.Ticket,
        Policies.TicketHierarchyPolicy,
        Policies.TicketEnrichmentPolicy
      ]
  end
  ```

### 1.4 Create Tickets Application Layer

- [ ] **GREEN**: Create `apps/agents/lib/agents/tickets/application/tickets_config.ex`
  - Module: `Agents.Tickets.Application.TicketsConfig`
  - Extract these functions from `Agents.Sessions.Application.SessionsConfig`:
    - `github_sync_enabled?/0`
    - `github_org/0`
    - `github_repo/0`
    - `github_poll_interval_ms/0`
    - `github_token/0`
    - `pubsub/0` (shared — duplicated, reads from same `:agents, :sessions` config key for now)
  - Implementation: Read from `Application.get_env(:agents, :sessions, [])` — same config key to avoid config migration
- [ ] **GREEN**: Create `apps/agents/lib/agents/tickets/application.ex`
  ```elixir
  defmodule Agents.Tickets.Application do
    use Boundary,
      top_level?: true,
      deps: [Agents.Tickets.Domain],
      exports: [TicketsConfig]
  end
  ```

### Phase 1 Validation
- [ ] All new ticket domain tests pass: `mix test apps/agents/test/agents/tickets/`
- [ ] All existing sessions tests still pass: `mix test apps/agents/test/agents/sessions/`
- [ ] Compiles cleanly: `mix compile --warnings-as-errors` (within agents app)
- [ ] No boundary violations on the new modules

---

## Phase 2: Create Tickets Infrastructure Layer ✓

**Goal**: Move infrastructure modules (schema, repository, sync server, GitHub client) into the Tickets namespace. Create the Tickets facade. Old modules stay as wrappers.

### 2.1 Create Tickets Infrastructure Schema

- [x] **RED**: Create test `apps/agents/test/agents/tickets/infrastructure/schemas/project_ticket_schema_test.exs`
  - Copy from `apps/agents/test/agents/sessions/infrastructure/schemas/project_ticket_schema_test.exs`
  - Update module name and aliases to `Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema`
- [x] **GREEN**: Create `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex`
  - Copy from `apps/agents/lib/agents/sessions/infrastructure/schemas/project_ticket_schema.ex`
  - Module: `Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema`
  - **Keep** `schema "sessions_project_tickets"` — table name unchanged
- [x] **REFACTOR**: Verify tests pass

### 2.2 Create Tickets Infrastructure Repository

- [x] **RED**: Create test `apps/agents/test/agents/tickets/infrastructure/repositories/project_ticket_repository_test.exs`
  - Copy from `apps/agents/test/agents/sessions/infrastructure/project_ticket_repository_test.exs`
  - Update module name: `Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepositoryTest`
  - Update all aliases to `Agents.Tickets.Infrastructure.*`
- [x] **GREEN**: Create `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex`
  - Copy from `apps/agents/lib/agents/sessions/infrastructure/repositories/project_ticket_repository.ex`
  - Module: `Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository`
  - Update alias: `Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema`
  - Keep `Agents.Repo` alias unchanged
- [x] **REFACTOR**: Verify tests pass

### 2.3 Create Tickets Infrastructure GitHub Client

- [x] **GREEN**: Create `apps/agents/lib/agents/tickets/infrastructure/clients/github_project_client.ex`
  - Copy from `apps/agents/lib/agents/sessions/infrastructure/clients/github_project_client.ex`
  - Module: `Agents.Tickets.Infrastructure.Clients.GithubProjectClient`
  - No internal dependency changes (standalone HTTP client)

### 2.4 Create Tickets Infrastructure Sync Server

- [x] **RED**: Create test `apps/agents/test/agents/tickets/infrastructure/ticket_sync_server_test.exs`
  - Copy from `apps/agents/test/agents/sessions/infrastructure/ticket_sync_server_test.exs`
  - Update module name: `Agents.Tickets.Infrastructure.TicketSyncServerTest`
  - Update all aliases to `Agents.Tickets.*` equivalents
  - Update test client references if needed (keep `Agents.Test.TicketSyncServerTestClient` — shared support module)
  - **Keep** PubSub topic `"sessions:tickets"` unchanged (changing topic is out of scope)
- [x] **GREEN**: Create `apps/agents/lib/agents/tickets/infrastructure/ticket_sync_server.ex`
  - Copy from `apps/agents/lib/agents/sessions/infrastructure/ticket_sync_server.ex`
  - Module: `Agents.Tickets.Infrastructure.TicketSyncServer`
  - Update all aliases:
    - `Agents.Tickets.Application.TicketsConfig` (replaces SessionsConfig for github_* functions)
    - `Agents.Tickets.Domain.Entities.Ticket`
    - `Agents.Tickets.Domain.Policies.TicketHierarchyPolicy`
    - `Agents.Tickets.Infrastructure.Clients.GithubProjectClient`
    - `Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository`
  - **Keep** `@topic "sessions:tickets"` unchanged
- [x] **REFACTOR**: Verify tests pass

### 2.5 Create Tickets Infrastructure Boundary

- [x] **GREEN**: Create `apps/agents/lib/agents/tickets/infrastructure.ex`
  ```elixir
  defmodule Agents.Tickets.Infrastructure do
    use Boundary,
      top_level?: true,
      deps: [
        Agents.Tickets.Domain,
        Agents.Tickets.Application,
        Agents.Repo
      ],
      exports: [
        Schemas.ProjectTicketSchema,
        Repositories.ProjectTicketRepository,
        TicketSyncServer
      ]
  end
  ```

### 2.6 Create Tickets Facade

- [x] **GREEN**: Create `apps/agents/lib/agents/tickets.ex`
  - Module: `Agents.Tickets`
  - Boundary declaration:
    ```elixir
    use Boundary,
      top_level?: true,
      deps: [
        Agents.Tickets.Domain,
        Agents.Tickets.Application,
        Agents.Tickets.Infrastructure,
        Agents.Sessions,          # for list_tasks dependency
        Agents.Sessions.Domain,   # for SessionLifecyclePolicy (transitive via enrichment)
        Agents.Repo
      ],
      exports: [
        {Domain.Entities.Ticket, []}
      ]
    ```
  - Public API functions (delegating to new Tickets modules):
    - `list_project_tickets/2` — from current `Agents.Sessions.list_project_tickets/2`
    - `reorder_triage_tickets/1`
    - `send_ticket_to_top/1`
    - `send_ticket_to_bottom/1`
    - `sync_tickets/0`
    - `close_project_ticket/1`
    - `link_ticket_to_task/2`
    - `unlink_ticket_from_task/1`
    - `extract_ticket_number/1`
  - **Note**: `list_project_tickets/2` calls `Agents.Sessions.list_tasks/1` for enrichment — this is an acceptable cross-context call via public API

### 2.7 Update Test Support Module

- [x] **GREEN**: Update `apps/agents/test/support/ticket_sync_server_test_client.ex`
  - If it references `Agents.Sessions.Infrastructure.*` types, update to reference `Agents.Tickets.Infrastructure.*`
  - If it's generic/agnostic, no changes needed (verify)

### Phase 2 Validation
- [x] All new ticket infrastructure tests pass: `mix test apps/agents/test/agents/tickets/`
- [x] All existing sessions tests still pass: `mix test apps/agents/test/agents/sessions/`
- [x] Compiles cleanly
- [x] No boundary violations

---

## Phase 3: Rewire Sessions → Tickets (Backend) ⏸

**Goal**: Update `Agents.Sessions` facade to delegate ticket functions to `Agents.Tickets`. Update boundary declarations to remove ticket exports from Sessions. Convert old Sessions ticket modules into thin wrappers or remove them.

### 3.1 Update Agents.Sessions Facade

- [ ] **RED**: Verify all existing `Agents.Sessions` tests still pass before changes
- [ ] **GREEN**: In `apps/agents/lib/agents/sessions.ex`:
  - Remove ticket-related aliases:
    - `Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository`
    - `Agents.Sessions.Domain.Entities.Ticket`
    - `Agents.Sessions.Domain.Policies.TicketEnrichmentPolicy`
    - `Agents.Sessions.Infrastructure.TicketSyncServer`
  - Delegate ticket functions to `Agents.Tickets`:
    ```elixir
    defdelegate list_project_tickets(user_id, opts \\ []), to: Agents.Tickets
    defdelegate reorder_triage_tickets(ordered_ticket_numbers), to: Agents.Tickets
    defdelegate send_ticket_to_top(number), to: Agents.Tickets
    defdelegate send_ticket_to_bottom(number), to: Agents.Tickets
    defdelegate sync_tickets(), to: Agents.Tickets
    defdelegate close_project_ticket(number), to: Agents.Tickets
    defdelegate link_ticket_to_task(ticket_number, task_id), to: Agents.Tickets
    defdelegate unlink_ticket_from_task(ticket_number), to: Agents.Tickets
    defdelegate extract_ticket_number(instruction), to: Agents.Tickets
    ```
  - This preserves backward compatibility — all callers still work via `Agents.Sessions.*`
- [ ] **REFACTOR**: All existing tests pass unchanged

### 3.2 Update Sessions Boundary Declarations

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions.ex` boundary:
  - Remove `{Domain.Entities.Ticket, []}` from exports
  - Add `Agents.Tickets` to deps
  ```elixir
  use Boundary,
    top_level?: true,
    deps: [
      Agents.Sessions.Domain,
      Agents.Sessions.Application,
      Agents.Sessions.Infrastructure,
      Agents.Tickets,
      Agents.Repo
    ],
    exports: [
      {Domain.Entities.Task, []}
    ]
  ```

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/domain.ex`:
  - Remove ticket exports:
    ```
    Remove: Entities.Ticket
    Remove: Policies.TicketHierarchyPolicy
    Remove: Policies.TicketEnrichmentPolicy
    ```

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure.ex`:
  - Remove ticket exports:
    ```
    Remove: Schemas.ProjectTicketSchema
    Remove: Repositories.ProjectTicketRepository
    Remove: TicketSyncServer
    ```

### 3.3 Convert Old Sessions Ticket Modules to Wrappers

To avoid breaking any remaining references during the transition, convert the old modules into thin delegation wrappers:

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/domain/entities/ticket.ex`
  - Replace full implementation with:
    ```elixir
    defmodule Agents.Sessions.Domain.Entities.Ticket do
      @moduledoc false
      # Deprecated: use Agents.Tickets.Domain.Entities.Ticket
      defdelegate new(attrs), to: Agents.Tickets.Domain.Entities.Ticket
      defdelegate from_schema(schema), to: Agents.Tickets.Domain.Entities.Ticket
      defdelegate open?(ticket), to: Agents.Tickets.Domain.Entities.Ticket
      defdelegate closed?(ticket), to: Agents.Tickets.Domain.Entities.Ticket
      defdelegate has_sub_tickets?(ticket), to: Agents.Tickets.Domain.Entities.Ticket
      defdelegate root_ticket?(ticket), to: Agents.Tickets.Domain.Entities.Ticket
      defdelegate sub_ticket?(ticket), to: Agents.Tickets.Domain.Entities.Ticket
      defdelegate valid_states(), to: Agents.Tickets.Domain.Entities.Ticket
    end
    ```
  - **Important**: The struct type itself must be `Agents.Tickets.Domain.Entities.Ticket` going forward. Callers that pattern-match on `%Agents.Sessions.Domain.Entities.Ticket{}` must be updated

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/domain/policies/ticket_hierarchy_policy.ex` — thin wrapper delegating to `Agents.Tickets.Domain.Policies.TicketHierarchyPolicy`

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/domain/policies/ticket_enrichment_policy.ex` — thin wrapper delegating to `Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy`

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/schemas/project_ticket_schema.ex` — thin wrapper or keep as-is (it defines the Ecto schema; the new module is the canonical version)
  - **Decision**: Convert to a wrapper that uses the new schema. Since the table name is hardcoded in both, both schemas point to the same table. The old module should be a simple `defdelegate` for `changeset/2`.
  - **Alternative (safer)**: Keep both schemas temporarily; remove the old one in Phase 6 cleanup.

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/repositories/project_ticket_repository.ex` — delegate all functions to `Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository`

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/ticket_sync_server.ex` — delegate `start_link/1`, `list_tickets/0`, `sync_now/0`, `close_ticket/1` to `Agents.Tickets.Infrastructure.TicketSyncServer`

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/clients/github_project_client.ex` — delegate to `Agents.Tickets.Infrastructure.Clients.GithubProjectClient`

### 3.4 Update Supervision Tree

- [ ] **GREEN**: Update `apps/agents/lib/agents/otp_app.ex`:
  - Change alias from `Agents.Sessions.Infrastructure.TicketSyncServer` to `Agents.Tickets.Infrastructure.TicketSyncServer`
  - The child spec reference in the children list uses the alias, so updating the alias is sufficient

### 3.5 Update Top-Level Agents Boundary

- [ ] **GREEN**: Update `apps/agents/lib/agents.ex` boundary:
  - Add `Agents.Tickets.Infrastructure` to deps (for supervision tree reference):
    ```elixir
    deps: [
      Agents.Domain,
      Agents.Application,
      Agents.Infrastructure,
      Agents.Sessions.Infrastructure,
      Agents.Tickets.Infrastructure,
      Agents.Repo
    ]
    ```

### 3.6 Update Old Tests to Use New Module Names

- [ ] **GREEN**: Update `apps/agents/test/agents/sessions/domain/entities/ticket_test.exs`:
  - Update aliases to use `Agents.Tickets.Domain.Entities.Ticket`
  - Keep the test module name as `Agents.Sessions.Domain.Entities.TicketTest` temporarily (or remove — the new test at `tickets/` is canonical)
  - **Decision**: Delete old test file since the new one at `tickets/` is canonical

- [ ] **GREEN**: Delete `apps/agents/test/agents/sessions/domain/policies/ticket_enrichment_policy_test.exs` (canonical version at `tickets/`)
- [ ] **GREEN**: Delete `apps/agents/test/agents/sessions/domain/policies/ticket_hierarchy_policy_test.exs` (canonical version at `tickets/`)
- [ ] **GREEN**: Delete `apps/agents/test/agents/sessions/infrastructure/schemas/project_ticket_schema_test.exs` (canonical version at `tickets/`)
- [ ] **GREEN**: Delete `apps/agents/test/agents/sessions/infrastructure/project_ticket_repository_test.exs` (canonical version at `tickets/`)
- [ ] **GREEN**: Delete `apps/agents/test/agents/sessions/infrastructure/ticket_sync_server_test.exs` (canonical version at `tickets/`)

### Phase 3 Validation
- [ ] All ticket tests pass via new paths: `mix test apps/agents/test/agents/tickets/`
- [ ] All remaining sessions tests pass: `mix test apps/agents/test/agents/sessions/`
- [ ] Compiles cleanly: `mix compile --warnings-as-errors`
- [ ] No boundary violations: `mix boundary`
- [ ] Full agents test suite passes: `mix test` (in agents app)

---

## Phase 4: Update AgentsWeb — Ticket References ⏸

**Goal**: Update all LiveView and test files that reference `Agents.Sessions.Domain.Entities.Ticket` and ticket policies to use `Agents.Tickets.*` instead.

### 4.1 Update LiveView Index

- [ ] **RED**: Verify `apps/agents_web/test/live/sessions/index_test.exs` passes before changes
- [ ] **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex`:
  - Change alias: `Agents.Sessions.Domain.Entities.Ticket` → `Agents.Tickets.Domain.Entities.Ticket`
  - Change alias: `Agents.Sessions.Domain.Policies.TicketEnrichmentPolicy` → `Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy`
  - Change alias: `Agents.Sessions.Domain.Policies.TicketHierarchyPolicy` → `Agents.Tickets.Domain.Policies.TicketHierarchyPolicy`
  - All ticket function calls still go through `Agents.Sessions` (which delegates to `Agents.Tickets`) — no function call changes needed yet
- [ ] **REFACTOR**: All LiveView tests pass

### 4.2 Update Session Components

- [ ] **GREEN**: Update `apps/agents_web/lib/live/sessions/components/session_components.ex`:
  - Change alias: `Agents.Sessions.Domain.Entities.Ticket` → `Agents.Tickets.Domain.Entities.Ticket`
  - Change alias: `Agents.Sessions.Domain.Policies.TicketHierarchyPolicy` → `Agents.Tickets.Domain.Policies.TicketHierarchyPolicy`

### 4.3 Update AgentsWeb Boundary

- [ ] **GREEN**: Update `apps/agents_web/lib/agents_web.ex` boundary:
  - Add `Agents.Tickets` and `Agents.Tickets.Domain` to deps:
    ```elixir
    use Boundary,
      deps: [
        Agents,
        Agents.Domain,
        Agents.Sessions,
        Agents.Sessions.Domain,
        Agents.Tickets,
        Agents.Tickets.Domain,
        Identity,
        IdentityWeb,
        Jarga,
        Jarga.Accounts,
        Perme8.Events
      ],
      exports: [Endpoint, Telemetry, SessionsLive.Index, AgentsLive.Index, AgentsLive.Form]
    ```

### 4.4 Update Web Test Files

- [ ] **GREEN**: Update `apps/agents_web/test/live/sessions/components/session_components_test.exs`:
  - Change alias: `Agents.Sessions.Domain.Entities.Ticket` → `Agents.Tickets.Domain.Entities.Ticket`

### Phase 4 Validation
- [ ] All `agents_web` tests pass: `mix test` (in agents_web app)
- [ ] Compiles cleanly
- [ ] No boundary violations
- [ ] Full test suite passes

---

## Phase 5: Promote Dashboard — Rename SessionsLive to DashboardLive ⏸

**Goal**: Rename all `AgentsWeb.SessionsLive.*` modules to `AgentsWeb.DashboardLive.*`, move files from `live/sessions/` to `live/dashboard/`, and update routers.

### 5.1 Create Dashboard Directory and Move Files

Source files to create (with updated module names):

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/index.ex`
  - Copy from `apps/agents_web/lib/live/sessions/index.ex`
  - Rename module: `AgentsWeb.SessionsLive.Index` → `AgentsWeb.DashboardLive.Index`
  - Update imports:
    - `AgentsWeb.SessionsLive.Components.SessionComponents` → `AgentsWeb.DashboardLive.Components.SessionComponents`
    - `AgentsWeb.SessionsLive.Components.QueueLaneComponents` → `AgentsWeb.DashboardLive.Components.QueueLaneComponents`
    - `AgentsWeb.SessionsLive.Helpers` → `AgentsWeb.DashboardLive.Helpers`
  - Update aliases:
    - `AgentsWeb.SessionsLive.EventProcessor` → `AgentsWeb.DashboardLive.EventProcessor`
    - `AgentsWeb.SessionsLive.SessionStateMachine` → `AgentsWeb.DashboardLive.SessionStateMachine`
  - **Ensure** ticket aliases already point to `Agents.Tickets.*` (done in Phase 4)

- [ ] **GREEN**: Copy `apps/agents_web/lib/live/sessions/index.html.heex` → `apps/agents_web/lib/live/dashboard/index.html.heex`
  - No module references in HEEx — just a file move

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/helpers.ex`
  - Rename module: `AgentsWeb.SessionsLive.Helpers` → `AgentsWeb.DashboardLive.Helpers`
  - Update alias: `AgentsWeb.SessionsLive.SessionStateMachine` → `AgentsWeb.DashboardLive.SessionStateMachine`

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/event_processor.ex`
  - Rename module: `AgentsWeb.SessionsLive.EventProcessor` → `AgentsWeb.DashboardLive.EventProcessor`
  - Update alias: `AgentsWeb.SessionsLive.SdkFieldResolver` → `AgentsWeb.DashboardLive.SdkFieldResolver`

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/session_state_machine.ex`
  - Rename module: `AgentsWeb.SessionsLive.SessionStateMachine` → `AgentsWeb.DashboardLive.SessionStateMachine`

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/sdk_field_resolver.ex`
  - Rename module: `AgentsWeb.SessionsLive.SdkFieldResolver` → `AgentsWeb.DashboardLive.SdkFieldResolver`

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/components/session_components.ex`
  - Rename module: `AgentsWeb.SessionsLive.Components.SessionComponents` → `AgentsWeb.DashboardLive.Components.SessionComponents`
  - Update alias: `AgentsWeb.SessionsLive.SessionStateMachine` → `AgentsWeb.DashboardLive.SessionStateMachine`
  - Update import: `AgentsWeb.SessionsLive.Helpers` → `AgentsWeb.DashboardLive.Helpers`

- [ ] **GREEN**: Create `apps/agents_web/lib/live/dashboard/components/queue_lane_components.ex`
  - Rename module: `AgentsWeb.SessionsLive.Components.QueueLaneComponents` → `AgentsWeb.DashboardLive.Components.QueueLaneComponents`

### 5.2 Convert Old SessionsLive Modules to Wrappers

To maintain backward compatibility during transition (especially for `perme8_dashboard` router):

- [ ] **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex`:
  - Replace with a thin wrapper that delegates to `AgentsWeb.DashboardLive.Index`
  - Or simply keep the old module as an alias: `defmodule AgentsWeb.SessionsLive.Index, do: defdelegate mount(p, s, sock), to: AgentsWeb.DashboardLive.Index` (etc.)
  - **Better approach**: Keep both modules temporarily; the old one uses `defdelegate` for `mount/3`, `handle_event/3`, `handle_info/2`, `render/1`
  - **Simplest approach**: Use `@moduledoc false` and `defdelegate` for LiveView callbacks

- [ ] **GREEN**: Convert remaining `apps/agents_web/lib/live/sessions/*.ex` files into thin wrappers delegating to `apps/agents_web/lib/live/dashboard/*.ex`

### 5.3 Update Routers

- [ ] **GREEN**: Update `apps/agents_web/lib/router.ex`:
  - Change route:
    ```elixir
    # Before
    live("/sessions", SessionsLive.Index, :index)
    # After
    live("/sessions", DashboardLive.Index, :index)
    ```
  - Keep the URL path `/sessions` unchanged (only the module reference changes)

- [ ] **GREEN**: Update `apps/perme8_dashboard/lib/perme8_dashboard_web/router.ex`:
  - Change route:
    ```elixir
    # Before
    live("/sessions", AgentsWeb.SessionsLive.Index, :index)
    # After
    live("/sessions", AgentsWeb.DashboardLive.Index, :index)
    ```

### 5.4 Update AgentsWeb Boundary Exports

- [ ] **GREEN**: Update `apps/agents_web/lib/agents_web.ex`:
  - Change exports:
    ```elixir
    exports: [Endpoint, Telemetry, DashboardLive.Index, AgentsLive.Index, AgentsLive.Form]
    ```

### 5.5 Move Test Files

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/index_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/index_test.exs`
  - Update module name: `AgentsWeb.DashboardLive.IndexTest` (or similar)
  - Update all module references from `SessionsLive` to `DashboardLive`
  - Update all `Agents.Sessions.Domain.Entities.Ticket` references to `Agents.Tickets.Domain.Entities.Ticket` (if not already done)
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/helpers_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/helpers_test.exs`
  - Update module names and aliases
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/components/session_components_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/components/session_components_test.exs`
  - Update module names and aliases
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/components/queue_lane_components_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/components/queue_lane_components_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/components/progress_bar_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/components/progress_bar_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/session_state_machine_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/session_state_machine_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/sdk_field_resolver_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/sdk_field_resolver_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/event_processor_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/event_processor_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/event_processor_todo_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/event_processor_todo_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/follow_up_dispatch_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/follow_up_dispatch_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/index_auth_refresh_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/index_auth_refresh_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

- [ ] **RED**: Create `apps/agents_web/test/live/dashboard/index_todo_test.exs`
  - Copy from `apps/agents_web/test/live/sessions/index_todo_test.exs`
  - Update module names
- [ ] **GREEN**: Verify tests pass

### 5.6 Move Feature Files

Feature files reference routes and selectors, not Elixir module names. Only file location changes — content may stay unchanged unless it references module paths in step definitions.

- [ ] **GREEN**: Copy ticket-related feature files to `apps/agents_web/test/features/dashboard/`:
  - `ticket-sync-sidebar.browser.feature`
  - `ticket-subticket-hierarchy.browser.feature`
  - `ticket-lane-dnd.browser.feature`
- [ ] **GREEN**: Copy remaining session feature files to `apps/agents_web/test/features/dashboard/`:
  - All remaining `*.browser.feature` and `*.security.feature` files from `sessions/`
  - **Note**: Feature file content should not need changes since URLs (`/sessions`) are unchanged

### Phase 5 Validation
- [ ] All dashboard tests pass: `mix test apps/agents_web/test/live/dashboard/`
- [ ] Router changes compile cleanly
- [ ] `perme8_dashboard` router compiles cleanly
- [ ] Feature files are in correct locations
- [ ] No boundary violations

---

## Phase 6: Cleanup — Remove Old Files ⏸

**Goal**: Delete the old `SessionsLive` source and test files, old Sessions ticket source files, and remove the wrapper modules.

### 6.1 Delete Old SessionsLive Source Files

- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/index.ex`
- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/index.html.heex`
- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/helpers.ex`
- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/event_processor.ex`
- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/session_state_machine.ex`
- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/sdk_field_resolver.ex`
- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/components/session_components.ex`
- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/components/queue_lane_components.ex`
- [ ] **GREEN**: Delete `apps/agents_web/lib/live/sessions/` directory (should be empty)

### 6.2 Delete Old SessionsLive Test Files

- [ ] **GREEN**: Delete all files in `apps/agents_web/test/live/sessions/`
- [ ] **GREEN**: Delete `apps/agents_web/test/live/sessions/` directory

### 6.3 Delete Old Feature Files

- [ ] **GREEN**: Delete all files in `apps/agents_web/test/features/sessions/`
- [ ] **GREEN**: Delete `apps/agents_web/test/features/sessions/` directory

### 6.4 Delete Old Sessions Ticket Source Files

- [ ] **GREEN**: Delete `apps/agents/lib/agents/sessions/domain/entities/ticket.ex` (wrapper)
- [ ] **GREEN**: Delete `apps/agents/lib/agents/sessions/domain/policies/ticket_hierarchy_policy.ex` (wrapper)
- [ ] **GREEN**: Delete `apps/agents/lib/agents/sessions/domain/policies/ticket_enrichment_policy.ex` (wrapper)
- [ ] **GREEN**: Delete `apps/agents/lib/agents/sessions/infrastructure/schemas/project_ticket_schema.ex` (wrapper)
- [ ] **GREEN**: Delete `apps/agents/lib/agents/sessions/infrastructure/repositories/project_ticket_repository.ex` (wrapper)
- [ ] **GREEN**: Delete `apps/agents/lib/agents/sessions/infrastructure/ticket_sync_server.ex` (wrapper)
- [ ] **GREEN**: Delete `apps/agents/lib/agents/sessions/infrastructure/clients/github_project_client.ex` (wrapper)

### 6.5 Update Sessions Facade — Remove Delegations

- [ ] **GREEN**: Update `apps/agents_web/lib/live/sessions/index.ex` boundary deps if the SessionsLive wrapper was the entry point for DashboardLive
  - **Actually**: After Phase 6.1, old SessionsLive files are deleted. The Sessions facade (`Agents.Sessions`) still has `defdelegate` wrappers for backward compatibility of any external callers. These can stay indefinitely or be removed once all callers are verified to use `Agents.Tickets` directly.

### 6.6 Update Sessions LiveView Callers to Use Tickets Directly

- [ ] **GREEN**: Update `apps/agents_web/lib/live/dashboard/index.ex`:
  - Replace `Agents.Sessions.list_project_tickets/2` calls with `Agents.Tickets.list_project_tickets/2`
  - Replace `Agents.Sessions.reorder_triage_tickets/1` with `Agents.Tickets.reorder_triage_tickets/1`
  - Replace `Agents.Sessions.send_ticket_to_top/1` with `Agents.Tickets.send_ticket_to_top/1`
  - Replace `Agents.Sessions.send_ticket_to_bottom/1` with `Agents.Tickets.send_ticket_to_bottom/1`
  - Replace `Agents.Sessions.sync_tickets/0` with `Agents.Tickets.sync_tickets/0`
  - Replace `Agents.Sessions.close_project_ticket/1` with `Agents.Tickets.close_project_ticket/1`
  - Replace `Agents.Sessions.link_ticket_to_task/2` with `Agents.Tickets.link_ticket_to_task/2`
  - Replace `Agents.Sessions.unlink_ticket_from_task/1` with `Agents.Tickets.unlink_ticket_from_task/1`
  - Replace `Agents.Sessions.extract_ticket_number/1` with `Agents.Tickets.extract_ticket_number/1`

### 6.7 Remove Ticket Delegations from Sessions Facade

- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions.ex`:
  - Remove all `defdelegate` calls for ticket functions
  - Remove `Agents.Tickets` from deps (unless still needed)
  - Sessions facade now contains only session/task/queue operations

### Phase 6 Validation
- [ ] Full compile with no warnings: `mix compile --warnings-as-errors`
- [ ] No boundary violations: `mix boundary`
- [ ] Full test suite passes: `mix test`
- [ ] No references to `AgentsWeb.SessionsLive` remain in source (only in git history)
- [ ] No references to `Agents.Sessions.Domain.Entities.Ticket` remain (only the wrapper if kept for backward compat)

---

## Pre-commit Checkpoint ⏸

- [ ] `mix precommit` passes
- [ ] `mix boundary` clean
- [ ] `mix test` — 435+ tests pass
- [ ] No regressions vs. baseline (same 4 Docker-related pre-existing failures)
- [ ] `mix compile --warnings-as-errors` clean

---

## Testing Strategy

### Test Distribution

| Layer | Location | Count (estimated) |
|-------|----------|-------------------|
| Domain (Ticket entity) | `apps/agents/test/agents/tickets/domain/entities/` | ~20 tests |
| Domain (Ticket policies) | `apps/agents/test/agents/tickets/domain/policies/` | ~35 tests |
| Infrastructure (Schema) | `apps/agents/test/agents/tickets/infrastructure/schemas/` | ~10 tests |
| Infrastructure (Repository) | `apps/agents/test/agents/tickets/infrastructure/repositories/` | ~15 tests |
| Infrastructure (SyncServer) | `apps/agents/test/agents/tickets/infrastructure/` | ~10 tests |
| Interface (DashboardLive) | `apps/agents_web/test/live/dashboard/` | ~200 tests |
| Interface (Components) | `apps/agents_web/test/live/dashboard/components/` | ~30 tests |
| Feature files | `apps/agents_web/test/features/dashboard/` | ~19 features |

**Total**: Same as current count (435 tests) — this is a pure refactor, no new tests required beyond verifying moved tests pass under new paths.

### Key Testing Risks

1. **Struct identity**: `%Agents.Sessions.Domain.Entities.Ticket{}` pattern matches will break if the struct is now `%Agents.Tickets.Domain.Entities.Ticket{}`. All pattern matches in LiveView and tests must be updated.
2. **Boundary violations**: New boundary declarations may surface previously-hidden violations. Run `mix boundary` after each phase.
3. **Router changes**: Both `agents_web` and `perme8_dashboard` routers must point to `DashboardLive.Index`. Test with both apps' test suites.
4. **PubSub topic**: `"sessions:tickets"` topic stays unchanged — verify LiveView subscription in `mount/3` matches the topic emitted by `TicketSyncServer`.

---

## File Summary

### New Files Created
| File | Phase |
|------|-------|
| `apps/agents/lib/agents/tickets.ex` | 2 |
| `apps/agents/lib/agents/tickets/domain.ex` | 1 |
| `apps/agents/lib/agents/tickets/application.ex` | 1 |
| `apps/agents/lib/agents/tickets/infrastructure.ex` | 2 |
| `apps/agents/lib/agents/tickets/domain/entities/ticket.ex` | 1 |
| `apps/agents/lib/agents/tickets/domain/policies/ticket_hierarchy_policy.ex` | 1 |
| `apps/agents/lib/agents/tickets/domain/policies/ticket_enrichment_policy.ex` | 1 |
| `apps/agents/lib/agents/tickets/application/tickets_config.ex` | 1 |
| `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex` | 2 |
| `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex` | 2 |
| `apps/agents/lib/agents/tickets/infrastructure/clients/github_project_client.ex` | 2 |
| `apps/agents/lib/agents/tickets/infrastructure/ticket_sync_server.ex` | 2 |
| `apps/agents_web/lib/live/dashboard/index.ex` | 5 |
| `apps/agents_web/lib/live/dashboard/index.html.heex` | 5 |
| `apps/agents_web/lib/live/dashboard/helpers.ex` | 5 |
| `apps/agents_web/lib/live/dashboard/event_processor.ex` | 5 |
| `apps/agents_web/lib/live/dashboard/session_state_machine.ex` | 5 |
| `apps/agents_web/lib/live/dashboard/sdk_field_resolver.ex` | 5 |
| `apps/agents_web/lib/live/dashboard/components/session_components.ex` | 5 |
| `apps/agents_web/lib/live/dashboard/components/queue_lane_components.ex` | 5 |

### Files Deleted (Phase 6)
| File | Phase |
|------|-------|
| `apps/agents/lib/agents/sessions/domain/entities/ticket.ex` | 6 |
| `apps/agents/lib/agents/sessions/domain/policies/ticket_hierarchy_policy.ex` | 6 |
| `apps/agents/lib/agents/sessions/domain/policies/ticket_enrichment_policy.ex` | 6 |
| `apps/agents/lib/agents/sessions/infrastructure/schemas/project_ticket_schema.ex` | 6 |
| `apps/agents/lib/agents/sessions/infrastructure/repositories/project_ticket_repository.ex` | 6 |
| `apps/agents/lib/agents/sessions/infrastructure/ticket_sync_server.ex` | 6 |
| `apps/agents/lib/agents/sessions/infrastructure/clients/github_project_client.ex` | 6 |
| `apps/agents_web/lib/live/sessions/` (entire directory) | 6 |
| `apps/agents_web/test/live/sessions/` (entire directory) | 6 |
| `apps/agents_web/test/features/sessions/` (entire directory) | 6 |
| `apps/agents/test/agents/sessions/domain/entities/ticket_test.exs` | 3 |
| `apps/agents/test/agents/sessions/domain/policies/ticket_*_test.exs` | 3 |
| `apps/agents/test/agents/sessions/infrastructure/ticket_sync_server_test.exs` | 3 |
| `apps/agents/test/agents/sessions/infrastructure/schemas/project_ticket_schema_test.exs` | 3 |
| `apps/agents/test/agents/sessions/infrastructure/project_ticket_repository_test.exs` | 3 |

### Files Modified
| File | Phase | Change |
|------|-------|--------|
| `apps/agents/lib/agents/sessions.ex` | 3, 6 | Remove ticket code, add delegations, then remove delegations |
| `apps/agents/lib/agents/sessions/domain.ex` | 3 | Remove ticket exports |
| `apps/agents/lib/agents/sessions/infrastructure.ex` | 3 | Remove ticket exports |
| `apps/agents/lib/agents/otp_app.ex` | 3 | Update TicketSyncServer alias |
| `apps/agents/lib/agents.ex` | 3 | Add Tickets.Infrastructure to boundary deps |
| `apps/agents_web/lib/agents_web.ex` | 4, 5 | Add Tickets deps, update LiveView exports |
| `apps/agents_web/lib/router.ex` | 5 | SessionsLive → DashboardLive |
| `apps/perme8_dashboard/lib/perme8_dashboard_web/router.ex` | 5 | SessionsLive → DashboardLive |

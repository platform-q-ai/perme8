# Feature: Rewire MCP Ticket Tools to Agents Domain Layer (#457)

## Overview

The 8 MCP ticket tools currently bypass the agents domain layer by calling `GithubProjectClient` directly via `Helpers.github_client()` and `Helpers.client_opts()`. This refactor rewires them to go through the `Agents.Tickets` facade so all changes hit the agents DB first and async-sync to GitHub. Additionally, the `ticket.comment` tool is removed (comments aren't modelled in the agents DB), GitHub client helpers are cleaned up, and 3 new dependency MCP tools are added.

## UI Strategy

- **LiveView coverage**: N/A — this is a backend/infrastructure refactor
- **TypeScript needed**: None

## Affected Boundaries

- **Owning app**: `agents`
- **Repo**: `Agents.Repo`
- **Migrations**: None required (schema already has all needed columns/associations)
- **Feature files**: N/A (MCP tool tests)
- **Primary context**: `Agents.Tickets`
- **Dependencies**: None (all within the `agents` app)
- **Exported schemas**: `Agents.Tickets.Domain.Entities.Ticket` (unchanged)
- **New context needed?**: No — all changes are within `Agents.Tickets`

## Summary of Changes

### Deletions
1. `CommentTool` module + test + fixture scope
2. `Helpers.github_client/0` and `Helpers.client_opts/0` functions + tests

### New Domain Layer Functions
1. `Agents.Tickets.get_ticket_by_number/1` — facade + repository function
2. `Agents.Tickets.update_ticket/3` — facade + use case + repository function
3. `Agents.Tickets.add_sub_issue/3` — facade + use case + repository function
4. `Agents.Tickets.remove_sub_issue/3` — facade + use case + repository function

### New Domain Events
1. `TicketUpdated` — emitted when a ticket is updated
2. `TicketSubIssueChanged` — emitted when sub-issue relationships change

### Rewired Tools (7)
1. `CreateTool` → `Agents.Tickets.create_ticket/2`
2. `ListTool` → `Agents.Tickets.list_project_tickets/2`
3. `ReadTool` → `Agents.Tickets.get_ticket_by_number/1`
4. `UpdateTool` → `Agents.Tickets.update_ticket/3`
5. `CloseTool` → `Agents.Tickets.close_project_ticket/2`
6. `AddSubIssueTool` → `Agents.Tickets.add_sub_issue/3`
7. `RemoveSubIssueTool` → `Agents.Tickets.remove_sub_issue/3`

### New Tools (3)
1. `AddDependencyTool` → `Agents.Tickets.add_dependency/3`
2. `RemoveDependencyTool` → `Agents.Tickets.remove_dependency/3`
3. `SearchDependencyTargetsTool` → `Agents.Tickets.search_tickets_for_dependency/2`

---

## Phase 1: Remove Comment Tool & GitHub Helpers Cleanup ⏸

**Goal**: Delete dead code and remove the direct GitHub client coupling from the helpers module.

### 1.1 Delete CommentTool

- [ ] ⏸ **RED**: Verify `CommentToolTest` (`apps/agents/test/agents/infrastructure/mcp/tools/ticket/comment_tool_test.exs`) exists and passes, then delete it
- [ ] ⏸ **GREEN**: Delete `CommentTool` module (`apps/agents/lib/agents/infrastructure/mcp/tools/ticket/comment_tool.ex`)
- [ ] ⏸ **GREEN**: Remove `{Ticket.CommentTool, "ticket.comment"}` from `TicketToolProvider.components/0` (`apps/agents/lib/agents/infrastructure/mcp/tool_providers/ticket_tool_provider.ex`)
- [ ] ⏸ **GREEN**: Remove `"mcp:ticket.comment"` from `api_key_struct/0` scopes in `TicketFixtures` (`apps/agents/test/support/fixtures/ticket_fixtures.ex`)
- [ ] ⏸ **GREEN**: Update `TicketToolProvider` `@moduledoc` count (from "8 GitHub ticket MCP tool components" to reflect the new count)
- [ ] ⏸ **REFACTOR**: Verify compilation succeeds and no dangling references to `CommentTool` or `ticket.comment` scope remain

### 1.2 Remove GitHub Client Helpers

- [ ] ⏸ **RED**: Verify `HelpersTest` tests for `github_client/0` and `client_opts/0` pass, then delete those test blocks from `apps/agents/test/agents/infrastructure/mcp/tools/ticket/helpers_test.exs`:
  - Delete `describe "client_opts/0"` block (lines 25-29)
  - Delete `describe "github_client/0"` block (lines 31-43)
- [ ] ⏸ **GREEN**: Remove `github_client/0` and `client_opts/0` from `Helpers` module (`apps/agents/lib/agents/infrastructure/mcp/tools/ticket/helpers.ex`)
- [ ] ⏸ **REFACTOR**: Verify no remaining tool modules reference `Helpers.github_client()` or `Helpers.client_opts()` (they will — that's fixed in Phase 3, but compilation may break temporarily; if so, leave stubbed functions that raise and remove in Phase 3)

### Phase 1 Validation

- [ ] ⏸ All tests pass with `CommentTool` and its test removed
- [ ] ⏸ No compile warnings about `CommentTool`
- [ ] ⏸ `TicketToolProvider.components/0` no longer includes `CommentTool`

**Note on ordering**: Phase 1.2 (removing `github_client/0` and `client_opts/0` from Helpers) will cause compilation failures in the 7 remaining tools that still reference them. Two approaches:
1. **Preferred**: Defer Helpers removal to Phase 3 and do it alongside the tool rewiring (remove the helper calls from each tool as you rewire it, then delete the helpers once no tool references them).
2. **Alternative**: Replace the helper functions with stubs that raise `"GitHub client helpers removed — use Agents.Tickets facade"` as a safety net during the transition.

**Recommendation**: Use approach 1 — move `Helpers.github_client/0` and `Helpers.client_opts/0` removal to Phase 3.7 (after all tools are rewired). Phase 1 only deletes `CommentTool`.

---

## Phase 2: New Domain Layer Functions ⏸

**Goal**: Build the domain layer functions needed by the rewired tools before touching any tool code. Each new function follows bottom-up TDD: repository → use case → facade.

### 2.1 Repository: `get_by_number/1`

Adds a `get_by_number/1` function to `ProjectTicketRepository` that loads a single ticket by its issue number with full preloads (lifecycle events, sub-tickets, dependencies).

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/repositories/project_ticket_repository_test.exs`
  - Add test in a new `describe "get_by_number/1"` block (or add to existing file if it exists)
  - Tests:
    - Returns `{:ok, schema}` with lifecycle_events, sub_tickets, blocking, blocked_by preloaded when ticket exists
    - Returns `nil` when no ticket with that number exists
    - Preloads sub-tickets correctly for parent tickets
- [ ] ⏸ **GREEN**: Implement `get_by_number/1` in `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex`
  ```elixir
  @spec get_by_number(integer()) :: {:ok, ProjectTicketSchema.t()} | nil
  def get_by_number(number) when is_integer(number) do
    lifecycle_events_query = lifecycle_events_query()
    sub_tickets_query =
      ProjectTicketSchema
      |> order_by([ticket], desc: ticket.position, desc: ticket.created_at)
      |> preload([ticket], lifecycle_events: ^lifecycle_events_query)

    case Repo.get_by(ProjectTicketSchema, number: number) do
      nil -> nil
      ticket ->
        {:ok, Repo.preload(ticket,
          lifecycle_events: lifecycle_events_query,
          sub_tickets: sub_tickets_query,
          blocking: [],
          blocked_by: []
        )}
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Ensure consistent return shape with `get_by_id/1`

### 2.2 Facade: `get_ticket_by_number/1`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets_test.exs` (or add to existing)
  - `describe "get_ticket_by_number/1"`
  - Tests:
    - Returns `{:ok, %Ticket{}}` entity when ticket exists (number match)
    - Returns `{:error, :ticket_not_found}` when no ticket with number
    - Entity has preloaded lifecycle_events, sub_tickets, blocks, blocked_by
- [ ] ⏸ **GREEN**: Add `get_ticket_by_number/1` to `apps/agents/lib/agents/tickets.ex`
  ```elixir
  @spec get_ticket_by_number(integer()) :: {:ok, Ticket.t()} | {:error, :ticket_not_found}
  def get_ticket_by_number(number) when is_integer(number) do
    case ProjectTicketRepository.get_by_number(number) do
      {:ok, schema} -> {:ok, Ticket.from_schema(schema)}
      nil -> {:error, :ticket_not_found}
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 2.3 Repository: `update_fields/2`

Adds a `update_fields/2` function to update arbitrary fields on a ticket by number.

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/tickets/infrastructure/repositories/project_ticket_repository_test.exs`
  - `describe "update_fields/2"`
  - Tests:
    - Updates title when ticket exists, returns `{:ok, schema}`
    - Updates body when ticket exists
    - Updates labels when ticket exists
    - Updates state when ticket exists
    - Returns `{:error, :not_found}` when ticket doesn't exist
    - Rejects invalid state values (changeset validation)
- [ ] ⏸ **GREEN**: Implement in `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex`
  ```elixir
  @spec update_fields(integer(), map()) :: {:ok, ProjectTicketSchema.t()} | {:error, :not_found} | {:error, Ecto.Changeset.t()}
  def update_fields(number, attrs) when is_integer(number) and is_map(attrs) do
    case Repo.get_by(ProjectTicketSchema, number: number) do
      nil -> {:error, :not_found}
      ticket -> ticket |> ProjectTicketSchema.changeset(attrs) |> Repo.update()
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Consider whether this subsumes `update_labels/2` and `close_by_number/1` (defer — keep existing functions for backward compat)

### 2.4 Domain Event: `TicketUpdated`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/events/ticket_updated_test.exs`
  - Tests: Creates event with required fields (ticket_id, changes), validates aggregate_type is "ticket"
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/tickets/domain/events/ticket_updated.ex`
  ```elixir
  defmodule Agents.Tickets.Domain.Events.TicketUpdated do
    use Perme8.Events.DomainEvent,
      aggregate_type: "ticket",
      fields: [ticket_id: nil, number: nil, changes: %{}],
      required: [:ticket_id, :number]
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 2.5 Use Case: `UpdateTicket`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/application/use_cases/update_ticket_test.exs`
  - `use Agents.DataCase, async: true`
  - Setup: insert a ticket via `ProjectTicketRepository.sync_remote_ticket/1`, start `TestEventBus`
  - Tests:
    - Updates ticket title locally and returns `{:ok, schema}`
    - Updates ticket body locally
    - Updates ticket labels locally
    - Sets sync_state to "pending_push" on successful update
    - Emits `TicketUpdated` domain event with correct fields
    - Returns `{:error, :not_found}` when ticket number doesn't exist
    - Returns `{:error, :no_changes}` when attrs map is empty
    - Does not emit event on failure
  - Mocks/DI: `event_bus: TestEventBus`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/tickets/application/use_cases/update_ticket.ex`
  ```elixir
  defmodule Agents.Tickets.Application.UseCases.UpdateTicket do
    alias Agents.Tickets.Domain.Events.TicketUpdated
    
    @default_event_bus Perme8.Events.EventBus
    @default_ticket_repo Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
    @default_pubsub Perme8.Events.PubSub
    @tickets_topic "sessions:tickets"
    @updatable_fields ~w(title body labels assignees state)a
    
    def execute(number, attrs, opts \\ []) do
      event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
      ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
      actor_id = Keyword.fetch!(opts, :actor_id)
      
      filtered_attrs = filter_attrs(attrs)
      
      with :ok <- validate_not_empty(filtered_attrs),
           update_attrs = Map.put(filtered_attrs, :sync_state, "pending_push"),
           {:ok, schema} <- ticket_repo.update_fields(number, update_attrs) do
        emit_event(schema, filtered_attrs, actor_id, event_bus)
        broadcast_tickets_refresh()
        {:ok, schema}
      end
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up, ensure consistent error returns

### 2.6 Facade: `update_ticket/3`

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/tickets_test.exs`
  - `describe "update_ticket/3"`
  - Tests:
    - Delegates to `UpdateTicket.execute/3` and returns `{:ok, schema}`
    - Returns `{:error, :not_found}` for missing ticket
- [ ] ⏸ **GREEN**: Add `update_ticket/3` to `apps/agents/lib/agents/tickets.ex`
  ```elixir
  alias Agents.Tickets.Application.UseCases.UpdateTicket
  
  @spec update_ticket(integer(), map(), keyword()) :: {:ok, struct()} | {:error, term()}
  def update_ticket(number, attrs, opts \\ []) do
    UpdateTicket.execute(number, attrs, opts)
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 2.7 Domain Event: `TicketSubIssueChanged`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/domain/events/ticket_sub_issue_changed_test.exs`
  - Tests: Creates event with required fields (parent_ticket_id, child_ticket_id, action), validates aggregate_type is "ticket"
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/tickets/domain/events/ticket_sub_issue_changed.ex`
  ```elixir
  defmodule Agents.Tickets.Domain.Events.TicketSubIssueChanged do
    use Perme8.Events.DomainEvent,
      aggregate_type: "ticket",
      fields: [parent_number: nil, child_number: nil, action: nil],
      required: [:parent_number, :child_number, :action]
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 2.8 Repository: `set_parent_ticket/2` and `clear_parent_ticket/1`

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/tickets/infrastructure/repositories/project_ticket_repository_test.exs`
  - `describe "set_parent_ticket/2"`
  - Tests:
    - Sets parent_ticket_id on child ticket by number, returns `{:ok, schema}`
    - Returns `{:error, :child_not_found}` when child number doesn't exist
    - Returns `{:error, :parent_not_found}` when parent number doesn't exist
  - `describe "clear_parent_ticket/1"`
  - Tests:
    - Clears parent_ticket_id on ticket by number, returns `{:ok, schema}`
    - Returns `{:error, :not_found}` when number doesn't exist
- [ ] ⏸ **GREEN**: Implement in `apps/agents/lib/agents/tickets/infrastructure/repositories/project_ticket_repository.ex`
  ```elixir
  @spec set_parent_ticket(integer(), integer()) :: {:ok, ProjectTicketSchema.t()} | {:error, :child_not_found | :parent_not_found}
  def set_parent_ticket(child_number, parent_number) do
    with {:parent, parent} when not is_nil(parent) <- {:parent, Repo.get_by(ProjectTicketSchema, number: parent_number)},
         {:child, child} when not is_nil(child) <- {:child, Repo.get_by(ProjectTicketSchema, number: child_number)} do
      child
      |> ProjectTicketSchema.changeset(%{parent_ticket_id: parent.id})
      |> Repo.update()
    else
      {:parent, nil} -> {:error, :parent_not_found}
      {:child, nil} -> {:error, :child_not_found}
    end
  end

  @spec clear_parent_ticket(integer()) :: {:ok, ProjectTicketSchema.t()} | {:error, :not_found}
  def clear_parent_ticket(child_number) do
    case Repo.get_by(ProjectTicketSchema, number: child_number) do
      nil -> {:error, :not_found}
      child -> child |> ProjectTicketSchema.changeset(%{parent_ticket_id: nil}) |> Repo.update()
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 2.9 Use Case: `AddSubIssue`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/application/use_cases/add_sub_issue_test.exs`
  - `use Agents.DataCase, async: true`
  - Setup: insert parent + child tickets, start `TestEventBus`
  - Tests:
    - Sets parent_ticket_id on child ticket, returns `{:ok, schema}`
    - Emits `TicketSubIssueChanged` event with `action: :added`
    - Sets sync_state to "pending_push" on child ticket
    - Returns `{:error, :child_not_found}` when child doesn't exist
    - Returns `{:error, :parent_not_found}` when parent doesn't exist
    - Does not emit event on failure
  - Mocks/DI: `event_bus: TestEventBus`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/tickets/application/use_cases/add_sub_issue.ex`
  ```elixir
  defmodule Agents.Tickets.Application.UseCases.AddSubIssue do
    alias Agents.Tickets.Domain.Events.TicketSubIssueChanged
    
    @default_event_bus Perme8.Events.EventBus
    @default_ticket_repo Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
    @default_pubsub Perme8.Events.PubSub
    @tickets_topic "sessions:tickets"
    
    def execute(parent_number, child_number, opts \\ []) do
      event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
      ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
      actor_id = Keyword.fetch!(opts, :actor_id)
      
      case ticket_repo.set_parent_ticket(child_number, parent_number) do
        {:ok, schema} ->
          emit_event(parent_number, child_number, :added, actor_id, event_bus)
          broadcast_tickets_refresh()
          {:ok, schema}
        error -> error
      end
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 2.10 Use Case: `RemoveSubIssue`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/application/use_cases/remove_sub_issue_test.exs`
  - `use Agents.DataCase, async: true`
  - Setup: insert parent + child tickets with parent_ticket_id set, start `TestEventBus`
  - Tests:
    - Clears parent_ticket_id on child ticket, returns `{:ok, schema}`
    - Emits `TicketSubIssueChanged` event with `action: :removed`
    - Returns `{:error, :not_found}` when child doesn't exist
    - Does not emit event on failure
  - Mocks/DI: `event_bus: TestEventBus`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/tickets/application/use_cases/remove_sub_issue.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.11 Facade: `add_sub_issue/3` and `remove_sub_issue/3`

- [ ] ⏸ **RED**: Write tests in `apps/agents/test/agents/tickets_test.exs`
  - `describe "add_sub_issue/3"` — delegates to use case, returns `{:ok, schema}` or error
  - `describe "remove_sub_issue/3"` — delegates to use case, returns `{:ok, schema}` or error
- [ ] ⏸ **GREEN**: Add to `apps/agents/lib/agents/tickets.ex`
  ```elixir
  alias Agents.Tickets.Application.UseCases.AddSubIssue
  alias Agents.Tickets.Application.UseCases.RemoveSubIssue
  
  @spec add_sub_issue(integer(), integer(), keyword()) :: {:ok, struct()} | {:error, term()}
  def add_sub_issue(parent_number, child_number, opts \\ []) do
    AddSubIssue.execute(parent_number, child_number, opts)
  end

  @spec remove_sub_issue(integer(), integer(), keyword()) :: {:ok, struct()} | {:error, term()}
  def remove_sub_issue(parent_number, child_number, opts \\ []) do
    RemoveSubIssue.execute(parent_number, child_number, opts)
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up, update `Agents.Tickets` boundary deps if needed

### 2.12 Facade: `list_tickets/1` (MCP-friendly variant)

The existing `list_project_tickets/2` takes a `user_id` and enriches with session state. MCP tools have no user context and don't need session enrichment. Add a simpler variant.

- [ ] ⏸ **RED**: Write test in `apps/agents/test/agents/tickets_test.exs`
  - `describe "list_tickets/1"`
  - Tests:
    - Returns list of `Ticket.t()` entities from DB
    - Supports `:state` filter (open/closed)
    - Supports `:labels` filter
    - Supports `:query` search filter (title/number)
    - Returns empty list when no tickets match
- [ ] ⏸ **GREEN**: Add `list_tickets/1` to `apps/agents/lib/agents/tickets.ex` and a corresponding `list_filtered/1` to `ProjectTicketRepository`
  ```elixir
  @spec list_tickets(keyword()) :: [Ticket.t()]
  def list_tickets(opts \\ []) do
    opts
    |> ProjectTicketRepository.list_filtered()
    |> Enum.map(&Ticket.from_schema/1)
  end
  ```
- [ ] ⏸ **RED**: Write test for `ProjectTicketRepository.list_filtered/1` in repository test
  - Tests:
    - Returns all open root tickets when no filters
    - Filters by state
    - Filters by labels (intersection)
    - Filters by query (title ilike / number exact)
    - Limits results with `:per_page`
- [ ] ⏸ **GREEN**: Implement `list_filtered/1` in `ProjectTicketRepository`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2 Validation

- [ ] ⏸ All new domain tests pass (`mix test apps/agents/test/agents/tickets/`)
- [ ] ⏸ All new facade tests pass
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Existing tests still pass (no regressions)

---

## Phase 3: Rewire Existing Tools to Domain Layer ⏸

**Goal**: Replace all `Helpers.github_client().<method>()` calls with `Agents.Tickets.<facade_function>()` calls. Tests change from Mox-based GitHub client mocks to DataCase-based DB tests.

**Important test pattern change**: The existing tool tests use `ExUnit.Case, async: false` with Mox stubs for the GitHub client. After rewiring, tools call the facade which hits the DB. Tests must switch to `Agents.DataCase, async: true` (with Ecto sandbox) and use `TestEventBus` for use cases that emit events. Tests should insert real ticket records and assert on the response format.

### 3.1 Helpers: `format_ticket/1` and `format_ticket_summary/1`

The existing `format_issue/1` and `format_issue_summary/1` format GitHub API response maps. After rewiring, tools receive `Ticket.t()` domain entities. Add new formatters for entities (or adapt existing ones).

- [ ] ⏸ **RED**: Write tests in `apps/agents/test/agents/infrastructure/mcp/tools/ticket/helpers_test.exs`
  - `describe "format_ticket/1"` — formats a `Ticket.t()` entity as markdown with title, state, labels, body, sub-tickets, dependencies
  - `describe "format_ticket_summary/1"` — formats compact one-line summary from `Ticket.t()`
- [ ] ⏸ **GREEN**: Add `format_ticket/1` and `format_ticket_summary/1` to `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/helpers.ex`
  ```elixir
  def format_ticket(%Agents.Tickets.Domain.Entities.Ticket{} = ticket) do
    labels = format_list(ticket.labels)
    sub_issues = ticket.sub_tickets |> Enum.map_join(", ", &"##{&1.number}") |> blank_to_default("None")
    blockers = ticket.blocked_by |> Enum.map_join(", ", &"##{&1.number}") |> blank_to_default("None")
    blocking = ticket.blocks |> Enum.map_join(", ", &"##{&1.number}") |> blank_to_default("None")
    
    """
    # Ticket ##{ticket.number}
    - Title: #{ticket.title}
    - State: #{ticket.state}
    - Labels: #{labels}
    - URL: #{ticket.url || "(none)"}
    - Sync state: #{ticket.sync_state}
    
    ## Body
    #{ticket.body |> blank_to_default("(empty)")}
    
    ## Sub-issues
    #{sub_issues}
    
    ## Blocked by
    #{blockers}
    
    ## Blocking
    #{blocking}
    """
    |> String.trim()
  end

  def format_ticket_summary(%Agents.Tickets.Domain.Entities.Ticket{} = ticket) do
    labels = ticket.labels |> Enum.join(", ") |> blank_to_default("none")
    "Ticket ##{ticket.number}: #{ticket.title} (#{ticket.state}) [#{labels}]"
  end
  ```
- [ ] ⏸ **REFACTOR**: Keep old `format_issue/1` and `format_issue_summary/1` until all tools are migrated, then remove them in Phase 3.7

### 3.2 Rewire CreateTool

- [ ] ⏸ **RED**: Rewrite `apps/agents/test/agents/infrastructure/mcp/tools/ticket/create_tool_test.exs`
  - Change to `use Agents.DataCase, async: true` (needs DB for facade)
  - Remove Mox setup for `GithubTicketClientMock`
  - Remove Application.put_env for `:github_ticket_client` and `:sessions`
  - Keep IdentityMock for permission guard
  - Start `TestEventBus` in setup
  - Tests:
    - Creates ticket locally via facade and returns `#number` in response text
    - Returns error response for empty title/body
    - Denies execution when scope is missing (keep existing)
  - The tool should construct a body string from title + body params and pass `actor_id` from frame
- [ ] ⏸ **GREEN**: Rewrite `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/create_tool.ex`
  - Remove `alias Helpers` for `github_client/client_opts` usage
  - Add `alias Agents.Tickets`
  - Change `execute/2` to:
    ```elixir
    def execute(params, frame) do
      case PermissionGuard.check_permission(frame, "ticket.create") do
        :ok ->
          title = Helpers.get_param(params, :title) || ""
          body = Helpers.get_param(params, :body) || ""
          labels = Helpers.get_param(params, :labels)
          
          full_body = if body == "", do: title, else: "#{title}\n#{body}"
          actor_id = frame.assigns[:user_id] || "mcp-system"
          opts = [actor_id: actor_id]
          # labels will be handled by a follow-up update if needed
          
          case Agents.Tickets.create_ticket(full_body, opts) do
            {:ok, ticket} ->
              # If labels provided, update them
              maybe_update_labels(ticket.number, labels, opts)
              text = "Created ticket ##{ticket.number}: #{ticket.title}"
              {:reply, Response.text(Response.tool(), text), frame}
            {:error, reason} ->
              {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "Ticket")), frame}
          end
        {:error, scope} -> ...
      end
    end
    ```
  - **Note**: `CreateTicket.execute/2` takes a raw body string (first line = title, rest = body). The tool must construct this from separate `title` and `body` params. Labels are not part of the current `create_ticket` flow — they will need a follow-up `update_ticket` call or the `CreateTicket` use case needs to accept labels. **Decision**: Extend `CreateTicket.execute/2` to accept optional `:labels` in opts, which gets passed into the insert attrs.
- [ ] ⏸ **REFACTOR**: Clean up

### 3.2.1 Extend CreateTicket Use Case to Accept Labels

- [ ] ⏸ **RED**: Add test to `apps/agents/test/agents/tickets/application/use_cases/create_ticket_test.exs`
  - Test: Creates ticket with labels when `:labels` option is provided
- [ ] ⏸ **GREEN**: Update `CreateTicket.execute/2` to accept `:labels` in opts and include in insert attrs
- [ ] ⏸ **REFACTOR**: Clean up

### 3.3 Rewire ListTool

- [ ] ⏸ **RED**: Rewrite `apps/agents/test/agents/infrastructure/mcp/tools/ticket/list_tool_test.exs`
  - Change to `use Agents.DataCase, async: true`
  - Remove Mox/GithubTicketClientMock setup
  - Insert test tickets via `ProjectTicketRepository.sync_remote_ticket/1`
  - Tests:
    - Returns formatted list with ticket entries from DB
    - Passes state filter (insert open + closed tickets, filter for open)
    - Passes labels filter
    - Passes query filter (title search)
    - Returns empty state message when no tickets
    - Denies execution when scope is missing
- [ ] ⏸ **GREEN**: Rewrite `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/list_tool.ex`
  - Replace `Helpers.github_client().list_issues(opts)` with `Agents.Tickets.list_tickets(opts)`
  - Map filter params: state, labels, query, per_page
  - Use `Helpers.format_ticket_summary/1` instead of `Helpers.format_issue_summary/1`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.4 Rewire ReadTool

- [ ] ⏸ **RED**: Rewrite `apps/agents/test/agents/infrastructure/mcp/tools/ticket/read_tool_test.exs`
  - Change to `use Agents.DataCase, async: true`
  - Remove Mox/GithubTicketClientMock setup
  - Insert test ticket via `ProjectTicketRepository.sync_remote_ticket/1`
  - Tests:
    - Returns formatted ticket details from DB (number, title, state, labels, body, sub-tickets, dependencies)
    - Returns not found error for unknown ticket number
    - Denies execution when scope is missing
- [ ] ⏸ **GREEN**: Rewrite `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/read_tool.ex`
  - Replace `Helpers.github_client().get_issue(number, opts)` with `Agents.Tickets.get_ticket_by_number(number)`
  - Use `Helpers.format_ticket/1` instead of `Helpers.format_issue/1`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.5 Rewire UpdateTool

- [ ] ⏸ **RED**: Rewrite `apps/agents/test/agents/infrastructure/mcp/tools/ticket/update_tool_test.exs`
  - Change to `use Agents.DataCase, async: true`
  - Start `TestEventBus` in setup
  - Insert test ticket via `ProjectTicketRepository.sync_remote_ticket/1`
  - Tests:
    - Updates issue title locally and returns success response
    - Returns not found error for unknown ticket number
    - Omitted fields are unchanged; explicit empty list clears labels
    - Denies execution when scope is missing
- [ ] ⏸ **GREEN**: Rewrite `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/update_tool.ex`
  - Replace `Helpers.github_client().update_issue(number, attrs, opts)` with `Agents.Tickets.update_ticket(number, attrs, opts)`
  - Extract `actor_id` from `frame.assigns[:user_id]`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.6 Rewire CloseTool

- [ ] ⏸ **RED**: Rewrite `apps/agents/test/agents/infrastructure/mcp/tools/ticket/close_tool_test.exs`
  - Change to `use Agents.DataCase, async: false` (close_project_ticket uses Application config for GitHub client)
  - Keep Mox for `GithubTicketClientMock` (because `close_project_ticket` still calls GitHub first)
  - Insert test ticket via `ProjectTicketRepository.sync_remote_ticket/1`
  - Tests:
    - Closes issue via facade and returns success response
    - Returns error for non-existent issue
    - Denies execution when scope is missing
  - **Note**: `close_project_ticket/2` currently calls GitHub first, then closes locally. The tool's comment parameter can be handled by adding a comment via facade or dropped. Since comments aren't modelled, **drop the comment parameter** from CloseTool or keep it as a no-op.
- [ ] ⏸ **GREEN**: Rewrite `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/close_tool.ex`
  - Replace direct GitHub call with `Agents.Tickets.close_project_ticket(number, opts)`
  - Remove `comment` parameter (or keep as no-op with a note)
- [ ] ⏸ **REFACTOR**: Clean up

### 3.7 Rewire AddSubIssueTool

- [ ] ⏸ **RED**: Rewrite `apps/agents/test/agents/infrastructure/mcp/tools/ticket/add_sub_issue_tool_test.exs`
  - Change to `use Agents.DataCase, async: true`
  - Start `TestEventBus` in setup
  - Insert parent + child tickets
  - Tests:
    - Adds sub-issue link via facade, returns success response text
    - Returns not found error when parent or child doesn't exist
    - Denies execution when scope is missing
- [ ] ⏸ **GREEN**: Rewrite `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/add_sub_issue_tool.ex`
  - Replace `Helpers.github_client().add_sub_issue(...)` with `Agents.Tickets.add_sub_issue(parent_number, child_number, opts)`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.8 Rewire RemoveSubIssueTool

- [ ] ⏸ **RED**: Rewrite `apps/agents/test/agents/infrastructure/mcp/tools/ticket/remove_sub_issue_tool_test.exs`
  - Change to `use Agents.DataCase, async: true`
  - Start `TestEventBus` in setup
  - Insert parent + child ticket with sub-issue link
  - Tests:
    - Removes sub-issue link via facade, returns success response text
    - Returns not found error when child doesn't exist
    - Denies execution when scope is missing
- [ ] ⏸ **GREEN**: Rewrite `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/remove_sub_issue_tool.ex`
  - Replace `Helpers.github_client().remove_sub_issue(...)` with `Agents.Tickets.remove_sub_issue(parent_number, child_number, opts)`
- [ ] ⏸ **REFACTOR**: Clean up

### 3.9 Remove GitHub Client Helpers & Legacy Formatters

After all tools are rewired, clean up dead code in Helpers.

- [ ] ⏸ **RED**: Delete tests for `github_client/0` and `client_opts/0` from `helpers_test.exs`
  - Delete `describe "client_opts/0"` block
  - Delete `describe "github_client/0"` block
- [ ] ⏸ **GREEN**: Remove `github_client/0` and `client_opts/0` from `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/helpers.ex`
- [ ] ⏸ **GREEN**: Remove `format_issue/1` and `format_issue_summary/1` from `helpers.ex` (replaced by `format_ticket/1` and `format_ticket_summary/1`)
- [ ] ⏸ **RED**: Delete tests for `format_issue/1` and `format_issue_summary/1` from `helpers_test.exs`
- [ ] ⏸ **REFACTOR**: Remove any remaining Application.put_env for `:github_ticket_client` or `:sessions` from MCP tool tests. Clean up unused `require Logger` imports in Helpers. Remove the `Logger` require if `format_error/2` doesn't need it.

### 3.10 Update Helpers: Remove `format_error(:missing_token, _)`

The `:missing_token` error format was GitHub-client specific. After rewiring, tools get domain-layer errors (`:not_found`, `:body_required`, `:no_changes`, etc.). Update error formatting.

- [ ] ⏸ **RED**: Update `format_error/2` tests in `helpers_test.exs`
  - Keep `:not_found` formatting
  - Remove `:missing_token` test
  - Add domain error formats: `:body_required`, `:no_changes`, `:child_not_found`, `:parent_not_found`
- [ ] ⏸ **GREEN**: Update `format_error/2` in `helpers.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3 Validation

- [ ] ⏸ All rewired tool tests pass
- [ ] ⏸ No tool references `Helpers.github_client()` or `Helpers.client_opts()`
- [ ] ⏸ No tool directly aliases or uses `GithubProjectClient`
- [ ] ⏸ `Helpers` module no longer exports `github_client/0` or `client_opts/0`
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test apps/agents`)

---

## Phase 4: Add New Dependency MCP Tools ⏸

**Goal**: Add 3 new MCP tools for dependency management. These call existing facade functions.

### 4.1 AddDependencyTool

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/add_dependency_tool_test.exs`
  - `use Agents.DataCase, async: true`
  - Start `TestEventBus` in setup
  - Insert two test tickets
  - Tests:
    - Adds dependency (blocker blocks blocked) and returns success text
    - Returns error for self-dependency
    - Returns error for duplicate dependency
    - Returns error for circular dependency
    - Returns error when blocker ticket not found
    - Returns error when blocked ticket not found
    - Denies execution when scope is missing (`mcp:ticket.add_dependency`)
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/add_dependency_tool.ex`
  ```elixir
  defmodule Agents.Infrastructure.Mcp.Tools.Ticket.AddDependencyTool do
    use Hermes.Server.Component, type: :tool
    
    alias Agents.Infrastructure.Mcp.PermissionGuard
    alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
    alias Hermes.Server.Response
    
    schema do
      field(:blocker_ticket_id, {:required, :integer}, description: "ID of the blocking ticket")
      field(:blocked_ticket_id, {:required, :integer}, description: "ID of the blocked ticket")
    end
    
    @impl true
    def execute(params, frame) do
      case PermissionGuard.check_permission(frame, "ticket.add_dependency") do
        :ok ->
          blocker_id = Helpers.get_param(params, :blocker_ticket_id)
          blocked_id = Helpers.get_param(params, :blocked_ticket_id)
          actor_id = frame.assigns[:user_id] || "mcp-system"
          
          case Agents.Tickets.add_dependency(blocker_id, blocked_id, actor_id: actor_id) do
            {:ok, _dep} ->
              {:reply, Response.text(Response.tool(), "Added dependency: ticket #{blocker_id} now blocks ticket #{blocked_id}."), frame}
            {:error, reason} ->
              {:reply, Response.error(Response.tool(), Helpers.format_error(reason, "Dependency")), frame}
          end
        {:error, scope} ->
          {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"), frame}
      end
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 4.2 RemoveDependencyTool

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/remove_dependency_tool_test.exs`
  - `use Agents.DataCase, async: true`
  - Start `TestEventBus` in setup
  - Insert two test tickets with a dependency
  - Tests:
    - Removes dependency and returns success text
    - Returns error when dependency doesn't exist
    - Denies execution when scope is missing (`mcp:ticket.remove_dependency`)
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/remove_dependency_tool.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 4.3 SearchDependencyTargetsTool

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/search_dependency_targets_tool_test.exs`
  - `use Agents.DataCase, async: true`
  - Insert several test tickets
  - Tests:
    - Searches by title substring and returns matching tickets
    - Searches by number and returns exact match
    - Excludes the specified ticket from results
    - Returns empty state message when no matches
    - Denies execution when scope is missing (`mcp:ticket.search_dependency_targets`)
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/search_dependency_targets_tool.ex`
  ```elixir
  defmodule Agents.Infrastructure.Mcp.Tools.Ticket.SearchDependencyTargetsTool do
    use Hermes.Server.Component, type: :tool
    
    alias Agents.Infrastructure.Mcp.PermissionGuard
    alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers
    alias Hermes.Server.Response
    
    schema do
      field(:query, {:required, :string}, description: "Search query (ticket number or title)")
      field(:exclude_ticket_id, {:required, :integer}, description: "Ticket ID to exclude from results")
    end
    
    @impl true
    def execute(params, frame) do
      case PermissionGuard.check_permission(frame, "ticket.search_dependency_targets") do
        :ok ->
          query = Helpers.get_param(params, :query)
          exclude_id = Helpers.get_param(params, :exclude_ticket_id)
          
          results = Agents.Tickets.search_tickets_for_dependency(query, exclude_id)
          
          if results == [] do
            {:reply, Response.text(Response.tool(), "No matching tickets found."), frame}
          else
            text = Enum.map_join(results, "\n", fn ticket ->
              "Ticket ##{ticket.number} (id: #{ticket.id}): #{ticket.title}"
            end)
            {:reply, Response.text(Response.tool(), text), frame}
          end
        {:error, scope} ->
          {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"), frame}
      end
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 4.4 Register New Tools in TicketToolProvider

- [ ] ⏸ **RED**: Write/update test for `TicketToolProvider.components/0` (if one exists) to assert the 3 new tools are registered
- [ ] ⏸ **GREEN**: Add to `apps/agents/lib/agents/infrastructure/mcp/tool_providers/ticket_tool_provider.ex`:
  ```elixir
  {Ticket.AddDependencyTool, "ticket.add_dependency"},
  {Ticket.RemoveDependencyTool, "ticket.remove_dependency"},
  {Ticket.SearchDependencyTargetsTool, "ticket.search_dependency_targets"}
  ```
- [ ] ⏸ **GREEN**: Update `@moduledoc` to reflect new tool count (was 8, now 10: 7 original - 1 comment + 3 dependency)
- [ ] ⏸ **REFACTOR**: Clean up

### 4.5 Update TicketFixtures with New Scopes

- [ ] ⏸ **GREEN**: Add new permission scopes to `api_key_struct/0` in `apps/agents/test/support/fixtures/ticket_fixtures.ex`:
  ```elixir
  "mcp:ticket.add_dependency",
  "mcp:ticket.remove_dependency",
  "mcp:ticket.search_dependency_targets"
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### 4.6 Update Helpers: Add Dependency Error Formats

- [ ] ⏸ **RED**: Add tests for dependency-specific error formats in `helpers_test.exs`
  - `:self_dependency` → "Cannot create a dependency between a ticket and itself."
  - `:duplicate_dependency` → "This dependency already exists."
  - `:circular_dependency` → "Adding this dependency would create a circular chain."
  - `:blocker_not_found` → "Blocker ticket not found."
  - `:blocked_not_found` → "Blocked ticket not found."
  - `:dependency_not_found` → "Dependency not found."
- [ ] ⏸ **GREEN**: Add pattern matches to `format_error/2` in `helpers.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 4 Validation

- [ ] ⏸ All new dependency tool tests pass
- [ ] ⏸ `TicketToolProvider.components/0` returns 10 tools
- [ ] ⏸ Permission scopes are correct for all 10 tools
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test apps/agents`)

---

## Phase 5: Final Cleanup & Documentation ⏸

### 5.1 Verify No Direct GitHub Client Usage in MCP Tools

- [ ] ⏸ Grep for `GithubProjectClient` in MCP tool files — should find zero matches
- [ ] ⏸ Grep for `Helpers.github_client` in tool files — should find zero matches
- [ ] ⏸ Grep for `Helpers.client_opts` in tool files — should find zero matches

### 5.2 Update Moduledocs

- [ ] ⏸ Update `CreateTool` `@moduledoc` from "Create a GitHub issue via MCP ticket tools" to "Create a ticket via MCP ticket tools"
- [ ] ⏸ Update `ListTool` `@moduledoc` from "List GitHub issues..." to "List tickets..."
- [ ] ⏸ Update `ReadTool` `@moduledoc` from "Read a GitHub issue..." to "Read a ticket..."
- [ ] ⏸ Update `UpdateTool` `@moduledoc` from "Update a GitHub issue..." to "Update a ticket..."
- [ ] ⏸ Update `CloseTool` `@moduledoc` from "Close a GitHub issue..." to "Close a ticket..."
- [ ] ⏸ Update `AddSubIssueTool` `@moduledoc` — keep or refine
- [ ] ⏸ Update `RemoveSubIssueTool` `@moduledoc` — keep or refine
- [ ] ⏸ Update `TicketToolProvider` `@moduledoc` to reflect new tool count and purpose
- [ ] ⏸ Update `Helpers` `@moduledoc` from `false` to a brief description of remaining responsibilities

### 5.3 Pre-commit Checkpoint

- [ ] ⏸ Run `mix precommit` (formatting, credo, dialyzer)
- [ ] ⏸ Run `mix boundary` — no violations
- [ ] ⏸ Run `mix test apps/agents` — all pass
- [ ] ⏸ Run full test suite `mix test` — all pass

### Phase 5 Validation

- [ ] ⏸ All moduledocs are accurate
- [ ] ⏸ No TODO/FIXME markers left from this refactor
- [ ] ⏸ Pre-commit passes cleanly

---

## Testing Strategy

### Test Distribution

| Layer | New Tests | Modified Tests | Deleted Tests |
|-------|-----------|---------------|---------------|
| Domain (events) | 2 (TicketUpdated, TicketSubIssueChanged) | 0 | 0 |
| Application (use cases) | 3 (UpdateTicket, AddSubIssue, RemoveSubIssue) | 1 (CreateTicket — labels) | 0 |
| Infrastructure (repositories) | 4 (get_by_number, update_fields, set_parent_ticket, clear_parent_ticket, list_filtered) | 0 | 0 |
| Infrastructure (MCP tools) | 3 (AddDependencyTool, RemoveDependencyTool, SearchDependencyTargetsTool) | 7 (all rewired tools) | 1 (CommentToolTest) |
| Infrastructure (helpers) | 2 (format_ticket, format_ticket_summary) | 2 (format_error updates, remove old tests) | 2 (github_client, client_opts) |
| Facade | 4 (get_ticket_by_number, update_ticket, add_sub_issue, remove_sub_issue, list_tickets) | 0 | 0 |

### Estimated Test Count

- **New tests**: ~40-50 test cases across 12+ test files
- **Modified tests**: ~25 test cases across 8 files  
- **Deleted tests**: ~8 test cases across 2 files (CommentTool + Helpers github_client/client_opts)

### Key Testing Patterns

1. **Use case tests**: `Agents.DataCase, async: true` + `TestEventBus.start_global()` + inject `event_bus: TestEventBus`
2. **Repository tests**: `Agents.DataCase, async: true` + `ProjectTicketRepository.sync_remote_ticket/1` for fixtures
3. **MCP tool tests (rewired)**: `Agents.DataCase, async: true` + `TestEventBus` + insert real DB records + keep `IdentityMock` for permission guard
4. **MCP tool tests (CloseTool)**: `Agents.DataCase, async: false` + `GithubTicketClientMock` (close still calls GitHub first)
5. **Domain event tests**: `ExUnit.Case, async: true` — pure struct creation

### Risk Areas

1. **CreateTool label handling**: The existing `CreateTicket` use case doesn't accept labels. Need to extend it or follow up with an update call.
2. **CloseTool comment parameter**: The CloseTool currently accepts a `comment` param. Since comments aren't modelled, this parameter should be dropped or the tool should call `close_project_ticket` which doesn't support comments. The existing facade `close_project_ticket/2` calls GitHub first — this is intentional (GitHub-first close to prevent drift). The tool should pass through to the facade; the comment feature is simply dropped.
3. **ListTool filter translation**: Need to ensure the new `list_filtered/1` repository function supports all the same filters the GitHub API accepted (state, labels, query, per_page).
4. **MCP tool `actor_id`**: Tools extract `user_id` from `frame.assigns[:user_id]`. This may be nil if the MCP client doesn't set it. Use `"mcp-system"` as fallback.
5. **Async test safety**: Use cases that emit domain events MUST use `TestEventBus` to prevent `GithubTicketPushHandler` crashes in the supervision tree.

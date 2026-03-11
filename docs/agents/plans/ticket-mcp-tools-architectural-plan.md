# Feature: Ticket Management MCP Tools

**Ticket**: [#401 — feat: Add ticket management MCP tools and migrate skills from gh CLI](https://github.com/platform-q-ai/perme8/issues/401)

## Overview

Add 8 ticket management tools to the perme8-mcp server so agents can manage GitHub issues through a unified, authenticated, and auditable API layer instead of shelling out to `gh issue` CLI commands. This eliminates ad-hoc token management, enables structured responses, and unlocks sub-issue hierarchy management.

## App Ownership

| Artifact | Owning App | Path |
|----------|-----------|------|
| **Domain app** | `agents` | `apps/agents/` |
| **Repo** | `Agents.Repo` | (no new migrations needed — no local DB artifacts) |
| **Tool modules** | `agents` | `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/` |
| **Tool provider** | `agents` | `apps/agents/lib/agents/infrastructure/mcp/tool_providers/ticket_tool_provider.ex` |
| **GitHub client extensions** | `agents` | `apps/agents/lib/agents/tickets/infrastructure/clients/github_project_client.ex` |
| **Behaviour (port)** | `agents` | `apps/agents/lib/agents/application/behaviours/github_ticket_client_behaviour.ex` |
| **Config registration** | umbrella root | `config/config.exs` |
| **Unit tests** | `agents` | `apps/agents/test/agents/infrastructure/mcp/tools/ticket/` |
| **Test fixtures** | `agents` | `apps/agents/test/support/fixtures/ticket_fixtures.ex` |
| **BDD feature files (HTTP)** | `agents` | `apps/agents/test/features/perme8-mcp/ticket-tools/ticket-tools.http.feature` |
| **BDD feature files (Security)** | `agents` | `apps/agents/test/features/perme8-mcp/ticket-tools/ticket-tools.security.feature` |

## UI Strategy

- **LiveView coverage**: N/A — this feature adds backend MCP tools only; no UI changes
- **TypeScript needed**: None

## Affected Boundaries

- **Owning app**: `agents`
- **Repo**: `Agents.Repo` (not used directly — tools delegate to GitHub REST/GraphQL API)
- **Migrations**: None required (no local database artifacts)
- **Feature files**: `apps/agents/test/features/perme8-mcp/ticket-tools/` (already created)
- **Primary context**: `Agents.Infrastructure.Mcp` (tool modules + provider) and `Agents.Tickets` (GitHub client extension)
- **Dependencies**: `Agents.Tickets.Application.TicketsConfig` (for GitHub token, org, repo config)
- **Exported schemas**: None
- **New context needed?**: No — the MCP tools live in `Agents.Infrastructure.Mcp` (existing), and the GitHub client lives in `Agents.Tickets` (existing). A behaviour bridges the two contexts cleanly.

## Architecture Decision: Cross-Context Access

The ticket tools need to call the GitHub API. The existing `GithubProjectClient` in `Agents.Tickets` already handles auth, headers, pagination, and error handling.

**Decision**: Option 1 — Extend `GithubProjectClient` with new functions and expose them through a behaviour (`GithubTicketClientBehaviour`). Tool modules depend on the behaviour and receive the real client via config-based dependency injection (matching existing patterns like `ErmGatewayBehaviour`, `JargaGatewayBehaviour`).

This gives us:
1. Reuse of existing HTTP infrastructure (headers, token, error handling)
2. Clean testability via Mox
3. No direct cross-context coupling (tools depend on behaviour, not concrete client)

## Resolved Open Questions

1. **Use case layer?** No — these are thin infrastructure tools that delegate to the GitHub API. No complex orchestration or domain logic. Tool modules call the GitHub client behaviour directly.
2. **Skills repo migration?** Out of scope — separate ticket/PR.
3. **`ticket.update` field semantics**: Omitting a field = no change; passing explicit empty list `[]` = clear labels/assignees.
4. **AGENTS.md update**: Add section delineating "MCP for tickets, `gh` for PRs" — included in Phase 2.
5. **Sub-issue API errors**: Return descriptive error messages if the API returns 404/422 (indicating the repo doesn't support sub-issues).
6. **`ticket.add_dependency` / `ticket.remove_dependency`**: Out of scope (P1, follow-up ticket).

---

## Phase 1: Behaviour + GitHub Client Extension + Test Fixtures (phoenix-tdd)

This phase establishes the testable contract (behaviour), extends the GitHub client with the 8 new API operations, and creates test fixtures for all downstream tool tests.

### Step 1.1: GithubTicketClientBehaviour

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/behaviours/github_ticket_client_behaviour_test.exs`
  - Tests: Behaviour module defines the expected callbacks
  - Verify: `@callback get_issue(integer(), keyword()) :: {:ok, map()} | {:error, term()}`
  - Verify: `@callback list_issues(keyword()) :: {:ok, [map()]} | {:error, term()}`
  - Verify: `@callback create_issue(map(), keyword()) :: {:ok, map()} | {:error, term()}`
  - Verify: `@callback update_issue(integer(), map(), keyword()) :: {:ok, map()} | {:error, term()}`
  - Verify: `@callback close_issue(integer(), keyword()) :: {:ok, map()} | {:error, term()}`
  - Verify: `@callback add_comment(integer(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}`
  - Verify: `@callback add_sub_issue(integer(), integer(), keyword()) :: {:ok, map()} | {:error, term()}`
  - Verify: `@callback remove_sub_issue(integer(), integer(), keyword()) :: {:ok, map()} | {:error, term()}`
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/behaviours/github_ticket_client_behaviour.ex`
  - Define the 8 callbacks with proper typespecs
- [ ] ⏸ **REFACTOR**: Ensure typespec consistency with existing client patterns

### Step 1.2: Extend GithubProjectClient — `get_issue/2`

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/tickets/infrastructure/clients/github_project_client_test.exs`
  - Test: `get_issue/2` returns `{:ok, issue_map}` for a valid issue number
  - Test: `get_issue/2` returns `{:error, :not_found}` for non-existent issue (404)
  - Test: `get_issue/2` returns `{:error, :missing_token}` when token is nil
  - Test: `get_issue/2` includes title, body, state, labels, assignees, comments, sub_issue_numbers
  - Use `Req.Test` adapter for HTTP stubbing (no real API calls)
- [ ] ⏸ **GREEN**: Implement `get_issue/2` in `apps/agents/lib/agents/tickets/infrastructure/clients/github_project_client.ex`
  - `GET /repos/{owner}/{repo}/issues/{number}` — fetches issue details
  - `GET /repos/{owner}/{repo}/issues/{number}/comments` — fetches comments
  - Enriches with sub_issue_numbers using existing `fetch_sub_issues/4`
  - Returns map with keys: `:number, :title, :body, :state, :labels, :assignees, :url, :comments, :sub_issue_numbers, :created_at`
- [ ] ⏸ **REFACTOR**: Extract shared parsing helpers if duplicated with `parse_issue/1`

### Step 1.3: Extend GithubProjectClient — `list_issues/1`

- [ ] ⏸ **RED**: Write tests in `github_project_client_test.exs`
  - Test: `list_issues/1` with no filters returns open issues
  - Test: `list_issues/1` with `state: "closed"` filters by state
  - Test: `list_issues/1` with `labels: ["bug"]` filters by labels
  - Test: `list_issues/1` with `query: "MCP"` uses GitHub search API
  - Test: `list_issues/1` with `assignee: "username"` filters by assignee
  - Test: `list_issues/1` returns `{:error, :missing_token}` when token is nil
- [ ] ⏸ **GREEN**: Implement `list_issues/1` in `github_project_client.ex`
  - `GET /repos/{owner}/{repo}/issues` with query params (state, labels, assignee, per_page)
  - When `query` is provided, use `GET /search/issues?q=...+repo:{owner}/{repo}`
  - Returns `{:ok, [issue_map]}` — each issue has `:number, :title, :state, :labels, :url, :assignees`
- [ ] ⏸ **REFACTOR**: Share parsing logic with `get_issue/2`

### Step 1.4: Extend GithubProjectClient — `create_issue/2`

- [ ] ⏸ **RED**: Write tests in `github_project_client_test.exs`
  - Test: `create_issue/2` with title and body returns `{:ok, issue_map}` with number and URL
  - Test: `create_issue/2` with labels creates issue with labels
  - Test: `create_issue/2` with assignees creates issue with assignees
  - Test: `create_issue/2` returns `{:error, :missing_token}` when token is nil
- [ ] ⏸ **GREEN**: Implement `create_issue/2` in `github_project_client.ex`
  - `POST /repos/{owner}/{repo}/issues` with JSON body `{title, body, labels, assignees}`
  - Returns `{:ok, %{number: N, url: "...", title: "..."}}`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.5: Extend GithubProjectClient — `update_issue/3`

- [ ] ⏸ **RED**: Write tests in `github_project_client_test.exs`
  - Test: `update_issue/3` updates title
  - Test: `update_issue/3` updates body
  - Test: `update_issue/3` updates labels (empty list clears)
  - Test: `update_issue/3` updates state (open/closed)
  - Test: `update_issue/3` returns `{:error, :not_found}` for non-existent issue
  - Test: `update_issue/3` omitted fields are not sent
- [ ] ⏸ **GREEN**: Implement `update_issue/3` in `github_project_client.ex`
  - `PATCH /repos/{owner}/{repo}/issues/{number}` with JSON body (only non-nil fields)
  - Returns `{:ok, updated_issue_map}`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.6: Extend GithubProjectClient — `close_issue/2` (REST version)

Note: The existing `close_issue/2` uses GraphQL. We add a new REST-based version that also supports an optional closing comment and returns the updated issue.

- [ ] ⏸ **RED**: Write tests in `github_project_client_test.exs`
  - Test: `close_issue_with_comment/2` closes issue and optionally adds comment
  - Test: `close_issue_with_comment/2` returns `{:error, :not_found}` for non-existent issue
- [ ] ⏸ **GREEN**: Implement `close_issue_with_comment/2` in `github_project_client.ex`
  - If comment provided: `POST /repos/{owner}/{repo}/issues/{number}/comments` then `PATCH .../issues/{number}` with `{state: "closed"}`
  - If no comment: just `PATCH .../issues/{number}` with `{state: "closed"}`
  - Returns `{:ok, closed_issue_map}`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.7: Extend GithubProjectClient — `add_comment/3`

- [ ] ⏸ **RED**: Write tests in `github_project_client_test.exs`
  - Test: `add_comment/3` posts comment and returns `{:ok, comment_map}`
  - Test: `add_comment/3` returns `{:error, :not_found}` for non-existent issue
- [ ] ⏸ **GREEN**: Implement `add_comment/3` in `github_project_client.ex`
  - `POST /repos/{owner}/{repo}/issues/{number}/comments` with `{body: "..."}`
  - Returns `{:ok, %{id: N, url: "...", body: "..."}}`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.8: Extend GithubProjectClient — `add_sub_issue/3`

- [ ] ⏸ **RED**: Write tests in `github_project_client_test.exs`
  - Test: `add_sub_issue/3` links child to parent and returns `{:ok, result_map}`
  - Test: `add_sub_issue/3` returns descriptive error if API returns 422/404
- [ ] ⏸ **GREEN**: Implement `add_sub_issue/3` in `github_project_client.ex`
  - `POST /repos/{owner}/{repo}/issues/{parent_number}/sub_issues` with `{sub_issue_id: child_issue_id}`
  - Needs to first resolve the child issue's node_id via `GET /repos/{owner}/{repo}/issues/{child_number}` (or GraphQL)
  - Returns `{:ok, %{parent_number: N, child_number: M}}`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.9: Extend GithubProjectClient — `remove_sub_issue/3`

- [ ] ⏸ **RED**: Write tests in `github_project_client_test.exs`
  - Test: `remove_sub_issue/3` unlinks child from parent and returns `{:ok, result_map}`
  - Test: `remove_sub_issue/3` returns descriptive error if API returns 422/404
- [ ] ⏸ **GREEN**: Implement `remove_sub_issue/3` in `github_project_client.ex`
  - `DELETE /repos/{owner}/{repo}/issues/{parent_number}/sub_issues` with `{sub_issue_id: child_issue_id}`
  - Returns `{:ok, %{parent_number: N, child_number: M}}`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.10: GithubProjectClient implements GithubTicketClientBehaviour

- [ ] ⏸ **RED**: Write test confirming the module implements the behaviour
  - Test: `GithubProjectClient` has `@behaviour GithubTicketClientBehaviour`
  - Test: all 8 callback functions are exported
- [ ] ⏸ **GREEN**: Add `@behaviour Agents.Application.Behaviours.GithubTicketClientBehaviour` to `GithubProjectClient`
- [ ] ⏸ **REFACTOR**: Ensure all function signatures match the behaviour typespecs

### Step 1.11: Register Mox Mock + Test Fixtures

- [ ] ⏸ **RED**: Write test `apps/agents/test/support/fixtures/ticket_fixtures.ex` exists and provides helpers
- [ ] ⏸ **GREEN**: Create:
  - `apps/agents/test/support/fixtures/ticket_fixtures.ex` — provides `issue_map/1`, `comment_map/1`, `api_key_struct/0`
  - Add `Mox.defmock(Agents.Mocks.GithubTicketClientMock, for: Agents.Application.Behaviours.GithubTicketClientBehaviour)` to `apps/agents/test/test_helper.exs`
  - Add `:github_ticket_client` config key support to tool modules
- [ ] ⏸ **REFACTOR**: Ensure fixture shapes match the real API response shapes

### Phase 1 Validation

- [ ] ⏸ All behaviour tests pass
- [ ] ⏸ All GitHub client extension tests pass (with HTTP stubs)
- [ ] ⏸ Mox mock created and registered
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Tool Modules + Provider + Config + AGENTS.md (phoenix-tdd)

This phase builds the 8 MCP tool modules, the TicketToolProvider, registers it in config, and updates AGENTS.md.

### Step 2.1: TicketToolProvider

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tool_providers/ticket_tool_provider_test.exs`
  - Test: `components/0` returns exactly 8 component specs
  - Test: each spec is a `{module, name}` tuple
  - Test: includes all 8 tool names: `ticket.read`, `ticket.list`, `ticket.create`, `ticket.update`, `ticket.close`, `ticket.comment`, `ticket.add_sub_issue`, `ticket.remove_sub_issue`
  - Test: all referenced modules are valid Hermes components (`__mcp_component_type__/0`)
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tool_providers/ticket_tool_provider.ex`
  ```elixir
  defmodule Agents.Infrastructure.Mcp.ToolProviders.TicketToolProvider do
    @behaviour Agents.Infrastructure.Mcp.ToolProvider

    alias Agents.Infrastructure.Mcp.Tools.Ticket

    @impl true
    def components do
      [
        {Ticket.ReadTool, "ticket.read"},
        {Ticket.ListTool, "ticket.list"},
        {Ticket.CreateTool, "ticket.create"},
        {Ticket.UpdateTool, "ticket.update"},
        {Ticket.CloseTool, "ticket.close"},
        {Ticket.CommentTool, "ticket.comment"},
        {Ticket.AddSubIssueTool, "ticket.add_sub_issue"},
        {Ticket.RemoveSubIssueTool, "ticket.remove_sub_issue"}
      ]
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.2: `ticket.read` Tool (ReadTool)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/read_tool_test.exs`
  - Test: returns formatted issue details (Title, Labels, State, Body, Comments, Sub-issues) — validates BDD scenario "Read an issue by number"
  - Test: returns error with "not found" for non-existent issue — validates BDD scenario "Read non-existent issue"
  - Test: denies execution when API key lacks `mcp:ticket.read` scope — validates BDD scenario "Permission denied for ticket.read"
  - Schema validation (missing required `number` param) is handled by Hermes framework → `-32602` error — validates BDD scenario "Read missing required number param"
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/read_tool.ex`
  - Schema: `field(:number, {:required, :integer}, description: "Issue number")`
  - Permission scope: `"ticket.read"`
  - Calls `github_client().get_issue(number, client_opts())`
  - Formats response as Markdown with Title, State, Labels, Assignees, Body, Comments, Sub-issues
  - Client resolved via: `Application.get_env(:agents, :github_ticket_client, Agents.Tickets.Infrastructure.Clients.GithubProjectClient)`
  - Config opts from `TicketsConfig`: token, org, repo
- [ ] ⏸ **REFACTOR**: Extract `format_issue/1` helper, extract `client_opts/0` and `github_client/0` into a shared helper module

### Step 2.3: Shared Helper Module for Ticket Tools

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/helpers_test.exs`
  - Test: `client_opts/0` returns `[token: ..., org: ..., repo: ...]` from TicketsConfig
  - Test: `github_client/0` returns the configured module (default or overridden)
  - Test: `format_issue/1` formats a full issue map as Markdown with all fields
  - Test: `format_issue_summary/1` formats a compact issue summary for list results
  - Test: `format_error/1` handles `:not_found`, `:missing_token`, and generic errors
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/helpers.ex`
  ```elixir
  defmodule Agents.Infrastructure.Mcp.Tools.Ticket.Helpers do
    alias Agents.Tickets.Application.TicketsConfig

    def github_client do
      Application.get_env(:agents, :github_ticket_client,
        Agents.Tickets.Infrastructure.Clients.GithubProjectClient)
    end

    def client_opts do
      [token: TicketsConfig.github_token(), org: TicketsConfig.github_org(), repo: TicketsConfig.github_repo()]
    end

    def format_issue(issue) do ... end
    def format_issue_summary(issue) do ... end
    def format_error(reason) do ... end
  end
  ```
- [ ] ⏸ **REFACTOR**: Ensure all formatting includes Title, State, Labels per BDD assertions

### Step 2.4: `ticket.list` Tool (ListTool)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/list_tool_test.exs`
  - Test: returns formatted list of issues with "Issue" in output — validates BDD "List issues with no filters"
  - Test: passes `state: "open"` filter to client — validates BDD "List issues filtered by state"
  - Test: passes `labels: ["enhancement"]` filter to client and response contains "enhancement" — validates BDD "List issues filtered by labels"
  - Test: passes `query: "MCP"` to client — validates BDD "List issues with search query"
  - Test: returns empty state message when no issues found
  - Test: denies execution when API key lacks scope
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/list_tool.ex`
  - Schema: `field(:state, :string, ...)`, `field(:labels, {:list, :string}, ...)`, `field(:assignee, :string, ...)`, `field(:query, :string, ...)`, `field(:per_page, :integer, ...)`
  - Permission scope: `"ticket.list"`
  - Builds filter opts from params, calls `github_client().list_issues(opts)`
  - Formats as Markdown list of issue summaries
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.5: `ticket.create` Tool (CreateTool)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/create_tool_test.exs`
  - Test: creates issue with title+body and returns `#N` in response — validates BDD "Create issue with title and body" (response matches `.*#[0-9]+.*`)
  - Test: creates issue with labels — validates BDD "Create issue with labels"
  - Test: schema validation rejects missing title → `-32602` — validates BDD "Create fails without title"
  - Test: denies execution when API key lacks scope
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/create_tool.ex`
  - Schema: `field(:title, {:required, :string}, ...)`, `field(:body, :string, ...)`, `field(:labels, {:list, :string}, ...)`, `field(:assignees, {:list, :string}, ...)`
  - Permission scope: `"ticket.create"`
  - Calls `github_client().create_issue(attrs, client_opts())`
  - Response includes `#N` and URL
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.6: `ticket.update` Tool (UpdateTool)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/update_tool_test.exs`
  - Test: updates issue title — validates BDD "Update issue title"
  - Test: returns error with "not found" for non-existent issue — validates BDD "Update non-existent issue"
  - Test: schema validation rejects missing number → `-32602` — validates BDD "Update missing number"
  - Test: omitted fields = no change, explicit empty list = clear
  - Test: denies execution when API key lacks scope
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/update_tool.ex`
  - Schema: `field(:number, {:required, :integer}, ...)`, `field(:title, :string, ...)`, `field(:body, :string, ...)`, `field(:labels, {:list, :string}, ...)`, `field(:assignees, {:list, :string}, ...)`, `field(:state, :string, ...)`
  - Permission scope: `"ticket.update"`
  - Builds update map from only present (non-nil) params
  - Calls `github_client().update_issue(number, attrs, client_opts())`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.7: `ticket.close` Tool (CloseTool)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/close_tool_test.exs`
  - Test: closes issue with optional comment — validates BDD "Close issue with comment"
  - Test: returns error for non-existent issue — validates BDD "Close non-existent issue"
  - Test: schema validation rejects missing number → `-32602` — validates BDD "Close missing number"
  - Test: denies execution when API key lacks scope
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/close_tool.ex`
  - Schema: `field(:number, {:required, :integer}, ...)`, `field(:comment, :string, ...)`
  - Permission scope: `"ticket.close"`
  - Calls `github_client().close_issue_with_comment(number, [comment: comment] ++ client_opts())`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.8: `ticket.comment` Tool (CommentTool)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/comment_tool_test.exs`
  - Test: adds comment to issue — validates BDD "Add comment to issue"
  - Test: returns error for non-existent issue — validates BDD "Comment on non-existent issue"
  - Test: schema validation rejects missing body → `-32602` — validates BDD "Comment missing body"
  - Test: denies execution when API key lacks scope
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/comment_tool.ex`
  - Schema: `field(:number, {:required, :integer}, ...)`, `field(:body, {:required, :string}, ...)`
  - Permission scope: `"ticket.comment"`
  - Calls `github_client().add_comment(number, body, client_opts())`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.9: `ticket.add_sub_issue` Tool (AddSubIssueTool)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/add_sub_issue_tool_test.exs`
  - Test: adds sub-issue link and returns success — validates BDD "Add sub-issue"
  - Test: schema validation rejects missing params → `-32602` — validates BDD "Add sub-issue missing params"
  - Test: returns descriptive error if API rejects (422/404)
  - Test: denies execution when API key lacks scope
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/add_sub_issue_tool.ex`
  - Schema: `field(:parent_number, {:required, :integer}, ...)`, `field(:child_number, {:required, :integer}, ...)`
  - Permission scope: `"ticket.add_sub_issue"`
  - Calls `github_client().add_sub_issue(parent_number, child_number, client_opts())`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.10: `ticket.remove_sub_issue` Tool (RemoveSubIssueTool)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tools/ticket/remove_sub_issue_tool_test.exs`
  - Test: removes sub-issue link and returns success — validates BDD "Remove sub-issue"
  - Test: schema validation rejects missing params → `-32602` — validates BDD "Remove sub-issue missing params"
  - Test: returns descriptive error if API rejects (422/404)
  - Test: denies execution when API key lacks scope
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/remove_sub_issue_tool.ex`
  - Schema: `field(:parent_number, {:required, :integer}, ...)`, `field(:child_number, {:required, :integer}, ...)`
  - Permission scope: `"ticket.remove_sub_issue"`
  - Calls `github_client().remove_sub_issue(parent_number, child_number, client_opts())`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.11: Register TicketToolProvider in Config

- [ ] ⏸ **RED**: Write test (or extend existing `loader_test.exs`) verifying `TicketToolProvider` is in the configured providers list
- [ ] ⏸ **GREEN**: Update `config/config.exs` to add `Agents.Infrastructure.Mcp.ToolProviders.TicketToolProvider` to the `:mcp_tool_providers` list:
  ```elixir
  config :agents, :mcp_tool_providers, [
    Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProvider,
    Agents.Infrastructure.Mcp.ToolProviders.JargaToolProvider,
    Agents.Infrastructure.Mcp.ToolProviders.ToolsToolProvider,
    Agents.Infrastructure.Mcp.ToolProviders.TicketToolProvider
  ]
  ```
- [ ] ⏸ **REFACTOR**: Clean up

### Step 2.12: Update AGENTS.md

- [ ] ⏸ **GREEN**: Update `AGENTS.md` to:
  - Add section documenting the 8 new MCP ticket tools (tool names, parameters, usage examples)
  - Delineate: "Use perme8-mcp ticket tools for all GitHub issue operations; retain `gh` CLI for PR operations (`gh pr create`, `gh pr view`, `gh api repos/.../pulls/...`)"
  - Note that `gh issue` commands should no longer be used by skills (migration in separate ticket)
- [ ] ⏸ **REFACTOR**: Ensure the documentation is consistent with existing AGENTS.md style

### Phase 2 Validation

- [ ] ⏸ All tool provider tests pass
- [ ] ⏸ All 8 tool module tests pass (with mocked GitHub client)
- [ ] ⏸ Helper module tests pass
- [ ] ⏸ Config registration verified
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ Pre-commit checks pass (`mix precommit`)

---

## BDD Feature File Coverage Matrix

The following matrix maps each BDD scenario to the tool module and unit test that covers it:

### HTTP Feature Scenarios (24 scenarios)

| # | BDD Scenario | Tool | Unit Test Coverage | Key Assertions |
|---|-------------|------|--------------------|----------------|
| 1 | Read an issue by number | `ticket.read` | `read_tool_test.exs` — "returns formatted issue details" | `isError: false`, text contains "Title", "Labels", "State" |
| 2 | Read non-existent issue | `ticket.read` | `read_tool_test.exs` — "returns error with not found" | `isError: true`, text contains "not found" |
| 3 | Read missing required number param | `ticket.read` | Hermes schema validation → `-32602` | `error.code: -32602`, no `result` |
| 4 | List issues with no filters | `ticket.list` | `list_tool_test.exs` — "returns formatted list" | `isError: false`, text contains "Issue" |
| 5 | List issues filtered by state | `ticket.list` | `list_tool_test.exs` — "passes state filter" | `isError: false` |
| 6 | List issues filtered by labels | `ticket.list` | `list_tool_test.exs` — "passes labels filter" | `isError: false`, text contains "enhancement" |
| 7 | List issues with search query | `ticket.list` | `list_tool_test.exs` — "passes query" | `isError: false` |
| 8 | Create issue with title and body | `ticket.create` | `create_tool_test.exs` — "creates issue" | `isError: false`, text matches `.*#[0-9]+.*` |
| 9 | Create issue with labels | `ticket.create` | `create_tool_test.exs` — "creates with labels" | `isError: false` |
| 10 | Create fails without title | `ticket.create` | Hermes schema validation → `-32602` | `error.code: -32602` |
| 11 | Update issue title | `ticket.update` | `update_tool_test.exs` — "updates title" | `isError: false` |
| 12 | Update non-existent issue | `ticket.update` | `update_tool_test.exs` — "not found error" | `isError: true`, text contains "not found" |
| 13 | Update missing number | `ticket.update` | Hermes schema validation → `-32602` | `error.code: -32602` |
| 14 | Close issue with comment | `ticket.close` | `close_tool_test.exs` — "closes with comment" | `isError: false` |
| 15 | Close non-existent issue | `ticket.close` | `close_tool_test.exs` — "not found error" | `isError: true` |
| 16 | Close missing number | `ticket.close` | Hermes schema validation → `-32602` | `error.code: -32602` |
| 17 | Add comment to issue | `ticket.comment` | `comment_tool_test.exs` — "adds comment" | `isError: false` |
| 18 | Comment on non-existent issue | `ticket.comment` | `comment_tool_test.exs` — "not found error" | `isError: true` |
| 19 | Comment missing body | `ticket.comment` | Hermes schema validation → `-32602` | `error.code: -32602` |
| 20 | Add sub-issue | `ticket.add_sub_issue` | `add_sub_issue_tool_test.exs` — "links sub-issue" | `isError: false` |
| 21 | Add sub-issue missing params | `ticket.add_sub_issue` | Hermes schema validation → `-32602` | `error.code: -32602` |
| 22 | Remove sub-issue | `ticket.remove_sub_issue` | `remove_sub_issue_tool_test.exs` — "unlinks sub-issue" | `isError: false` |
| 23 | Remove sub-issue missing params | `ticket.remove_sub_issue` | Hermes schema validation → `-32602` | `error.code: -32602` |
| 24 | Permission denied for ticket.read | `ticket.read` | `read_tool_test.exs` — "denies execution" | `isError: true`, text contains "Insufficient permissions", "mcp:ticket.read" |

### Security Feature Scenarios (3 scenarios)

| # | BDD Scenario | Coverage | Notes |
|---|-------------|----------|-------|
| 1 | Active scan — no injection vulnerabilities | ZAP adapter | Validates that integer/string/array params are safe from SQLi, XSS, path traversal, command injection |
| 2 | Passive scan — no sensitive leakage | ZAP adapter | Validates that auth tokens and validation error details don't leak |
| 3 | Generate security audit report | ZAP adapter | Produces HTML+JSON audit reports |

---

## File Inventory

### New Files (16 files)

| File | Type | Purpose |
|------|------|---------|
| `apps/agents/lib/agents/application/behaviours/github_ticket_client_behaviour.ex` | Behaviour | Contract for GitHub ticket operations |
| `apps/agents/lib/agents/infrastructure/mcp/tool_providers/ticket_tool_provider.ex` | Tool Provider | Registers 8 ticket tools with MCP server |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/helpers.ex` | Helper | Shared client resolution, config, formatting |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/read_tool.ex` | Tool | `ticket.read` — view issue by number |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/list_tool.ex` | Tool | `ticket.list` — list/search issues |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/create_tool.ex` | Tool | `ticket.create` — create issue |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/update_tool.ex` | Tool | `ticket.update` — update issue |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/close_tool.ex` | Tool | `ticket.close` — close issue |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/comment_tool.ex` | Tool | `ticket.comment` — add comment |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/add_sub_issue_tool.ex` | Tool | `ticket.add_sub_issue` — link sub-issue |
| `apps/agents/lib/agents/infrastructure/mcp/tools/ticket/remove_sub_issue_tool.ex` | Tool | `ticket.remove_sub_issue` — unlink sub-issue |
| `apps/agents/test/agents/application/behaviours/github_ticket_client_behaviour_test.exs` | Test | Behaviour callback verification |
| `apps/agents/test/agents/infrastructure/mcp/tool_providers/ticket_tool_provider_test.exs` | Test | Provider component spec tests |
| `apps/agents/test/agents/infrastructure/mcp/tools/ticket/helpers_test.exs` | Test | Helper module tests |
| `apps/agents/test/agents/infrastructure/mcp/tools/ticket/*_test.exs` (8 files) | Tests | One test file per tool |
| `apps/agents/test/support/fixtures/ticket_fixtures.ex` | Fixture | Test data factories |

### Modified Files (4 files)

| File | Change |
|------|--------|
| `apps/agents/lib/agents/tickets/infrastructure/clients/github_project_client.ex` | Add 8 new functions: `get_issue/2`, `list_issues/1`, `create_issue/2`, `update_issue/3`, `close_issue_with_comment/2`, `add_comment/3`, `add_sub_issue/3`, `remove_sub_issue/3` |
| `apps/agents/test/test_helper.exs` | Add `Mox.defmock(Agents.Mocks.GithubTicketClientMock, ...)` |
| `config/config.exs` | Add `TicketToolProvider` to `:mcp_tool_providers` list |
| `AGENTS.md` | Add ticket MCP tools documentation, delineate MCP vs gh CLI usage |

### Pre-existing Files (not modified by this plan)

| File | Role |
|------|------|
| `apps/agents/test/features/perme8-mcp/ticket-tools/ticket-tools.http.feature` | 24 HTTP BDD scenarios (already created) |
| `apps/agents/test/features/perme8-mcp/ticket-tools/ticket-tools.security.feature` | 3 security BDD scenarios (already created) |

---

## Testing Strategy

- **Total estimated tests**: ~65
- **Distribution**:
  - Behaviour verification: 2 tests
  - GitHub client (integration with HTTP stubs): ~25 tests
  - Tool helper module: ~5 tests
  - Tool provider: 4 tests
  - Tool modules (8 tools × ~4 tests each): ~32 tests
- **Test approach**:
  - GitHub client tests use `Req.Test` adapter to stub HTTP responses (no real API calls)
  - Tool module tests use Mox mock of `GithubTicketClientBehaviour` (matching existing pattern)
  - All tool tests are `async: false` (matching existing tool test pattern)
  - Permission denial tests included in each tool's test file (matching existing pattern)
  - BDD feature files test the full MCP JSON-RPC flow end-to-end (run separately via exo-bdd)

## Implementation Notes for TDD Agent

### Tool Module Pattern (copy from existing)

Every tool module follows this exact pattern:

```elixir
defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ReadTool do
  use Hermes.Server.Component, type: :tool
  require Logger
  alias Hermes.Server.Response
  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Infrastructure.Mcp.Tools.Ticket.Helpers

  schema do
    field(:number, {:required, :integer}, description: "Issue number")
  end

  @impl true
  def execute(%{number: number}, frame) do
    case PermissionGuard.check_permission(frame, "ticket.read") do
      :ok ->
        case Helpers.github_client().get_issue(number, Helpers.client_opts()) do
          {:ok, issue} ->
            {:reply, Response.text(Response.tool(), Helpers.format_issue(issue)), frame}
          {:error, :not_found} ->
            {:reply, Response.error(Response.tool(), "Issue ##{number} not found."), frame}
          {:error, reason} ->
            Logger.error("ReadTool error: #{inspect(reason)}")
            {:reply, Response.error(Response.tool(), "Failed to read issue: #{inspect(reason)}"), frame}
        end
      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"), frame}
    end
  end
end
```

### Tool Test Pattern (copy from existing)

Every tool test follows this exact pattern:

```elixir
defmodule Agents.Infrastructure.Mcp.Tools.Ticket.ReadToolTest do
  use ExUnit.Case, async: false
  import Mox
  alias Agents.Infrastructure.Mcp.Tools.Ticket.ReadTool
  alias Agents.Test.TicketFixtures, as: Fixtures
  alias Hermes.Server.Frame

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:agents, :github_ticket_client, Agents.Mocks.GithubTicketClientMock)
    Application.put_env(:agents, :identity_module, Agents.Mocks.IdentityMock)
    stub(Agents.Mocks.IdentityMock, :api_key_has_permission?, fn _api_key, _scope -> true end)
    on_exit(fn -> Application.delete_env(:agents, :github_ticket_client) end)
    on_exit(fn -> Application.delete_env(:agents, :identity_module) end)
    :ok
  end

  defp build_frame do
    Frame.new(%{api_key: Fixtures.api_key_struct()})
  end

  describe "execute/2" do
    test "returns formatted issue details" do
      frame = build_frame()
      issue = Fixtures.issue_map(%{number: 1, title: "Test Issue"})
      Agents.Mocks.GithubTicketClientMock
      |> expect(:get_issue, fn 1, _opts -> {:ok, issue} end)

      assert {:reply, response, ^frame} = ReadTool.execute(%{number: 1}, frame)
      assert %Hermes.Server.Response{type: :tool, isError: false} = response
      assert [%{"type" => "text", "text" => text}] = response.content
      assert text =~ "Title"
      assert text =~ "Labels"
      assert text =~ "State"
    end
    # ... more tests
  end
end
```

### Formatting Requirements (from BDD scenarios)

The formatted output for `ticket.read` MUST contain these strings (verified by BDD):
- `"Title"` — issue title header/label
- `"Labels"` — labels section
- `"State"` — state indicator

The formatted output for `ticket.list` MUST contain:
- `"Issue"` — each issue entry
- Label names when filtering by labels (e.g., `"enhancement"`)

The formatted output for `ticket.create` MUST match:
- `.*#[0-9]+.*` — issue number in `#N` format

---

## Out of Scope (explicit exclusions)

- [ ] Skills repo migration (`platform-q-ai/skills`) — separate ticket/PR
- [ ] `ticket.add_dependency` / `ticket.remove_dependency` — P1 follow-up
- [ ] Opencode Docker image rebuild — P2 follow-up
- [ ] PR management MCP tools — PRs remain on `gh` CLI
- [ ] Changes to `TicketSyncServer` or Sessions UI ticket display

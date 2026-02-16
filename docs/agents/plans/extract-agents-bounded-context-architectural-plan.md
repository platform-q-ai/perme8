# Feature: Extract Agents Bounded Context from Jarga into Standalone App

**GitHub Issue**: #51
**Status**: ⏸ Not Started
**Created**: 2026-02-16

## Overview

Extract the `Jarga.Agents` bounded context from the `jarga` umbrella app into its own independent `agents` umbrella app. This follows the Modularity principle — Agents is a cohesive domain (agent CRUD, cloning, LLM client, query execution) that other contexts (Documents, Chat, JargaWeb) consume via its public API facade.

The key challenge is a **namespace migration** (`Jarga.Agents.*` → `Agents.*`) combined with preserving all 54+ BDD scenarios, maintaining database compatibility, and correctly wiring cross-context dependencies.

## UI Strategy

- **LiveView coverage**: 100% — all UI stays in `jarga_web`, only the aliased context module changes
- **TypeScript needed**: None — this is a backend extraction, no UI changes

## Affected Boundaries

- **Primary context**: `Agents` (new standalone app, extracted from `Jarga.Agents`)
- **Dependencies (agents app depends on)**:
  - `Identity` — for `Identity.Repo`, `Identity.Infrastructure.Schemas.UserSchema`, `Identity.Infrastructure.Schemas.WorkspaceSchema`
  - `Jarga.Accounts` — for `get_user!/1` (used by SyncAgentWorkspaces)
  - `Jarga.Workspaces` — for `member?/2`, `list_workspaces_for_user/1` (used by CloneSharedAgent, SyncAgentWorkspaces)
- **Consumers (depend on agents)**:
  - `Jarga.Documents` — calls `Agents.agent_query/2`, `Agents.get_workspace_agents_list/3`
  - `Jarga.Chat` — uses agent's `system_prompt` field via `Agents` facade
  - `JargaWeb` — LiveViews call `Agents.*` facade functions
- **Exported schemas**: `Agents.Domain.Entities.Agent` (used by consumers matching on agent structs)
- **New context needed?**: Yes — new umbrella app `agents` under `apps/agents/`

## Module Renaming Strategy

All modules under `Jarga.Agents.*` become `Agents.*`:

| Old Module | New Module |
|---|---|
| `Jarga.Agents` | `Agents` |
| `Jarga.Agents.Domain` | `Agents.Domain` |
| `Jarga.Agents.Domain.Entities.Agent` | `Agents.Domain.Entities.Agent` |
| `Jarga.Agents.Domain.Entities.WorkspaceAgentJoin` | `Agents.Domain.Entities.WorkspaceAgentJoin` |
| `Jarga.Agents.Domain.AgentCloner` | `Agents.Domain.AgentCloner` |
| `Jarga.Agents.Application` | `Agents.Application` |
| `Jarga.Agents.Application.UseCases.*` | `Agents.Application.UseCases.*` |
| `Jarga.Agents.Application.Policies.*` | `Agents.Application.Policies.*` |
| `Jarga.Agents.Application.Behaviours.*` | `Agents.Application.Behaviours.*` |
| `Jarga.Agents.Infrastructure` | `Agents.Infrastructure` |
| `Jarga.Agents.Infrastructure.Schemas.*` | `Agents.Infrastructure.Schemas.*` |
| `Jarga.Agents.Infrastructure.Repositories.*` | `Agents.Infrastructure.Repositories.*` |
| `Jarga.Agents.Infrastructure.Queries.*` | `Agents.Infrastructure.Queries.*` |
| `Jarga.Agents.Infrastructure.Services.*` | `Agents.Infrastructure.Services.*` |
| `Jarga.Agents.Infrastructure.Notifiers.*` | `Agents.Infrastructure.Notifiers.*` |

## Migration Strategy

### Database Tables
The `agents` and `workspace_agents` tables already exist via migration `20251120175234_add_user_agents_and_preferences.exs` in `apps/jarga/priv/repo/migrations/`. **No new migrations needed.** The migration stays in Jarga since:
1. It also modifies the `users` table (adding `preferences` column)
2. Tables are already created in production
3. Moving migrations risks re-running them

### Configuration
The OpenRouter config in `config/runtime.exs` currently uses `:jarga` app key:
```elixir
config :jarga, :openrouter, ...
```
This must change to `:agents` app key:
```elixir
config :agents, :openrouter, ...
```

### PubSub Compatibility
The PubSubNotifier broadcasts on `Jarga.PubSub`. The new app must continue using `Jarga.PubSub` (not create its own) to maintain real-time compatibility. The PubSub process is started by `JargaWeb.Application` and shared across the umbrella.

## Risk Areas and Rollback Approach

### Risks
1. **Compilation order**: The new `agents` app must compile before `jarga` and `jarga_web` since they depend on it
2. **Test fixtures**: `Jarga.AgentsFixtures` is used across `jarga` and `jarga_web` tests — must be moved to new app and re-imported
3. **Mox mock definitions**: `Jarga.Agents.Infrastructure.Services.LlmClientMock` in test_helper.exs needs updating
4. **Boundary cascading**: Removing `Jarga.Agents.*` boundaries from Jarga's boundary config while adding them in the new app
5. **Config namespace**: LlmClient reads from `:jarga` app config — must switch to `:agents`

### Rollback
- Each phase is independently testable
- Phase 1 (new app with tests) can exist alongside the old code
- Phase 2 (consumers updated) is the critical switchover
- If rollback needed: revert the consumer changes and delete the new app directory

---

## Phase 1: Create Agents Umbrella App Scaffold

This phase creates the new `apps/agents/` umbrella app structure and migrates all domain, application, and infrastructure code with tests.

### Step 1.1: Generate Agents App Scaffold

- [ ] ⏸ **Create new umbrella app**
  - Run `mix new agents --sup` in `apps/` directory
  - This creates a plain Elixir app with supervision tree (no Ecto/Phoenix — agents uses Identity.Repo)

- [ ] ⏸ **Configure `apps/agents/mix.exs`**
  - Add umbrella dependencies: `{:identity, in_umbrella: true}`
  - Add external deps: `boundary`, `ecto_sql`, `phoenix_ecto`, `postgrex`, `phoenix_live_view`, `phoenix_html`, `req`, `jason`, `mox` (test), `bypass` (test)
  - Add compilers: `[:boundary, :phoenix_live_view] ++ Mix.compilers()`
  - Add boundary config (same pattern as jarga's): `externals_mode: :relaxed`, ignore test modules
  - Add `elixirc_paths/1`: `["lib", "test/support"]` for `:test`, `["lib"]` otherwise
  - Add test aliases: `test: ["test"]`

- [ ] ⏸ **Create `apps/agents/lib/agents.ex`** — root namespace module
  ```elixir
  defmodule Agents do
    use Boundary, top_level?: true, deps: [], exports: []
  end
  ```

### Step 1.2: Domain Layer — Entities

#### Agent Entity
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/domain/entities/agent_test.exs`
  - Module: `Agents.Domain.Entities.AgentTest`
  - Tests: `new/1` creates struct with defaults, `from_schema/1` converts schema to entity, `valid_visibilities/0` returns list, default temperature is 0.7, default visibility is "PRIVATE", default enabled is true
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/domain/entities/agent.ex`
  - Module: `Agents.Domain.Entities.Agent` — copy from `Jarga.Agents.Domain.Entities.Agent`, rename module
- [ ] ⏸ **REFACTOR**: Ensure pure struct, no Ecto deps

#### WorkspaceAgentJoin Entity
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/domain/entities/workspace_agent_join_test.exs`
  - Module: `Agents.Domain.Entities.WorkspaceAgentJoinTest`
  - Tests: `new/1` creates struct, `from_schema/1` converts schema to entity
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/domain/entities/workspace_agent_join.ex`
  - Module: `Agents.Domain.Entities.WorkspaceAgentJoin` — copy and rename
- [ ] ⏸ **REFACTOR**: Clean up

#### Domain Boundary Module
- [ ] ⏸ **Create** `apps/agents/lib/agents/domain.ex`
  - Module: `Agents.Domain`
  - Boundary: `top_level?: true, deps: [], exports: [Entities.Agent, Entities.WorkspaceAgentJoin, AgentCloner]`

### Step 1.3: Domain Layer — Services

#### AgentCloner
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/domain/agent_cloner_test.exs`
  - Module: `Agents.Domain.AgentClonerTest`
  - Tests: copies name with " (Copy)" suffix, sets visibility to PRIVATE, sets new user_id, copies system_prompt/model/temperature/description
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/domain/agent_cloner.ex`
  - Module: `Agents.Domain.AgentCloner` — copy and rename
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.4: Application Layer — Policies

#### AgentPolicy
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/policies/agent_policy_test.exs`
  - Module: `Agents.Application.Policies.AgentPolicyTest`
  - Tests: can_edit? (owner true, non-owner false), can_delete? (owner true, non-owner false), can_clone? (owner always true, shared+workspace_member true, private non-owner false, shared non-member false)
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/policies/agent_policy.ex`
  - Module: `Agents.Application.Policies.AgentPolicy`
- [ ] ⏸ **REFACTOR**: Clean up

#### VisibilityPolicy
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/policies/visibility_policy_test.exs`
  - Module: `Agents.Application.Policies.VisibilityPolicyTest`
  - Tests: owner can view any visibility, shared+member can view, private non-owner cannot view, shared non-member cannot view
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/policies/visibility_policy.ex`
  - Module: `Agents.Application.Policies.VisibilityPolicy`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.5: Application Layer — Behaviours

- [ ] ⏸ **Create all behaviour modules** (no tests needed — pure interfaces):
  - `apps/agents/lib/agents/application/behaviours/agent_repository_behaviour.ex` — `Agents.Application.Behaviours.AgentRepositoryBehaviour`
  - `apps/agents/lib/agents/application/behaviours/workspace_agent_repository_behaviour.ex` — `Agents.Application.Behaviours.WorkspaceAgentRepositoryBehaviour`
  - `apps/agents/lib/agents/application/behaviours/agent_schema_behaviour.ex` — `Agents.Application.Behaviours.AgentSchemaBehaviour`
  - `apps/agents/lib/agents/application/behaviours/llm_client_behaviour.ex` — `Agents.Application.Behaviours.LlmClientBehaviour`
  - `apps/agents/lib/agents/application/behaviours/pub_sub_notifier_behaviour.ex` — `Agents.Application.Behaviours.PubSubNotifierBehaviour`

### Step 1.6: Application Layer — Use Cases

#### AgentQuery Use Case
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/application/use_cases/agent_query_test.exs`
  - Module: `Agents.Application.UseCases.AgentQueryTest`
  - Mocks: `LlmClientMock` (via Mox)
  - Tests: builds messages from question/assigns, uses agent's system_prompt/model/temperature when provided, falls back to defaults without agent, streams response to caller with node_id wrapping, handles cancellation, handles errors, handles timeout
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/agent_query.ex`
  - Module: `Agents.Application.UseCases.AgentQuery`
  - **IMPORTANT**: Update `@default_llm_client` to `Agents.Infrastructure.Services.LlmClient`
- [ ] ⏸ **REFACTOR**: Clean up

#### CreateUserAgent, UpdateUserAgent, DeleteUserAgent Use Cases
- [ ] ⏸ **GREEN**: Implement all CRUD use cases (copied from Jarga, rename modules and default repo references):
  - `apps/agents/lib/agents/application/use_cases/create_user_agent.ex` — `Agents.Application.UseCases.CreateUserAgent`
  - `apps/agents/lib/agents/application/use_cases/update_user_agent.ex` — `Agents.Application.UseCases.UpdateUserAgent`
  - `apps/agents/lib/agents/application/use_cases/delete_user_agent.ex` — `Agents.Application.UseCases.DeleteUserAgent`
  - Update all `@default_*` module attributes to point to `Agents.Infrastructure.*` modules

#### ListUserAgents, ListViewableAgents, ListWorkspaceAvailableAgents Use Cases
- [ ] ⏸ **GREEN**: Implement all list use cases:
  - `apps/agents/lib/agents/application/use_cases/list_user_agents.ex` — `Agents.Application.UseCases.ListUserAgents`
  - `apps/agents/lib/agents/application/use_cases/list_viewable_agents.ex` — `Agents.Application.UseCases.ListViewableAgents`
  - `apps/agents/lib/agents/application/use_cases/list_workspace_available_agents.ex` — `Agents.Application.UseCases.ListWorkspaceAvailableAgents`

#### CloneSharedAgent Use Case
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/application/use_cases/clone_shared_agent.ex`
  - Module: `Agents.Application.UseCases.CloneSharedAgent`
  - **IMPORTANT**: Update `@default_workspaces` from `Jarga.Workspaces` — this is a cross-context dependency that the new app inherits. The agents app must declare `jarga` as an umbrella dependency OR abstract this via a behaviour. **Decision: Keep `Jarga.Workspaces` as the default** since agents depends on jarga for Workspaces/Accounts context access.

#### ValidateAgentParams, SyncAgentWorkspaces, AddAgentToWorkspace, RemoveAgentFromWorkspace
- [ ] ⏸ **GREEN**: Implement remaining use cases:
  - `apps/agents/lib/agents/application/use_cases/validate_agent_params.ex`
  - `apps/agents/lib/agents/application/use_cases/sync_agent_workspaces.ex` — Update `@default_accounts` to `Jarga.Accounts`, `@default_workspaces` to `Jarga.Workspaces`
  - `apps/agents/lib/agents/application/use_cases/add_agent_to_workspace.ex`
  - `apps/agents/lib/agents/application/use_cases/remove_agent_from_workspace.ex`

#### Application Boundary Module
- [ ] ⏸ **Create** `apps/agents/lib/agents/application.ex`
  - Module: `Agents.Application` (NOTE: This is the boundary module, NOT the OTP Application. The OTP app supervisor should be named differently, e.g., `Agents.OTPApp` or the supervision tree can be in the root `Agents` module)
  - Boundary: `top_level?: true, deps: [Agents.Domain], exports: [all use cases, policies, behaviours]`

### Step 1.7: Infrastructure Layer — Schemas

#### AgentSchema
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/schemas/agent_schema.ex`
  - Module: `Agents.Infrastructure.Schemas.AgentSchema`
  - `@behaviour Agents.Application.Behaviours.AgentSchemaBehaviour`
  - References `Identity.Infrastructure.Schemas.UserSchema` (unchanged)
  - Schema on `"agents"` table (unchanged)

#### WorkspaceAgentJoinSchema
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/schemas/workspace_agent_join_schema.ex`
  - Module: `Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema`
  - References `Identity.Infrastructure.Schemas.WorkspaceSchema` and `Agents.Infrastructure.Schemas.AgentSchema`

### Step 1.8: Infrastructure Layer — Queries

#### AgentQueries
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/queries/agent_queries_test.exs`
  - Module: `Agents.Infrastructure.Queries.AgentQueriesTest`
  - Use `Agents.DataCase` (to be created)
  - Tests: base/0 returns queryable, for_user/2 filters by user_id, by_visibility/2 filters by visibility, in_workspace/2 joins and filters by workspace_id
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/queries/agent_queries.ex`
  - Module: `Agents.Infrastructure.Queries.AgentQueries`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.9: Infrastructure Layer — Repositories

#### AgentRepository
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/repositories/agent_repository_test.exs`
  - Module: `Agents.Infrastructure.Repositories.AgentRepositoryTest`
  - Tests: get/1, get_agent_for_user/2, list_agents_for_user/1, create_agent/1, update_agent/2, delete_agent/1, list_viewable_agents/1
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/repositories/agent_repository.ex`
  - Module: `Agents.Infrastructure.Repositories.AgentRepository`
  - Uses `Identity.Repo` (unchanged)
- [ ] ⏸ **REFACTOR**: Clean up

#### WorkspaceAgentRepository
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/repositories/workspace_agent_repository_test.exs`
  - Module: `Agents.Infrastructure.Repositories.WorkspaceAgentRepositoryTest`
  - Tests: add_to_workspace/2, remove_from_workspace/2, list_workspace_agents/2, agent_in_workspace?/2, get_agent_workspace_ids/1, sync_agent_workspaces/3
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/repositories/workspace_agent_repository.ex`
  - Module: `Agents.Infrastructure.Repositories.WorkspaceAgentRepository`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.10: Infrastructure Layer — Services

#### LlmClient
- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/infrastructure/services/llm_client_test.exs`
  - Module: `Agents.Infrastructure.Services.LlmClientTest`
  - Uses Bypass for HTTP mocking
  - Tests: chat/2 success, chat/2 API error, chat/2 no API key, chat_stream/3 basic streaming
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/services/llm_client.ex`
  - Module: `Agents.Infrastructure.Services.LlmClient`
  - **IMPORTANT**: Change `config/0` to read from `:agents` app instead of `:jarga`:
    ```elixir
    defp config(key, default \\ nil) do
      Application.get_env(:agents, :openrouter, [])
      |> Keyword.get(key, default)
    end
    ```
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.11: Infrastructure Layer — Notifiers

#### PubSubNotifier
- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/notifiers/pub_sub_notifier.ex`
  - Module: `Agents.Infrastructure.Notifiers.PubSubNotifier`
  - **IMPORTANT**: Continue using `Jarga.PubSub` as the PubSub server name for compatibility
  - Topic format stays: `"workspace:#{workspace_id}"`, `"user:#{user_id}"`

#### Infrastructure Boundary Module
- [ ] ⏸ **Create** `apps/agents/lib/agents/infrastructure.ex`
  - Module: `Agents.Infrastructure`
  - Boundary: `top_level?: true, deps: [Agents.Domain, Agents.Application, Identity, Identity.Repo, Jarga.Accounts, Jarga.Workspaces], exports: [all schemas, repositories, services, queries, notifiers]`

### Step 1.12: Context Facade

- [ ] ⏸ **GREEN**: Implement `apps/agents/lib/agents.ex` (update from scaffold)
  - Module: `Agents`
  - Full facade with `use Boundary`:
    ```elixir
    use Boundary,
      top_level?: true,
      deps: [
        Agents.Domain,
        Agents.Application,
        Agents.Infrastructure,
        Jarga.Accounts,
        Jarga.Workspaces,
        Identity.Repo
      ],
      exports: [
        {Domain.Entities.Agent, []}
      ]
    ```
  - Copy all `defdelegate` and public functions from `Jarga.Agents`, update aliases to `Agents.*`

### Step 1.13: Test Support Infrastructure

- [ ] ⏸ **Create** `apps/agents/test/support/data_case.ex`
  - Module: `Agents.DataCase`
  - Uses `Ecto.Adapters.SQL.Sandbox` with `Identity.Repo`
  - Pattern: same as `Jarga.DataCase`

- [ ] ⏸ **Create** `apps/agents/test/support/fixtures/agents_fixtures.ex`
  - Module: `Agents.AgentsFixtures` (new namespace)
  - Functions: `user_agent_fixture/1`, `agent_fixture/2`
  - Calls `Agents.create_user_agent/1` (new facade)
  - Depends on `Jarga.AccountsFixtures` for `user_fixture/0` (cross-app test dependency)

- [ ] ⏸ **Create** `apps/agents/test/test_helper.exs`
  - Start ExUnit
  - Set sandbox mode for `Identity.Repo`
  - Define Mox mock: `Agents.Infrastructure.Services.LlmClientMock` for `Agents.Application.Behaviours.LlmClientBehaviour`

### Step 1.14: Integration Test — Context Facade

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents_test.exs`
  - Module: `AgentsTest`
  - Uses `Agents.DataCase`
  - Tests: All public API functions through the facade (mirrors existing `Jarga.AgentsTest`)
  - Covers: list_user_agents, create_user_agent, update_user_agent, delete_user_agent, clone_shared_agent, list_workspace_available_agents, get_workspace_agents_list, cancel_agent_query
- [ ] ⏸ **GREEN**: Ensure all tests pass against new `Agents` facade

### Phase 1 Validation
- [ ] ⏸ All domain tests pass (`mix test apps/agents/test/agents/domain/`) — milliseconds, no I/O
- [ ] ⏸ All application tests pass (`mix test apps/agents/test/agents/application/`)
- [ ] ⏸ All infrastructure tests pass (`mix test apps/agents/test/agents/infrastructure/`)
- [ ] ⏸ Facade integration tests pass (`mix test apps/agents/test/agents_test.exs`)
- [ ] ⏸ No boundary violations (`mix compile` in agents app)
- [ ] ⏸ `mix test` in agents app passes

---

## Phase 2: Update Configuration and Cross-Context Dependencies

This phase wires the new agents app into the umbrella, updates all consumers, and removes the old code from Jarga.

### Step 2.1: Update Umbrella Configuration

- [ ] ⏸ **Update `config/runtime.exs`**
  - Change OpenRouter config from `:jarga` to `:agents`:
    ```elixir
    config :agents, :openrouter,
      api_key: System.get_env("OPENROUTER_API_KEY"),
      ...
    ```
  - Keep `:jarga` config for any remaining Jarga-specific settings

- [ ] ⏸ **Update `apps/jarga/mix.exs`**
  - Add `{:agents, in_umbrella: true}` to deps (Jarga.Documents and Jarga.Chat need Agents)

- [ ] ⏸ **Update `apps/jarga_web/mix.exs`**
  - Add `{:agents, in_umbrella: true}` to deps
  - Keep `{:jarga, in_umbrella: true}` (still needed for other contexts)
  - Update boundary config to add `{:agents, :relaxed}` to apps check list

### Step 2.2: OTP Application Setup

- [ ] ⏸ **Create/Update `apps/agents/lib/agents/otp_app.ex`**
  - Module: `Agents.OTPApp` (to avoid collision with `Agents.Application` boundary module)
  - Starts supervision tree (currently agents has no supervised processes, but scaffold for future)
  - Update `apps/agents/mix.exs` application: `mod: {Agents.OTPApp, []}`

### Step 2.3: Update Jarga — Documents Context

- [ ] ⏸ **Update `apps/jarga/lib/documents.ex`**
  - Change boundary deps: replace `Jarga.Agents` with `Agents`
  - Update any function calls from `Jarga.Agents.*` to `Agents.*`

- [ ] ⏸ **Update `apps/jarga/lib/documents/application.ex`**
  - Change boundary deps: replace `Jarga.Agents` with `Agents`

- [ ] ⏸ **Update Documents use cases that call Agents**
  - Search for `Jarga.Agents` in Documents use cases and update to `Agents`
  - Primary file: `ExecuteAgentQuery` use case

### Step 2.4: Update Jarga — Chat Context

- [ ] ⏸ **Update `apps/jarga/lib/chat.ex`**
  - Change boundary deps: replace `Jarga.Agents` with `Agents`

- [ ] ⏸ **Update Chat use cases/modules that reference Agents**
  - `PrepareContext` — if it aliases `Jarga.Agents`, update to `Agents`

### Step 2.5: Update JargaWeb — Boundary and LiveViews

- [ ] ⏸ **Update `apps/jarga_web/lib/jarga_web.ex`**
  - Change boundary deps: replace `Jarga.Agents` with `Agents`

- [ ] ⏸ **Update LiveViews**:
  - `apps/jarga_web/lib/live/app_live/agents/index.ex` — `alias Jarga.Agents` → `alias Agents`
  - `apps/jarga_web/lib/live/app_live/agents/form.ex` — `alias Jarga.Agents` → `alias Agents`
  - `apps/jarga_web/lib/live/app_live/workspaces/show.ex` — `Jarga.Agents.*` → `Agents.*`
  - `apps/jarga_web/lib/live/app_live/projects/show.ex` — `Jarga.Agents.*` → `Agents.*`
  - `apps/jarga_web/lib/live/app_live/documents/show.ex` — `Jarga.Agents.*` → `Agents.*`
  - `apps/jarga_web/lib/live/app_live/dashboard.ex` — `Jarga.Agents.*` → `Agents.*`
  - `apps/jarga_web/lib/live/chat_live/panel.ex` — `alias Jarga.Agents` → `alias Agents`

### Step 2.6: Update Jarga Layer Documentation Modules

- [ ] ⏸ **Update `apps/jarga/lib/jarga/domain.ex`**
  - Remove all references to `Jarga.Agents.Domain.*` from documentation and introspection functions

- [ ] ⏸ **Update `apps/jarga/lib/jarga/application_layer.ex`**
  - Remove all references to `Jarga.Agents.Application.*`

- [ ] ⏸ **Update `apps/jarga/lib/jarga/infrastructure_layer.ex`**
  - Remove all references to `Jarga.Agents.Infrastructure.*`

### Step 2.7: Update Test Support Across Apps

- [ ] ⏸ **Update `apps/jarga/test/test_helper.exs`**
  - Remove Mox mock definition for `Jarga.Agents.Infrastructure.Services.LlmClientMock`
  - (The new mock is defined in `apps/agents/test/test_helper.exs`)

- [ ] ⏸ **Update or Remove `apps/jarga/test/support/fixtures/agents_fixtures.ex`**
  - Option A (preferred): Keep `Jarga.AgentsFixtures` as a thin wrapper that delegates to `Agents.AgentsFixtures` — preserves compatibility with existing BDD step definitions
  - Option B: Update all BDD step definitions to import `Agents.AgentsFixtures` instead
  - **Decision: Option A** — minimal disruption to BDD tests

  ```elixir
  defmodule Jarga.AgentsFixtures do
    # Delegate to new agents app fixtures for backwards compatibility
    defdelegate user_agent_fixture(attrs \\ %{}), to: Agents.AgentsFixtures
    defdelegate agent_fixture(user, attrs \\ %{}), to: Agents.AgentsFixtures
  end
  ```

- [ ] ⏸ **Update `apps/jarga_web/test/support/feature_case.ex`**
  - Verify `import Jarga.AgentsFixtures` still works (via delegation wrapper)

- [ ] ⏸ **Update `apps/jarga_web/test/support/step_helpers.ex`**
  - Verify `Jarga.AgentsFixtures` references still work (via delegation wrapper)

### Step 2.8: Update Jarga Boundary Configuration

- [ ] ⏸ **Update `apps/jarga/lib/agents.ex`** — the OLD facade
  - Option A: Delete entirely (cleanest)
  - Option B: Keep as thin redirect module temporarily
  - **Decision: Delete.** Consumers are updated in steps 2.3-2.5 to use `Agents` directly.

- [ ] ⏸ **Delete old agents code from Jarga**:
  - Delete `apps/jarga/lib/agents/` directory entirely
  - Delete `apps/jarga/lib/agents.ex` facade
  - Delete `apps/jarga/test/agents/` directory entirely
  - Delete `apps/jarga/test/agents_test.exs`

- [ ] ⏸ **Update Jarga root boundary** (`apps/jarga/lib/jarga.ex`)
  - Remove `Jarga.Agents` from any remaining boundary refs (it's top_level?, so likely no change needed to the root module)

### Phase 2 Validation
- [ ] ⏸ `mix compile` across entire umbrella — no warnings, no boundary violations
- [ ] ⏸ `mix test apps/agents` — all agents app tests pass
- [ ] ⏸ `mix test apps/jarga` — all Jarga tests pass (documents, chat, etc.)
- [ ] ⏸ `mix test apps/jarga_web` — all web tests pass
- [ ] ⏸ All 54+ BDD scenarios pass (`mix test` in jarga_web with Cucumber)
- [ ] ⏸ `mix boundary` — no violations
- [ ] ⏸ `mix precommit` — full pre-commit checks pass

---

## Phase 3: Clean Up and Hardening

### Step 3.1: Verify No Stale References

- [ ] ⏸ **Search entire codebase** for remaining `Jarga.Agents` references
  - `grep -r "Jarga\.Agents" apps/` — should only find the delegation wrapper in fixtures
  - Fix any stragglers

### Step 3.2: Update Documentation

- [ ] ⏸ **Update `docs/umbrella_apps.md`** if it lists specific apps
  - Add `agents` to the list of umbrella apps

- [ ] ⏸ **Update `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md`** if it references `Jarga.Agents`
  - Update examples to use `Agents` namespace

### Step 3.3: Verify Dependency Graph

- [ ] ⏸ **Verify dependency arrows are correct**:
  ```
  agents → identity (Repo, UserSchema, WorkspaceSchema)
  agents → jarga (Accounts, Workspaces — for workspace membership checks)
  jarga → agents (Documents.ExecuteAgentQuery, Chat uses agent data)
  jarga_web → agents (LiveViews call Agents facade)
  ```
  - NOTE: `agents → jarga` creates a bidirectional umbrella dependency! This is architecturally concerning.
  
  **IMPORTANT DESIGN DECISION**: The current code has `SyncAgentWorkspaces` and `CloneSharedAgent` depending on `Jarga.Accounts` and `Jarga.Workspaces`. These are currently in the same app, but extracting agents creates a **circular dependency**: `agents` depends on `jarga` (for Accounts/Workspaces) AND `jarga` depends on `agents` (for Documents/Chat).

  **Resolution Options**:
  1. **Inject the Jarga dependencies via behaviours** — SyncAgentWorkspaces and CloneSharedAgent accept workspace/accounts functions via opts (they already do via DI!)
  2. **Don't declare `jarga` as umbrella dep** — use the existing DI opts pattern. The `@default_*` module attributes reference `Jarga.Workspaces`/`Jarga.Accounts` but these are resolved at runtime, not compile-time. The Boundary library handles this at the module level.
  3. **Extract Accounts/Workspaces to their own apps** — out of scope for this issue.

  **Decision: Option 2** — Don't declare `{:jarga, in_umbrella: true}` in agents' mix.exs. The agents app only declares `{:identity, in_umbrella: true}`. The `Jarga.Accounts`/`Jarga.Workspaces` references in `@default_*` attributes are runtime-resolved. The Boundary library config for `Agents.Infrastructure` will list `Jarga.Accounts` and `Jarga.Workspaces` as deps (boundary deps are compile-time metadata, not Mix deps).

  **Corrected dependency graph**:
  ```
  agents (Mix deps) → identity
  jarga (Mix deps) → identity, agents
  jarga_web (Mix deps) → jarga, agents
  
  agents (Boundary deps) → Identity, Identity.Repo, Jarga.Accounts, Jarga.Workspaces
  jarga (Boundary deps) → Agents, Identity, ...
  jarga_web (Boundary deps) → Agents, Jarga.*, ...
  ```

### Step 3.4: Pre-commit Checkpoint

- [ ] ⏸ Run `mix precommit` — compilation, boundary, format, credo, tests
- [ ] ⏸ Run `mix boundary` — verify no violations
- [ ] ⏸ Run full BDD suite — all 54+ scenarios pass
- [ ] ⏸ Verify no circular Mix dependencies

---

## Testing Strategy

### Test Distribution

| Layer | Location | Test Count (est.) | Async? |
|-------|----------|-------------------|--------|
| Domain Entities | `apps/agents/test/agents/domain/entities/` | 2 files, ~10 tests | Yes |
| Domain Services | `apps/agents/test/agents/domain/` | 1 file, ~5 tests | Yes |
| Application Policies | `apps/agents/test/agents/application/policies/` | 2 files, ~12 tests | Yes |
| Application Use Cases | `apps/agents/test/agents/application/use_cases/` | 1 file, ~8 tests | Yes (Mox) |
| Infrastructure Queries | `apps/agents/test/agents/infrastructure/queries/` | 1 file, ~6 tests | No (DB) |
| Infrastructure Repos | `apps/agents/test/agents/infrastructure/repositories/` | 2 files, ~15 tests | No (DB) |
| Infrastructure Services | `apps/agents/test/agents/infrastructure/services/` | 1 file, ~5 tests | Yes (Bypass) |
| Facade Integration | `apps/agents/test/agents_test.exs` | 1 file, ~15 tests | No (DB) |
| **BDD (unchanged)** | `apps/jarga_web/test/features/agents/` | 4 feature files, 54+ scenarios | No |

**Total estimated**: ~76 unit/integration tests + 54+ BDD scenarios

### Test Case Modules

- **Domain/Application tests**: `use ExUnit.Case, async: true` (pure logic, no DB)
- **Infrastructure/Facade tests**: `use Agents.DataCase` (needs DB sandbox via Identity.Repo)
- **BDD tests**: Continue using `Jarga.DataCase` and `JargaWeb.FeatureCase` (unchanged)

### Fixtures Strategy

```
apps/agents/test/support/fixtures/agents_fixtures.ex  →  Agents.AgentsFixtures (primary)
apps/jarga/test/support/fixtures/agents_fixtures.ex   →  Jarga.AgentsFixtures (delegation wrapper)
```

The delegation wrapper preserves compatibility with all existing BDD step definitions that `import Jarga.AgentsFixtures`.

---

## File Summary

### New Files (apps/agents/)

```
apps/agents/
├── mix.exs
├── lib/
│   └── agents.ex                                              # Facade + Boundary
│   └── agents/
│       ├── otp_app.ex                                         # OTP Application supervisor
│       ├── domain.ex                                          # Domain boundary
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── agent.ex                                   # Pure struct
│       │   │   └── workspace_agent_join.ex                    # Pure struct
│       │   └── agent_cloner.ex                                # Pure business logic
│       ├── application.ex                                     # Application boundary
│       ├── application/
│       │   ├── behaviours/
│       │   │   ├── agent_repository_behaviour.ex
│       │   │   ├── agent_schema_behaviour.ex
│       │   │   ├── llm_client_behaviour.ex
│       │   │   ├── pub_sub_notifier_behaviour.ex
│       │   │   └── workspace_agent_repository_behaviour.ex
│       │   ├── policies/
│       │   │   ├── agent_policy.ex
│       │   │   └── visibility_policy.ex
│       │   └── use_cases/
│       │       ├── add_agent_to_workspace.ex
│       │       ├── agent_query.ex
│       │       ├── clone_shared_agent.ex
│       │       ├── create_user_agent.ex
│       │       ├── delete_user_agent.ex
│       │       ├── list_user_agents.ex
│       │       ├── list_viewable_agents.ex
│       │       ├── list_workspace_available_agents.ex
│       │       ├── remove_agent_from_workspace.ex
│       │       ├── sync_agent_workspaces.ex
│       │       ├── update_user_agent.ex
│       │       └── validate_agent_params.ex
│       ├── infrastructure.ex                                  # Infrastructure boundary
│       └── infrastructure/
│           ├── notifiers/
│           │   └── pub_sub_notifier.ex
│           ├── queries/
│           │   └── agent_queries.ex
│           ├── repositories/
│           │   ├── agent_repository.ex
│           │   └── workspace_agent_repository.ex
│           ├── schemas/
│           │   ├── agent_schema.ex
│           │   └── workspace_agent_join_schema.ex
│           └── services/
│               └── llm_client.ex
└── test/
    ├── test_helper.exs
    ├── agents_test.exs                                        # Facade integration tests
    ├── support/
    │   ├── data_case.ex
    │   └── fixtures/
    │       └── agents_fixtures.ex
    └── agents/
        ├── domain/
        │   ├── entities/
        │   │   ├── agent_test.exs
        │   │   └── workspace_agent_join_test.exs
        │   └── agent_cloner_test.exs
        ├── application/
        │   ├── policies/
        │   │   ├── agent_policy_test.exs
        │   │   └── visibility_policy_test.exs
        │   └── use_cases/
        │       └── agent_query_test.exs
        └── infrastructure/
            ├── queries/
            │   └── agent_queries_test.exs
            ├── repositories/
            │   ├── agent_repository_test.exs
            │   └── workspace_agent_repository_test.exs
            └── services/
                └── llm_client_test.exs
```

### Modified Files

```
config/runtime.exs                                            # Add :agents OpenRouter config
apps/jarga/mix.exs                                            # Add {:agents, in_umbrella: true}
apps/jarga_web/mix.exs                                        # Add {:agents, in_umbrella: true}, boundary config
apps/jarga_web/lib/jarga_web.ex                               # Boundary deps: Jarga.Agents → Agents
apps/jarga_web/lib/live/app_live/agents/index.ex             # alias Jarga.Agents → alias Agents
apps/jarga_web/lib/live/app_live/agents/form.ex              # alias Jarga.Agents → alias Agents
apps/jarga_web/lib/live/app_live/workspaces/show.ex          # Jarga.Agents → Agents
apps/jarga_web/lib/live/app_live/projects/show.ex            # Jarga.Agents → Agents
apps/jarga_web/lib/live/app_live/documents/show.ex           # Jarga.Agents → Agents
apps/jarga_web/lib/live/app_live/dashboard.ex                # Jarga.Agents → Agents
apps/jarga_web/lib/live/chat_live/panel.ex                   # alias Jarga.Agents → alias Agents
apps/jarga/lib/documents.ex                                   # Boundary dep: Jarga.Agents → Agents
apps/jarga/lib/documents/application.ex                       # Boundary dep: Jarga.Agents → Agents
apps/jarga/lib/chat.ex                                        # Boundary dep: Jarga.Agents → Agents
apps/jarga/lib/jarga/domain.ex                                # Remove Agents references
apps/jarga/lib/jarga/application_layer.ex                     # Remove Agents references
apps/jarga/lib/jarga/infrastructure_layer.ex                  # Remove Agents references
apps/jarga/test/test_helper.exs                               # Remove LlmClientMock
apps/jarga/test/support/fixtures/agents_fixtures.ex           # Become delegation wrapper
```

### Deleted Files

```
apps/jarga/lib/agents.ex                                      # Old facade
apps/jarga/lib/agents/                                         # Entire directory (domain, application, infrastructure)
apps/jarga/test/agents/                                        # Old agents tests
apps/jarga/test/agents_test.exs                                # Old facade tests
```

---

## Dependency Analysis — Avoiding Circular Mix Dependencies

### The Problem

The current `Jarga.Agents` code internally references:
- `Jarga.Accounts.get_user!/1` (in SyncAgentWorkspaces)
- `Jarga.Workspaces.member?/2` (in CloneSharedAgent)
- `Jarga.Workspaces.list_workspaces_for_user/1` (in SyncAgentWorkspaces)

If `agents` declares `{:jarga, in_umbrella: true}` AND `jarga` declares `{:agents, in_umbrella: true}`, we get a circular Mix dependency.

### The Solution

**The agents app does NOT need `jarga` as a Mix dependency.** Here's why:

1. **All cross-context calls are via dependency injection** — every use case accepts `opts` with `:accounts`, `:workspaces` overrides
2. **Default module attributes** (`@default_accounts Jarga.Accounts`) are resolved at **runtime**, not compile-time
3. **Boundary library deps** are metadata annotations, not Mix-level compile deps
4. **The only compile-time dep** agents needs is `Identity` (for `Identity.Repo`, schemas)

**Mix dependency graph** (unidirectional):
```
identity ← agents ← jarga ← jarga_web
```

**Boundary dependency graph** (cross-cutting, compile-time checked):
```
Agents.Infrastructure → Jarga.Accounts, Jarga.Workspaces (via Boundary deps list)
```

The Boundary library will ensure correct usage at compile time without requiring Mix-level circular dependencies, because `externals_mode: :relaxed` allows cross-app references.

### What This Means for Implementation

1. `apps/agents/mix.exs` deps: `[{:identity, in_umbrella: true}, ...]` — NO jarga dep
2. `apps/jarga/mix.exs` deps: `[{:identity, in_umbrella: true}, {:agents, in_umbrella: true}, ...]`
3. `apps/jarga_web/mix.exs` deps: `[{:jarga, in_umbrella: true}, {:agents, in_umbrella: true}, ...]`
4. Boundary config in agents lists `Jarga.Accounts`, `Jarga.Workspaces` as deps — enforced at compile time
5. At runtime, the BEAM VM resolves module references from all loaded umbrella apps

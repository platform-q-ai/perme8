# Feature: Rename knowledge-mcp to perme8-mcp & Introduce ToolProvider Abstraction

**GitHub Issue**: #181
**Status**: Not Started
**Created**: 2026-02-23
**App**: `agents` (Elixir umbrella)

## Overview

Two-part refactor of the MCP server in the `agents` app:

1. **Rename**: Change the MCP server identity from `"knowledge-mcp"` to `"perme8-mcp"` across source, tests, BDD feature files, and documentation.
2. **ToolProvider abstraction**: Replace the 14 static `component()` macro calls in `Server` with a compile-time composition system driven by `ToolProvider` modules, making tool registration config-driven and extensible for future `RemoteToolProvider` implementations.

## UI Strategy

- **LiveView coverage**: N/A — no UI changes
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context**: `Agents.Infrastructure` (MCP layer)
- **Dependencies**: None changed — tool modules remain identical
- **Exported schemas**: None changed
- **New context needed?**: No — this is an internal infrastructure refactor

## Key Technical Constraint: Compile-Time `component()` Macro

The `component()` macro from `hermes_mcp ~> 0.14` works as follows:

1. `use Hermes.Server` registers a `:components` module attribute with `accumulate: true`
2. Each `component(Module, name: "x")` call appends `{:tool, "x", Module}` to `@components`
3. `@before_compile` reads `@components` and generates `__components__/0` and `__components__/1`
4. Tests use `Server.__components__(:tool)` for compile-time introspection

**Design decision**: The `ToolProvider` behaviour defines `components/0` returning a list of
`{module, name}` tuples. A `__using__` macro (`use Agents.Infrastructure.Mcp.ToolProvider.Loader`)
iterates configured providers at compile time and emits `component()` calls, preserving full
Hermes compile-time introspection. Application config (`:agents, :mcp_tool_providers`) controls
which providers are loaded.

This approach:
- Preserves `Server.__components__(:tool)` working exactly as before
- Is config-driven — adding/removing providers requires no code changes to `Server`
- Has a clean seam for a future `RemoteToolProvider` (just add a new provider module)
- Keeps individual tool modules 100% unchanged

---

## Phase 1: Rename "knowledge-mcp" to "perme8-mcp" (phoenix-tdd)

This phase is purely mechanical text replacement. Tests are updated first (RED — they fail
against old code), then source is updated (GREEN), then cleanup (REFACTOR).

### Step 1.1: Update Server Test — name assertion

- [ ] ⏸ **RED**: Edit `apps/agents/test/agents/infrastructure/mcp/server_test.exs`
  - Change line 60: `test "server name is knowledge-mcp"` → `test "server name is perme8-mcp"`
  - Change line 62: `assert info["name"] == "knowledge-mcp"` → `assert info["name"] == "perme8-mcp"`
  - **Expected failure**: Test asserts `"perme8-mcp"` but server still returns `"knowledge-mcp"`
- [ ] ⏸ **GREEN**: Edit `apps/agents/lib/agents/infrastructure/mcp/server.ex`
  - Change line 6 moduledoc: `"knowledge-mcp"` → `"perme8-mcp"`
  - Change line 10: `name: "knowledge-mcp"` → `name: "perme8-mcp"`
- [ ] ⏸ **REFACTOR**: Verify server test passes: `mix test apps/agents/test/agents/infrastructure/mcp/server_test.exs`

### Step 1.2: Update Router Test — serverInfo name assertion

- [ ] ⏸ **RED**: Edit `apps/agents/test/agents/infrastructure/mcp/router_test.exs`
  - Change line 118: `assert body["result"]["serverInfo"]["name"] == "knowledge-mcp"` → `"perme8-mcp"`
  - **Expected failure**: Test asserts `"perme8-mcp"` but health endpoint still returns `"knowledge-mcp"`
- [ ] ⏸ **GREEN**: Edit `apps/agents/lib/agents/infrastructure/mcp/router.ex`
  - Change line 33: `"knowledge-mcp"` → `"perme8-mcp"` in health response JSON
- [ ] ⏸ **REFACTOR**: Verify router test passes: `mix test apps/agents/test/agents/infrastructure/mcp/router_test.exs`

### Step 1.3: Update OTPApp moduledoc

- [ ] ⏸ **GREEN**: Edit `apps/agents/lib/agents/otp_app.ex`
  - Change moduledoc line 5: `"knowledge tools"` → `"perme8-mcp tools"` (or similar wording reflecting the new name)

### Step 1.4: Rename BDD Feature Files and Update Content

Feature files need both renaming (directory + filename) and content updates.

- [ ] ⏸ **GREEN**: Create directory `apps/agents/test/features/perme8-mcp/`
- [ ] ⏸ **GREEN**: Copy + rename `knowledge-mcp.feature` → `perme8-mcp/perme8-mcp.feature`
  - Update line 40: `"knowledge-mcp"` → `"perme8-mcp"` (server info name assertion)
- [ ] ⏸ **GREEN**: Copy + rename `knowledge-mcp.http.feature` → `perme8-mcp/perme8-mcp.http.feature`
  - Update line 37: `$.service` assertion `"knowledge-mcp"` → `"perme8-mcp"`
  - Update line 121: `$.result.serverInfo.name` assertion `"knowledge-mcp"` → `"perme8-mcp"`
- [ ] ⏸ **GREEN**: Copy + rename `knowledge-mcp.security.feature` → `perme8-mcp/perme8-mcp.security.feature`
  - Update line 238: report path `"reports/knowledge-mcp-security-audit.html"` → `"reports/perme8-mcp-security-audit.html"`
  - Update line 239: report path `"reports/knowledge-mcp-security-audit.json"` → `"reports/perme8-mcp-security-audit.json"`
- [ ] ⏸ **REFACTOR**: Delete old directory `apps/agents/test/features/knowledge-mcp/`

### Step 1.5: Update Documentation

- [ ] ⏸ **GREEN**: Edit `docs/architecture/service_evolution_plan.md`
  - Line 119: Change `"Knowledge MCP (6 tools)"` to reflect the perme8-mcp naming
- [ ] ⏸ **GREEN**: Edit `docs/agents/plans/extract-agents-bounded-context-architectural-plan.md`
  - Line 4: Update branch reference `refactor/knowledge-mcp-to-agents` (this is historical — leave as-is or add note)
- [ ] ⏸ **GREEN**: Update `docs/umbrella_apps.md` line 12 if it mentions "Knowledge MCP"

### Phase 1 Validation

- [ ] ⏸ All server tests pass: `mix test apps/agents/test/agents/infrastructure/mcp/server_test.exs`
- [ ] ⏸ All router tests pass: `mix test apps/agents/test/agents/infrastructure/mcp/router_test.exs`
- [ ] ⏸ Full agents test suite passes: `mix test apps/agents/test/ --exclude sessions` (exclude unrelated session failures)
- [ ] ⏸ No references to `"knowledge-mcp"` in source files (search `*.ex`, `*.exs`):
  ```bash
  grep -r "knowledge-mcp" apps/agents/lib/ apps/agents/test/ --include="*.ex" --include="*.exs"
  ```
- [ ] ⏸ Feature files renamed and old directory deleted
- [ ] ⏸ Commit: `refactor: rename knowledge-mcp to perme8-mcp (#181)`

---

## Phase 2: ToolProvider Behaviour (phoenix-tdd) ✓

### Design

```
Agents.Infrastructure.Mcp.ToolProvider (behaviour)
├── @callback components() :: [{module(), String.t()}]
│
├── Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProvider
│   └── components/0 → [{SearchTool, "knowledge.search"}, ...]  (6 tools)
│
├── Agents.Infrastructure.Mcp.ToolProviders.JargaToolProvider
│   └── components/0 → [{ListWorkspacesTool, "jarga.list_workspaces"}, ...]  (8 tools)
│
└── Agents.Infrastructure.Mcp.ToolProvider.Loader (__using__ macro)
    └── Reads :agents, :mcp_tool_providers config at compile time
    └── Calls provider.components() for each
    └── Emits component() macro calls into the using module
```

### Step 2.1: ToolProvider Behaviour

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tool_provider_test.exs`
  - Tests:
    - `ToolProvider` module exists and defines the behaviour
    - The `components/0` callback is defined in the behaviour
    - A mock module implementing the behaviour returns the expected format `[{module, name}]`
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tool_provider.ex`
  ```elixir
  defmodule Agents.Infrastructure.Mcp.ToolProvider do
    @moduledoc """
    Behaviour for modules that provide tool components to the MCP server.

    Implementors return a list of `{module, name}` tuples where each module
    is a `Hermes.Server.Component` and the name is the tool's MCP-visible name.

    ## Example

        defmodule MyProvider do
          @behaviour Agents.Infrastructure.Mcp.ToolProvider

          @impl true
          def components do
            [{MyTool, "my.tool"}]
          end
        end
    """

    @type component_spec :: {module(), String.t()}

    @callback components() :: [component_spec()]
  end
  ```
- [x] ✓ **REFACTOR**: Clean up, verify test passes

### Step 2.2: KnowledgeToolProvider

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tool_providers/knowledge_tool_provider_test.exs`
  - Tests:
    - Returns exactly 6 component specs
    - Each spec is a `{module, name}` tuple
    - Includes all 6 knowledge tool names: `"knowledge.search"`, `"knowledge.get"`, `"knowledge.traverse"`, `"knowledge.create"`, `"knowledge.update"`, `"knowledge.relate"`
    - All referenced modules exist and are valid Hermes components (`Hermes.Server.Component.component?/1`)
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tool_providers/knowledge_tool_provider.ex`
  ```elixir
  defmodule Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProvider do
    @behaviour Agents.Infrastructure.Mcp.ToolProvider

    alias Agents.Infrastructure.Mcp.Tools

    @impl true
    def components do
      [
        {Tools.SearchTool, "knowledge.search"},
        {Tools.GetTool, "knowledge.get"},
        {Tools.TraverseTool, "knowledge.traverse"},
        {Tools.CreateTool, "knowledge.create"},
        {Tools.UpdateTool, "knowledge.update"},
        {Tools.RelateTool, "knowledge.relate"}
      ]
    end
  end
  ```
- [x] ✓ **REFACTOR**: Clean up

### Step 2.3: JargaToolProvider

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tool_providers/jarga_tool_provider_test.exs`
  - Tests:
    - Returns exactly 8 component specs
    - Each spec is a `{module, name}` tuple
    - Includes all 8 jarga tool names: `"jarga.list_workspaces"`, `"jarga.get_workspace"`, `"jarga.list_projects"`, `"jarga.create_project"`, `"jarga.get_project"`, `"jarga.list_documents"`, `"jarga.create_document"`, `"jarga.get_document"`
    - All referenced modules exist and are valid Hermes components
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tool_providers/jarga_tool_provider.ex`
  ```elixir
  defmodule Agents.Infrastructure.Mcp.ToolProviders.JargaToolProvider do
    @behaviour Agents.Infrastructure.Mcp.ToolProvider

    alias Agents.Infrastructure.Mcp.Tools.Jarga

    @impl true
    def components do
      [
        {Jarga.ListWorkspacesTool, "jarga.list_workspaces"},
        {Jarga.GetWorkspaceTool, "jarga.get_workspace"},
        {Jarga.ListProjectsTool, "jarga.list_projects"},
        {Jarga.CreateProjectTool, "jarga.create_project"},
        {Jarga.GetProjectTool, "jarga.get_project"},
        {Jarga.ListDocumentsTool, "jarga.list_documents"},
        {Jarga.CreateDocumentTool, "jarga.create_document"},
        {Jarga.GetDocumentTool, "jarga.get_document"}
      ]
    end
  end
  ```
- [x] ✓ **REFACTOR**: Clean up

### Step 2.4: Loader Macro

The Loader is the key piece: a `__using__` macro that reads application config to determine
which `ToolProvider` modules to load, calls `components/0` on each, and emits `component()`
macro calls into the caller module at compile time.

- [x] ✓ **RED**: Write test `apps/agents/test/agents/infrastructure/mcp/tool_provider/loader_test.exs`
  - Tests:
    - Loader module exists and defines `__using__/1` macro
    - Server.__components__(:tool) returns all 14 tools from configured providers
    - Server includes all knowledge tools loaded by KnowledgeToolProvider
    - Server includes all jarga tools loaded by JargaToolProvider
  - **Note**: Compile-time macros tested indirectly through the Server module
- [x] ✓ **GREEN**: Implement `apps/agents/lib/agents/infrastructure/mcp/tool_provider/loader.ex`
  ```elixir
  defmodule Agents.Infrastructure.Mcp.ToolProvider.Loader do
    @moduledoc """
    Compile-time macro that reads configured tool providers and emits
    `component()` calls for each tool they provide.

    ## Usage

    In your Hermes.Server module:

        defmodule MyServer do
          use Hermes.Server, name: "perme8-mcp", version: "1.0.0", capabilities: [:tools]
          use Agents.Infrastructure.Mcp.ToolProvider.Loader
        end

    ## Configuration

        config :agents, :mcp_tool_providers, [
          Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProvider,
          Agents.Infrastructure.Mcp.ToolProviders.JargaToolProvider
        ]
    """

    defmacro __using__(_opts) do
      providers = Application.compile_env(:agents, :mcp_tool_providers, [])

      component_calls =
        providers
        |> Enum.flat_map(fn provider -> provider.components() end)
        |> Enum.map(fn {mod, name} ->
          quote do
            component(unquote(mod), name: unquote(name))
          end
        end)

      quote do
        unquote_splicing(component_calls)
      end
    end
  end
  ```
  - **Key**: Uses `Application.compile_env/3` (not `get_env`) so Mix validates compile-time config access
  - The providers are called at compile time — their `components/0` must be pure (no I/O), which is already guaranteed by our implementation
- [x] ✓ **REFACTOR**: Clean up, ensure tests pass

### Step 2.5: Wire Server to Use Loader + Configure Providers

- [x] ✓ **RED**: Existing `server_test.exs` already tests `Server.__components__(:tool)` returns 14 tools — this is our regression safety net. No new test needed; the existing test IS the red test if we break anything.
  - Verify: `mix test apps/agents/test/agents/infrastructure/mcp/server_test.exs` passes BEFORE the change
- [x] ✓ **GREEN**: Apply the changes:
  1. Added `config :agents, :mcp_tool_providers` to `config/config.exs`
  2. Rewrote `apps/agents/lib/agents/infrastructure/mcp/server.ex` to use Loader
  3. Removed the 14 explicit `component()` calls and the `alias` lines for tool modules
- [x] ✓ **REFACTOR**: Verify all existing server tests still pass — `Server.__components__(:tool)` must still return 14 tools with the same names. Run:
  ```bash
  mix test apps/agents/test/agents/infrastructure/mcp/server_test.exs
  mix test apps/agents/test/agents/infrastructure/mcp/router_test.exs
  ```

### Step 2.6: Update Boundary Exports (if needed)

- [x] ✓ **GREEN**: Check if new modules need to be added to boundary exports in `apps/agents/lib/agents/infrastructure.ex`
  - The `ToolProvider` behaviour and `Loader` macro are internal to the Infrastructure boundary — they should NOT be exported
  - The `ToolProviders.KnowledgeToolProvider` and `ToolProviders.JargaToolProvider` are internal — should NOT be exported
  - Verified: `mix compile --warnings-as-errors` succeeds with no new violations
- [x] ✓ **REFACTOR**: No boundary issues — all new modules are internal to Agents.Infrastructure

### Phase 2 Validation

- [x] ✓ All ToolProvider tests pass (async, no I/O):
  ```bash
  mix test apps/agents/test/agents/infrastructure/mcp/tool_provider_test.exs
  mix test apps/agents/test/agents/infrastructure/mcp/tool_providers/
  mix test apps/agents/test/agents/infrastructure/mcp/tool_provider/loader_test.exs
  ```
- [x] ✓ All existing MCP tests pass (regression): 86 tests, 0 failures
  ```bash
  mix test apps/agents/test/agents/infrastructure/mcp/
  ```
- [x] ✓ Server introspection works: `Server.__components__(:tool)` returns 14 tools with correct names
- [x] ✓ No boundary violations: `mix compile --warnings-as-errors` succeeds
- [ ] ⏸ Commit: `refactor: introduce ToolProvider abstraction for MCP tool composition (#181)`

---

## Pre-Commit Checkpoint

After both phases are complete:

- [ ] ⏸ `mix format`
- [ ] ⏸ `mix compile --warnings-as-errors`
- [ ] ⏸ `mix boundary`
- [ ] ⏸ `mix credo --strict`
- [ ] ⏸ `mix test apps/agents/test/ --exclude sessions` (all agents tests minus unrelated session failures)
- [ ] ⏸ No `"knowledge-mcp"` references in source/test `*.ex`/`*.exs` files
- [ ] ⏸ Feature files properly renamed under `perme8-mcp/`
- [ ] ⏸ `mix precommit` (full pre-commit suite)

---

## Testing Strategy

### Test Count Estimate

| Layer | Module | Tests | Type |
|-------|--------|-------|------|
| Infrastructure | `ToolProvider` (behaviour) | 2 | `ExUnit.Case, async: true` |
| Infrastructure | `KnowledgeToolProvider` | 4 | `ExUnit.Case, async: true` |
| Infrastructure | `JargaToolProvider` | 4 | `ExUnit.Case, async: true` |
| Infrastructure | `Loader` (macro) | 3-4 | `ExUnit.Case, async: true` |
| Infrastructure | `ServerTest` (existing, updated) | 9 (existing) | `ExUnit.Case, async: true` |
| Infrastructure | `RouterTest` (existing, updated) | 5 (existing) | `ExUnit.Case, async: false` |
| **Total new** | | **~13** | |
| **Total modified** | | **~14 (existing)** | |

### Distribution

- **Domain**: 0 (no domain changes)
- **Application**: 0 (no use case changes)
- **Infrastructure**: ~13 new + 14 existing modified
- **Interface**: 0 (no web changes)

### Test Characteristics

- All new tests are `async: true` — pure function tests, no I/O, no database
- ToolProvider behaviour + implementations are pure compile-time contracts
- Loader tests may need `Application.put_env` in setup (which requires care with async)
  - If concurrent config writes cause issues, mark Loader test as `async: false`

---

## File Changes Summary

### New Files

| File | Purpose |
|------|---------|
| `apps/agents/lib/agents/infrastructure/mcp/tool_provider.ex` | Behaviour definition |
| `apps/agents/lib/agents/infrastructure/mcp/tool_provider/loader.ex` | Compile-time macro |
| `apps/agents/lib/agents/infrastructure/mcp/tool_providers/knowledge_tool_provider.ex` | Knowledge tools (6) |
| `apps/agents/lib/agents/infrastructure/mcp/tool_providers/jarga_tool_provider.ex` | Jarga tools (8) |
| `apps/agents/test/agents/infrastructure/mcp/tool_provider_test.exs` | Behaviour tests |
| `apps/agents/test/agents/infrastructure/mcp/tool_provider/loader_test.exs` | Macro tests |
| `apps/agents/test/agents/infrastructure/mcp/tool_providers/knowledge_tool_provider_test.exs` | Provider tests |
| `apps/agents/test/agents/infrastructure/mcp/tool_providers/jarga_tool_provider_test.exs` | Provider tests |
| `apps/agents/test/features/perme8-mcp/perme8-mcp.feature` | Renamed BDD feature |
| `apps/agents/test/features/perme8-mcp/perme8-mcp.http.feature` | Renamed BDD feature |
| `apps/agents/test/features/perme8-mcp/perme8-mcp.security.feature` | Renamed BDD feature |

### Modified Files

| File | Change |
|------|--------|
| `apps/agents/lib/agents/infrastructure/mcp/server.ex` | Rename + replace static components with Loader |
| `apps/agents/lib/agents/infrastructure/mcp/router.ex` | Rename in health response |
| `apps/agents/lib/agents/otp_app.ex` | Update moduledoc |
| `apps/agents/test/agents/infrastructure/mcp/server_test.exs` | Update name assertion |
| `apps/agents/test/agents/infrastructure/mcp/router_test.exs` | Update name assertion |
| `config/config.exs` (or app-specific config) | Add `:mcp_tool_providers` config |
| `docs/architecture/service_evolution_plan.md` | Update name reference |
| `docs/umbrella_apps.md` | Update description if needed |

### Deleted Files

| File | Reason |
|------|--------|
| `apps/agents/test/features/knowledge-mcp/knowledge-mcp.feature` | Renamed |
| `apps/agents/test/features/knowledge-mcp/knowledge-mcp.http.feature` | Renamed |
| `apps/agents/test/features/knowledge-mcp/knowledge-mcp.security.feature` | Renamed |

### Unchanged Files (14 tool modules)

All tool modules under `apps/agents/lib/agents/infrastructure/mcp/tools/` remain 100% untouched:
- `search_tool.ex`, `get_tool.ex`, `traverse_tool.ex`, `create_tool.ex`, `update_tool.ex`, `relate_tool.ex`
- `jarga/list_workspaces_tool.ex`, `jarga/get_workspace_tool.ex`, `jarga/list_projects_tool.ex`, `jarga/create_project_tool.ex`, `jarga/get_project_tool.ex`, `jarga/list_documents_tool.ex`, `jarga/create_document_tool.ex`, `jarga/get_document_tool.ex`

---

## Future Extensibility

The `ToolProvider` abstraction is designed for future `RemoteToolProvider` implementation:

```elixir
# Future: not implemented in this PR
defmodule Agents.Infrastructure.Mcp.ToolProviders.RemoteToolProvider do
  @behaviour Agents.Infrastructure.Mcp.ToolProvider

  @impl true
  def components do
    # Could read from config, discovery service, etc.
    # Each component module would be a proxy that forwards execute/2
    # to a remote MCP server via HTTP/SSE
    []
  end
end
```

Adding a new provider requires only:
1. Implement the `ToolProvider` behaviour
2. Add the module to `:agents, :mcp_tool_providers` config list
3. No changes to `Server`, `Loader`, or existing providers

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| `Application.compile_env` config missing in test env | Add config to `config/test.exs` with same providers |
| Loader macro ordering issue (must be after `use Hermes.Server`) | Test explicitly; `use` order is deterministic |
| Feature file rename breaks exo-bdd test runner | Verify feature files are discovered by test config |
| Boundary violations from new modules | Run `mix boundary` in validation |
| Compile-time provider loading changes tool order | `Hermes.Server.parse_components` sorts by name — order is deterministic |

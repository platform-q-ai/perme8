# Feature: Move Agent Management LiveViews from jarga_web to agents_web

**Ticket**: [#243](https://github.com/platform-q-ai/perme8/issues/243)
**Type**: Refactor (CRUD Update — interface layer move)

## Overview

Move `JargaWeb.AppLive.Agents.Index` and `JargaWeb.AppLive.Agents.Form` from `jarga_web` to `agents_web`, renaming them to `AgentsWeb.AgentsLive.Index` and `AgentsWeb.AgentsLive.Form`. This aligns with the app ownership model: `agents_web` owns agent management UI.

Key changes:
1. Create new LiveViews in `agents_web` with chat panel dependencies **removed**
2. Create a minimal `admin/1` layout in `AgentsWeb.Layouts`
3. Add agent routes to `AgentsWeb.Router`
4. Update cross-app references in `jarga_web` to use full external URLs
5. Delete old files from `jarga_web`

## UI Strategy
- **LiveView coverage**: 100%
- **TypeScript needed**: None

## Affected Boundaries

- **Owning app**: `agents_web` (destination), `jarga_web` (source — files being removed)
- **Repo**: N/A — interface-only change, no migrations
- **Migrations**: None
- **Feature files**: `apps/agents_web/test/features/agents/` (deferred — follow-up ticket)
- **Primary context**: `AgentsWeb` (interface layer)
- **Dependencies**: `Agents` (agent CRUD), `Jarga.Workspaces` (workspace listing, delegates to Identity), `Agents.Domain` (event structs), `Perme8.Events` (PubSub subscriptions)
- **Exported schemas**: None (interface layer)
- **New context needed?**: No — adding LiveViews to existing `AgentsWeb` boundary

## Architectural Decisions

### 1. File Placement Convention

The `agents_web` app places files directly under `apps/agents_web/lib/` (e.g., `lib/live/sessions/index.ex`), NOT under `lib/agents_web/`. The ticket's proposed paths are corrected here:

| Proposed (ticket) | Corrected (actual convention) |
|---|---|
| `apps/agents_web/lib/agents_web/live/agents/index.ex` | `apps/agents_web/lib/live/agents/index.ex` |
| `apps/agents_web/lib/agents_web/live/agents/form.ex` | `apps/agents_web/lib/live/agents/form.ex` |

### 2. MessageHandlers Removal

Both source LiveViews import `JargaWeb.ChatLive.MessageHandlers` and call `handle_chat_messages()`, plus `send_update(JargaWeb.ChatLive.Panel, ...)`. Since `agents_web` is a separate endpoint with no chat panel, ALL of this is removed:
- `import JargaWeb.ChatLive.MessageHandlers` — removed
- `handle_chat_messages()` call — removed  
- `send_update(JargaWeb.ChatLive.Panel, ...)` in `reload_agents/1` / `reload_agents_for_chat_panel/1` — removed
- The `handle_info` callbacks for domain events remain, but simply update assigns directly

### 3. Layout Approach

Create a new `admin/1` function component in `AgentsWeb.Layouts` that provides:
- Minimal sidebar navigation (Agents link, Sessions link)
- Flash messages
- No chat panel (out of scope)
- No notification bell (out of scope)
- Theme toggle (copied from `JargaWeb.Layouts`)

### 4. Route Changes

| Old (jarga_web) | New (agents_web) |
|---|---|
| `/app/agents` | `/agents` |
| `/app/agents/new` | `/agents/new` |
| `/app/agents/:id/view` | `/agents/:id/view` |
| `/app/agents/:id/edit` | `/agents/:id/edit` |

### 5. Cross-App URL Pattern

`jarga_web` links to agents must become full external URLs pointing to `agents_web` endpoint. We'll use a config-driven base URL pattern:

```elixir
# config/dev.exs
config :jarga_web, :agents_web_url, "http://localhost:4014"

# config/test.exs  
config :jarga_web, :agents_web_url, "http://localhost:5014"

# config/runtime.exs (production)
config :jarga_web, :agents_web_url, System.get_env("AGENTS_WEB_URL") || "https://agents.example.com"
```

A helper function in `JargaWeb` or layouts will construct full URLs:
```elixir
defp agents_web_url(path) do
  base = Application.get_env(:jarga_web, :agents_web_url, "http://localhost:4014")
  "#{base}#{path}"
end
```

### 6. Workspace Back-Path

The `form.ex` `get_back_path/2` for `return_to=workspace` currently uses `~p"/app/workspaces/#{workspace_slug}"` (a jarga_web route). Since agents_web can't use verified routes for jarga_web paths, and this is cross-app navigation, we'll:
- Use a config-driven `jarga_web_url` for the workspace back path
- Or simply link back to `/agents` as the default, with workspace back-path using a full URL

---

## Phase 1: Foundation — Boundary & Config Setup

No domain/application layer changes needed — this is an interface-only refactor.

### Step 1.1: Update AgentsWeb Boundary

Update `apps/agents_web/lib/agents_web.ex` to add required boundary deps and exports.

- [ ] ⏸ **RED**: Run `mix boundary` — verify it fails when the new LiveViews reference `Agents.Domain`, `Jarga.Workspaces`, and `Perme8.Events`
- [ ] ⏸ **GREEN**: Update boundary in `apps/agents_web/lib/agents_web.ex`:
  ```elixir
  use Boundary,
    deps: [
      Agents,
      Agents.Domain,
      Agents.Sessions,
      Agents.Sessions.Domain,
      Identity,
      IdentityWeb,
      Jarga,
      Jarga.Accounts,
      Jarga.Workspaces,
      Perme8.Events
    ],
    exports: [Endpoint, Telemetry, SessionsLive.Index, AgentsLive.Index, AgentsLive.Form]
  ```
- [ ] ⏸ **REFACTOR**: Verify no unnecessary deps remain

### Step 1.2: Update AgentsWeb.ConnCase Boundary

Update test support to allow `Agents.AgentsFixtures` import.

- [ ] ⏸ **RED**: New agent LiveView tests will fail to compile without `Agents.AgentsFixtures` in ConnCase boundary
- [ ] ⏸ **GREEN**: Update boundary in `apps/agents_web/test/support/conn_case.ex`:
  ```elixir
  use Boundary,
    top_level?: true,
    deps: [
      AgentsWeb,
      Identity,
      Jarga.Accounts,
      Jarga.DataCase,
      Jarga.AccountsFixtures,
      Agents.SessionsFixtures,
      Agents.AgentsFixtures
    ],
    exports: []
  ```
- [ ] ⏸ **REFACTOR**: Verify boundary compiles cleanly

### Step 1.3: Add Cross-App URL Configuration

Add `agents_web_url` config to `jarga_web` for constructing cross-app links.

- [ ] ⏸ **RED**: No verified route `~p"/app/agents"` will exist in jarga_web after routes are removed; config-based URL needed
- [ ] ⏸ **GREEN**: Add configuration:
  - `config/dev.exs`: `config :jarga_web, :agents_web_url, "http://localhost:4014"`
  - `config/test.exs`: `config :jarga_web, :agents_web_url, "http://localhost:5014"`
  - `config/runtime.exs`: `config :jarga_web, :agents_web_url, System.get_env("AGENTS_WEB_URL") || "https://agents.#{host}"`
- [ ] ⏸ **REFACTOR**: Ensure consistent config pattern with existing `identity_url` configs

### Step 1.4: Add Back-Link URL Configuration

Add `jarga_web_url` config to `agents_web` for cross-app workspace back-links.

- [ ] ⏸ **RED**: Form `get_back_path("workspace", slug)` needs to link back to jarga_web workspace page
- [ ] ⏸ **GREEN**: Add configuration:
  - `config/dev.exs`: `config :agents_web, :jarga_web_url, "http://localhost:4000"`
  - `config/test.exs`: `config :agents_web, :jarga_web_url, "http://localhost:5000"`
  - `config/runtime.exs`: `config :agents_web, :jarga_web_url, System.get_env("JARGA_WEB_URL") || "https://#{host}"`
- [ ] ⏸ **REFACTOR**: Verify pattern consistency

### Phase 1 Validation
- [ ] ⏸ `mix compile` passes with no boundary warnings
- [ ] ⏸ `mix boundary` passes cleanly
- [ ] ⏸ Existing test suite still passes (`mix test`)

---

## Phase 2: Interface — LiveViews, Layout, Routes & Tests

### Step 2.1: Create Admin Layout Component

Create a minimal `admin/1` function component in `AgentsWeb.Layouts` that provides sidebar navigation and flash messages.

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/agents/layout_test.exs`
  - Test: `admin/1` layout renders flash messages
  - Test: `admin/1` layout renders sidebar with "Agents" navigation link
  - Test: `admin/1` layout renders sidebar with "Sessions" navigation link
  - Test: `admin/1` layout renders inner block content
  - Test: `admin/1` layout renders user info from `current_scope`
- [ ] ⏸ **GREEN**: Add `admin/1` function component to `apps/agents_web/lib/components/layouts.ex`
  - Accepts: `flash` (map), `current_scope` (map), inner_block (slot)
  - Renders: drawer layout with sidebar, navigation links, flash group
  - Sidebar links: Agents (`/agents`), Sessions (`/sessions`)
  - No chat panel, no notification bell
  - Include `theme_toggle/1` component (copy from JargaWeb.Layouts or extract to shared)
- [ ] ⏸ **REFACTOR**: Ensure layout follows DaisyUI patterns consistent with jarga_web admin layout

### Step 2.2: Add Agent Routes

Add agent management routes to `AgentsWeb.Router`.

- [ ] ⏸ **RED**: Test that visiting `/agents` returns 200 (will fail until routes exist)
- [ ] ⏸ **GREEN**: Update `apps/agents_web/lib/router.ex`:
  ```elixir
  scope "/", AgentsWeb do
    pipe_through([:browser, :require_authenticated_user])

    live_session :agents,
      on_mount: [{AgentsWeb.UserAuth, :require_authenticated}] do
      live("/agents", AgentsLive.Index, :index)
      live("/agents/new", AgentsLive.Form, :new)
      live("/agents/:id/view", AgentsLive.Form, :view)
      live("/agents/:id/edit", AgentsLive.Form, :edit)
    end

    live_session :sessions,
      on_mount: [{AgentsWeb.UserAuth, :require_authenticated}] do
      live("/sessions", SessionsLive.Index, :index)
    end
  end
  ```
- [ ] ⏸ **REFACTOR**: Verify route naming doesn't conflict with existing sessions routes

### Step 2.3: Create AgentsLive.Index

Move and refactor the index LiveView.

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/agents/index_test.exs`
  - Module: `AgentsWeb.AgentsLive.IndexTest`
  - Uses: `AgentsWeb.ConnCase, async: true`
  - Imports: `Phoenix.LiveViewTest`, `Jarga.AccountsFixtures`, `Agents.AgentsFixtures`
  - Tests (mounting & rendering):
    - `mount renders agent list page with correct title`
    - `mount shows empty state when no agents exist`
    - `mount shows agents table when agents exist`
  - Tests (user actions):
    - `delete event removes agent and shows flash`
    - `delete event for non-existent agent shows error`
    - `new agent link navigates to /agents/new`
    - `edit agent link navigates to /agents/:id/edit`
  - Tests (domain events — no chat panel):
    - `handles AgentUpdated event by reloading agents list`
    - `handles AgentDeleted event by reloading agents list`
    - `handles AgentAddedToWorkspace event by reloading agents list`
    - `handles AgentRemovedFromWorkspace event by reloading agents list`
  - Route paths: `/agents` (NOT `/app/agents`)
  - No references to JargaWeb, no MessageHandlers
- [ ] ⏸ **GREEN**: Create `apps/agents_web/lib/live/agents/index.ex`
  - Module: `AgentsWeb.AgentsLive.Index`
  - Uses: `AgentsWeb, :live_view`
  - Changes from source:
    - `use AgentsWeb, :live_view` (was `JargaWeb`)
    - Remove `import JargaWeb.ChatLive.MessageHandlers`
    - Remove `alias JargaWeb.Layouts` (use auto-aliased `AgentsWeb.Layouts`)
    - Keep `alias Agents` and domain event aliases
    - Keep `alias Jarga.Workspaces`
    - Keep `mount/3` with PubSub subscriptions (via `Perme8.Events.subscribe`)
    - Update `render/1`: `<Layouts.admin ...>` uses AgentsWeb's admin layout
    - Update all `~p"/app/agents..."` to `~p"/agents..."`
    - Remove `handle_chat_messages()` call
    - Simplify `reload_agents/1` — remove `send_update(JargaWeb.ChatLive.Panel, ...)`, just `assign(socket, :agents, agents)`
    - Keep domain event `handle_info` callbacks unchanged (pattern match on event structs)
- [ ] ⏸ **REFACTOR**: Ensure LiveView is thin — delegates to `Agents` context, no business logic

### Step 2.4: Create AgentsLive.Form

Move and refactor the form LiveView.

- [ ] ⏸ **RED**: Write test `apps/agents_web/test/live/agents/form_test.exs`
  - Module: `AgentsWeb.AgentsLive.FormTest`
  - Uses: `AgentsWeb.ConnCase, async: true`
  - Imports: `Phoenix.LiveViewTest`, `Jarga.AccountsFixtures`, `Agents.AgentsFixtures`
  - Tests (domain events — no chat panel):
    - `handles AgentUpdated event without crashing`
    - `handles AgentDeleted event without crashing`
    - `handles AgentAddedToWorkspace event without crashing`
    - `handles AgentRemovedFromWorkspace event without crashing`
  - Tests (form — read-only security):
    - `view action works without workspace context`
    - `allows form submission when not read-only (owner editing)`
  - Tests (form — new agent):
    - `new action renders agent creation form`
    - `saving new agent creates agent and redirects to /agents`
    - `saving with invalid data shows errors`
  - Tests (form — edit agent):
    - `edit action renders agent editing form with existing data`
    - `saving edit updates agent and redirects to /agents`
  - Tests (form — clone):
    - `clone_agent clones shared agent and redirects to edit`
  - Tests (navigation — back path):
    - `back link from agents context goes to /agents`
    - `back link from workspace context uses external jarga_web URL`
  - Route paths: `/agents/...` (NOT `/app/agents/...`)
- [ ] ⏸ **GREEN**: Create `apps/agents_web/lib/live/agents/form.ex`
  - Module: `AgentsWeb.AgentsLive.Form`
  - Uses: `AgentsWeb, :live_view`
  - Changes from source:
    - `use AgentsWeb, :live_view` (was `JargaWeb`)
    - Remove `import JargaWeb.ChatLive.MessageHandlers`
    - Remove `alias JargaWeb.Layouts`
    - Keep `alias Agents`, domain event aliases, `alias Jarga.Workspaces`
    - Update `render/1`: `<Layouts.admin ...>` uses AgentsWeb's admin layout
    - Update all `~p"/app/agents..."` to `~p"/agents..."` (in navigations, redirects, save callbacks)
    - Update `get_back_path("workspace", workspace_slug)` — use config-based external URL:
      ```elixir
      defp get_back_path("workspace", workspace_slug) when is_binary(workspace_slug) do
        jarga_url = Application.get_env(:agents_web, :jarga_web_url, "http://localhost:4000")
        "#{jarga_url}/app/workspaces/#{workspace_slug}"
      end
      defp get_back_path(_, _), do: ~p"/agents"
      ```
    - Remove `handle_chat_messages()` call
    - Simplify `reload_agents_for_chat_panel/1` → rename to `handle_agent_event/1`:
      - Remove `send_update(JargaWeb.ChatLive.Panel, ...)` call
      - Just return `socket` (no-op — the form page doesn't display a list)
    - Keep domain event `handle_info` callbacks
    - `clone_agent` event: update redirect to `~p"/agents/#{cloned_agent.id}/edit"`
- [ ] ⏸ **REFACTOR**: Remove any dead code, ensure consistent naming

### Step 2.5: Update jarga_web — Remove Agent Routes

Remove agent routes from jarga_web router.

- [ ] ⏸ **RED**: Existing jarga_web agent tests will fail once routes are removed
- [ ] ⏸ **GREEN**: Update `apps/jarga_web/lib/router.ex` — remove lines 78-81:
  ```elixir
  # REMOVE:
  live("/agents", AppLive.Agents.Index, :index)
  live("/agents/new", AppLive.Agents.Form, :new)
  live("/agents/:id/view", AppLive.Agents.Form, :view)
  live("/agents/:id/edit", AppLive.Agents.Form, :edit)
  ```
- [ ] ⏸ **REFACTOR**: Verify remaining jarga_web routes compile without warnings

### Step 2.6: Update jarga_web — Sidebar Agent Link

Update the sidebar "Agents" link in `JargaWeb.Layouts.admin/1` to use external URL.

- [ ] ⏸ **RED**: Compile warning — `~p"/app/agents"` no longer exists in jarga_web router
- [ ] ⏸ **GREEN**: Update `apps/jarga_web/lib/components/layouts.ex` line ~240:
  ```elixir
  # Change from:
  <.link navigate={~p"/app/agents"} class="flex items-center gap-3">
  # To:
  <.link href={agents_web_url("/agents")} class="flex items-center gap-3">
  ```
  Add helper function:
  ```elixir
  defp agents_web_url(path) do
    base = Application.get_env(:jarga_web, :agents_web_url, "http://localhost:4014")
    "#{base}#{path}"
  end
  ```
- [ ] ⏸ **REFACTOR**: Verify link works in dev environment

### Step 2.7: Update jarga_web — Workspace Agent Links

Update agent links in `JargaWeb.AppLive.Workspaces.Show` to use external URLs.

- [ ] ⏸ **RED**: Compile warnings — `~p"/app/agents/..."` paths no longer exist
- [ ] ⏸ **GREEN**: Update `apps/jarga_web/lib/live/app_live/workspaces/show.ex`:
  - Line ~224: `~p"/app/agents/new"` → `agents_web_url("/agents/new")`
  - Line ~241: `~p"/app/agents/new"` → `agents_web_url("/agents/new")`
  - Line ~270: `~p"/app/agents/#{agent.id}/edit?return_to=workspace&workspace_slug=#{@workspace.slug}"` → `agents_web_url("/agents/#{agent.id}/edit?return_to=workspace&workspace_slug=#{@workspace.slug}")`
  - Line ~309: `~p"/app/agents/#{agent.id}/view?return_to=workspace&workspace_slug=#{@workspace.slug}"` → `agents_web_url("/agents/#{agent.id}/view?return_to=workspace&workspace_slug=#{@workspace.slug}")`
  - Change `<.button variant="primary" navigate={...}>` and `<.link navigate={...}>` to `<.link href={...}>` (external links use `href`, not `navigate`)
  - Add `agents_web_url/1` private helper (same as layouts)
- [ ] ⏸ **REFACTOR**: Verify all agent links in workspace show page are updated

### Step 2.8: Delete Old Files from jarga_web

Remove the source LiveView files and their tests.

- [ ] ⏸ **RED**: N/A (deletion step)
- [ ] ⏸ **GREEN**: Delete files:
  - `apps/jarga_web/lib/live/app_live/agents/index.ex`
  - `apps/jarga_web/lib/live/app_live/agents/form.ex`
  - `apps/jarga_web/test/live/app_live/agents/index_test.exs`
  - `apps/jarga_web/test/live/app_live/agents/form_test.exs`
- [ ] ⏸ **REFACTOR**: Verify no dangling references to deleted modules (`JargaWeb.AppLive.Agents.Index`, `JargaWeb.AppLive.Agents.Form`)

### Step 2.9: Update jarga_web Boundary (if needed)

If `JargaWeb` boundary exports `AppLive.Agents.Index` or `AppLive.Agents.Form`, remove them.

- [ ] ⏸ **RED**: Check if `JargaWeb` boundary lists these modules — if so, compile will warn
- [ ] ⏸ **GREEN**: Update `apps/jarga_web/lib/jarga_web.ex` boundary exports if needed
- [ ] ⏸ **REFACTOR**: Clean up any orphaned aliases/imports

### Phase 2 Validation
- [ ] ⏸ All new tests pass: `mix test apps/agents_web/test/live/agents/`
- [ ] ⏸ No boundary violations: `mix boundary`
- [ ] ⏸ No compile warnings: `mix compile --warnings-as-errors`
- [ ] ⏸ jarga_web tests still pass: `mix test apps/jarga_web/`
- [ ] ⏸ Full test suite passes: `mix test`
- [ ] ⏸ Pre-commit validation: `mix precommit`

---

## Pre-Commit Checkpoint

- [ ] ⏸ `mix compile --warnings-as-errors` — zero warnings
- [ ] ⏸ `mix boundary` — zero violations
- [ ] ⏸ `mix format --check-formatted` — all formatted
- [ ] ⏸ `mix credo --strict` — zero issues
- [ ] ⏸ `mix test` — all tests pass
- [ ] ⏸ `mix precommit` — full pre-commit passes

---

## Testing Strategy

### Estimated Tests

| Location | Count | Type |
|---|---|---|
| `apps/agents_web/test/live/agents/index_test.exs` | ~11 | LiveView (ConnCase) |
| `apps/agents_web/test/live/agents/form_test.exs` | ~12 | LiveView (ConnCase) |
| `apps/agents_web/test/live/agents/layout_test.exs` | ~5 | Component (ConnCase) |
| **Total** | **~28** | |

### Distribution
- Domain: 0 (no domain changes)
- Application: 0 (no application changes)
- Infrastructure: 0 (no infrastructure changes)
- Interface: ~28 (all LiveView / component tests)

### Test Dependencies
- `Jarga.AccountsFixtures` — user creation for auth
- `Agents.AgentsFixtures` — agent creation for test data
- `AgentsWeb.ConnCase` — connection setup + login helpers

---

## Files Summary

### Create
| File | Description |
|---|---|
| `apps/agents_web/lib/live/agents/index.ex` | `AgentsWeb.AgentsLive.Index` — moved + refactored |
| `apps/agents_web/lib/live/agents/form.ex` | `AgentsWeb.AgentsLive.Form` — moved + refactored |
| `apps/agents_web/test/live/agents/index_test.exs` | Index LiveView tests |
| `apps/agents_web/test/live/agents/form_test.exs` | Form LiveView tests |
| `apps/agents_web/test/live/agents/layout_test.exs` | Admin layout component tests |

### Modify
| File | Change |
|---|---|
| `apps/agents_web/lib/agents_web.ex` | Add boundary deps + exports |
| `apps/agents_web/lib/router.ex` | Add agent routes (live_session :agents) |
| `apps/agents_web/lib/components/layouts.ex` | Add `admin/1` layout + `theme_toggle/1` component |
| `apps/agents_web/test/support/conn_case.ex` | Add `Agents.AgentsFixtures` to boundary deps |
| `apps/jarga_web/lib/router.ex` | Remove agent route lines (78-81) |
| `apps/jarga_web/lib/components/layouts.ex` | Update sidebar "Agents" link to external URL |
| `apps/jarga_web/lib/live/app_live/workspaces/show.ex` | Update agent links to external URLs |
| `config/dev.exs` | Add `agents_web_url` for jarga_web, `jarga_web_url` for agents_web |
| `config/test.exs` | Add `agents_web_url` for jarga_web, `jarga_web_url` for agents_web |
| `config/runtime.exs` | Add `agents_web_url` for jarga_web, `jarga_web_url` for agents_web |

### Delete
| File | Reason |
|---|---|
| `apps/jarga_web/lib/live/app_live/agents/index.ex` | Moved to agents_web |
| `apps/jarga_web/lib/live/app_live/agents/form.ex` | Moved to agents_web |
| `apps/jarga_web/test/live/app_live/agents/index_test.exs` | Moved to agents_web |
| `apps/jarga_web/test/live/app_live/agents/form_test.exs` | Moved to agents_web |

---

## Follow-Up Items (Out of Scope)

1. **Move BDD feature files**: `apps/jarga_web/test/features/agents/` → `apps/agents_web/test/features/agents/` (requires baseUrl changes in exo-bdd config)
2. **Live reload pattern**: Verify `config/dev.exs` live_reload patterns for agents_web include `lib/live/agents/` path (current pattern `~r"lib/agents_web/..."` may need updating to `~r"lib/(?:live|components|router)/.*"`)
3. **E2E browser test baseUrl**: Update any Playwright/browser test configs pointing to jarga_web agent routes

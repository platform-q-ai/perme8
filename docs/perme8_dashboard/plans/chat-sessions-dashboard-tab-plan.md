# Feature: Move Chat Sessions View to Agents Web & Add Dashboard Tab (Issue #178)

## Overview

Extract the chat Sessions view from the `jarga_web` ChatLive.Panel drawer into a standalone pair of LiveViews (`Index` + `Show`) in the `agents_web` app, then mount them in the `perme8_dashboard` app as a "Sessions" tab alongside the existing "Features" tab.

The domain layer (`Jarga.Chat` context) stays untouched in the `jarga` app — only the **Interface layer** changes.

### Key Constraint: `list_sessions/2` requires `user_id`

`Jarga.Chat.list_sessions/2` requires a `user_id`. The perme8_dashboard is a dev-only tool with no user auth. Two options:

1. **Add `Jarga.Chat.list_all_sessions/1`** — a new public API function that lists all sessions without user filtering (dev-tool use case)
2. **Hardcode/config a dev user** — fragile, requires a user to exist

**Decision:** Option 1 is cleaner. We add `list_all_sessions/1` to `Jarga.Chat` (with a new `ListAllSessions` use case and `list_all_sessions` query). This is a small domain extension, not a view concern. The delete operation also requires `user_id` for ownership verification — in the dashboard we can extract the `user_id` from the loaded session itself (it's a dev tool).

### Key Constraint: Message Rendering & MDEx

The `JargaWeb.ChatLive.Components.Message` component uses `MDEx.to_html` for markdown rendering. We cannot import from `jarga_web` (boundary violation). We will create a simpler `AgentsWeb.ChatSessionsLive.Components.MessageComponent` in `agents_web` that also uses `MDEx` (already available via `:jarga` dep).

## UI Strategy

- **LiveView coverage**: 100%
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context (domain, unchanged)**: `Jarga.Chat` — small extension: add `list_all_sessions/1`
- **Primary context (interface)**: `AgentsWeb` — new `ChatSessionsLive.Index` + `ChatSessionsLive.Show`
- **Secondary context (interface)**: `Perme8DashboardWeb` — add Sessions tab + routes
- **Dependencies**:
  - `AgentsWeb` already depends on `Jarga` (boundary declared)
  - `Perme8DashboardWeb` needs new dep on `AgentsWeb` (for mounting LiveView)
  - `perme8_dashboard` mix.exs needs `{:agents_web, in_umbrella: true}` and `{:jarga, in_umbrella: true}`
- **Exported schemas**: `Jarga.Chat.Domain.Entities.Session`, `Jarga.Chat.Domain.Entities.Message` (already exported)
- **New context needed?**: No — this is a view extraction, not a new domain

## Implementation Phases

---

## Phase 1: Domain Extension — `list_all_sessions` (phoenix-tdd)

> Small extension to `Jarga.Chat` to support listing all sessions without `user_id` filtering. Required because perme8_dashboard has no user auth.

### 1.1 ListAllSessions Use Case

- [ ] **RED** ⏸: Write test `apps/jarga/test/chat/application/use_cases/list_all_sessions_test.exs`
  - Tests:
    - Returns `{:ok, sessions}` with all sessions across users
    - Respects `:limit` option (default 50)
    - Returns sessions ordered by most recent first
    - Returns session maps with `id`, `title`, `inserted_at`, `updated_at`, `message_count`, `preview`, `user_id`
    - Uses `async: true`, mock the repository via dependency injection
- [ ] **GREEN** ⏸: Implement `apps/jarga/lib/chat/application/use_cases/list_all_sessions.ex`
  - Pattern: follows existing `ListSessions` use case
  - Calls `session_repository.list_all_sessions(limit)` (new repo function)
  - Adds preview via `session_repository.get_first_message_content(session_id)`
- [ ] **REFACTOR** ⏸: DRY up shared logic with `ListSessions` if appropriate

### 1.2 Query + Repository Extensions

- [ ] **RED** ⏸: Write test `apps/jarga/test/chat/infrastructure/repositories/session_repository_test.exs`
  - Add test for `list_all_sessions(limit, repo)` — returns all sessions with message count, ordered by recent, limited
  - If this test file exists, add to it; otherwise create it
- [ ] **GREEN** ⏸: Add to `apps/jarga/lib/chat/infrastructure/queries/queries.ex`
  - `all_sessions/0` — base query without user filter
  - Compose with existing `ordered_by_recent/1`, `with_message_count/1`, `limit_results/2`
- [ ] **GREEN** ⏸: Add to `apps/jarga/lib/chat/infrastructure/repositories/session_repository.ex`
  - `list_all_sessions(limit, repo \\ Repo)` — uses new query composition
- [ ] **REFACTOR** ⏸: Clean up

### 1.3 Public API Facade

- [ ] **RED** ⏸: Write test (or add to existing) for `Jarga.Chat.list_all_sessions/1`
  - Integration test in `apps/jarga/test/chat_test.exs` or equivalent
  - Verifies delegation to `ListAllSessions.execute/1`
- [ ] **GREEN** ⏸: Add to `apps/jarga/lib/chat.ex`
  - `defdelegate list_all_sessions(opts \\ []), to: ListAllSessions, as: :execute`
  - Add `@doc` with examples
- [ ] **REFACTOR** ⏸: Clean up

### Phase 1 Validation

- [ ] All domain/application tests pass (`mix test apps/jarga/test/chat/`)
- [ ] No boundary violations (`mix boundary`)

---

## Phase 2: Interface Layer — AgentsWeb LiveViews (phoenix-tdd) ✓

> Create standalone `ChatSessionsLive.Index` and `ChatSessionsLive.Show` in agents_web.

### 2.1 Message Component

- [x] **RED**: Write test `apps/agents_web/test/live/chat_sessions/components/message_component_test.exs`
  - Tests:
    - Renders user messages with plain text content
    - Renders assistant messages with markdown-rendered HTML (uses MDEx)
    - Shows role indicator (user vs assistant)
    - Renders timestamp
    - Uses `data-message-role` attribute for role identification
    - Uses `data-message-content` attribute
    - Uses `data-message-timestamp` attribute
    - DaisyUI chat bubble styling (chat-end/chat-start)
- [x] **GREEN**: Implement `apps/agents_web/lib/live/chat_sessions/components/message_component.ex`
  - Function component (not LiveComponent)
  - Uses `MDEx.to_html/2` for assistant message rendering (same approach as `JargaWeb.ChatLive.Components.Message`)
  - Simpler than jarga_web version — no insert/delete/streaming, read-only view
  - Attrs: `message` (map with `:role`, `:content`, `:inserted_at`)
- [x] **REFACTOR**: Clean up

### 2.2 ChatSessionsLive.Index

- [x] **RED**: Write test `apps/agents_web/test/live/chat_sessions/index_test.exs`
  - Tests:
    - Mounts and renders page heading "Chat Sessions"
    - Sets page title
    - Lists all chat sessions (uses `Jarga.Chat.list_all_sessions/1`)
    - Displays session title, message count, and relative timestamp with data attributes
    - Shows empty state when no sessions exist (`data-empty-state`)
    - Each session has `data-session` attribute and `data-session-list` container
    - Clicking a session navigates to show view (`/chat-sessions/:id`)
    - Has delete button per session (`data-session-delete`)
    - Deleting a session removes it from the list
  - Uses: `AgentsWeb.ConnCase` with authenticated user + `Jarga.ChatFixtures`
- [x] **GREEN**: Implement `apps/agents_web/lib/live/chat_sessions/index.ex` (inline render)
  - Module: `AgentsWeb.ChatSessionsLive.Index`
  - `use AgentsWeb, :live_view`
  - `mount/3`: calls `Jarga.Chat.list_all_sessions(limit: 50)`, streams sessions
  - `handle_event("delete_session", ...)`: loads session to get user_id, then calls `Jarga.Chat.delete_session/2`
  - DaisyUI table styling with data-* attributes per BDD feature file
  - Empty state with icon and message
  - Added `Jarga.Chat` to AgentsWeb boundary deps
  - Added `Jarga.ChatFixtures` to ConnCase boundary deps
- [x] **REFACTOR**: Clean up

### 2.3 ChatSessionsLive.Show

- [x] **RED**: Write test `apps/agents_web/test/live/chat_sessions/show_test.exs`
  - Tests:
    - Mounts with session ID and loads session with messages
    - Displays session title in heading
    - Renders messages with data-session-message, data-message-role, data-message-content attributes
    - Messages in chronological order
    - data-session-detail container
    - Back link to /chat-sessions
    - Redirects when session not found
    - Sets page title to session title
    - Handles session without title (shows "Untitled Session")
  - Uses: `AgentsWeb.ConnCase` with authenticated user + `Jarga.ChatFixtures`
- [x] **GREEN**: Implement `apps/agents_web/lib/live/chat_sessions/show.ex` (inline render)
  - Module: `AgentsWeb.ChatSessionsLive.Show`
  - `use AgentsWeb, :live_view`
  - `mount/3`: no-op (handle_params loads session)
  - `handle_params/3`: loads session via `Jarga.Chat.load_session(id)`, handles `:not_found` with redirect
  - Renders session header + message list using MessageComponent
  - Back link to `/chat-sessions`
  - Data attributes per BDD feature file
- [x] **REFACTOR**: Clean up

### 2.4 AgentsWeb Router Extension

- [x] **RED**: Write test `apps/agents_web/test/live/chat_sessions/routing_test.exs`
  - Tests:
    - `GET /chat-sessions` renders the chat sessions index
    - `GET /chat-sessions/:id` renders session detail
    - Both routes require authentication (redirect to login when unauthenticated)
- [x] **GREEN**: Routes already added to `apps/agents_web/lib/router.ex` in 2.2
- [x] **REFACTOR**: Clean up

### Phase 2 Validation

- [x] All new agents_web tests pass (34 tests, 0 failures; 13 pre-existing failures in SessionsLive.IndexTest unrelated to chat sessions)
- [x] No new boundary violations (`mix boundary` — only pre-existing warnings in other apps)
- [ ] Routes respond correctly in dev (`http://localhost:4014/chat-sessions`)

---

## Phase 3: Dashboard Integration — Perme8 Dashboard Tab (phoenix-tdd) ✓

> Mount the new ChatSessionsLive views in perme8_dashboard and add the "Sessions" tab.

### 3.1 Dependency Configuration

- [x] **GREEN**: Modify `apps/perme8_dashboard/mix.exs`
  - Add dependencies:
    ```elixir
    {:agents_web, in_umbrella: true},
    {:jarga, in_umbrella: true}
    ```
  - Add to boundary config `apps:` list:
    ```elixir
    {:agents_web, :relaxed},
    {:jarga, :relaxed}
    ```
- [x] **GREEN**: Modify `apps/perme8_dashboard/lib/perme8_dashboard_web.ex`
  - Update boundary deps:
    ```elixir
    use Boundary,
      top_level?: true,
      deps: [ExoDashboardWeb, AgentsWeb],
      exports: [Endpoint, Telemetry]
    ```
- [x] **REFACTOR**: Verify compilation with `mix compile`

### 3.2 Dashboard Router — Sessions Routes

- [x] **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/live/chat_sessions_tab_test.exs`
  - Tests:
    - `GET /sessions` renders the sessions tab within dashboard layout
    - `GET /sessions/:id` renders session detail within dashboard layout
    - Dashboard layout wraps the content (sidebar, tabs visible)
    - Sessions tab is marked as active (`data-tab="sessions"` has `tab-active` class)
    - Features tab is NOT marked as active when on sessions page
    - Session links use /sessions/ prefix (dashboard route)
    - Back link uses /sessions (dashboard route)
    - Session deletion works in dashboard context
    - Tab navigation shows both tabs on all pages
  - Note: ConnCase extended with `Jarga.DataCase.setup_sandbox/1` for DB access.
- [x] **GREEN**: Modify `apps/perme8_dashboard/lib/perme8_dashboard_web/router.ex`
  - Add routes in the `:dashboard` live_session with on_mount hook:
    ```elixir
    live_session :dashboard,
      layout: {Perme8DashboardWeb.Layouts, :app},
      on_mount: [{Perme8DashboardWeb.Hooks.SetActiveTab, :default}] do
      live("/", ExoDashboardWeb.DashboardLive, :index)
      live("/features/*uri", ExoDashboardWeb.FeatureDetailLive, :show)
      live("/sessions", AgentsWeb.ChatSessionsLive.Index, :index)
      live("/sessions/:id", AgentsWeb.ChatSessionsLive.Show, :show)
    end
    ```
  - Note: No auth pipeline needed — perme8_dashboard is dev-only
- [x] **REFACTOR**: Clean up

### 3.3 Active Tab Assignment via on_mount Hook

- [x] **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/hooks/set_active_tab_test.exs`
  - Tests:
    - Sets `active_tab: :sessions` when path starts with `/sessions`
    - Sets `active_tab: :features` when path is `/` or starts with `/features`
    - Default is `:features` for unknown paths
    - Assigns sessions_path and sessions_base_path for cross-app navigation
- [x] **GREEN**: Create `apps/perme8_dashboard/lib/perme8_dashboard_web/hooks/set_active_tab.ex`
  - Module: `Perme8DashboardWeb.Hooks.SetActiveTab`
  - Implements `on_mount/4` callback
  - Inspects the current URL/path to determine active tab
  - Assigns `active_tab` to socket
- [x] **GREEN**: Modify `apps/perme8_dashboard/lib/perme8_dashboard_web/router.ex`
  - Add `on_mount` to the `:dashboard` live_session:
    ```elixir
    live_session :dashboard,
      layout: {Perme8DashboardWeb.Layouts, :app},
      on_mount: [{Perme8DashboardWeb.Hooks.SetActiveTab, :default}] do
    ```
- [x] **REFACTOR**: Clean up

### 3.4 Dashboard Layout — Sessions Tab Entry

- [x] **RED**: Write test `apps/perme8_dashboard/test/perme8_dashboard_web/layouts/app_layout_sessions_tab_test.exs`
  - Tests:
    - Layout contains "Sessions" tab in tab bar
    - Layout contains sessions tab key and path in config
    - Layout contains `hero-chat-bubble-left-right` icon for sessions
    - Sidebar contains data-sidebar- attributes for navigation links
- [x] **GREEN**: Modify `apps/perme8_dashboard/lib/perme8_dashboard_web/components/layouts/app.html.heex`
  - Update `tabs` list:
    ```elixir
    tabs = [{:features, "Features", ~p"/"}, {:sessions, "Sessions", ~p"/sessions"}]
    ```
  - Update `tab_icons` map:
    ```elixir
    tab_icons = %{features: "hero-squares-2x2", sessions: "hero-chat-bubble-left-right"}
    ```
- [x] **REFACTOR**: Clean up

### 3.5 Dashboard ConnCase Extension

- [x] **GREEN**: Modify `apps/perme8_dashboard/test/support/conn_case.ex`
  - Add sandbox setup for database access (sessions live in DB):
    ```elixir
    setup tags do
      Jarga.DataCase.setup_sandbox(tags)
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end
    ```
  - Add boundary dep on `Jarga.DataCase` if needed
- [x] **GREEN**: Modify `apps/perme8_dashboard/mix.exs`
  - Ensure `{:jarga, in_umbrella: true}` provides DataCase access for tests
- [x] **REFACTOR**: Clean up

### 3.6 LiveView Compatibility — Layout Awareness

The `AgentsWeb.ChatSessionsLive.Index` and `Show` modules use `use AgentsWeb, :live_view`, which imports `AgentsWeb.CoreComponents` and aliases `AgentsWeb.Layouts`. When mounted in perme8_dashboard's router, the layout is overridden by `{Perme8DashboardWeb.Layouts, :app}` (from the `live_session`), so the inner content works correctly. However, we need to ensure:

- [x] **RED**: Tests in `chat_sessions_tab_test.exs` cover cross-app rendering
  - Renders session list within dashboard frame
  - Tab navigation works between Features and Sessions
  - Session detail view loads within dashboard frame
  - Session links use dashboard routes (/sessions/) not agents_web routes (/chat-sessions/)
  - Back link uses /sessions (dashboard route)
- [x] **GREEN**: Resolved cross-app routing via configurable path assigns
  - `assign_new` in Index mount sets `:sessions_base_path` (defaults to `~p"/chat-sessions"`)
  - `assign_new` in Show mount sets `:sessions_path` (defaults to `~p"/chat-sessions"`)
  - `SetActiveTab` on_mount hook injects `/sessions` paths for dashboard context
  - Templates use `@sessions_base_path` and `@sessions_path` instead of hardcoded `~p`
  - Added `ChatSessionsLive.Index` and `.Show` to AgentsWeb boundary exports
- [x] **REFACTOR**: Clean up

### Phase 3 Validation

- [x] All perme8_dashboard tests pass (122 tests, 0 failures)
- [x] All agents_web chat sessions tests pass (34 tests, 0 failures)
- [x] No new boundary violations (only pre-existing warnings in other apps)
- [ ] Dashboard serves at `http://localhost:4012/sessions` with tab navigation
- [ ] Features tab still works at `http://localhost:4012/`
- [ ] Session detail loads at `http://localhost:4012/sessions/:id`

---

## Phase 4: Regression Verification (no new code)

> Ensure the existing ChatLive.Panel in jarga_web is unaffected.

### 4.1 JargaWeb ChatLive.Panel Regression

- [ ] Verify `apps/jarga_web` tests still pass (`mix test apps/jarga_web/`)
- [ ] Verify `ChatLive.Panel` renders and works correctly in jarga_web (no imports changed, no shared code modified)
- [ ] `Jarga.Chat` domain tests still pass (`mix test apps/jarga/test/chat/`)

### 4.2 Pre-commit Checkpoint

- [ ] `mix precommit` passes (format + credo + compile + boundary + tests)
- [ ] `mix boundary` shows no violations
- [ ] Full test suite passes (`mix test`)

---

## Cross-Cutting Concerns

### Verified Routes Conflict

The `ChatSessionsLive` modules use `AgentsWeb.verified_routes`, which generates `~p` paths against `AgentsWeb.Router`. When these LiveViews are mounted in `Perme8DashboardWeb.Router`, `~p"/chat-sessions"` will still resolve against `AgentsWeb.Router` — this is fine for standalone agents_web, but links within the dashboard need to point to `/sessions` (the perme8_dashboard route), not `/chat-sessions` (the agents_web route).

**Solution:** Use a configurable base path or detect the mounting context:
- Option A: Pass a `base_path` assign from the router/on_mount and use it in templates
- Option B: Use `Phoenix.LiveView.get_connect_info/2` to detect the endpoint
- Option C: Define routes in both routers and let verified routes work per-endpoint

**Recommended:** Option A — the `on_mount` hook in Phase 3.3 can also assign a `:sessions_base_path` that the LiveView templates use for navigation links. This is the cleanest approach.

Update the `SetActiveTab` hook to also set:
```elixir
assign(socket, :sessions_path, "/sessions")  # or "/chat-sessions" for agents_web standalone
assign(socket, :sessions_detail_path, fn id -> "/sessions/#{id}" end)
```

And in the LiveView, use `@sessions_path` and `@sessions_detail_path.(id)` instead of `~p` for cross-app links.

### MDEx Dependency

`agents_web` already depends on `:jarga` which depends on `:mdex`. MDEx should be available transitively. If not, add `{:mdex, "~> 0.2"}` to `agents_web/mix.exs`. Verify at compile time.

### Data Attributes for BDD Testing

Per the BDD feature files (referenced in ticket), use these `data-*` attributes:
- `data-testid="sessions-list"` — sessions list container
- `data-testid="session-row"` — each session entry
- `data-session-id={id}` — session identifier on each row
- `data-testid="session-detail"` — session detail container
- `data-testid="messages-list"` — messages container
- `data-testid="chat-message"` — each message
- `data-role={role}` — message role (user/assistant)
- `data-testid="delete-session"` — delete button
- `data-testid="back-link"` — back navigation
- `data-testid="sessions-empty-state"` — empty state
- `data-tab="sessions"` — sessions tab (already in tab_components pattern)

---

## Testing Strategy

- **Total estimated tests**: ~35-40
- **Distribution**:
  - Domain/Application (Phase 1): ~8 tests (ListAllSessions use case + query/repo + facade)
  - Interface - AgentsWeb (Phase 2): ~20 tests (MessageComponent ~6, Index ~8, Show ~6)
  - Interface - Perme8Dashboard (Phase 3): ~10 tests (routing ~3, on_mount hook ~3, layout ~4)
- **Regression**: existing test suites must continue passing with zero modifications

## File Change Summary

### NEW files:
1. `apps/jarga/lib/chat/application/use_cases/list_all_sessions.ex`
2. `apps/jarga/test/chat/application/use_cases/list_all_sessions_test.exs`
3. `apps/agents_web/lib/live/chat_sessions/index.ex`
4. `apps/agents_web/lib/live/chat_sessions/index.html.heex`
5. `apps/agents_web/lib/live/chat_sessions/show.ex`
6. `apps/agents_web/lib/live/chat_sessions/show.html.heex`
7. `apps/agents_web/lib/live/chat_sessions/components/message_component.ex`
8. `apps/agents_web/test/live/chat_sessions/index_test.exs`
9. `apps/agents_web/test/live/chat_sessions/show_test.exs`
10. `apps/agents_web/test/live/chat_sessions/components/message_component_test.exs`
11. `apps/agents_web/test/live/chat_sessions/routing_test.exs`
12. `apps/perme8_dashboard/lib/perme8_dashboard_web/hooks/set_active_tab.ex`
13. `apps/perme8_dashboard/test/perme8_dashboard_web/hooks/set_active_tab_test.exs`
14. `apps/perme8_dashboard/test/perme8_dashboard_web/live/chat_sessions_tab_test.exs`
15. `apps/perme8_dashboard/test/perme8_dashboard_web/layouts/app_layout_sessions_tab_test.exs`

### MODIFIED files:
1. `apps/jarga/lib/chat.ex` — add `list_all_sessions/1` delegate
2. `apps/jarga/lib/chat/infrastructure/queries/queries.ex` — add `all_sessions/0` query
3. `apps/jarga/lib/chat/infrastructure/repositories/session_repository.ex` — add `list_all_sessions/2`
4. `apps/agents_web/lib/router.ex` — add chat-sessions routes
5. `apps/perme8_dashboard/lib/perme8_dashboard_web/router.ex` — add sessions routes + on_mount hook
6. `apps/perme8_dashboard/lib/perme8_dashboard_web/components/layouts/app.html.heex` — add Sessions tab
7. `apps/perme8_dashboard/lib/perme8_dashboard_web.ex` — add AgentsWeb to boundary deps
8. `apps/perme8_dashboard/mix.exs` — add agents_web + jarga deps
9. `apps/perme8_dashboard/test/support/conn_case.ex` — add DB sandbox setup

### UNCHANGED files:
- `apps/jarga_web/lib/live/chat_live/panel.ex` — no regression
- `apps/jarga_web/lib/live/chat_live/components/message.ex` — no regression
- All other existing files

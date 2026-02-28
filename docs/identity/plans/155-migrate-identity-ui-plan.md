# Feature: Migrate Identity-Related UI from jarga_web to identity_web

**Ticket**: [#155](https://github.com/platform-q-ai/perme8/issues/155)

## Overview

The Identity app already owns ALL workspace domain logic — `Jarga.Workspaces` is a pure delegation facade. The Identity app has its own Phoenix Endpoint (port 4001), router, layouts, CoreComponents, and already serves 7 LiveView pages. This plan migrates the remaining identity-related UI (workspace CRUD, member management, landing page, profile page) from `jarga_web` into `identity_web`, decomposes the 1102-line `Workspaces.Show` page, removes duplicate auth LiveViews from `jarga_web`, and cleans up the delegation facades.

## UI Strategy

- **LiveView coverage**: 100%
- **TypeScript needed**: None

## Affected Boundaries

- **Owning app**: `identity` (domain) + `identity_web` (interface — currently embedded in `apps/identity/`)
- **Repo**: `Identity.Repo`
- **Migrations**: None required (no schema changes)
- **Feature files**: `apps/identity/test/identity_web/live/` (unit tests), `apps/identity/test/features/` (BDD if needed)
- **Primary context**: `Identity` (workspace operations already here)
- **Dependencies**: None added — Identity remains self-contained
- **Apps affected by removals**: `jarga_web` (LiveViews, routes, helpers removed), `jarga` (facade evaluated)

## Key Decisions

1. **New LiveViews use `IdentityWeb.Layouts.app`** — not jarga_web's admin layout. The identity app's layout is simpler (no sidebar, no chat panel, no notifications bell). This is intentional: identity pages should be self-contained.
2. **All workspace CRUD calls `Identity.*` directly** — not `Jarga.Workspaces`.
3. **Show page decomposition**: Identity gets workspace settings + member management as a new `WorkspacesLive.Settings` page. jarga_web keeps a trimmed `Workspaces.Show` as the domain hub (projects, documents, agents) that calls `Identity` for workspace metadata.
4. **Permissions split**: Workspace-level permission helpers (`can_edit_workspace?`, `can_delete_workspace?`, `can_manage_members?`) move to `IdentityWeb.Live.PermissionsHelper`. Domain-specific permissions (`can_create_project?`, `can_edit_document?`, etc.) stay in `JargaWeb.Live.PermissionsHelper`.
5. **Route prefixes**: Identity workspace routes live under `/workspaces/*` (no `/app` prefix) on the Identity endpoint (port 4001). jarga_web's `/app/workspaces/*` routes redirect or are updated.

---

## Phase 1: Workspace CRUD LiveViews in identity_web ⏸

**Goal**: Create `IdentityWeb.WorkspacesLive.{Index, New, Edit}` — the straightforward migrations of workspace list, create, and edit pages.

### 1.1 WorkspacesLive.Index

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/workspaces_live/index_test.exs`
  - Tests:
    - Redirects unauthenticated users to login
    - Renders empty state when user has no workspaces
    - Lists user's workspaces (name, description, color bar)
    - Does not show other users' workspaces
    - Has "New Workspace" button linking to `/workspaces/new`
    - Real-time update: workspace appears when user is invited (`WorkspaceInvitationNotified`)
    - Real-time update: workspace disappears when user is removed (`MemberRemoved`)
    - Real-time update: workspace name updates on `WorkspaceUpdated` event
    - Real-time update: workspace appears when user accepts invitation (`MemberJoined`)
- [ ] **GREEN**: Implement `apps/identity/lib/identity_web/live/workspaces_live/index.ex`
  - Uses `IdentityWeb, :live_view`
  - Uses `Layouts.app` (identity's layout)
  - Calls `Identity.list_workspaces_for_user/1` directly
  - Subscribes to `events:user:{id}` and `events:workspace:{id}` topics
  - Handles `WorkspaceInvitationNotified`, `MemberJoined`, `MemberRemoved`, `WorkspaceUpdated` events
  - No chat panel integration (no `handle_chat_messages()`)
  - Routes: links to `/workspaces/new`, `/workspaces/:slug`
- [ ] **REFACTOR**: Extract shared workspace card component if reused

### 1.2 WorkspacesLive.New

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/workspaces_live/new_test.exs`
  - Tests:
    - Redirects unauthenticated users to login
    - Renders new workspace form with name, description, color fields
    - Creates workspace with valid data and redirects to index
    - Creates workspace with full data (name + description + color)
    - Shows validation errors for blank name
    - Has cancel button linking back to `/workspaces`
- [ ] **GREEN**: Implement `apps/identity/lib/identity_web/live/workspaces_live/new.ex`
  - Uses `IdentityWeb, :live_view`
  - Uses `Layouts.app`
  - Calls `Identity.change_workspace/0` for form initialization
  - Calls `Identity.create_workspace/2` on submit
  - Redirects to `/workspaces` on success
  - No chat panel integration
- [ ] **REFACTOR**: Clean up

### 1.3 WorkspacesLive.Edit

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/workspaces_live/edit_test.exs`
  - Tests:
    - Redirects unauthenticated users to login
    - Renders edit form pre-populated with workspace data
    - Updates workspace with valid data and redirects to workspace settings
    - Shows validation errors for blank name
    - Has cancel button linking back to `/workspaces/:slug/settings`
    - Raises/redirects when user is not a member
- [ ] **GREEN**: Implement `apps/identity/lib/identity_web/live/workspaces_live/edit.ex`
  - Uses `IdentityWeb, :live_view`
  - Uses `Layouts.app`
  - Calls `Identity.get_workspace_by_slug!/2` in mount
  - Calls `Identity.change_workspace/2` for form
  - Calls `Identity.update_workspace/4` on submit
  - Redirects to `/workspaces/:slug/settings` on success
  - No chat panel integration
- [ ] **REFACTOR**: Clean up

### 1.4 Update Identity Router — Workspace Routes

- [ ] Add workspace routes to `apps/identity/lib/identity_web/router.ex`:
  ```elixir
  # Inside the :authenticated live_session
  live "/workspaces", WorkspacesLive.Index, :index
  live "/workspaces/new", WorkspacesLive.New, :new
  live "/workspaces/:workspace_slug/edit", WorkspacesLive.Edit, :edit
  ```

### Phase 1 Validation

- [ ] All new identity_web tests pass (`mix test apps/identity/test/identity_web/live/workspaces_live/`)
- [ ] Identity endpoint serves workspace pages on port 4001
- [ ] No boundary violations (`mix boundary`)
- [ ] Existing jarga_web tests still pass (nothing removed yet)

---

## Phase 2: Workspace Settings + Members Page ⏸

**Goal**: Create `IdentityWeb.WorkspacesLive.Settings` — the identity-owned portion of the current `Workspaces.Show` page. This handles workspace metadata display, member management modal, workspace deletion, and links to edit.

### 2.1 IdentityWeb.Live.PermissionsHelper

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/permissions_helper_test.exs`
  - Tests:
    - `can_edit_workspace?/1` returns true for admin/owner, false for member/guest
    - `can_delete_workspace?/1` returns true for owner only
    - `can_manage_members?/1` returns true for admin/owner
- [ ] **GREEN**: Implement `apps/identity/lib/identity_web/live/permissions_helper.ex`
  - Contains only workspace-level permission checks:
    - `can_edit_workspace?/1`
    - `can_delete_workspace?/1`
    - `can_manage_members?/1`
  - Delegates to `Identity.Domain.Policies.WorkspacePermissionsPolicy`
- [ ] **REFACTOR**: Clean up

### 2.2 WorkspacesLive.Settings

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/workspaces_live/settings_test.exs`
  - Tests:
    - Redirects unauthenticated users to login
    - Renders workspace name, description, color
    - Shows "Edit Workspace" link for admin/owner
    - Shows "Manage Members" button for admin/owner
    - Shows "Delete Workspace" button for owner only
    - Hides admin controls for regular members and guests
    - Opens members management modal with member list
    - Modal shows invite form (email + role select + invite button)
    - Can invite a new member
    - Can change a member's role
    - Can remove a non-owner member
    - Cannot change owner's role
    - Cannot remove owner
    - Closes members modal
    - Deletes workspace and redirects to `/workspaces`
    - Redirects with error when workspace not found
    - Redirects with error when user is not a member
    - Real-time: workspace name updates on `WorkspaceUpdated` event
- [ ] **GREEN**: Implement `apps/identity/lib/identity_web/live/workspaces_live/settings.ex`
  - Uses `IdentityWeb, :live_view`
  - Imports `IdentityWeb.Live.PermissionsHelper`
  - Uses `Layouts.app`
  - Mount: calls `Identity.get_workspace_and_member_by_slug/2`
  - Displays workspace info (name, description, color bar)
  - Kebab menu with Edit/Manage Members/Delete (permission-gated)
  - Members modal (copied from current Show page lines 337-533):
    - Invite form
    - Members table with role dropdown, status badge, remove button
  - Event handlers:
    - `invite_member` → `Identity.invite_member/5`
    - `change_role` → `Identity.change_member_role/4`
    - `remove_member` → `Identity.remove_member/3`
    - `delete_workspace` → `Identity.delete_workspace/2`
    - `show_members_modal` / `hide_members_modal`
  - Subscribes to `events:workspace:{id}` for `WorkspaceUpdated`
  - Links to `/workspaces/:slug/edit` for editing
  - No projects/documents/agents sections
  - No chat panel
- [ ] **REFACTOR**: Extract members modal into a function component if it grows

### 2.3 Update Identity Router — Settings Route

- [ ] Add to the `:authenticated` live_session:
  ```elixir
  live "/workspaces/:slug/settings", WorkspacesLive.Settings, :show
  ```

### Phase 2 Validation

- [ ] All workspace settings tests pass
- [ ] Members modal works end-to-end (invite, change role, remove)
- [ ] Workspace deletion redirects correctly
- [ ] Permission gating works for all role combinations
- [ ] No boundary violations

---

## Phase 3: Landing Page / Dashboard ⏸

**Goal**: Add a landing/home page to identity_web at `/` that shows the user's workspaces or redirects appropriately. This gives the Identity app a proper entry point.

### 3.1 DashboardLive (or redirect)

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/dashboard_live_test.exs`
  - Tests:
    - Authenticated user sees their workspaces listed
    - Authenticated user with no workspaces sees prompt to create one
    - Unauthenticated user is redirected to login OR sees a public landing page
    - Links to individual workspace settings pages
    - Link to create new workspace
- [ ] **GREEN**: Implement `apps/identity/lib/identity_web/live/dashboard_live.ex`
  - Uses `IdentityWeb, :live_view`
  - Uses `Layouts.app`
  - Shows workspace cards with links to `/workspaces/:slug/settings`
  - Quick-access to settings, API keys
  - Calls `Identity.list_workspaces_for_user/1`
- [ ] **REFACTOR**: Clean up

### 3.2 Update Identity Router — Dashboard Route

- [ ] Add to authenticated live_session:
  ```elixir
  live "/", DashboardLive, :index
  ```
- [ ] Decision: Does `/` require auth? If yes, put in `:authenticated` session. If it shows a public marketing page for unauthenticated users, create a separate route.

### Phase 3 Validation

- [ ] Dashboard test passes
- [ ] Authenticated users see their workspace list
- [ ] No boundary violations

---

## Phase 4: Profile Page ⏸

**Goal**: Add a profile page to identity_web that shows user profile information and links to settings.

### 4.1 ProfileLive

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/profile_live_test.exs`
  - Tests:
    - Renders user's email
    - Links to settings page
    - Links to API keys page
    - Shows workspace membership count or list
    - Redirects unauthenticated users to login
- [ ] **GREEN**: Implement `apps/identity/lib/identity_web/live/profile_live.ex`
  - Uses `IdentityWeb, :live_view`
  - Uses `Layouts.app`
  - Displays current user info (email, member since date)
  - Links to `/users/settings` and `/users/settings/api-keys`
  - Lists workspaces the user belongs to
- [ ] **REFACTOR**: Clean up

### 4.2 Update Identity Router — Profile Route

- [ ] Add to `:authenticated` live_session:
  ```elixir
  live "/users/profile", ProfileLive, :show
  ```

### Phase 4 Validation

- [ ] Profile tests pass
- [ ] No boundary violations

---

## Phase 5: Decompose jarga_web Workspaces.Show ⏸

**Goal**: Strip identity concerns from `JargaWeb.AppLive.Workspaces.Show` (1102 lines), leaving it as a "workspace domain hub" that shows projects, documents, and agents only. Workspace metadata, member management, and deletion move to identity_web (Phase 2).

### 5.1 Slim Down Workspaces.Show

- [ ] **RED**: Update test `apps/jarga_web/test/live/app_live/workspaces_test.exs`
  - Update "workspace show page" tests:
    - Verify page still shows projects, documents, agents sections
    - Verify page NO LONGER shows "Manage Members" button
    - Verify page NO LONGER shows "Delete Workspace" button
    - Verify page links to identity's settings page for workspace management
    - Add new test: "has settings link that points to identity workspace settings"
  - Remove or update workspace deletion tests (deletion moved to identity)
  - Keep all project CRUD tests (create project modal, project listing, real-time events)
  - Keep all document CRUD tests (create document modal, document listing, real-time events)
  - Keep all agent-related tests
- [ ] **GREEN**: Modify `apps/jarga_web/lib/live/app_live/workspaces/show.ex`
  - **Remove**:
    - Members management modal (lines 337-533) — moved to identity Phase 2
    - Delete workspace button and handler — moved to identity Phase 2
    - `show_members_modal` / `hide_members_modal` events and assigns
    - `invite_member` / `change_role` / `remove_member` events
    - `@members` assign
    - `@invite_form` assign
    - `@show_members_modal` assign
    - Import of `IdentityWeb.Live.PermissionsHelper` workspace permission functions (keep domain ones)
  - **Keep**:
    - Projects section + modal + CRUD events
    - Documents section + modal + CRUD events
    - Agents section (my agents, shared agents, clone)
    - All domain event handlers (project/document/agent events)
    - `WorkspaceUpdated` handler (for breadcrumb name updates)
    - Chat panel integration (`handle_chat_messages()`, `send_update(ChatLive.Panel, ...)`)
    - `@workspace`, `@current_member` assigns (needed for domain permission checks)
  - **Add**:
    - Link to identity settings page: e.g., a "Settings" link in the kebab menu pointing to `{identity_url}/workspaces/:slug/settings` (or a relative cross-app URL strategy)
  - **Update**:
    - `PermissionsHelper` import: only import domain-specific checks from `JargaWeb.Live.PermissionsHelper` (`can_create_project?`, `can_create_document?`, etc.)
    - Remove `can_edit_workspace?`, `can_delete_workspace?`, `can_manage_members?` usage from template
- [ ] **REFACTOR**: The file should drop from ~1102 to ~700 lines. Consider extracting project/document/agent sections into function components.

### 5.2 Update JargaWeb.Live.PermissionsHelper

- [ ] **RED**: Write/update test `apps/jarga_web/test/live/permissions_helper_test.exs`
  - Tests: Verify remaining domain permission functions still work
  - Verify workspace-level functions (`can_edit_workspace?`, `can_delete_workspace?`, `can_manage_members?`) are removed
- [ ] **GREEN**: Modify `apps/jarga_web/lib/live/permissions_helper.ex`
  - **Remove**:
    - `can_edit_workspace?/1`
    - `can_delete_workspace?/1`
    - `can_manage_members?/1`
    - `alias Identity.Domain.Policies.WorkspacePermissionsPolicy`
  - **Keep**:
    - `can_create_project?/1`
    - `can_edit_project?/3`
    - `can_delete_project?/3`
    - `can_create_document?/1`
    - `can_edit_document?/3`
    - `can_delete_document?/3`
    - `can_pin_document?/3`
    - `can_create_agent?/1`
    - `can_edit_agent?/3`
    - `can_delete_agent?/3`
    - `alias Jarga.Domain.Policies.DomainPermissionsPolicy`
- [ ] **REFACTOR**: Clean up

### Phase 5 Validation

- [ ] `JargaWeb.AppLive.Workspaces.Show` still renders correctly with projects/docs/agents
- [ ] Members modal and delete button are gone from Show page
- [ ] All remaining jarga_web workspace tests pass
- [ ] All project/document real-time event tests still pass
- [ ] No boundary violations

---

## Phase 6: Remove Duplicate Auth LiveViews from jarga_web ⏸

**Goal**: Delete the 7 duplicate auth-related files from `jarga_web` that are copies of existing `identity_web` pages.

### 6.1 Remove Duplicate LiveViews

- [ ] Delete `apps/jarga_web/lib/live/user_live/settings.ex` (duplicate of `IdentityWeb.SettingsLive`)
- [ ] Delete `apps/jarga_web/lib/live/user_live/registration.ex` (duplicate of `IdentityWeb.RegistrationLive`)
- [ ] Delete `apps/jarga_web/lib/live/user_live/login.ex` (duplicate of `IdentityWeb.LoginLive`)
- [ ] Delete `apps/jarga_web/lib/live/user_live/confirmation.ex` (duplicate of `IdentityWeb.ConfirmationLive`)
- [ ] Delete `apps/jarga_web/lib/live/api_keys_live.ex` (duplicate of `IdentityWeb.ApiKeysLive`)

### 6.2 Remove Duplicate Controller

- [ ] Delete `apps/jarga_web/lib/controllers/user_session_controller.ex` (duplicate of `IdentityWeb.SessionController`)

### 6.3 Evaluate JargaWeb.UserAuth

- [ ] **Analyze**: Determine if `apps/jarga_web/lib/user_auth.ex` can be replaced by importing `IdentityWeb.Plugs.UserAuth`
  - `JargaWeb.UserAuth` uses `JargaWeb.Endpoint` for broadcast disconnect — this is a jarga_web concern
  - `JargaWeb.UserAuth` uses `Jarga.Accounts` (delegation facade) — can switch to `Identity`
  - `JargaWeb.UserAuth` defines `signed_in_path/1` as `~p"/app"` — jarga_web specific
  - **Decision**: Keep `JargaWeb.UserAuth` but simplify it. It should delegate to `Identity` directly (not via `Jarga.Accounts`). It still needs its own `signed_in_path` and `disconnect_sessions` that use `JargaWeb.Endpoint`.
- [ ] **RED**: Write test verifying `JargaWeb.UserAuth` still works after switch from `Jarga.Accounts` to `Identity`
- [ ] **GREEN**: Update `JargaWeb.UserAuth` to call `Identity` directly instead of `Jarga.Accounts`
- [ ] **REFACTOR**: Clean up

### Phase 6 Validation

- [ ] Deleted files are gone
- [ ] `mix compile` succeeds (no references to deleted modules)
- [ ] jarga_web auth still works through `JargaWeb.UserAuth`
- [ ] No boundary violations

---

## Phase 7: Update jarga_web Router ⏸

**Goal**: Remove workspace CRUD routes and duplicate auth routes from jarga_web's router. The workspace domain hub (`/app/workspaces/:slug`) stays but workspace management routes move to identity.

### 7.1 Update Router

- [ ] **RED**: Update router tests to reflect new route structure
- [ ] **GREEN**: Modify `apps/jarga_web/lib/router.ex`
  - **Remove from `:app` live_session**:
    - `live("/workspaces", AppLive.Workspaces.Index, :index)` — now in identity
    - `live("/workspaces/new", AppLive.Workspaces.New, :new)` — now in identity
    - `live("/workspaces/:workspace_slug/edit", AppLive.Workspaces.Edit, :edit)` — now in identity
  - **Keep in `:app` live_session**:
    - `live("/workspaces/:slug", AppLive.Workspaces.Show, :show)` — domain hub stays
    - All project routes (`/workspaces/:slug/projects/...`)
    - All document routes (`/workspaces/:slug/documents/...`)
    - Agent routes
    - Dashboard
  - **Remove `:require_authenticated_user` live_session** (auth routes):
    - `live("/users/settings", UserLive.Settings, :edit)` — now in identity only
    - `live("/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email)` — now in identity only
    - `live("/users/settings/api-keys", ApiKeysLive, :index)` — now in identity only
    - `post("/users/update-password", UserSessionController, :update_password)` — now in identity only
  - **Remove `:current_user` live_session** (public auth routes):
    - `live("/users/register", UserLive.Registration, :new)` — now in identity only
    - `live("/users/log-in", UserLive.Login, :new)` — now in identity only
    - `live("/users/log-in/:token", UserLive.Confirmation, :new)` — now in identity only
    - `post("/users/log-in", UserSessionController, :create)` — now in identity only
    - `delete("/users/log-out", UserSessionController, :delete)` — now in identity only
  - **Add redirect routes** (optional, for backwards compatibility):
    - Consider adding `get "/app/workspaces", redirect_to: identity_workspaces_url` for any bookmarks
    - Or a catch-all redirect plug for `/users/*` paths
- [ ] **REFACTOR**: Clean up empty scopes and live_sessions

### 7.2 Delete Now-Unused LiveView Files

- [ ] Delete `apps/jarga_web/lib/live/app_live/workspaces/index.ex` — functionality moved to identity
- [ ] Delete `apps/jarga_web/lib/live/app_live/workspaces/new.ex` — functionality moved to identity
- [ ] Delete `apps/jarga_web/lib/live/app_live/workspaces/edit.ex` — functionality moved to identity

### Phase 7 Validation

- [ ] `mix compile` succeeds
- [ ] jarga_web router has no workspace CRUD or auth routes
- [ ] `/app/workspaces/:slug` (domain hub) still works
- [ ] Project/document routes still work
- [ ] No boundary violations
- [ ] All remaining jarga_web tests pass

---

## Phase 8: Clean Up Jarga Facades ⏸

**Goal**: Evaluate and simplify `Jarga.Workspaces` and `Jarga.Accounts` facades now that identity owns all UI.

### 8.1 Evaluate Jarga.Workspaces Facade

- [ ] **Analyze**: Check all usages of `Jarga.Workspaces` across the codebase
  - `apps/jarga_web/lib/live/app_live/workspaces/show.ex` — the trimmed domain hub
  - `apps/jarga_web/test/live/app_live/workspaces_test.exs` — tests
  - `apps/jarga/test/support/fixtures/workspaces_fixtures.ex` — fixtures
  - Any other jarga or jarga_web references
  - `apps/jarga_api/` — API layer may use it
- [ ] **Decision**: 
  - **If only jarga_web's Show page uses it**: Switch Show page to call `Identity.*` directly and deprecate the facade
  - **If jarga_api also uses it**: Keep as a thin convenience for jarga's apps, but add deprecation notice
  - **If nothing uses it after Phase 7**: Delete it
- [ ] **GREEN**: Update remaining callers to use `Identity.*` directly OR keep minimal facade
- [ ] **REFACTOR**: Add `@deprecated` annotation or delete facade

### 8.2 Evaluate Jarga.Accounts Facade

- [ ] **Analyze**: Check all usages of `Jarga.Accounts` across the codebase
  - `apps/jarga_web/lib/user_auth.ex` — switched to `Identity` in Phase 6
  - `apps/jarga_web/lib/live/user_live/*.ex` — deleted in Phase 6
  - `apps/jarga/test/support/fixtures/accounts_fixtures.ex` — fixtures
  - Any other references
- [ ] **Decision**: Same as above — deprecate or delete based on remaining usage
- [ ] **GREEN**: Update remaining callers
- [ ] **REFACTOR**: Add `@deprecated` annotation or delete facade

### Phase 8 Validation

- [ ] All callers use `Identity.*` directly or explicitly choose to keep facade
- [ ] No orphaned facade functions
- [ ] `mix compile` succeeds
- [ ] No boundary violations

---

## Phase 9: Move/Update Related Tests ⏸

**Goal**: Ensure test coverage is complete in identity_web and clean up jarga_web tests that tested moved functionality.

### 9.1 Update jarga_web Workspace Tests

- [ ] **Modify** `apps/jarga_web/test/live/app_live/workspaces_test.exs`:
  - **Remove**: "workspaces index page" tests (functionality moved to identity)
  - **Remove**: "new workspace page" tests (functionality moved to identity)
  - **Remove**: "workspace edit page" tests (functionality moved to identity)
  - **Remove**: "workspace deletion" tests (functionality moved to identity)
  - **Remove**: "workspaces index structured event handlers" tests (functionality moved to identity)
  - **Keep**: "workspace show page" tests BUT update:
    - Remove member management tests
    - Remove workspace deletion tests
    - Keep project CRUD tests
    - Keep document CRUD tests
    - Keep agent-related tests
    - Keep real-time event tests for projects/documents/agents
    - Add: test that Show page links to identity settings

### 9.2 Verify Identity Tests Are Comprehensive

- [ ] Verify `apps/identity/test/identity_web/live/workspaces_live/index_test.exs` covers all index scenarios
- [ ] Verify `apps/identity/test/identity_web/live/workspaces_live/new_test.exs` covers form validation + creation
- [ ] Verify `apps/identity/test/identity_web/live/workspaces_live/edit_test.exs` covers edit + validation
- [ ] Verify `apps/identity/test/identity_web/live/workspaces_live/settings_test.exs` covers member management + deletion
- [ ] Verify `apps/identity/test/identity_web/live/dashboard_live_test.exs` covers landing page
- [ ] Verify `apps/identity/test/identity_web/live/profile_live_test.exs` covers profile page
- [ ] Verify `apps/identity/test/identity_web/live/permissions_helper_test.exs` covers workspace permissions

### 9.3 Clean Up Feature Files

- [ ] Evaluate `apps/jarga_web/test/features/workspaces/workspaces.security.feature` — does it test moved functionality?
  - If yes, create equivalent in `apps/identity/test/features/workspaces/`
  - If it tests domain hub (projects/docs within workspace), keep in jarga_web
- [ ] Evaluate `apps/jarga_web/test/features/agents/workspaces.browser.feature` — keep (agents in workspace context)

### Phase 9 Validation

- [ ] Full test suite passes: `mix test`
- [ ] No orphaned test files referencing deleted modules
- [ ] Test coverage for identity_web workspace LiveViews is complete
- [ ] Test coverage for jarga_web domain hub is maintained

---

## Pre-Commit Checkpoint

After all phases:

- [ ] `mix compile --warnings-as-errors` — no warnings
- [ ] `mix boundary` — no violations
- [ ] `mix format` — all files formatted
- [ ] `mix credo --strict` — no issues
- [ ] `mix test` — all tests pass
- [ ] Manual verification: Identity endpoint (port 4001) serves workspace pages
- [ ] Manual verification: jarga_web endpoint (port 4000) `/app/workspaces/:slug` still shows domain hub

---

## File Inventory

### New Files (created)

| File | Phase | Description |
|------|-------|-------------|
| `apps/identity/lib/identity_web/live/workspaces_live/index.ex` | 1 | Workspace list page |
| `apps/identity/lib/identity_web/live/workspaces_live/new.ex` | 1 | Create workspace page |
| `apps/identity/lib/identity_web/live/workspaces_live/edit.ex` | 1 | Edit workspace page |
| `apps/identity/lib/identity_web/live/workspaces_live/settings.ex` | 2 | Workspace settings + members |
| `apps/identity/lib/identity_web/live/permissions_helper.ex` | 2 | Workspace permission helpers |
| `apps/identity/lib/identity_web/live/dashboard_live.ex` | 3 | Landing/dashboard page |
| `apps/identity/lib/identity_web/live/profile_live.ex` | 4 | User profile page |
| `apps/identity/test/identity_web/live/workspaces_live/index_test.exs` | 1 | Tests |
| `apps/identity/test/identity_web/live/workspaces_live/new_test.exs` | 1 | Tests |
| `apps/identity/test/identity_web/live/workspaces_live/edit_test.exs` | 1 | Tests |
| `apps/identity/test/identity_web/live/workspaces_live/settings_test.exs` | 2 | Tests |
| `apps/identity/test/identity_web/live/permissions_helper_test.exs` | 2 | Tests |
| `apps/identity/test/identity_web/live/dashboard_live_test.exs` | 3 | Tests |
| `apps/identity/test/identity_web/live/profile_live_test.exs` | 4 | Tests |

### Modified Files

| File | Phase | Description |
|------|-------|-------------|
| `apps/identity/lib/identity_web/router.ex` | 1,2,3,4 | Add workspace + dashboard + profile routes |
| `apps/jarga_web/lib/live/app_live/workspaces/show.ex` | 5 | Strip identity concerns (~400 lines removed) |
| `apps/jarga_web/lib/live/permissions_helper.ex` | 5 | Remove workspace-level permissions |
| `apps/jarga_web/lib/user_auth.ex` | 6 | Switch from Jarga.Accounts to Identity |
| `apps/jarga_web/lib/router.ex` | 7 | Remove workspace CRUD + auth routes |
| `apps/jarga_web/test/live/app_live/workspaces_test.exs` | 5,9 | Remove moved tests, keep domain hub tests |

### Deleted Files

| File | Phase | Description |
|------|-------|-------------|
| `apps/jarga_web/lib/live/user_live/settings.ex` | 6 | Duplicate of IdentityWeb.SettingsLive |
| `apps/jarga_web/lib/live/user_live/registration.ex` | 6 | Duplicate of IdentityWeb.RegistrationLive |
| `apps/jarga_web/lib/live/user_live/login.ex` | 6 | Duplicate of IdentityWeb.LoginLive |
| `apps/jarga_web/lib/live/user_live/confirmation.ex` | 6 | Duplicate of IdentityWeb.ConfirmationLive |
| `apps/jarga_web/lib/live/api_keys_live.ex` | 6 | Duplicate of IdentityWeb.ApiKeysLive |
| `apps/jarga_web/lib/controllers/user_session_controller.ex` | 6 | Duplicate of IdentityWeb.SessionController |
| `apps/jarga_web/lib/live/app_live/workspaces/index.ex` | 7 | Moved to identity_web |
| `apps/jarga_web/lib/live/app_live/workspaces/new.ex` | 7 | Moved to identity_web |
| `apps/jarga_web/lib/live/app_live/workspaces/edit.ex` | 7 | Moved to identity_web |
| `apps/jarga/lib/workspaces.ex` | 8 | Facade (delete or deprecate) |
| `apps/jarga/lib/accounts.ex` | 8 | Facade (delete or deprecate) |

---

## Testing Strategy

- **Total estimated tests**: ~55-65 new/modified tests
- **Distribution**:
  - Identity Interface (new LiveView tests): ~40 tests
    - WorkspacesLive.Index: ~10 tests
    - WorkspacesLive.New: ~6 tests
    - WorkspacesLive.Edit: ~6 tests
    - WorkspacesLive.Settings: ~14 tests
    - DashboardLive: ~5 tests
    - ProfileLive: ~5 tests
    - PermissionsHelper: ~3 tests
  - jarga_web Interface (updated tests): ~15-20 tests modified
    - Workspaces.Show (trimmed): ~10 tests kept/updated
    - PermissionsHelper (trimmed): ~5 tests updated
  - jarga_web Interface (removed tests): ~25 tests removed
    - Index, New, Edit, Delete, Event handler tests: removed (covered by identity)

## Risks and Mitigations

1. **Cross-app navigation**: Identity LiveViews on port 4001 cannot use `~p"/app/workspaces/..."` (those are jarga_web routes). Links from identity_web to jarga_web's domain hub need full URLs or a shared URL helper. **Mitigation**: Use environment-configured base URLs, or accept that workspace settings and workspace hub are on separate endpoints initially.

2. **Shared cookie authentication**: Both endpoints must share the same session cookie for SSO. Identity already has this configured. Verify `JargaWeb.UserAuth` and `IdentityWeb.Plugs.UserAuth` both read the same session key. **Mitigation**: Both use `:user_token` session key and `Identity.get_user_by_session_token/1`.

3. **Layout differences**: jarga_web's `Layouts.admin` has sidebar, chat panel, notifications. identity_web's `Layouts.app` is minimal. Users navigating between apps will see layout changes. **Mitigation**: This is acceptable — identity pages are account management, not workspace content. Consider updating identity layout in a future ticket to add minimal navigation.

4. **Facade removal timing**: Removing `Jarga.Workspaces` and `Jarga.Accounts` may break `jarga_api` or other consumers. **Mitigation**: Phase 8 explicitly audits all callers before removal. If callers exist, keep facade with deprecation notice.

5. **Feature file ownership**: Some BDD feature files in jarga_web may test workspace CRUD. **Mitigation**: Phase 9 explicitly evaluates and migrates feature files.

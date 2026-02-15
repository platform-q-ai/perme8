# Feature: Workspace UI Migration from JargaWeb to IdentityWeb

## Overview

Migrate workspace management LiveViews (CRUD + member/invite/role management) from `JargaWeb` to `IdentityWeb`. This is the P2 follow-up to the backend workspace migration (documented in `workspace-migration-architectural-plan.md`), which moved all workspace domain logic into the `Identity` bounded context while leaving the UI in `jarga_web`.

The workspace Show page currently mixes two concerns: **workspace management** (settings, members, invites, roles) and **workspace dashboard** (projects, documents, agents). This plan splits them, moving identity-level concerns to `IdentityWeb` and keeping domain-level concerns in `JargaWeb`.

This is a UI reorganization — no backend changes, no database changes, and all existing functionality is preserved.

## Status: Pending

## UI Strategy

- **LiveView coverage**: 4 new LiveViews in IdentityWeb + 1 refactored LiveView in JargaWeb
- **TypeScript needed**: None
- **Layout work**: New `admin` layout in IdentityWeb (extracted from JargaWeb)

## Affected Boundaries

- **Primary context**: `IdentityWeb` (receives workspace CRUD + members LiveViews)
- **Secondary context**: `JargaWeb` (Show page loses member management, gains settings link)
- **Shared concern**: Admin layout (sidebar, breadcrumbs) — extracted to shared pattern

## Current State

### LiveViews to Migrate

| LiveView | Lines | Calls Identity Only? | Migration |
|----------|-------|---------------------|-----------|
| `Workspaces.Index` | 179 | Yes (`Jarga.Workspaces` facade) | Move to IdentityWeb |
| `Workspaces.New` | 97 | Yes (`Jarga.Workspaces` facade) | Move to IdentityWeb |
| `Workspaces.Edit` | 111 | Yes (`Jarga.Workspaces` facade) | Move to IdentityWeb |
| `Workspaces.Show` | 1068 | No (calls Projects, Documents, Agents) | Split — extract members to IdentityWeb |

### The Show Page Problem

`Workspaces.Show` is 1068 lines handling 6 concerns:

1. **Workspace settings** (edit link, delete) — Identity concern
2. **Member management** (invite, role change, remove — modal) — Identity concern
3. **Projects** (list, create — modal + PubSub) — Jarga domain concern
4. **Documents** (list, create — modal + PubSub) — Jarga domain concern
5. **Agents** (list, clone, select — PubSub) — Jarga domain concern
6. **Chat integration** (via `MessageHandlers` macro) — Jarga web concern

**Strategy**: Extract member management into a dedicated IdentityWeb LiveView at `/users/workspaces/:slug/members`. The JargaWeb Show page keeps projects/documents/agents and links to the IdentityWeb members page.

### Layout Challenge

All workspace LiveViews currently use `JargaWeb.Layouts.admin` which provides sidebar navigation, breadcrumbs, chat panel, and notification bell. IdentityWeb has no equivalent — only a simple `app` layout for auth pages.

**Strategy**: Create a minimal `admin` layout in IdentityWeb that provides sidebar + breadcrumbs (matching JargaWeb visual style) but without chat/notifications (those are Jarga concerns). Use shared CSS (both apps already share the same Tailwind/DaisyUI setup via the root layout).

---

## Phase 1: IdentityWeb Admin Layout

Create the admin layout infrastructure needed to host workspace LiveViews in IdentityWeb.

### 1.1 Admin Layout Component

- [ ] **RED**: Write test `apps/identity/test/identity_web/components/layouts_test.exs`
  - Tests: `admin/1` renders sidebar with navigation links
  - Tests: `admin/1` renders breadcrumbs slot
  - Tests: `admin/1` renders flash messages
  - Tests: `admin/1` renders inner content block
  - Tests: `admin/1` highlights active nav item based on current path
- [ ] **GREEN**: Modify `apps/identity/lib/identity_web/components/layouts.ex`
  - Add `admin/1` component with:
    - Sidebar with: Home (`/app`), Workspaces (`/users/workspaces`), Settings (`/users/settings`) links
    - Breadcrumbs slot (`:breadcrumbs`)
    - Flash group
    - `@current_scope` assign for user display
  - Sidebar links to JargaWeb routes (`/app`, `/app/agents`) use full URLs (cross-app navigation)
  - Sidebar links to IdentityWeb routes (`/users/workspaces`, `/users/settings`) use verified routes
- [ ] **REFACTOR**: Verify visual consistency with JargaWeb admin layout (same sidebar width, colors, typography)

### 1.2 Add Missing CoreComponents

- [ ] **RED**: Verify existing component tests still pass after additions
- [ ] **GREEN**: Add to `apps/identity/lib/identity_web/components/core_components.ex`:
  - `kebab_menu/1` component (copy from JargaWeb — used by workspace Show/members)
  - `breadcrumbs/1` component (for layout breadcrumb rendering)
- [ ] **REFACTOR**: Ensure no duplication of components that already exist in IdentityWeb

### Phase 1 Validation

- [ ] `admin` layout renders correctly with sidebar, breadcrumbs, and content
- [ ] Existing IdentityWeb LiveViews (settings, API keys) are unaffected
- [ ] `mix compile --warnings-as-errors` passes

---

## Phase 2: Workspace Index, New, Edit LiveViews

Move the three simple workspace CRUD LiveViews. These only call `Identity` (via the `Jarga.Workspaces` facade) and have no cross-context dependencies.

### 2.1 Workspace Index LiveView

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/workspaces/index_live_test.exs`
  - Tests: Redirects unauthenticated users to login
  - Tests: Lists all workspaces for authenticated user
  - Tests: Shows empty state when user has no workspaces
  - Tests: Shows "New Workspace" button
  - Tests: Links to workspace show page
  - Tests: Real-time update when workspace invitation received (PubSub)
  - Tests: Real-time update when workspace removed (PubSub)
  - Tests: Real-time update when workspace name changed (PubSub)
- [ ] **GREEN**: Create `apps/identity/lib/identity_web/live/workspaces/index_live.ex`
  - Module: `IdentityWeb.Workspaces.IndexLive`
  - `use IdentityWeb, :live_view`
  - Replace `Jarga.Workspaces` calls with `Identity` calls directly:
    - `Identity.list_workspaces_for_user/1`
  - Use `IdentityWeb.Layouts.admin` layout
  - Subscribe to `"user:#{user.id}"` and `"workspace:#{workspace.id}"` PubSub topics
  - PubSub server: Use `Jarga.PubSub` (shared PubSub — both apps use the same OTP app)
  - Handle same PubSub messages as current implementation
- [ ] **REFACTOR**: Remove `JargaWeb.ChatLive.MessageHandlers` import (no chat in IdentityWeb)

### 2.2 Workspace New LiveView

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/workspaces/new_live_test.exs`
  - Tests: Renders workspace creation form
  - Tests: Creates workspace on valid submit, redirects to workspace show
  - Tests: Shows validation errors on invalid submit
  - Tests: Cancel navigates back to index
- [ ] **GREEN**: Create `apps/identity/lib/identity_web/live/workspaces/new_live.ex`
  - Module: `IdentityWeb.Workspaces.NewLive`
  - Replace `Jarga.Workspaces` calls with `Identity`:
    - `Identity.change_workspace/0`
    - `Identity.create_workspace/2`
  - Use `IdentityWeb.Layouts.admin` layout
  - On success, redirect to `/users/workspaces` (IdentityWeb index)
- [ ] **REFACTOR**: Remove chat message handlers

### 2.3 Workspace Edit LiveView

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/workspaces/edit_live_test.exs`
  - Tests: Renders workspace edit form with current values
  - Tests: Updates workspace on valid submit, redirects to show
  - Tests: Shows validation errors on invalid submit
  - Tests: Cancel navigates back to show page
  - Tests: Non-admin/non-owner cannot access edit page
- [ ] **GREEN**: Create `apps/identity/lib/identity_web/live/workspaces/edit_live.ex`
  - Module: `IdentityWeb.Workspaces.EditLive`
  - Replace `Jarga.Workspaces` calls with `Identity`:
    - `Identity.get_workspace_by_slug!/2`
    - `Identity.change_workspace/1`
    - `Identity.update_workspace/3`
  - Use `IdentityWeb.Layouts.admin` layout
  - On success, redirect to JargaWeb show page (`/app/workspaces/:slug`) — since the dashboard stays in JargaWeb
- [ ] **REFACTOR**: Remove chat message handlers

### Phase 2 Validation

- [ ] All new IdentityWeb workspace LiveView tests pass
- [ ] `mix compile --warnings-as-errors` passes
- [ ] No boundary violations

---

## Phase 3: Members Management LiveView

Extract the member management modal from `Workspaces.Show` into a dedicated LiveView page in IdentityWeb.

### 3.1 Members LiveView

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/workspaces/members_live_test.exs`
  - Tests: Renders workspace name and member list
  - Tests: Shows invite form for admin/owner
  - Tests: Hides invite form for guest/member
  - Tests: Successfully invites a new member
  - Tests: Shows error when inviting already-member user
  - Tests: Shows error for invalid role
  - Tests: Shows member with role select dropdown for admin/owner
  - Tests: Hides role select for non-admin/non-owner
  - Tests: Changes member role successfully
  - Tests: Shows error when changing owner role
  - Tests: Shows remove button for non-owner members
  - Tests: Removes member successfully
  - Tests: Shows error when removing owner
  - Tests: Guest cannot access members page (redirect or 403)
  - Tests: Real-time update when member joins (PubSub)
  - Tests: Real-time update when invitation declined (PubSub)
  - Tests: Shows pending badge for pending invitations
  - Tests: Shows active badge for accepted members
  - Tests: Workspace delete button for owners
  - Tests: No delete button for non-owners
- [ ] **GREEN**: Create `apps/identity/lib/identity_web/live/workspaces/members_live.ex`
  - Module: `IdentityWeb.Workspaces.MembersLive`
  - All calls go through `Identity` directly:
    - `Identity.get_workspace_and_member_by_slug/2`
    - `Identity.list_members/1`
    - `Identity.invite_member/4`
    - `Identity.change_member_role/4`
    - `Identity.remove_member/3`
    - `Identity.delete_workspace/2`
  - Permission checks use `Identity.Domain.Policies.WorkspacePermissionsPolicy` directly (no PermissionsHelper dependency)
  - Subscribe to `"workspace:#{workspace.id}"` for `:member_joined` and `:invitation_declined`
  - Use `IdentityWeb.Layouts.admin` layout
  - Breadcrumbs: Home > Workspaces > {workspace name} > Members
  - Full page layout (not a modal) with:
    - Invite form section (for admin/owner)
    - Members table with role dropdowns and remove buttons
    - Workspace settings section (edit link, delete button for owner)
- [ ] **REFACTOR**: Verify all permission gates match current behavior

### 3.2 Workspace PermissionsHelper (IdentityWeb)

- [ ] **RED**: Write test `apps/identity/test/identity_web/live/permissions_helper_test.exs`
  - Tests: `can_edit_workspace?/1` returns true for owner and admin, false for member and guest
  - Tests: `can_delete_workspace?/1` returns true for owner only
  - Tests: `can_manage_members?/1` returns true for owner and admin
  - Tests: `can_invite_member?/1` returns true for owner and admin
- [ ] **GREEN**: Create `apps/identity/lib/identity_web/live/permissions_helper.ex`
  - Module: `IdentityWeb.Live.PermissionsHelper`
  - Only workspace permissions (no project/document/agent permissions)
  - Uses `Identity.Domain.Policies.WorkspacePermissionsPolicy.can?/3` directly
  - Functions: `can_edit_workspace?/1`, `can_delete_workspace?/1`, `can_manage_members?/1`, `can_invite_member?/1`
- [ ] **REFACTOR**: Verify this is a strict subset of `JargaWeb.Live.PermissionsHelper`

### Phase 3 Validation

- [ ] Members LiveView renders correctly with full member management functionality
- [ ] Permission gates work correctly for all 4 roles
- [ ] PubSub real-time updates work
- [ ] `mix compile --warnings-as-errors` passes
- [ ] No boundary violations

---

## Phase 4: Router & Navigation

Wire up the new IdentityWeb routes and update navigation across both apps.

### 4.1 IdentityWeb Router Updates

- [ ] **RED**: Verify new routes are accessible in tests (already covered by LiveView tests)
- [ ] **GREEN**: Modify `apps/identity/lib/identity_web/router.ex`
  - Add new `live_session :workspace_management` within the authenticated scope:
    ```elixir
    live_session :workspace_management,
      on_mount: [{IdentityWeb.Plugs.UserAuth, :require_authenticated}] do
      live "/users/workspaces", Workspaces.IndexLive, :index
      live "/users/workspaces/new", Workspaces.NewLive, :new
      live "/users/workspaces/:workspace_slug/edit", Workspaces.EditLive, :edit
      live "/users/workspaces/:workspace_slug/members", Workspaces.MembersLive, :members
    end
    ```
  - Keep existing authenticated routes untouched
- [ ] **REFACTOR**: Verify no route conflicts with existing routes

### 4.2 Update JargaWeb Router (Remove Old Routes)

- [ ] **RED**: Verify JargaWeb tests that navigate to workspace CRUD pages are updated
- [ ] **GREEN**: Modify `apps/jarga_web/lib/router.ex`
  - Remove from `live_session :app`:
    - `live("/workspaces", AppLive.Workspaces.Index, :index)`
    - `live("/workspaces/new", AppLive.Workspaces.New, :new)`
    - `live("/workspaces/:workspace_slug/edit", AppLive.Workspaces.Edit, :edit)`
  - Keep: `live("/workspaces/:slug", AppLive.Workspaces.Show, :show)` — the dashboard page stays
  - Keep: All project/document routes nested under `/workspaces/:workspace_slug/`
- [ ] **REFACTOR**: Verify no broken links

### 4.3 Update Navigation Links

- [ ] **RED**: Verify navigation works across both apps
- [ ] **GREEN**: Update the following:
  - **IdentityWeb admin layout sidebar**: "Workspaces" links to `/users/workspaces`
  - **JargaWeb admin layout sidebar**: "Workspaces" links to `/users/workspaces` (cross-app, full URL)
  - **JargaWeb Workspaces.Show**: Replace "Edit Workspace" kebab link with `/users/workspaces/:slug/edit`
  - **JargaWeb Workspaces.Show**: Replace "Manage Members" modal trigger with link to `/users/workspaces/:slug/members`
  - **JargaWeb Workspaces.Show**: Remove members modal markup entirely (~190 lines)
  - **JargaWeb Workspaces.Show**: Remove member-related `handle_event` callbacks (`invite_member`, `change_role`, `remove_member`, `show_members_modal`, `hide_members_modal`)
  - **JargaWeb Workspaces.Show**: Remove member-related `handle_info` callbacks (`:member_joined`, `:invitation_declined`)
  - **JargaWeb Workspaces.Show**: Remove `members`, `show_members_modal`, `invite_form` assigns
  - **IdentityWeb Workspaces.MembersLive**: "Back to Workspace" links to `/app/workspaces/:slug` (cross-app)
  - **IdentityWeb Workspaces.IndexLive**: Workspace cards link to `/app/workspaces/:slug` (cross-app, dashboard)
- [ ] **REFACTOR**: Verify all cross-app links use full URLs (not verified routes from the wrong app)

### 4.4 Redirect Old Routes (Optional)

- [ ] **GREEN**: Add redirects in JargaWeb router for old workspace CRUD URLs:
  - `GET /app/workspaces` → redirect to `/users/workspaces`
  - `GET /app/workspaces/new` → redirect to `/users/workspaces/new`
  - `GET /app/workspaces/:slug/edit` → redirect to `/users/workspaces/:slug/edit`
  - These prevent broken bookmarks/links during transition

### Phase 4 Validation

- [ ] All IdentityWeb workspace routes are accessible
- [ ] JargaWeb workspace Show page still works (dashboard with projects/documents/agents)
- [ ] Cross-app navigation works (IdentityWeb ↔ JargaWeb)
- [ ] Old URLs redirect correctly
- [ ] `mix compile --warnings-as-errors` passes

---

## Phase 5: Cleanup & Test Migration

Remove old LiveViews from JargaWeb, migrate tests, and slim down the Show page.

### 5.1 Remove Old JargaWeb Workspace LiveViews

- [ ] **RED**: Verify `mix compile` passes after removal
- [ ] **GREEN**: Delete the following files from `apps/jarga_web/`:
  - `lib/live/app_live/workspaces/index.ex`
  - `lib/live/app_live/workspaces/new.ex`
  - `lib/live/app_live/workspaces/edit.ex`
- [ ] **REFACTOR**: Remove empty directories

### 5.2 Slim Down JargaWeb Workspaces.Show

- [ ] **RED**: Verify existing Show tests that cover projects/documents/agents still pass
- [ ] **GREEN**: Modify `apps/jarga_web/lib/live/app_live/workspaces/show.ex`
  - Remove all member management code:
    - Remove `show_members_modal`, `hide_members_modal` event handlers
    - Remove `invite_member`, `change_role`, `remove_member` event handlers
    - Remove `:member_joined`, `:invitation_declined` info handlers
    - Remove `members`, `show_members_modal`, `invite_form` assigns from mount
    - Remove members modal markup from template (~190 lines)
    - Remove `import JargaWeb.Live.PermissionsHelper` for `can_manage_members?` (keep for project/document permissions)
  - Update kebab menu:
    - "Edit Workspace" → external link to `/users/workspaces/:slug/edit`
    - "Manage Members" → external link to `/users/workspaces/:slug/members`
    - "Delete Workspace" → external link to `/users/workspaces/:slug/members` (delete is on members/settings page now)
  - Expected reduction: ~1068 lines → ~600 lines
- [ ] **REFACTOR**: Verify Show page still handles all project/document/agent concerns correctly

### 5.3 Migrate Workspace LiveView Tests

- [ ] **RED**: Verify new test paths exist and run
- [ ] **GREEN**: Move/update tests:
  - `apps/jarga_web/test/live/app_live/workspaces_test.exs`:
    - Move workspace index tests → already covered in 2.1 test
    - Move workspace new tests → already covered in 2.2 test
    - Move workspace edit tests → already covered in 2.3 test
    - Keep project/document CRUD tests in JargaWeb (they test the Show page)
    - Keep workspace deletion test in JargaWeb (if delete stays on Show) or move to IdentityWeb
  - `apps/jarga_web/test/live/app_live/workspaces/show_test.exs`:
    - Move all member management tests → already covered in 3.1 test
    - Keep project/document/agent tests (they test Show page)
    - Update remaining tests to reflect removed member modal
- [ ] **REFACTOR**: Ensure no orphaned test files

### 5.4 Update JargaWeb PermissionsHelper

- [ ] **RED**: Verify existing tests pass
- [ ] **GREEN**: Modify `apps/jarga_web/lib/live/permissions_helper.ex`
  - Remove `can_manage_members?/1` if no longer used in JargaWeb
  - Keep all project/document/agent permission functions
  - Keep workspace permission functions that are still used (`can_edit_workspace?`, `can_delete_workspace?` for kebab menu)
- [ ] **REFACTOR**: Verify no unused imports

### 5.5 Update IdentityWeb Boundary

- [ ] **RED**: Verify `mix compile --warnings-as-errors` passes
- [ ] **GREEN**: Modify `apps/identity/lib/identity_web.ex`
  - Verify boundary `deps` includes `Identity` (already does)
  - Remove `Jarga.Workspaces` from deps if no longer needed (calls go to `Identity` directly)
- [ ] **REFACTOR**: Verify boundary is clean

### Phase 5 Validation

- [ ] Old JargaWeb workspace CRUD LiveViews are deleted
- [ ] JargaWeb Show page is slimmed to ~600 lines (projects/documents/agents only + settings links)
- [ ] All tests pass across both apps
- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix test` passes at umbrella root
- [ ] No boundary violations

---

## Pre-Commit Checkpoint

After all phases complete:

- [ ] `mix precommit` passes (compilation, formatting, Credo, tests, boundary)
- [ ] `mix boundary` shows clean architecture (verified via `mix compile --warnings-as-errors`)
- [ ] `mix test --cover` shows no drop in test coverage

---

## Testing Strategy

### Test Distribution

| Layer | Location | Estimated Tests | Async |
|-------|----------|----------------|-------|
| Layouts | `apps/identity/test/identity_web/components/layouts_test.exs` | 5 | Yes |
| Index LiveView | `apps/identity/test/identity_web/live/workspaces/index_live_test.exs` | 8 | No (ConnCase) |
| New LiveView | `apps/identity/test/identity_web/live/workspaces/new_live_test.exs` | 4 | No (ConnCase) |
| Edit LiveView | `apps/identity/test/identity_web/live/workspaces/edit_live_test.exs` | 5 | No (ConnCase) |
| Members LiveView | `apps/identity/test/identity_web/live/workspaces/members_live_test.exs` | 18 | No (ConnCase) |
| PermissionsHelper | `apps/identity/test/identity_web/live/permissions_helper_test.exs` | 4 | Yes |
| Updated JargaWeb Show | `apps/jarga_web/test/live/app_live/workspaces/show_test.exs` | ~15 (reduced) | No (ConnCase) |

**Total estimated new tests**: ~44
**Total removed from JargaWeb**: ~15 (moved to IdentityWeb)

### Test Principles

1. **LiveView tests** (`ConnCase`): Full integration with `Phoenix.LiveViewTest`
2. **Permission tests** (`async: true`): Pure policy function checks
3. **Cross-app navigation**: Verify links render correct URLs (don't follow cross-app links in LiveView tests)

---

## File Inventory Summary

### New Files in `apps/identity/` (~8 source + 6 test files)

#### Source Files
```
lib/identity_web/live/workspaces/index_live.ex
lib/identity_web/live/workspaces/new_live.ex
lib/identity_web/live/workspaces/edit_live.ex
lib/identity_web/live/workspaces/members_live.ex
lib/identity_web/live/permissions_helper.ex
```

#### Modified Files in `apps/identity/`
```
lib/identity_web/router.ex                          # Add workspace routes
lib/identity_web/components/layouts.ex               # Add admin layout
lib/identity_web/components/core_components.ex       # Add kebab_menu, breadcrumbs
lib/identity_web.ex                                  # Update boundary deps if needed
```

### Deleted Files from `apps/jarga_web/` (3 files)
```
lib/live/app_live/workspaces/index.ex
lib/live/app_live/workspaces/new.ex
lib/live/app_live/workspaces/edit.ex
```

### Modified Files in `apps/jarga_web/` (~4 files)
```
lib/router.ex                                        # Remove old workspace CRUD routes, add redirects
lib/live/app_live/workspaces/show.ex                 # Remove member management (~400 lines removed)
lib/components/layouts.ex                            # Update Workspaces sidebar link
lib/live/permissions_helper.ex                       # Remove unused member permission functions
```

---

## Key Design Decisions

### 1. Why not move Show entirely?

The Show page is a **workspace dashboard** displaying projects, documents, and agents — all Jarga domain concerns. Moving it to IdentityWeb would require IdentityWeb to depend on `Jarga.Projects`, `Jarga.Documents`, and `Jarga.Agents`, which violates the dependency direction (Identity should not depend on Jarga domain contexts).

### 2. Why a separate Members page instead of keeping the modal?

The modal pattern tightly couples member management to the Show page. A dedicated page:
- Has a clear URL (`/users/workspaces/:slug/members`) that can be bookmarked/shared
- Can be tested independently
- Lives cleanly in IdentityWeb without dragging in Jarga dependencies
- Follows the pattern of other settings pages (user settings, API keys)

### 3. Why `/users/workspaces/` route prefix?

Matches the existing IdentityWeb convention (`/users/settings`, `/users/settings/api-keys`). All identity-owned authenticated routes live under `/users/`.

### 4. Cross-app navigation approach

Links between IdentityWeb and JargaWeb use full URLs (not verified routes from the other app). Phoenix verified routes are scoped to a single endpoint, so cross-app links must be plain strings or constructed from the other app's endpoint URL.

### 5. PubSub sharing

Both apps share `Jarga.PubSub` as the PubSub server (configured via the shared OTP app). IdentityWeb LiveViews subscribe to the same topics and handle the same message formats. No PubSub changes are needed.

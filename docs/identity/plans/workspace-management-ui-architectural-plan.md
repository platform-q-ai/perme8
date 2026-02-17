# Feature: Workspace Management UI — Invites, Roles & Members

## Overview

The workspace management UI LiveView code already exists across 4 files in `apps/jarga_web/lib/live/app_live/workspaces/`. The domain, application, and infrastructure layers are fully built. **24 BDD browser scenarios** have been written across 3 feature files. This plan focuses on gap analysis: running existing BDD tests, identifying failures, and fixing/implementing whatever is needed to make all 24 scenarios pass.

## UI Strategy

- **LiveView coverage**: 100% — all UI is LiveView
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context**: `Jarga.Workspaces` (facade) -> `Identity` (implementation)
- **Dependencies**: `Jarga.Projects`, `Jarga.Documents`, `Agents` (all via public API)
- **Exported schemas**: None new needed
- **New context needed?**: No — existing contexts are sufficient

## Existing Implementation Inventory

### LiveView Files (all exist)
| File | Status | Notes |
|------|--------|-------|
| `apps/jarga_web/lib/live/app_live/workspaces/index.ex` | Complete | Card grid, empty state, PubSub, New Workspace link |
| `apps/jarga_web/lib/live/app_live/workspaces/new.ex` | Complete | Form with validation, `phx-change` + `phx-submit` |
| `apps/jarga_web/lib/live/app_live/workspaces/edit.ex` | Complete | Pre-populated form, update + redirect |
| `apps/jarga_web/lib/live/app_live/workspaces/show.ex` | Complete | Kebab menu, members modal, projects/docs/agents sections, invite/role/remove events |
| `apps/jarga_web/lib/live/permissions_helper.ex` | Complete | All permission checks for workspace/member management |

### Existing LiveView Unit Tests
| File | Tests | Notes |
|------|-------|-------|
| `apps/jarga_web/test/live/app_live/workspaces_test.exs` | ~30 | Index, New, Show, Edit, Delete, PubSub |
| `apps/jarga_web/test/live/app_live/workspaces/show_test.exs` | ~25 | Members modal, docs section, PubSub, permissions, cloning |

### BDD Feature Files (24 scenarios total)
| File | Scenarios | Coverage |
|------|-----------|----------|
| `crud.browser.feature` | 7 | Create, Edit (admin, member, guest), Delete (owner, admin), Validation |
| `members.browser.feature` | 10 | Open modal, Invite, Member/Guest restrictions, Role change, Owner badge, Remove, Owner protection, Modal close, Non-member access |
| `navigation.browser.feature` | 7 | Detail view, Guest limitations, Member actions, Workspace list, Card navigation, Empty state, New Workspace link |

### Seed Data (exo_seeds_web.exs)
| User | Email | Role in Product Team |
|------|-------|---------------------|
| Alice | alice@example.com | Owner |
| Bob | bob@example.com | Admin |
| Charlie | charlie@example.com | Member |
| Diana | diana@example.com | Guest |
| Eve | eve@example.com | Non-member |
| Frank | frank@example.com | Member (for removal test) |

Additional workspaces: `engineering` (alice owner), `throwaway-workspace` (alice owner, for deletion test).

### Config Variables (exo-bdd-jarga-web.config.ts)
All required variables are defined: `ownerEmail`, `adminEmail`, `memberEmail`, `guestEmail`, `nonMemberEmail`, `removableMemberEmail`, `productTeamSlug`, `engineeringSlug`, `throwawayWorkspaceSlug`.

---

## Gap Analysis

After thoroughly reading ALL existing code, BDD scenarios, seed data, and config files, here is the detailed assessment:

### Code <-> BDD Alignment Analysis

#### CRUD Feature (crud.browser.feature) - 7 scenarios

| # | Scenario | Expected by BDD | Current Code | Gap? |
|---|----------|----------------|--------------|------|
| 1 | Owner creates workspace | Fill form, submit, see flash + name | `new.ex`: form, `phx-change="validate"`, `phx-submit="save"`, flash, redirect | **Likely pass** |
| 2 | Admin edits workspace | Navigate to edit, update, flash | `edit.ex`: pre-populated form, save, flash, redirect to show | **Likely pass** |
| 3 | Member cannot edit | No kebab menu visible | `show.ex`: kebab wrapped in `can_edit_workspace? \|\| can_manage_members? \|\| can_delete_workspace?`. Member has none of these. | **Likely pass** |
| 4 | Guest cannot edit | No kebab menu visible | Same as member | **Likely pass** |
| 5 | Owner deletes workspace | Click kebab, confirm, flash | `show.ex`: `delete_workspace` event, confirm dialog, flash | **Likely pass** |
| 6 | Admin cannot delete | Kebab visible but no "Delete Workspace" | `show.ex`: `:if={can_delete_workspace?(@current_member)}` — admin can't delete | **Likely pass** |
| 7 | Invalid creation shows errors | Empty name -> "can't be blank" | `new.ex`: `phx-change="validate"` with blank name check, `phx-submit="save"` returns changeset errors | **Potential issue**: BDD clicks "Create Workspace" button without filling name. The `phx-change` validation fires on input change. Need to verify the submit path handles blank name via changeset. |

#### Members Feature (members.browser.feature) - 10 scenarios

| # | Scenario | Expected by BDD | Current Code | Gap? |
|---|----------|----------------|--------------|------|
| 1 | Admin opens members modal | Click kebab -> "Manage Members" -> modal opens, see owner email + "Owner" | `show.ex`: `show_members_modal` loads members, shows modal | **Likely pass** |
| 2 | Admin invites new member | Fill email, select role, click "Invite" -> see email in list | `show.ex`: `invite_member` event handles it | **Likely pass** |
| 3 | Member can't see Manage Members | No kebab menu for member | Kebab hidden for member role | **Likely pass** |
| 4 | Guest can't see Manage Members | No kebab menu for guest | Kebab hidden for guest role | **Likely pass** |
| 5 | Admin changes member role | Select new role from `select[data-email='...']` -> flash | `show.ex`: `change_role` event with `phx-change` on form | **Potential issue**: The BDD does `I select "admin" from "select[data-email='${memberEmail}']"`. The `<form phx-change="change_role">` wraps the select. The `change_role` event expects `%{"email" => email, "value" => new_role}`. The hidden input provides `email`, and the select provides `value`. Should work. |
| 6 | Owner role displayed as badge not select | `select[data-email='${ownerEmail}']` should not exist, see "Owner" text | `show.ex`: owner gets badge, not select | **Likely pass** |
| 7 | Admin removes member | Click `button[phx-value-email='...']` with confirm -> flash | `show.ex`: `remove_member` event | **Potential issue**: The BDD expects `button[phx-value-email='${removableMemberEmail}']`. The `.button` component uses `{@rest}` for global attrs, and `phx-value-email={member.email}` is passed. Need to verify this renders as `phx-value-email="frank@example.com"` in the HTML. |
| 8 | Owner cannot be removed | `button[phx-value-email='${ownerEmail}']` should not exist | `show.ex`: owner row has no remove button (`:if={member.role != :owner}`) | **Likely pass** |
| 9 | Close modal with Done | Click "Done" -> modal hidden, `#members-list` gone | `show.ex`: `hide_members_modal` sets `show_members_modal: false` | **Likely pass** |
| 10 | Non-member cannot access workspace | Navigate -> redirect to workspaces, see "Workspace not found" | `show.ex`: mount returns `:workspace_not_found`, redirect with flash | **Likely pass** |

#### Navigation Feature (navigation.browser.feature) - 7 scenarios

| # | Scenario | Expected by BDD | Current Code | Gap? |
|---|----------|----------------|--------------|------|
| 1 | Member views workspace details | See name, "Projects", "Documents", "Agents" | `show.ex`: all sections rendered | **Likely pass** |
| 2 | Guest limited actions | See name, no "New Project", no "New Document", no "Manage Members" | `show.ex`: permission-gated buttons | **Likely pass** |
| 3 | Member can see project/document actions | See "New Project", "New Document" | `show.ex`: member role allows create | **Likely pass** |
| 4 | Workspace list shows all user workspaces | See "Product Team", "Engineering", links with correct slugs | `index.ex`: lists all workspaces | **Likely pass** |
| 5 | Clicking workspace card navigates | Click "Product Team" link -> navigate to workspace | `index.ex`: cards are links | **Likely pass** |
| 6 | Empty workspace list | See "No workspaces yet", "Create your first workspace to get started" | `index.ex`: empty state with exact text | **Likely pass** |
| 7 | New Workspace link available | `a[href='/app/workspaces/new']` exists, see "New Workspace" | `index.ex`: button with navigate to `~p"/app/workspaces/new"` | **Potential issue**: The BDD checks for `a[href='/app/workspaces/new']`. The index uses `<.button variant="primary" size="sm" navigate={~p"/app/workspaces/new"}>`. When `navigate` is set, `.button` renders as a `<.link>` which becomes `<a>`. Should work. |

### Identified Risk Areas

1. **Validation on create (crud #7)**: The BDD clears the name field then clicks "Create Workspace" button. If the `phx-submit="save"` handles an empty name by returning changeset errors, it should show "can't be blank". The code path: `Workspaces.create_workspace(user, %{"name" => ""})` should return `{:error, changeset}`. The test expects to remain on `/workspaces/new`. Need to verify the changeset error handling renders inline errors properly.

2. **Role change event (members #5)**: The `phx-change="change_role"` on the form will fire when the select changes. The params structure must be `%{"email" => ..., "value" => ...}`. Since `email` comes from a hidden input and `value` from the select's name, this should match.

3. **Remove button selector (members #7)**: The BDD uses `button[phx-value-email='${removableMemberEmail}']`. The `.button` component's `:global` rest passes through `phx-value-email`. Need to verify the output HTML has this attribute on the `<button>` element.

4. **Seed data stability**: The tests rely on specific seed data. If seeds fail to create properly (e.g., `frank@example.com` as member of product-team), multiple scenarios will fail.

5. **`Agents` module availability**: `show.ex` calls `Agents.list_workspace_available_agents/2` in mount. If the Agents app isn't properly started in test, mount will fail for all workspace show page BDD tests.

---

## Phase 0: Baseline — Run All BDD Tests

### 0.1 Run All 24 BDD Scenarios
- [ ] **RUN**: Execute all workspace BDD tests to establish baseline
  ```bash
  mix exo_test --name jarga-web --adapter browser
  ```
- [ ] **DOCUMENT**: Record which scenarios pass and which fail
- [ ] **CATEGORIZE**: Group failures by root cause (seed data, selector mismatch, missing feature, timing)

### 0.2 Run Seed Script Independently
- [ ] **RUN**: Verify seed data creates cleanly
  ```bash
  MIX_ENV=test mix run --no-start apps/jarga/priv/repo/exo_seeds_web.exs
  ```
- [ ] **VERIFY**: All 6 users, 3 workspaces, 5 memberships created without errors

---

## Phase 1: Fix Seed Data & Configuration Issues (if any)

### 1.1 Seed Data Completeness
- [ ] **RED**: If BDD tests fail because expected data is missing (e.g., frank not in product-team, throwaway workspace missing)
- [ ] **GREEN**: Fix `apps/jarga/priv/repo/exo_seeds_web.exs` to ensure:
  - frank@example.com is member of product-team (confirmed: line 227 adds frank as `:member`)
  - throwaway-workspace exists with alice as owner (confirmed: line 207)
  - engineering workspace exists with alice as owner (confirmed: line 195)
- [ ] **REFACTOR**: Ensure seed script is idempotent (already TRUNCATES first)

### 1.2 Config Variable Verification
- [ ] **RED**: If BDD interpolation fails for any `${variable}`
- [ ] **GREEN**: Fix `apps/jarga_web/test/exo-bdd-jarga-web.config.ts` to match seed data exactly
- [ ] **REFACTOR**: Ensure all variable names match what feature files reference

---

## Phase 2: Fix LiveView Code Gaps (phoenix-tdd)

Based on the code review, the implementation looks largely complete. This phase addresses the specific risk areas and any failures discovered in Phase 0.

### 2.1 Workspace Create Validation (crud.browser.feature scenario 7)
- [ ] **RED**: Write unit test `apps/jarga_web/test/live/app_live/workspaces/new_validation_test.exs`
  - Test: Submit form with empty name via `phx-submit` (not just `phx-change`)
  - Test: Verify "can't be blank" appears in rendered HTML
  - Test: Verify URL remains on `/workspaces/new` (no redirect)
- [ ] **GREEN**: If test fails, fix `apps/jarga_web/lib/live/app_live/workspaces/new.ex`
  - Ensure `handle_event("save", ...)` with empty name returns changeset with errors
  - The current code calls `Workspaces.create_workspace(user, workspace_params)` which should return `{:error, changeset}` for blank name
  - If the changeset doesn't propagate to the form correctly, fix the error handling branch
- [ ] **REFACTOR**: Consolidate duplicate validation logic between `phx-change` and `phx-submit` handlers if both perform identical changeset validation

### 2.2 Members Modal — Invite Flow (members.browser.feature scenario 2)
- [ ] **RED**: Write unit test for invite flow end-to-end
  - Test: Open members modal -> fill email + role -> submit -> verify new member appears in list
  - Test: Verify flash message "Invitation sent via email"
  - Test: Verify invite form resets after successful invite
- [ ] **GREEN**: If test fails, fix `apps/jarga_web/lib/live/app_live/workspaces/show.ex`
  - Verify `invite_member` event correctly handles the form params
  - BDD submits `[name='email']` and `[name='role']` — these come as top-level params: `%{"email" => "...", "role" => "..."}`
  - Current code: `handle_event("invite_member", %{"email" => email, "role" => role}, socket)` — matches correctly
- [ ] **REFACTOR**: Verify invite form field names (`email`, `role`) align with BDD selectors and add comments documenting the expected params structure

### 2.3 Members Modal — Role Change (members.browser.feature scenario 5)
- [ ] **RED**: Write unit test for role change via select dropdown
  - Test: Open modal, verify select exists with `data-email` attribute
  - Test: Change select value -> verify flash "Member role updated successfully"
  - Test: Verify member list reloads with new role
- [ ] **GREEN**: If test fails, fix the `change_role` event handling
  - The `<form phx-change="change_role">` wraps a hidden `email` input and a `value` select
  - When the select changes, params are: `%{"email" => "...", "value" => "admin"}`
  - Current handler: `handle_event("change_role", %{"email" => email, "value" => new_role}, socket)` — matches

### 2.4 Members Modal — Remove Button Selector (members.browser.feature scenarios 7 & 8)
- [ ] **RED**: Write unit test verifying remove button has `phx-value-email` attribute
  - Test: Open modal, render HTML, verify `button[phx-value-email="frank@example.com"]` exists
  - Test: Verify `button[phx-value-email="alice@example.com"]` does NOT exist (owner)
- [ ] **GREEN**: If test fails, fix `show.ex` template
  - The `.button` component uses `:global` rest which passes through `phx-value-email`
  - The `phx-click="remove_member"` and `phx-value-email={member.email}` should render correctly
  - If `.button` component doesn't pass through `phx-value-email`, may need to use raw `<button>` element

### 2.5 Kebab Menu Visibility (crud & members scenarios for member/guest)
- [ ] **RED**: Write unit test confirming kebab menu is hidden for member/guest roles
  - Test: Log in as member, navigate to workspace show, verify `button[aria-label='Actions menu']` is NOT present
  - Test: Same for guest role
- [ ] **GREEN**: If test fails, fix permission gating in `show.ex` template
  - The kebab is wrapped in `if can_edit_workspace? || can_manage_members? || can_delete_workspace?`
  - For member/guest, all three should return false
  - `can_manage_members?` checks `member.role in [:admin, :owner]` — correct

### 2.6 Admin Delete Restriction (crud.browser.feature scenario 6)
- [ ] **RED**: Write unit test confirming admin sees Edit + Manage Members but NOT Delete in kebab
  - Test: Log in as admin, navigate to workspace show, click kebab, verify "Edit Workspace" visible
  - Test: Verify "Manage Members" visible
  - Test: Verify "Delete Workspace" NOT visible
- [ ] **GREEN**: If test fails, fix `show.ex` template conditional rendering
  - `can_delete_workspace?` calls `WorkspacePermissionsPolicy.can?(member.role, :delete_workspace)` — only owner should pass

### 2.7 Non-Member Access Control (members.browser.feature scenario 10)
- [ ] **RED**: Write unit test for non-member redirect
  - Test: Log in as eve (non-member), navigate to `/app/workspaces/product-team`
  - Test: Verify redirect to `/app/workspaces` with flash "Workspace not found"
- [ ] **GREEN**: Already handled in `show.ex` mount:
  ```elixir
  {:error, :workspace_not_found} ->
    {:ok, socket |> put_flash(:error, "Workspace not found") |> push_navigate(to: ~p"/app/workspaces")}
  ```

### Phase 2 Validation
- [ ] All new unit tests pass: `mix test apps/jarga_web/test/live/app_live/workspaces/`
- [ ] Full test suite passes: `mix test`
- [ ] No boundary violations: `mix boundary`

---

## Phase 3: BDD Integration Fixes (phoenix-tdd)

This phase addresses any remaining BDD failures after Phase 2 fixes. The fixes here are likely timing, selector, or rendering issues specific to browser automation.

### 3.1 Timing Issues — Network Idle Waits
- [ ] **RED**: If BDD tests fail due to LiveView not being mounted when assertions run
- [ ] **GREEN**: The feature files already include `I wait for network idle` after navigation. If specific scenarios still fail:
  - Add `I wait for 1 seconds` or `I wait for 2 seconds` after critical actions
  - Ensure flash messages persist long enough for assertions
  - Prefer waiting for specific DOM conditions over fixed-duration sleeps

### 3.2 Modal Rendering — Members Modal
- [ ] **RED**: If `I wait for ".modal.modal-open" to be visible` fails
- [ ] **GREEN**: The modal uses `<%= if @show_members_modal do %>` which conditionally renders. When the flag is set, the modal appears in DOM with class `modal modal-open`. Playwright's visibility check should work.
  - If timing issue: the members list loads via `Workspaces.list_members/1` which is synchronous, so the modal should render immediately with data

### 3.3 Modal Close — Members Modal
- [ ] **RED**: If `I wait for ".modal.modal-open" to be hidden` fails after clicking "Done"
- [ ] **GREEN**: When `hide_members_modal` fires, `@show_members_modal` becomes false, and the entire modal is removed from DOM. The `to be hidden` check should pass when the element no longer exists.
  - Also: `#members-list` should not exist after modal closes (BDD assertion line 187)

### 3.4 Dropdown Menu Behavior
- [ ] **RED**: If clicking kebab menu doesn't open dropdown (DaisyUI dropdown needs focus)
- [ ] **GREEN**: DaisyUI `dropdown` component opens on focus/click. The `I click "button[aria-label='Actions menu']"` step should trigger the dropdown. BDD adds `I wait for 1 seconds` after click.
  - If dropdown items aren't visible: may need to verify the `dropdown-content` is rendered in DOM and just hidden via CSS

### 3.5 Confirm Dialog Handling
- [ ] **RED**: If delete workspace or remove member fails due to confirm dialog
- [ ] **GREEN**: The BDD uses `I accept the next browser dialog` BEFORE the click action. The `data-confirm` attribute triggers a browser confirm dialog. Playwright's `page.on('dialog')` handler must accept before the click.
  - Delete Workspace: `data_confirm="Are you sure you want to delete this workspace?..."` on kebab item
  - Remove Member: `data-confirm="Are you sure you want to remove this member?"` on `.button` component

### 3.6 Form Selector Compatibility
- [ ] **RED**: If `I fill "[name='workspace[name]']"` or `I select "member" from "[name='role']"` fails
- [ ] **GREEN**: Verify the rendered HTML form field names match BDD selectors:
  - Workspace form: `<.input field={@form[:name]} ...>` with `as: :workspace` produces `name="workspace[name]"` 
  - Invite email: `<.input field={@invite_form[:email]} ...>` — the form is `to_form(%{}, ...)` without `as:` parameter, so field names are `name="email"` and `name="role"` (matches BDD selectors `[name='email']` and `[name='role']`)
  - Role select per member: `<select name="value" data-email={member.email} ...>` — BDD uses `select[data-email='...']` (matches)

### Phase 3 Validation
- [ ] Run all workspace BDD tests:
  ```bash
  mix exo_test --name jarga-web --adapter browser
  ```
- [ ] All 24 scenarios pass (7 CRUD + 10 members + 7 navigation)
- [ ] Document any remaining failures with screenshots from `tools/exo-bdd/test-failures/`

---

## Phase 4: Missing Unit Test Coverage (phoenix-tdd)

After BDD scenarios pass, fill any gaps in the LiveView unit test suite.

### 4.1 Member Management — Invite Error Cases
- [ ] **RED**: Write test `apps/jarga_web/test/live/app_live/workspaces/show_members_test.exs`
  - Test: Invite with invalid role shows error flash
  - Test: Invite already-member shows "already a member" error
  - Test: Invite with valid email shows success flash and member appears in list
  - Test: Invite form resets after successful invite
- [ ] **GREEN**: Verify existing `show.ex` event handlers cover these cases (they do)

### 4.2 Member Management — Role Change Cases
- [ ] **RED**: Write tests in `apps/jarga_web/test/live/app_live/workspaces/show_members_test.exs`
  - Test: Change member role from member to admin shows success flash
  - Test: Cannot change owner role (owner has badge, no select)
  - Test: Role change reloads members list with updated role
- [ ] **GREEN**: Verify existing event handlers

### 4.3 Member Management — Remove Cases
- [ ] **RED**: Write tests in `apps/jarga_web/test/live/app_live/workspaces/show_members_test.exs`
  - Test: Remove non-owner member shows success flash
  - Test: Removed member disappears from list
  - Test: Owner has no remove button
- [ ] **GREEN**: Verify existing event handlers

### 4.4 Permission-Based UI Rendering
- [ ] **RED**: Write tests in `apps/jarga_web/test/live/app_live/workspaces/show_permissions_test.exs`
  - Test: Owner sees full kebab menu (Edit, Manage Members, Delete)
  - Test: Admin sees kebab menu (Edit, Manage Members, NO Delete)
  - Test: Member sees NO kebab menu
  - Test: Guest sees NO kebab menu
  - Test: Guest sees workspace content (name, Projects, Documents, Agents sections)
  - Test: Guest sees no "New Project", "New Document" buttons
- [ ] **GREEN**: Verify existing permission helpers and template conditionals

### 4.5 Edit Page Authorization
- [ ] **RED**: Write tests
  - Test: Admin can access edit page and update workspace
  - Test: Member accessing edit page directly gets error/redirect
  - Test: Guest accessing edit page directly gets error/redirect
- [ ] **GREEN**: Currently `edit.ex` uses `get_workspace_by_slug!` which only checks membership, not role. This may need role-based authorization.
  - **Potential gap**: Edit page doesn't check if user has edit permission — any member can access it. The BDD doesn't test this directly (it tests via kebab menu visibility), but it's a security concern.
  - If needed, add role check in `edit.ex` mount

### Phase 4 Validation
- [ ] All new unit tests pass
- [ ] Full test suite passes: `mix test`
- [ ] No boundary violations: `mix boundary`

---

## Phase 5: Pre-Commit Checkpoint

- [ ] `mix format` — code formatting
- [ ] `mix credo` — style checks
- [ ] `mix boundary` — no violations
- [ ] `mix test` — all unit tests pass
- [ ] `mix exo_test --name jarga-web --adapter browser` — all BDD scenarios pass
- [ ] `mix precommit` — full pre-commit check passes

---

## Testing Strategy

### BDD Scenarios (black-box, existing)
- **CRUD**: 7 scenarios (create, edit x2, delete x2, validation, member/guest restrictions)
- **Members**: 10 scenarios (modal open, invite, member/guest restrictions x2, role change, owner badge, remove, owner protection, modal close, non-member access)
- **Navigation**: 7 scenarios (detail view, guest limits, member actions, workspace list, card nav, empty state, new workspace link)
- **Total BDD**: 24 scenarios

### LiveView Unit Tests (white-box, existing + new)
- **Existing**: ~55 tests across 2 files
- **New Phase 2**: ~8-10 tests (validation, selectors, permissions)
- **New Phase 4**: ~15-20 tests (invite errors, role changes, removal, permissions)
- **Estimated total**: ~80-85 unit tests

### Distribution
- Domain: 0 (no domain changes needed)
- Application: 0 (no use case changes needed)
- Infrastructure: 0 (no infrastructure changes needed)
- Interface: ~30 new tests + 55 existing = ~85 total

---

## File Inventory

### Files to potentially modify (if BDD tests reveal issues)
| File | Potential Changes |
|------|------------------|
| `apps/jarga_web/lib/live/app_live/workspaces/new.ex` | Fix validation error rendering on submit |
| `apps/jarga_web/lib/live/app_live/workspaces/show.ex` | Fix any selector/attribute mismatches |
| `apps/jarga_web/lib/live/app_live/workspaces/edit.ex` | Add role-based authorization if needed |
| `apps/jarga/priv/repo/exo_seeds_web.exs` | Fix any missing seed data |
| `apps/jarga_web/test/exo-bdd-jarga-web.config.ts` | Fix any config variable issues |

### Files to create (new unit tests)
| File | Purpose |
|------|---------|
| `apps/jarga_web/test/live/app_live/workspaces/show_members_test.exs` | Exists — add invite/role/remove tests |
| `apps/jarga_web/test/live/app_live/workspaces/show_permissions_test.exs` | New — role-based UI rendering tests |

### Files that should NOT be modified
| File | Reason |
|------|--------|
| `apps/identity/lib/identity.ex` | Public API facade is complete |
| `apps/jarga/lib/workspaces.ex` | Facade is complete |
| `apps/jarga_web/lib/live/permissions_helper.ex` | Permission checks are correct |
| `apps/jarga_web/lib/components/core_components.ex` | Components are working |
| `apps/jarga_web/lib/router.ex` | Routes are correctly configured |

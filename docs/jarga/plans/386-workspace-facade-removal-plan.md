# Feature: #386 — Workspace Facade Removal (Jarga.Workspaces → Identity)

## Overview

Remove the `Jarga.Workspaces` delegation facade and update all callers across jarga, jarga_web, jarga_api, agents, and entity_relationship_manager to call `Identity` directly. The core workspace migration (entities, schemas, repos, use cases, policies, tests) is **already complete** in the Identity app. This plan covers only facade removal and caller migration.

**Out of scope**: `Jarga.Accounts` facade removal (separate ticket).

## UI Strategy
- **LiveView coverage**: N/A (refactoring, no UI changes)
- **TypeScript needed**: None

## Affected Boundaries
- **Owning app**: `identity` (workspaces already migrated)
- **Repo**: `Identity.Repo`
- **Primary context**: `Identity` (public API)
- **Apps affected**: `jarga`, `jarga_web`, `jarga_api`, `agents`, `entity_relationship_manager`
- **Dependencies removed**: `Jarga.Workspaces` from 11 boundary declarations
- **Facade to delete**: `apps/jarga/lib/workspaces.ex` (67 lines, 24 functions)
- **Facade test to delete**: `apps/jarga/test/workspaces_test.exs` (267 lines)

## Migration Strategy

Since `Jarga.Workspaces` is a pure delegation facade (every function delegates 1:1 to `Identity`), all callers can be mechanically updated: replace `Workspaces.function(args)` or `Jarga.Workspaces.function(args)` with `Identity.function(args)`.

The plan is ordered to allow incremental commits where each phase is independently compilable and testable:
1. Update test fixtures first (they're shared across all apps)
2. Update internal jarga callers + boundaries (highest count, core domain)
3. Update jarga_web callers + boundary
4. Update jarga_api callers + boundary
5. Update agents callers
6. Update entity_relationship_manager callers + boundary
7. Update test files that directly call `Jarga.Workspaces`
8. Delete the facade and its test
9. Update seed file and documentation references

---

## Phase 1: Test Fixtures Update ⏸

Update the shared test fixture module that many test files depend on. This must be done first because it's imported across jarga, jarga_web, jarga_api, webhooks_api, and chat_web tests.

### 1.1 Update `Jarga.WorkspacesFixtures` boundary deps

- [ ] **RED**: Run `mix boundary` — should show `Jarga.Workspaces` as a dep
- [ ] **GREEN**: Update boundary deps in `apps/jarga/test/support/fixtures/workspaces_fixtures.ex`
  - Remove `Jarga.Workspaces` from `deps` list (line 15)
  - Remove `Jarga.Accounts` from `deps` list (line 16) — fixture already calls Identity directly
  - Keep `Identity` and `Identity.Repo`
- [ ] **REFACTOR**: Update `@moduledoc` to remove "delegates to Identity" language — it now calls Identity directly (which it already does in the function bodies)

**Files changed:**
- `apps/jarga/test/support/fixtures/workspaces_fixtures.ex`

**Verification:** `mix compile --warnings-as-errors` for jarga + `mix test apps/jarga`

---

## Phase 2: Jarga Internal Callers — Use Cases ⏸

Update all use cases in jarga that `alias Jarga.Workspaces` and call its functions. These are the core domain callers.

### 2.1 Projects use cases

For each file, the change is: `alias Jarga.Workspaces` → `alias Identity` and update the function call from `Workspaces.get_member(...)` → `Identity.get_member(...)`.

- [ ] **RED**: Verify existing tests pass: `mix test apps/jarga/test/projects/`
- [ ] **GREEN**: Update the following files:
  - `apps/jarga/lib/projects/application/use_cases/create_project.ex` — `alias Jarga.Workspaces` → replace with direct `Identity.get_member/2` call (line 24, 84)
  - `apps/jarga/lib/projects/application/use_cases/update_project.ex` — `alias Jarga.Workspaces` → `Identity` (line 24)
  - `apps/jarga/lib/projects/application/use_cases/delete_project.ex` — `alias Jarga.Workspaces` → `Identity` (line 24)
- [ ] **REFACTOR**: Ensure `Workspaces.` references in function bodies are replaced with `Identity.`

**Verification:** `mix test apps/jarga/test/projects/ && mix compile --warnings-as-errors`

### 2.2 Documents use cases

- [ ] **RED**: Verify existing tests pass: `mix test apps/jarga/test/documents/`
- [ ] **GREEN**: Update the following files:
  - `apps/jarga/lib/documents/application/use_cases/create_document.ex` — `alias Jarga.Workspaces` → `Identity` (line 26, 98)
  - `apps/jarga/lib/documents/application/use_cases/update_document.ex` — `alias Jarga.Workspaces` → `Identity` (line 24)
  - `apps/jarga/lib/documents/application/use_cases/delete_document.ex` — `alias Jarga.Workspaces` → `Identity` (line 22)
- [ ] **REFACTOR**: Verify all `Workspaces.` call sites updated

**Verification:** `mix test apps/jarga/test/documents/ && mix compile --warnings-as-errors`

### 2.3 Infrastructure authorization repositories

- [ ] **RED**: Verify existing tests pass for auth repos
- [ ] **GREEN**: Update the following files:
  - `apps/jarga/lib/documents/infrastructure/repositories/authorization_repository.ex` — `alias Jarga.Workspaces` → `Identity` (line 15); update `Workspaces.get_workspace(...)` → `Identity.get_workspace(...)` (line 24)
  - `apps/jarga/lib/documents/notes/infrastructure/repositories/authorization_repository.ex` — `alias Jarga.Workspaces` → `Identity` (line 13); update `Workspaces.get_workspace(...)` → `Identity.get_workspace(...)` (line 26)
  - `apps/jarga/lib/projects/infrastructure/repositories/authorization_repository.ex` — `alias Jarga.Workspaces` → `Identity` (line 15); update `Workspaces.verify_membership(...)` → `Identity.verify_membership(...)` (line 51)
- [ ] **REFACTOR**: Clean up

**Verification:** `mix test apps/jarga && mix compile --warnings-as-errors`

---

## Phase 3: Jarga Internal — Boundary Declarations ⏸

Update all boundary `deps` lists in jarga to remove `Jarga.Workspaces`. All of these already list `Identity` as a dep, so only the `Jarga.Workspaces` entry needs removal.

### 3.1 Update boundary declarations

- [ ] **RED**: Run `mix boundary` — should pass (deps still valid before facade deletion)
- [ ] **GREEN**: Remove `Jarga.Workspaces` from `deps` in each boundary module:

| File | Line | Change |
|------|------|--------|
| `apps/jarga/lib/documents.ex` | 20 | Remove `Jarga.Workspaces,` |
| `apps/jarga/lib/documents/application.ex` | 36 | Remove `Jarga.Workspaces,` |
| `apps/jarga/lib/documents/infrastructure.ex` | 42 | Remove `Jarga.Workspaces,` |
| `apps/jarga/lib/documents/notes/infrastructure.ex` | 35 | Remove `Jarga.Workspaces,` |
| `apps/jarga/lib/projects.ex` | 21 | Remove `Jarga.Workspaces,` |
| `apps/jarga/lib/projects/application.ex` | 32 | Remove `Jarga.Workspaces` |
| `apps/jarga/lib/projects/infrastructure.ex` | 36 | Remove `Jarga.Workspaces` |
| `apps/jarga/lib/notes.ex` | 23 | Remove `Jarga.Workspaces,` |

- [ ] **REFACTOR**: Verify boundary graph is cleaner

**Verification:** `mix boundary && mix compile --warnings-as-errors`

---

## Phase 4: JargaWeb Callers ⏸

Update all LiveViews and controllers in jarga_web that reference `Jarga.Workspaces`.

### 4.1 Workspace LiveViews

Each file aliases `Jarga.Workspaces` (or destructures it). Replace with `Identity`.

- [ ] **RED**: Verify existing tests pass: `mix test apps/jarga_web/test/live/app_live/`
- [ ] **GREEN**: Update the following files:

| File | Pattern | Change |
|------|---------|--------|
| `apps/jarga_web/lib/live/app_live/workspaces/show.ex` | `alias Jarga.{Workspaces, Projects, Documents}` (line 11) | Change to `alias Jarga.{Projects, Documents}` and add separate `alias Identity` (or use existing); replace all `Workspaces.fn()` → `Identity.fn()` calls (~8 call sites: `get_workspace_and_member_by_slug`, `delete_workspace`, `list_members`, `invite_member`, `change_member_role`, `remove_member`) |
| `apps/jarga_web/lib/live/app_live/workspaces/index.ex` | `alias Jarga.Workspaces` (line 10) | Remove alias; replace `Workspaces.list_workspaces_for_user(user)` → `Identity.list_workspaces_for_user(user)` (~4 call sites) |
| `apps/jarga_web/lib/live/app_live/workspaces/new.ex` | `alias Jarga.Workspaces` (line 10) | Remove alias; replace `Workspaces.change_workspace()` → `Identity.change_workspace()`, `Workspaces.create_workspace(...)` → `Identity.create_workspace(...)` |
| `apps/jarga_web/lib/live/app_live/workspaces/edit.ex` | `alias Jarga.Workspaces` (line 10) | Remove alias; replace `Workspaces.get_workspace_by_slug!(...)` → `Identity.get_workspace_by_slug!(...)`, `Workspaces.change_workspace(...)` → `Identity.change_workspace(...)`, `Workspaces.update_workspace(...)` → `Identity.update_workspace(...)` |
| `apps/jarga_web/lib/live/app_live/dashboard.ex` | `alias Jarga.Workspaces` (line 5) | Remove alias; replace `Workspaces.list_workspaces_for_user(user)` → `Identity.list_workspaces_for_user(user)` (~4 call sites) |

- [ ] **REFACTOR**: Ensure no dangling `Workspaces.` references

**Verification:** `mix test apps/jarga_web/test/live/app_live/ && mix compile --warnings-as-errors`

### 4.2 API Keys LiveView

- [ ] **RED**: Verify existing API keys tests pass
- [ ] **GREEN**: Update `apps/jarga_web/lib/live/api_keys_live.ex`:
  - Replace `Jarga.Workspaces.list_workspaces_for_user(user)` → `Identity.list_workspaces_for_user(user)` (line 657)
- [ ] **REFACTOR**: Clean up

**Verification:** `mix compile --warnings-as-errors`

### 4.3 User Session Controller

- [ ] **RED**: Verify existing session tests pass
- [ ] **GREEN**: Update `apps/jarga_web/lib/controllers/user_session_controller.ex`:
  - Replace `Jarga.Workspaces.create_notifications_for_pending_invitations(user)` → `Identity.create_notifications_for_pending_invitations(user)` (line 23)
- [ ] **REFACTOR**: Clean up

**Note:** This file also references `Jarga.Accounts` (line 4) — that is **out of scope** for this ticket.

**Verification:** `mix test apps/jarga_web && mix compile --warnings-as-errors`

### 4.4 JargaWeb boundary declaration

- [ ] **RED**: Run `mix boundary`
- [ ] **GREEN**: Update `apps/jarga_web/lib/jarga_web.ex`:
  - Remove `Jarga.Workspaces,` from deps list (line 27)
  - `Identity` is already listed (line 41)
- [ ] **REFACTOR**: Clean up

**Verification:** `mix boundary && mix compile --warnings-as-errors`

---

## Phase 5: JargaApi Callers ⏸

Update all controllers in jarga_api that reference `Jarga.Workspaces`.

### 5.1 API Controllers

- [ ] **RED**: Verify existing API tests pass: `mix test apps/jarga_api`
- [ ] **GREEN**: Update the following files:

| File | Change |
|------|--------|
| `apps/jarga_api/lib/jarga_api/controllers/workspace_api_controller.ex` | `alias Jarga.Workspaces` → remove; replace `Workspaces.list_workspaces_for_user` → `Identity.list_workspaces_for_user` and `Workspaces.get_workspace_by_slug` → `Identity.get_workspace_by_slug` in function capture references (lines 41, 67) |
| `apps/jarga_api/lib/jarga_api/controllers/project_api_controller.ex` | `alias Jarga.Workspaces` → remove; replace `Workspaces.get_workspace_and_member_by_slug` → `Identity.get_workspace_and_member_by_slug` in function captures (lines 50, 97) |
| `apps/jarga_api/lib/jarga_api/controllers/document_api_controller.ex` | `alias Jarga.Workspaces` → remove; replace `Workspaces.get_workspace_and_member_by_slug` → `Identity.get_workspace_and_member_by_slug` in function captures (lines 62, 118, 178) |

- [ ] **REFACTOR**: Clean up

**Verification:** `mix test apps/jarga_api && mix compile --warnings-as-errors`

### 5.2 JargaApi boundary declaration

- [ ] **RED**: Run `mix boundary`
- [ ] **GREEN**: Update `apps/jarga_api/lib/jarga_api.ex`:
  - Remove `Jarga.Workspaces,` from deps list (line 16)
  - `Identity` is already listed (line 20)
- [ ] **REFACTOR**: Clean up

**Verification:** `mix boundary && mix compile --warnings-as-errors`

---

## Phase 6: Agents App Callers ⏸

Update the two use cases in the agents app that use `@default_workspaces Jarga.Workspaces`.

### 6.1 Agents use cases

- [ ] **RED**: Verify existing agent tests pass: `mix test apps/agents`
- [ ] **GREEN**: Update the following files:

| File | Change |
|------|--------|
| `apps/agents/lib/agents/application/use_cases/clone_shared_agent.ex` | `@default_workspaces Jarga.Workspaces` → `@default_workspaces Identity` (line 17); update `@moduledoc` reference (line 29) |
| `apps/agents/lib/agents/application/use_cases/sync_agent_workspaces.ex` | `@default_workspaces Jarga.Workspaces` → `@default_workspaces Identity` (line 13); update `@moduledoc` reference (line 29) |

- [ ] **REFACTOR**: Update `@doc` strings that reference `Jarga.Workspaces`

**Note:** `Agents.Application` boundary deps (`[Agents.Domain, Identity]`) already include `Identity` — no boundary changes needed.

**Verification:** `mix test apps/agents && mix compile --warnings-as-errors`

---

## Phase 7: Entity Relationship Manager Callers ⏸

Update ERM's workspace auth plug and boundary declaration.

### 7.1 ERM workspace auth plug

- [ ] **RED**: Verify existing ERM tests pass
- [ ] **GREEN**: Update:
  - `apps/entity_relationship_manager/lib/entity_relationship_manager/plugs/workspace_auth_plug.ex` — Replace `&Jarga.Workspaces.get_member/2` → `&Identity.get_member/2` (line 38)

- [ ] **REFACTOR**: Update `@moduledoc` reference to `Jarga.Workspaces` (line 12 in entity_relationship_manager.ex)

### 7.2 ERM boundary declaration

- [ ] **GREEN**: Update `apps/entity_relationship_manager/lib/entity_relationship_manager.ex`:
  - Remove `Jarga.Workspaces,` from deps list (line 25)
  - `Identity` is already listed (line 24)
  - Update `@moduledoc` (line 12)
- [ ] **REFACTOR**: Clean up

**Verification:** `mix compile --warnings-as-errors && mix boundary`

---

## Phase 8: Test Files — Direct Jarga.Workspaces Calls ⏸

Several test files call `Jarga.Workspaces.function()` directly (not via fixtures). These must be updated.

### 8.1 Jarga test files

- [ ] **RED**: Verify tests pass before changes
- [ ] **GREEN**: Update direct `Jarga.Workspaces` calls in:

| File | Lines | Change |
|------|-------|--------|
| `apps/jarga/test/accounts_test.exs` | 406, 409, 425, 428, 446, 449, 462, 465, 470, 486, 497, 500 | Replace all `Jarga.Workspaces.function()` → `Identity.function()` |

- [ ] **REFACTOR**: Clean up

### 8.2 JargaWeb test files

- [ ] **GREEN**: Update direct `Jarga.Workspaces` calls in:

| File | Lines | Change |
|------|-------|--------|
| `apps/jarga_web/test/live/notifications_live/notification_bell_test.exs` | 7 (alias), 331, 472 | Remove `alias Jarga.Workspaces`; replace `Jarga.Workspaces.list_members(...)` → `Identity.list_members(...)` |
| `apps/jarga_web/test/live/app_live/workspaces_test.exs` | 588 | Replace `Jarga.Workspaces.list_workspaces_for_user(user)` → `Identity.list_workspaces_for_user(user)` |
| `apps/jarga_web/test/live/app_live/dashboard_test.exs` | 8 (alias) | Remove `alias Jarga.Workspaces` (check if used elsewhere in file) |
| `apps/jarga_web/test/integration/user_signup_and_confirmation_test.exs` | 303, 368, 400, 418, 440, 443 | Replace all `Jarga.Workspaces.invite_member(...)` → `Identity.invite_member(...)` |

### 8.3 JargaApi test files

- [ ] **GREEN**: Update direct `Jarga.Workspaces` references in:

| File | Lines | Change |
|------|-------|--------|
| `apps/jarga_api/test/jarga_api/accounts/application/use_cases/list_accessible_workspaces_test.exs` | 6 | Remove `alias Jarga.Workspaces` (check if used) |
| `apps/jarga_api/test/jarga_api/accounts/application/use_cases/get_workspace_with_details_test.exs` | 6 | Remove `alias Jarga.Workspaces` (check if used) |

- [ ] **REFACTOR**: Clean up

**Verification:** `mix test && mix compile --warnings-as-errors`

---

## Phase 9: Delete Facade and Facade Test ⏸

With all callers migrated, delete the facade module and its test.

### 9.1 Delete facade files

- [ ] **RED**: Grep for remaining `Jarga.Workspaces` references (expect only doc comments and the files being deleted)
  ```bash
  grep -r "Jarga\.Workspaces" apps/ --include="*.ex" --include="*.exs" | grep -v "moduledoc\|@doc\|#\|workspaces_fixtures"
  ```
- [ ] **GREEN**: Delete the following files:
  - `apps/jarga/lib/workspaces.ex` (the facade — 67 lines)
  - `apps/jarga/test/workspaces_test.exs` (facade test — 267 lines)
- [ ] **REFACTOR**: Clean up

**Verification:** `mix compile --warnings-as-errors && mix boundary && mix test`

---

## Phase 10: Cleanup — Seeds, Docs, and Comments ⏸

Final cleanup of remaining non-functional references.

### 10.1 Seed file

- [ ] **GREEN**: Update `apps/jarga/priv/repo/exo_seeds.exs`:
  - Remove unused `alias Jarga.Workspaces` (line 31)

### 10.2 Documentation and comment references

- [ ] **GREEN**: Update non-functional references in:

| File | Change |
|------|--------|
| `apps/jarga/lib/jarga/domain/policies/domain_permissions_policy.ex` | Update `@moduledoc` comment referencing `Jarga.Workspaces.Application.Policies.PermissionsPolicy` (line 8) |
| `apps/jarga_web/lib/jarga_web/presentation.ex` | Update comment referencing `Jarga.Workspaces` (line 52) |
| `apps/perme8_tools/lib/mix/tasks/step_linter/rules/use_liveview_testing.ex` | Update example code referencing `Jarga.Workspaces` (lines 25, 107) |
| `apps/notifications/lib/notifications/infrastructure.ex` | Update comment referencing `Jarga.Workspaces` (line 8) |
| `apps/notifications/lib/notifications/application.ex` | Update comment referencing `Jarga.Workspaces` (line 8) |
| `apps/jarga/test/.credo/checks/use_case_adoption_test.exs` | Update test fixture referencing `defmodule Jarga.Workspaces` (line 102) — this is test code for a Credo check; update the example module name |

### 10.3 Architecture docs

- [ ] **GREEN**: Update `docs/architecture/workspace_facade_removal_plan.md`:
  - Mark `Jarga.Workspaces` phases as complete
  - Note: `Jarga.Accounts` phases remain as future work

- [ ] **GREEN**: Verify `docs/app_ownership.md` is current (workspaces correctly listed under `identity`)

**Verification:** Full test suite:
```bash
mix compile --warnings-as-errors && mix boundary && mix test
```

---

## Phase 11: Final Verification ⏸

### Pre-commit checkpoint

- [ ] `mix compile --warnings-as-errors` — zero warnings
- [ ] `mix boundary` — zero violations
- [ ] `mix test` — full suite passes
- [ ] `grep -r "Jarga\.Workspaces" apps/ --include="*.ex" --include="*.exs"` — zero functional references (only historical doc comments acceptable)
- [ ] `mix precommit` — passes (if available)

---

## Testing Strategy

- **Total estimated test updates**: ~30 files
- **Test files with direct `Jarga.Workspaces` calls**: 6 files (need function call updates)
- **Test files importing `Jarga.WorkspacesFixtures`**: ~30 files (fixture module unchanged, only boundary dep)
- **No new tests needed** — this is a pure refactoring with no behavior changes
- **Distribution**: All changes are mechanical alias/reference replacements

## Commit Strategy

Each phase can be committed independently:

| Phase | Commit Message | Risk |
|-------|---------------|------|
| 1 | `refactor: update WorkspacesFixtures boundary deps to remove Jarga.Workspaces` | Low |
| 2 | `refactor: migrate jarga use cases from Jarga.Workspaces to Identity` | Medium |
| 3 | `refactor: remove Jarga.Workspaces from jarga boundary declarations` | Low |
| 4 | `refactor: migrate jarga_web callers from Jarga.Workspaces to Identity` | Medium |
| 5 | `refactor: migrate jarga_api callers from Jarga.Workspaces to Identity` | Low |
| 6 | `refactor: migrate agents use cases from Jarga.Workspaces to Identity` | Low |
| 7 | `refactor: migrate ERM callers from Jarga.Workspaces to Identity` | Low |
| 8 | `refactor: update test files to use Identity instead of Jarga.Workspaces` | Low |
| 9 | `refactor: delete Jarga.Workspaces facade and facade test` | Low (all callers migrated) |
| 10 | `chore: clean up docs and seed references to Jarga.Workspaces` | Low |

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Function signature mismatch | All 24 functions are pure delegation — signatures identical. `mix compile` catches instantly. |
| Boundary violations | `mix boundary` after every phase. All target boundaries already list `Identity` as a dep. |
| Test fixture breakage | Fixture module (`Jarga.WorkspacesFixtures`) already calls `Identity` directly in function bodies — only the boundary dep changes. |
| Missed callers | Phase 9 includes comprehensive grep to find any remaining references before deletion. |
| ERM dependency | ERM uses DI (Keyword.get with default) — just updating the default reference. |
| Agents dependency | Agents use DI (`@default_workspaces`) — just updating the module attribute. All tests mock this dependency. |

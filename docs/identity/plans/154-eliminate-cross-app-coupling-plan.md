# Feature: #154 — Eliminate Cross-App Coupling from Identity

## Overview

Remove all remaining runtime and configuration dependencies from the `identity` app on other umbrella apps (primarily `Jarga.*`). After this refactor, Identity will have zero cross-app coupling in production code and can boot/run as a standalone service. The `identity` app already owns all replacement functions (`list_workspaces_for_user/1`, `create_notifications_for_pending_invitations/1`, `member_by_slug?/2`) — the `Jarga.Workspaces` methods were circular indirections that delegated back to Identity.

## UI Strategy

- **LiveView coverage**: N/A — this is a pure refactoring of backend coupling. No UI changes.
- **TypeScript needed**: None

## Affected Boundaries

- **Owning app**: `identity`
- **Repo**: `Identity.Repo`
- **Migrations**: None — no schema changes
- **Feature files**: N/A — no new features
- **Primary context**: `Identity` (facade) + `IdentityWeb` (interface)
- **Dependencies**: None after refactor (that's the point)
- **Exported schemas**: No changes
- **New context needed?**: No

## Regression Baseline

- 563 tests, 0 failures (as of ticket creation)
- `mix boundary` passes (no violations)

## Risk Assessment

- **Cookie rename** (`_jarga_web_user_remember_me` → `_identity_web_user_remember_me`): All existing remember-me cookies will be invalidated. Affected users will need to log in again. This is acceptable and expected.
- **Config migration** (`:jarga` → `:identity`): The new config keys must be added to `config/config.exs` BEFORE the code changes, or notifiers will fall back to hardcoded defaults.

---

## Phase 1: Configuration Foundation

This phase adds the new `:identity` config keys that the subsequent code changes depend on. No tests needed — this is pure config wiring.

### Step 1.1: Add `:identity` app config keys to `config/config.exs`

- [ ] ⏸ Add the following keys to the existing `:identity` config block in `config/config.exs`:
  ```elixir
  config :identity,
    app_name: "Perme8",
    mailer_from_email: "noreply@perme8.app",
    mailer_from_name: "Perme8",
    signed_in_redirect_path: "/app",
    base_url: "http://localhost:4000"
  ```
  - File: `config/config.exs`
  - Place inside the existing `# Identity App Configuration` section, after the `ecto_repos` line
  - **Note**: `base_url` may need environment-specific overrides in `dev.exs`, `test.exs`, `runtime.exs`

### Phase 1 Validation

- [ ] App compiles with no warnings (`mix compile --warnings-as-errors`, scoped to identity)
- [ ] Existing test suite still passes (563 tests, 0 failures)

---

## Phase 2: Production Code — Replace Dynamic Dispatch (#230)

Replace all 4 sites where `Code.ensure_loaded?(Jarga.Workspaces)` + `apply/3` is used to call functions that already exist on the `Identity` facade.

### Step 2.1: SessionController — replace Jarga.Workspaces dispatch

- [ ] ⏸ **RED**: Update test `apps/identity/test/identity_web/controllers/session_controller_test.exs`
  - The existing test for magic link login should still pass after the change (no new test needed since the behaviour is identical)
  - Verify: magic link login still calls `create_notifications_for_pending_invitations`
- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity_web/controllers/session_controller.ex`
  - Replace lines 22-33 (the `Code.ensure_loaded?` + `apply/3` block) with:
    ```elixir
    Identity.create_notifications_for_pending_invitations(user)
    ```
  - Remove the comment about `apply/3` and compile-time warnings
  - Remove the `credo:disable-for-next-line` annotation
- [ ] ⏸ **REFACTOR**: Clean up surrounding comments to reflect direct call

### Step 2.2: ApiKeysLive — replace `get_user_workspaces/1` dispatch

- [ ] ⏸ **RED**: Verify existing test `apps/identity/test/identity_web/live/api_keys_live_test.exs` still passes
  - The mount should populate `available_workspaces` via `Identity.list_workspaces_for_user/1`
- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity_web/live/api_keys_live.ex`
  - Replace the `get_user_workspaces/1` private function (lines 659-670) with:
    ```elixir
    defp get_user_workspaces(user) do
      Identity.list_workspaces_for_user(user)
    end
    ```
  - Remove the comment on line 343 about cross-app communication
- [ ] ⏸ **REFACTOR**: Consider inlining `get_user_workspaces/1` directly in `mount/3` since it's now a simple delegation

### Step 2.3: CreateApiKey — replace `default_workspaces/0`

- [ ] ⏸ **RED**: Verify existing test `apps/identity/test/identity/application/use_cases/create_api_key_test.exs` passes
  - Tests already inject `:workspaces` via opts, so the default shouldn't matter for tests
  - Add a unit test confirming that when no `:workspaces` opt is provided, `Identity` is used as the default module
- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/application/use_cases/create_api_key.ex`
  - Replace `default_workspaces/0` (lines 102-108) with:
    ```elixir
    defp default_workspaces, do: Identity
    ```
  - Update `@moduledoc` (line 9) to reference `Identity` instead of `Jarga.Workspaces`
- [ ] ⏸ **REFACTOR**: Remove comment about "avoiding compile-time coupling"

### Step 2.4: UpdateApiKey — replace `default_workspaces/0`

- [ ] ⏸ **RED**: Verify existing test `apps/identity/test/identity/application/use_cases/update_api_key_test.exs` passes
  - Same pattern as CreateApiKey — tests inject `:workspaces` via opts
- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/application/use_cases/update_api_key.ex`
  - Replace `default_workspaces/0` (lines 89-95) with:
    ```elixir
    defp default_workspaces, do: Identity
    ```
  - Update `@moduledoc` (lines 10, 30) to reference `Identity` instead of `Jarga.Workspaces`
- [ ] ⏸ **REFACTOR**: Remove comment about "avoiding compile-time coupling"

### Phase 2 Validation

- [ ] No `Jarga.Workspaces` references remain in production code (verify with `grep -r "Jarga.Workspaces" apps/identity/lib/`)
- [ ] All tests pass
- [ ] `mix boundary` passes

---

## Phase 3: Production Code — Config Migration (#231, #232)

Move config reads from `:jarga` app env to `:identity` app env, and make the post-login redirect path configurable.

### Step 3.1: UserNotifier — move mailer config from `:jarga` to `:identity`

- [ ] ⏸ **RED**: Write/update test `apps/identity/test/identity/infrastructure/notifiers/user_notifier_test.exs`
  - Verify that emails are sent with the correct `from` name and email
  - Test that `Application.get_env(:identity, :mailer_from_email)` is read (not `:jarga`)
  - Test that `Application.get_env(:identity, :mailer_from_name)` is read (not `:jarga`)
- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/infrastructure/notifiers/user_notifier.ex`
  - Line 33: Change `Application.get_env(:jarga, :mailer_from_email, "noreply@jarga.app")` to `Application.get_env(:identity, :mailer_from_email, "noreply@perme8.app")`
  - Line 37: Change `Application.get_env(:jarga, :mailer_from_name, "Jarga")` to `Application.get_env(:identity, :mailer_from_name, "Perme8")`
  - Update docstring references on lines 57-58, 89-90, 150-151 to say `"noreply@perme8.app"` and `"Perme8"` instead of `"noreply@jarga.app"` and `"Jarga"`
- [ ] ⏸ **REFACTOR**: Ensure defaults are consistent with config.exs values

### Step 3.2: WorkspaceNotifier — remove `:jarga` config fallbacks, replace brand name

- [ ] ⏸ **RED**: Update test `apps/identity/test/identity/infrastructure/notifiers/workspace_notifier_test.exs`
  - Verify email `from` field uses configured `app_name` (not hardcoded "Jarga")
  - Verify `build_workspace_url/1` reads from `:identity` config only
  - Verify `build_signup_url/0` reads from `:identity` config only
  - Verify email body uses configured `app_name` (not hardcoded "Jarga")
- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/infrastructure/notifiers/workspace_notifier.ex`
  - Line 19: Change `{"Jarga", "contact@example.com"}` to use config:
    ```elixir
    |> from({app_name(), default_from_email()})
    ```
    Add private helpers:
    ```elixir
    defp app_name, do: Application.get_env(:identity, :app_name, "Perme8")
    defp default_from_email, do: Application.get_env(:identity, :mailer_from_email, "noreply@perme8.app")
    ```
  - Lines 37, 43, 45: Replace hardcoded "Jarga" with `#{app_name()}` (will need to restructure the string interpolation in the email body)
  - Lines 98-103: Remove the `:jarga` fallback in `build_workspace_url/1`:
    ```elixir
    defp build_workspace_url(workspace_id) do
      base_url = Application.get_env(:identity, :base_url, "http://localhost:4000")
      "#{base_url}/app/workspaces/#{workspace_id}"
    end
    ```
  - Lines 106-111: Remove the `:jarga` fallback in `build_signup_url/0`:
    ```elixir
    defp build_signup_url do
      base_url = Application.get_env(:identity, :base_url, "http://localhost:4000")
      "#{base_url}/users/register"
    end
    ```
- [ ] ⏸ **REFACTOR**: Extract `base_url/0` helper to avoid duplication between the two URL builders

### Step 3.3: UserAuth — make redirect path configurable (#232)

- [ ] ⏸ **RED**: Update test `apps/identity/test/identity_web/plugs/user_auth_test.exs`
  - Verify `signed_in_path/1` reads from config instead of hardcoded `"/app"`
  - Test that the default value is `"/app"` when no config is set
- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity_web/plugs/user_auth.ex`
  - Line 18: Replace `@signed_in_redirect_path "/app"` with a function:
    ```elixir
    defp signed_in_redirect_path do
      Application.get_env(:identity, :signed_in_redirect_path, "/app")
    end
    ```
  - Update all references to `@signed_in_redirect_path` to call `signed_in_redirect_path()` instead
  - Update the comment on line 16 to remove "these point to JargaWeb routes"
  - Update the `@moduledoc` on line 5 to remove "both IdentityWeb and JargaWeb routers"
- [ ] ⏸ **REFACTOR**: Clean up comments

### Phase 3 Validation

- [ ] No `Application.get_env(:jarga, ...)` references remain in identity production code
- [ ] All tests pass
- [ ] `mix boundary` passes

---

## Phase 4: Production Code — Cookie Rename & Boundary Cleanup (#233, #234)

### Step 4.1: Rename remember-me cookie (#233)

- [ ] ⏸ **RED**: Update test `apps/identity/test/identity_web/plugs/user_auth_test.exs`
  - Line 11: Change `@remember_me_cookie "_jarga_web_user_remember_me"` to `@remember_me_cookie "_identity_web_user_remember_me"`
  - All existing tests referencing this cookie should now use the new name
- [ ] ⏸ **RED**: Update test `apps/identity/test/identity_web/controllers/session_controller_test.exs`
  - Line 36: Change `assert conn.resp_cookies["_jarga_web_user_remember_me"]` to `assert conn.resp_cookies["_identity_web_user_remember_me"]`
- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity_web/plugs/user_auth.ex`
  - Line 23: Change `@remember_me_cookie "_jarga_web_user_remember_me"` to `@remember_me_cookie "_identity_web_user_remember_me"`
- [ ] ⏸ **REFACTOR**: No further cleanup needed

### Step 4.2: Remove `Jarga.Workspaces` from IdentityWeb boundary deps (#234)

- [ ] ⏸ **GREEN**: Verify `apps/identity/lib/identity_web.ex` boundary deps
  - Current deps (lines 21-28) do NOT include `Jarga.Workspaces` — this was already cleaned up
  - **If** `Jarga.Workspaces` appears, remove it from the `deps` list
  - Confirm boundary config is clean: only `Identity` and `Identity.Repo`
- [ ] ⏸ **REFACTOR**: No changes needed if already clean

### Phase 4 Validation

- [ ] Cookie rename tests pass
- [ ] `mix boundary` passes with no `Jarga.Workspaces` dependency from IdentityWeb
- [ ] All tests pass

---

## Phase 5: Test Code Cleanup (#235)

Fix all test-only coupling: fixture imports, Repo references.

### Step 5.1: Remove `Jarga.Repo` from ConnCase

- [ ] ⏸ **RED**: Run `mix test apps/identity` — should still pass before change
- [ ] ⏸ **GREEN**: Modify `apps/identity/test/support/conn_case.ex`
  - Remove line 47: `:ok = Sandbox.checkout(Jarga.Repo)`
  - Remove line 51: `Sandbox.mode(Jarga.Repo, {:shared, self()})`
  - Remove line 56: `Sandbox.checkin(Jarga.Repo)`
  - Remove the comment on line 45-46 about "Jarga.Repo for any cross-app test data"
  - Result: only `Identity.Repo` sandbox setup remains
- [ ] ⏸ **REFACTOR**: Clean up the `setup` block formatting

### Step 5.2: Replace `import Jarga.AccountsFixtures` in test files (7 sites)

All 7 files already have identical functions available in `Identity.AccountsFixtures`.

- [ ] ⏸ **GREEN**: Change `import Jarga.AccountsFixtures` → `import Identity.AccountsFixtures` in:
  1. `apps/identity/test/identity_web/plugs/user_auth_test.exs` (line 9)
  2. `apps/identity/test/identity_web/live/registration_live_test.exs` (line 5)
  3. `apps/identity/test/identity_web/live/login_live_test.exs` (line 5)
  4. `apps/identity/test/identity_web/live/confirmation_live_test.exs` (line 5)
  5. `apps/identity/test/identity_web/controllers/session_controller_test.exs` (line 4)
  6. `apps/identity/test/identity_web/live/settings_live_test.exs` (line 6)
  7. `apps/identity/test/identity_web/plugs/api_auth_plug_test.exs` (line 7)

### Step 5.3: Replace `import Jarga.WorkspacesFixtures` in test files (1 site)

- [ ] ⏸ **GREEN**: Change `import Jarga.WorkspacesFixtures` → `import Identity.WorkspacesFixtures` in:
  1. `apps/identity/test/identity_web/plugs/api_auth_plug_test.exs` (line 8)

### Phase 5 Validation

- [ ] No `Jarga.` imports remain in identity test files (verify with `grep -r "import Jarga\." apps/identity/test/`)
- [ ] No `Jarga.Repo` references remain in identity test files
- [ ] All 563+ tests pass
- [ ] `mix test apps/identity` passes in isolation

---

## Phase 6: Docstring & Comment Cleanup (#236)

Remove all Jarga references from docstrings and comments in identity production code.

### Step 6.1: Clean up `identity.ex` facade

- [ ] ⏸ **GREEN**: No Jarga references remain in `identity.ex` production code (already clean after Phase 2)

### Step 6.2: Clean up `repo.ex`

- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/repo.ex`
  - Lines 5-6: Change moduledoc from "Connects to the same database as Jarga.Repo but allows Identity to be self-contained without depending on the jarga app." to "Ecto repository for the Identity app. Connects to the Identity-owned PostgreSQL database."

### Step 6.3: Clean up `user_schema.ex`

- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/infrastructure/schemas/user_schema.ex`
  - Line 195: Change comment "Fallback for any struct with user-like fields (e.g., Jarga.Accounts.Domain.Entities.User)" to "Fallback for any struct with user-like fields"
  - Remove "This enables compatibility during migration period" on line 196

### Step 6.4: Clean up `scope.ex`

- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/domain/scope.ex`
  - Line 24: Change "Accepts any user struct (Identity.Domain.Entities.User or Jarga.Accounts.Domain.Entities.User)" to "Accepts any user struct (e.g., Identity.Domain.Entities.User)"

### Step 6.5: Clean up `workspace_permissions_policy.ex`

- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/domain/policies/workspace_permissions_policy.ex`
  - Line 8: Change "Extracted from the original `Jarga.Workspaces.Application.Policies.PermissionsPolicy`," to "Defines workspace-level permission rules."
  - Line 13: Change "Project and document permissions are handled by `Jarga.Domain.Policies.DomainPermissionsPolicy`." to "Project and document permissions are handled by their respective domain apps."

### Step 6.6: Clean up `token_builder.ex`

- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity/domain/services/token_builder.ex`
  - Lines 22-23: Change "Default implementations - will be updated to Identity modules in Phase 4 / For now, they point to Jarga modules for backward compatibility during migration" to "Default implementations for token generation"

### Step 6.7: Clean up `user_auth.ex`

- [ ] ⏸ **GREEN**: Modify `apps/identity/lib/identity_web/plugs/user_auth.ex`
  - Line 5: Change "This module can be imported by both IdentityWeb and JargaWeb routers" to "This module provides authentication and authorization plugs that can be shared across web apps."

### Phase 6 Validation

- [ ] `grep -r "Jarga\|jarga" apps/identity/lib/` returns NO matches (zero references)
- [ ] `mix compile --warnings-as-errors` passes
- [ ] All tests pass

---

## Pre-Commit Checkpoint

- [ ] `mix precommit` passes (compilation, boundary, formatting, credo, tests)
- [ ] `mix boundary` reports no violations
- [ ] `grep -rn "Jarga\|jarga" apps/identity/lib/` returns zero matches
- [ ] `grep -rn "import Jarga\." apps/identity/test/` returns zero matches
- [ ] `grep -rn "Jarga\.Repo" apps/identity/test/` returns zero matches
- [ ] Full test suite passes (`mix test`) — target: 563+ tests, 0 failures

---

## Testing Strategy

- **Total estimated new/modified tests**: ~8-12 (mostly modifications, few net-new)
- **Distribution**:
  - Domain: 0 (no domain logic changes)
  - Application: 2 (verify default_workspaces returns Identity)
  - Infrastructure: 4 (notifier config reads verified)
  - Interface: 4-6 (cookie rename, redirect path, fixture import changes)
- **Approach**: This is a refactor — the primary validation is that ALL existing tests continue to pass with the updated code. New tests are only added where the behaviour subtly changes (default module, config source, cookie name).

## Implementation Notes

### Ordering Matters

1. **Config first** (Phase 1) — code changes in later phases depend on `:identity` config keys existing
2. **Production code** (Phases 2-4) — can be done in any order within phases
3. **Test code** (Phase 5) — should be done AFTER production changes so tests validate the new behaviour
4. **Docstrings** (Phase 6) — purely cosmetic, do last

### Cookie Rename Impact

The `_jarga_web_user_remember_me` → `_identity_web_user_remember_me` rename means:
- All existing remember-me cookies in user browsers become invalid
- Users will need to log in again (session tokens in the DB are unaffected)
- This is a one-time impact and is acceptable

### No Migration Needed

There are no database changes in this refactor. All changes are in application code, configuration, and tests.

### Sub-Issue Mapping

| Sub-Issue | Phase | Steps |
|-----------|-------|-------|
| #230 Replace dynamic dispatch | Phase 2 | Steps 2.1-2.4 |
| #231 Move config reads | Phase 3 | Steps 3.1-3.2 |
| #232 Configurable redirect path | Phase 3 | Step 3.3 |
| #233 Rename cookie | Phase 4 | Step 4.1 |
| #234 Remove boundary dep | Phase 4 | Step 4.2 |
| #235 Fix test coupling | Phase 5 | Steps 5.1-5.3 |
| #236 Clean up docstrings | Phase 6 | Steps 6.1-6.7 |

# Workspace Facade Removal Plan

> Phase 0 of the [Service Evolution Plan](./service_evolution_plan.md): Remove delegation facades and migrate all workspace management callers to use `Identity` directly.

## Context

`Jarga.Workspaces` (68 lines, 24 public functions) and `Jarga.Accounts` (88 lines, 27 public functions) are pure pass-through facades that delegate every call to `Identity`. They add zero business logic — only indirection. Removing them:

- Eliminates a layer of abstraction that slows comprehension
- Removes 13 internal boundary dependencies on `Jarga.Workspaces`
- Unblocks future service extractions (Notifications, Chat, Agents, Components) by establishing `Identity` as the sole authority for workspace/account concerns
- Aligns with the target dependency graph where domain apps depend directly on `identity`

---

## Scope

### In Scope

| Facade | File | Functions |
|--------|------|-----------|
| `Jarga.Workspaces` | `apps/jarga/lib/workspaces.ex` | 24 delegation functions |
| `Jarga.Accounts` | `apps/jarga/lib/accounts.ex` | 27 delegation functions |

### Out of Scope

- `JargaApi.Accounts` (separate facade in `jarga_api` with its own purpose — evaluate separately)
- Adding new workspace settings features to `identity`
- Repo strategy decisions (shared vs per-app)
- PubSub namespace rename (`Jarga.PubSub` → `Perme8.PubSub`)

---

## Current Dependency Graph

```
jarga_web ──→ Jarga.Workspaces ──→ Identity
jarga_web ──→ Jarga.Accounts   ──→ Identity
jarga_api ──→ Jarga.Workspaces ──→ Identity

jarga (internal):
  Documents.Application      ──→ Jarga.Workspaces ──→ Identity
  Documents.Infrastructure    ──→ Jarga.Workspaces ──→ Identity
  Documents.Notes.Infrastructure ──→ Jarga.Workspaces ──→ Identity
  Projects.Application        ──→ Jarga.Workspaces ──→ Identity
  Projects.Infrastructure     ──→ Jarga.Workspaces ──→ Identity
  Notifications               ──→ Jarga.Workspaces ──→ Identity
  Notifications.Application   ──→ Jarga.Workspaces ──→ Identity
  Notes                       ──→ Jarga.Workspaces ──→ Identity
  Chat                        ──→ Jarga.Workspaces ──→ Identity
  Agents                      ──→ Jarga.Workspaces ──→ Identity
  Agents.Infrastructure       ──→ Jarga.Workspaces ──→ Identity
```

## Target Dependency Graph

```
jarga_web ──→ Identity  (direct)
jarga_api ──→ Identity  (direct)

jarga (internal):
  Documents.Application      ──→ Identity  (direct)
  Documents.Infrastructure    ──→ Identity  (direct)
  Documents.Notes.Infrastructure ──→ Identity  (direct)
  Projects.Application        ──→ Identity  (direct)
  Projects.Infrastructure     ──→ Identity  (direct)
  Notifications               ──→ Identity  (direct)
  Notifications.Application   ──→ Identity  (direct)
  Notes                       ──→ Identity  (direct)
  Chat                        ──→ Identity  (direct)
  Agents                      ──→ Identity  (direct)
  Agents.Infrastructure       ──→ Identity  (direct)

Jarga.Workspaces  →  DELETED
Jarga.Accounts    →  DELETED
```

---

## Migration Phases

### Phase 1: Migrate `jarga_web` callers of `Jarga.Workspaces`

**Risk:** Medium (highest surface area — 11 LiveView/controller files)
**Strategy:** Replace `alias Jarga.Workspaces` with `alias Identity` (or use `Identity` directly). All function signatures match 1:1 since the facade was pure delegation.

| File | Calls to Replace |
|------|-----------------|
| `apps/jarga_web/lib/live/app_live/workspaces/show.ex` | `Workspaces.get_workspace_and_member_by_slug`, `delete_workspace`, `list_members`, `invite_member`, `change_member_role`, `remove_member` |
| `apps/jarga_web/lib/live/app_live/workspaces/index.ex` | `Workspaces.list_workspaces_for_user` |
| `apps/jarga_web/lib/live/app_live/workspaces/new.ex` | `Workspaces.change_workspace`, `Workspaces.create_workspace` |
| `apps/jarga_web/lib/live/app_live/workspaces/edit.ex` | `Workspaces.get_workspace_by_slug!`, `Workspaces.change_workspace`, `Workspaces.update_workspace` |
| `apps/jarga_web/lib/live/app_live/dashboard.ex` | `Workspaces.list_workspaces_for_user` |
| `apps/jarga_web/lib/live/app_live/agents/form.ex` | `Workspaces.list_workspaces_for_user` |
| `apps/jarga_web/lib/live/app_live/projects/edit.ex` | `Workspaces.get_workspace_by_slug!` |
| `apps/jarga_web/lib/live/app_live/documents/show.ex` | `Workspaces.get_workspace_and_member_by_slug` |
| `apps/jarga_web/lib/live/app_live/projects/show.ex` | `Workspaces.get_workspace_by_slug` |
| `apps/jarga_web/lib/controllers/user_session_controller.ex` | `Workspaces.create_notifications_for_pending_invitations` |
| `apps/jarga_web/lib/live/api_keys_live.ex` | `Workspaces.list_workspaces_for_user` |

**Verification:** `mix compile --warnings-as-errors` for `jarga_web` + existing test suite.

---

### Phase 2: Migrate `jarga_web` callers of `Jarga.Accounts`

**Risk:** Medium (auth-sensitive code paths — login, registration, session management)

| File | Calls to Replace |
|------|-----------------|
| `apps/jarga_web/lib/live/user_live/settings.ex` | `Accounts.change_user_email`, `change_user_password`, `update_user_email`, `update_user_password`, `sudo_mode?` |
| `apps/jarga_web/lib/controllers/user_session_controller.ex` | `Accounts.login_user_by_magic_link`, `Accounts.create_notifications_for_pending_invitations` |
| Auth plugs / `UserAuth` module | `Accounts.get_user_by_session_token`, `generate_user_session_token`, `delete_user_session_token` |
| Registration LiveViews | `Accounts.register_user`, `change_user_registration` |

**Verification:** Auth integration tests must all pass. Manual smoke test of login/register/settings flows.

---

### Phase 3: Migrate `jarga_api` callers of `Jarga.Workspaces`

**Risk:** Low (only 3 controller files, pure read operations)

| File | Calls to Replace |
|------|-----------------|
| `apps/jarga_api/lib/jarga_api/controllers/workspace_api_controller.ex` | `Workspaces.list_workspaces_for_user`, `Workspaces.get_workspace_by_slug` |
| `apps/jarga_api/lib/jarga_api/controllers/document_api_controller.ex` | `Workspaces.get_workspace_and_member_by_slug` |
| `apps/jarga_api/lib/jarga_api/controllers/project_api_controller.ex` | `Workspaces.get_workspace_and_member_by_slug` |

**Verification:** API controller tests must pass.

---

### Phase 4: Migrate `jarga` internal callers of `Jarga.Workspaces`

**Risk:** Medium-High (13 boundary modules depend on `Jarga.Workspaces`; these are core domain/application/infrastructure layers)

**Strategy:** Replace `Jarga.Workspaces.function_name(args)` with `Identity.function_name(args)` in each module. Update boundary `deps` lists to replace `Jarga.Workspaces` with `Identity`.

| Module | File | Functions Used |
|--------|------|---------------|
| `Jarga.Documents.Infrastructure.Repositories.AuthorizationRepository` | `apps/jarga/lib/documents/infrastructure/repositories/authorization_repository.ex` | `get_workspace` |
| `Jarga.Documents.Notes.Infrastructure.Repositories.AuthorizationRepository` | `apps/jarga/lib/documents/notes/infrastructure/repositories/authorization_repository.ex` | `get_workspace` |
| `Jarga.Projects.Infrastructure.Repositories.AuthorizationRepository` | `apps/jarga/lib/projects/infrastructure/repositories/authorization_repository.ex` | `verify_membership` |
| `Jarga.Projects.Application.UseCases.CreateProject` | `apps/jarga/lib/projects/application/use_cases/create_project.ex` | `get_member` |
| `Jarga.Projects.Application.UseCases.UpdateProject` | `apps/jarga/lib/projects/application/use_cases/update_project.ex` | `get_member` |
| `Jarga.Projects.Application.UseCases.DeleteProject` | `apps/jarga/lib/projects/application/use_cases/delete_project.ex` | `get_member` |
| `Jarga.Documents.Application.UseCases.CreateDocument` | `apps/jarga/lib/documents/application/use_cases/create_document.ex` | `get_member` |
| `Jarga.Documents.Application.UseCases.UpdateDocument` | `apps/jarga/lib/documents/application/use_cases/update_document.ex` | `get_member`, `verify_membership` |
| `Jarga.Documents.Application.UseCases.DeleteDocument` | `apps/jarga/lib/documents/application/use_cases/delete_document.ex` | `get_member`, `verify_membership` |
| `Jarga.Notifications.Application.UseCases.AcceptWorkspaceInvitation` | `apps/jarga/lib/notifications/application/use_cases/accept_workspace_invitation.ex` | `accept_invitation_by_workspace` |
| `Jarga.Notifications.Application.UseCases.DeclineWorkspaceInvitation` | `apps/jarga/lib/notifications/application/use_cases/decline_workspace_invitation.ex` | `decline_invitation_by_workspace` |
| `Jarga.Agents.Application.UseCases.CloneSharedAgent` | `apps/jarga/lib/agents/application/use_cases/clone_shared_agent.ex` | (module attribute default) |
| `Jarga.Agents.Application.UseCases.SyncAgentWorkspaces` | `apps/jarga/lib/agents/application/use_cases/sync_agent_workspaces.ex` | (module attribute default) |

**Boundary updates required** (replace `Jarga.Workspaces` with `Identity` in deps):

| Boundary Module | File |
|----------------|------|
| `Jarga.Documents` | `apps/jarga/lib/documents.ex` |
| `Jarga.Documents.Application` | `apps/jarga/lib/documents/application.ex` |
| `Jarga.Documents.Infrastructure` | `apps/jarga/lib/documents/infrastructure.ex` |
| `Jarga.Documents.Notes.Infrastructure` | `apps/jarga/lib/documents/notes/infrastructure.ex` |
| `Jarga.Projects` | `apps/jarga/lib/projects.ex` |
| `Jarga.Projects.Application` | `apps/jarga/lib/projects/application.ex` |
| `Jarga.Projects.Infrastructure` | `apps/jarga/lib/projects/infrastructure.ex` |
| `Jarga.Notifications` | `apps/jarga/lib/notifications.ex` |
| `Jarga.Notifications.Application` | `apps/jarga/lib/notifications/application.ex` |
| `Jarga.Notes` | `apps/jarga/lib/notes.ex` |
| `Jarga.Chat` | `apps/jarga/lib/chat.ex` |
| `Jarga.Agents` | `apps/jarga/lib/agents.ex` |
| `Jarga.Agents.Infrastructure` | `apps/jarga/lib/agents/infrastructure.ex` |

**Verification:** `mix compile --warnings-as-errors` + `mix boundary` for the entire umbrella.

---

### Phase 5: Update `jarga_web` and `jarga_api` boundary configs

Remove `Jarga.Workspaces` and `Jarga.Accounts` from boundary deps. Ensure `Identity` is already listed (it is in both).

| Boundary | File | Change |
|----------|------|--------|
| `JargaWeb` | `apps/jarga_web/lib/jarga_web.ex` (lines 22-42) | Remove `Jarga.Accounts`, `Jarga.Workspaces` from deps |
| `JargaApi` | `apps/jarga_api/lib/jarga_api.ex` (lines 14-23) | Remove `Jarga.Workspaces` from deps |

**Verification:** `mix boundary` passes with no violations.

---

### Phase 6: Delete facades and their tests

| Action | File |
|--------|------|
| Delete | `apps/jarga/lib/workspaces.ex` |
| Delete | `apps/jarga/lib/accounts.ex` |
| Delete | `apps/jarga/test/workspaces_test.exs` |
| Delete | `apps/jarga/test/accounts_test.exs` (if exists) |

**Verification:** Full test suite passes. `mix boundary` has no violations. `mix compile --warnings-as-errors` succeeds.

---

### Phase 7: Clean up test fixtures

The `jarga` test fixtures in `apps/jarga/test/support/fixtures/workspaces_fixtures.ex` delegate to Identity's fixtures or call `Jarga.Workspaces` functions. Update them to call `Identity` directly.

| File | Change |
|------|--------|
| `apps/jarga/test/support/fixtures/workspaces_fixtures.ex` | Replace all `Jarga.Workspaces` calls with `Identity` |

Any `jarga_web` or `jarga_api` test helpers that alias `Jarga.Workspaces` or `Jarga.Accounts` must also be updated.

**Verification:** Full test suite passes across all apps.

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Function signature mismatch** between facade and Identity | Compile error, easy to detect | All facade functions are pure delegation — signatures are identical. Verify with `mix compile`. |
| **Boundary violations after removal** | Compile warnings/errors | Run `mix boundary` after each phase. The boundary library catches cross-boundary calls at compile time. |
| **Auth regression** (Phase 2) | Users unable to log in | Run full auth test suite. Manual smoke test: login, register, magic link, password change, email change. |
| **Implicit coupling** through test fixtures | Test failures | Phase 7 explicitly addresses fixture updates. Run full suite after every phase. |
| **Other apps importing facade indirectly** | Missed callers | Grep for `Jarga.Workspaces` and `Jarga.Accounts` across entire project after deletion to confirm zero references. |

---

## Verification Checklist (Run After Each Phase)

```bash
# Compile with warnings as errors
mix compile --warnings-as-errors

# Check boundary violations
mix boundary

# Run full test suite
mix test

# Grep for any remaining references (run after Phase 6)
grep -r "Jarga\.Workspaces" apps/ --include="*.ex" --include="*.exs"
grep -r "Jarga\.Accounts" apps/ --include="*.ex" --include="*.exs"
```

---

## Relationship to Service Evolution Plan

This work corresponds to **Phase 0** in the service evolution plan:

> | Phase | Extraction | Rationale |
> |---|---|---|
> | **0** | **Remove delegation facades** | Clean up `Jarga.Accounts`/`Jarga.Workspaces`; update all callers to use `Identity` directly |

Completing this phase:
- Establishes `Identity` as the single source of truth for workspace/account operations
- Removes indirection that would complicate future extractions
- Makes the dependency graph cleaner for Phase 1 (Notifications extraction) through Phase 4 (Components extraction)
- Validates that all 13 internal jarga modules can depend on `Identity` directly without boundary violations

---

## Estimated Effort

| Phase | Description | Estimate |
|-------|-------------|----------|
| 1 | Migrate `jarga_web` workspace callers | ~1 hour |
| 2 | Migrate `jarga_web` account callers | ~1 hour |
| 3 | Migrate `jarga_api` workspace callers | ~30 min |
| 4 | Migrate `jarga` internal callers + boundaries | ~2 hours |
| 5 | Update web/api boundary configs | ~15 min |
| 6 | Delete facades and tests | ~15 min |
| 7 | Clean up test fixtures | ~30 min |
| **Total** | | **~5.5 hours** |

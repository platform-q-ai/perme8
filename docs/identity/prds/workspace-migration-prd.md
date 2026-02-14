# PRD: Migrate Workspaces from Jarga to Identity

## Document Metadata

**Document Prepared By**: PRD Agent
**Date Created**: 2026-02-14
**Last Updated**: 2026-02-14
**Version**: 1.0
**Status**: Draft

---

## 1. Executive Summary

**Feature Name**: Workspace Migration to Identity

**Problem Statement**: Workspaces and membership currently live in the `jarga` app (`Jarga.Workspaces`), but they are fundamentally about identity and access control — they determine WHO can access WHAT. This creates a cross-cutting dependency where `jarga` owns both business domain logic (documents, projects, agents) AND the tenancy/access layer. The `identity` app already handles users, authentication, sessions, and API keys, but workspaces — the unit of multi-tenancy — are stranded in the wrong bounded context.

**Business Value**: Moving workspaces into `identity` makes multi-tenancy a first-class identity concern. This:
1. Creates a clean dependency graph: `identity` (users + workspaces + tenancy) -> `jarga` (business domain scoped by workspace_id)
2. Unifies all access-related concepts (users, auth, API keys, workspaces, memberships, roles) in one bounded context
3. Enables the `Scope` struct to carry both user AND workspace context through the request lifecycle
4. Eliminates an architectural boundary violation where API keys in `identity` already reference workspace slugs via `workspace_access` but have no first-class workspace entity

**Target Users**: This is an internal architectural refactoring. End users are not directly affected — all existing functionality is preserved. The primary beneficiaries are:
- **Developers** who reason about the codebase and its boundaries
- **The architect agent** who plans feature implementation across bounded contexts
- **Future features** that need unified identity + tenancy context (e.g., workspace-scoped API keys, SSO per workspace, workspace-level audit logs)

---

## 2. User Stories

**Primary User Story**:
```
As a developer working on the jarga platform,
I want workspaces and membership to live in the identity bounded context,
so that all access-related concepts (users, auth, workspaces, roles) are unified
and the dependency graph between apps is clean.
```

**Additional User Stories**:

- As a developer, I want `Identity.Domain.Scope` to carry workspace context alongside user context, so that controllers and LiveViews can pass a single scope struct that encapsulates the full identity + tenancy context.

- As a developer, I want `Jarga.Workspaces` to remain as a thin delegation facade (like `Jarga.Accounts`), so that existing code across `jarga`, `jarga_web`, and `jarga_api` continues to work without requiring a big-bang rewrite of all call sites.

- As a developer, I want the PermissionsPolicy to be split so that workspace/membership permissions live in Identity and domain-specific permissions (projects, documents) stay in Jarga, so that each bounded context owns the permissions relevant to its domain.

- As a developer, I want the workspace database tables to be formally owned by `Identity.Repo`, so that all identity-related data (users, tokens, API keys, workspaces, workspace members) is under a single repository.

---

## 3. Functional Requirements

### Must Have (P0)

1. **Move workspace domain entities to Identity** — `Workspace` and `WorkspaceMember` pure domain structs move from `Jarga.Workspaces.Domain.Entities` to `Identity.Domain.Entities`. The `SlugGenerator` domain service also moves.

2. **Move workspace infrastructure to Identity** — Schemas (`WorkspaceSchema`, `WorkspaceMemberSchema`), repositories (`WorkspaceRepository`, `MembershipRepository`), and queries move from `Jarga.Workspaces.Infrastructure` to `Identity.Infrastructure`.

3. **Move workspace application layer to Identity** — Use cases (`InviteMember`, `RemoveMember`, `ChangeMemberRole`, `CreateNotificationsForPendingInvitations`), policies (`MembershipPolicy`), services (`NotificationService`), and behaviours move to `Identity.Application`.

4. **Move workspace/membership permissions to Identity** — The subset of `PermissionsPolicy` covering `:view_workspace`, `:edit_workspace`, `:delete_workspace`, and `:invite_member` moves to `Identity.Application.Policies.WorkspacePermissionsPolicy` (or similar). Domain-specific permissions (`:edit_project`, `:create_document`, etc.) remain in Jarga as `Jarga.Domain.Policies.DomainPermissionsPolicy`.

5. **Leave `Jarga.Workspaces` as thin facade** — Convert `Jarga.Workspaces` to a delegation module (using `defdelegate`) that forwards all calls to `Identity`, matching the `Jarga.Accounts` pattern. This ensures ~100 existing references across `jarga`, `jarga_web`, and `jarga_api` continue to work.

6. **Formalize workspace tables under `Identity.Repo`** — The `workspaces` and `workspace_members` tables already use `Identity.Repo` at runtime. Formalize this by moving the Ecto migration files to `apps/identity/priv/repo/migrations/`.

7. **Expand `Identity.Domain.Scope`** — Add a `workspace` field to the Scope struct: `%Scope{user: user, workspace: workspace}`. This enables controllers and LiveViews to carry workspace context through the request lifecycle.

8. **Update Identity boundary exports** — Export `Identity.Domain.Entities.Workspace`, `Identity.Domain.Entities.WorkspaceMember`, and the workspace permissions policy from the Identity boundary so other apps can use them.

9. **Move workspace notifiers to Identity** — `EmailAndPubSubNotifier`, `PubSubNotifier`, and `WorkspaceNotifier` move to `Identity.Infrastructure.Notifiers`.

10. **Update all existing tests** — Move workspace tests from `apps/jarga/test/` to `apps/identity/test/` and update module references. Ensure the thin facade in Jarga has its own minimal test coverage verifying delegation.

### Should Have (P1)

1. **Gradually migrate call sites from `Jarga.Workspaces` to `Identity`** — While the facade provides backward compatibility, new code should call `Identity` directly. Document this convention.

2. **Update jarga_web LiveViews to call Identity** — Workspace LiveViews (`Index`, `New`, `Edit`, `Show`) in `jarga_web` should be updated to call `Identity` instead of `Jarga.Workspaces` where practical. The facade ensures this isn't blocking.

3. **Update jarga_api controllers to call Identity** — The `WorkspaceApiController` and API use cases (`ListAccessibleWorkspaces`, `GetWorkspaceWithDetails`) should be updated to call `Identity` for workspace operations.

4. **Update Jarga schemas with `belongs_to` associations** — `ProjectSchema`, `DocumentSchema`, `NoteSchema`, `SessionSchema`, and `WorkspaceAgentJoinSchema` all have `belongs_to(:workspace, Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema)`. These need to reference the new Identity module path.

### Nice to Have (P2)

1. **Remove `Jarga.Workspaces` facade entirely** — Once all call sites have migrated to `Identity`, delete the facade. This mirrors the intended endgame for `Jarga.Accounts`.

2. **Move workspace LiveViews from `jarga_web` to `identity`** — If workspace management views (create, edit, list, show) are considered identity-level concerns, they could move to `IdentityWeb`. This is a separate decision from the backend migration.

3. **Add workspace context to PubSub topic naming** — Standardize PubSub topics to use Identity's namespace for workspace events.

---

## 4. User Workflows

### Workflow 1: Developer calls workspace function (post-migration)

1. `jarga_web` LiveView calls `Jarga.Workspaces.list_workspaces_for_user(user)`
2. `Jarga.Workspaces` facade delegates to `Identity.list_workspaces_for_user(user)`
3. `Identity` context queries via `Identity.Infrastructure.Queries.WorkspaceQueries`
4. Result returned as `Identity.Domain.Entities.Workspace` structs
5. LiveView renders workspace list (no user-visible change)

### Workflow 2: New code calls Identity directly

1. New LiveView or API endpoint calls `Identity.create_workspace(user, attrs)`
2. `Identity` delegates to `Identity.Application.UseCases.CreateWorkspace.execute/2`
3. Use case generates slug via `Identity.Domain.SlugGenerator`
4. Use case creates workspace and owner member via `Identity.Repo`
5. Returns `{:ok, %Identity.Domain.Entities.Workspace{}}`

### Workflow 3: Permission check with split policy

1. LiveView needs to check if user can edit a project in a workspace
2. Calls `Jarga.Domain.Policies.DomainPermissionsPolicy.can?(:member, :edit_project, owns_resource: true)`
3. Domain policy returns `true`/`false` based on role + ownership
4. Separately, workspace-level access is checked via `Identity.Application.Policies.WorkspacePermissionsPolicy.can?(:member, :edit_workspace)`

### Workflow 4: Scope carries workspace context

1. User navigates to `/app/workspaces/my-workspace/projects`
2. LiveView mount resolves workspace by slug via `Identity.get_workspace_by_slug(user, slug)`
3. Scope is constructed: `%Scope{user: user, workspace: workspace}`
4. Scope is passed to Jarga domain operations for authorization
5. Jarga use cases use `scope.workspace.id` to scope queries

---

## 5. Data Requirements

### Data to Capture (moved, not new)

| Field | Type | Required | Table | Notes |
|-------|------|----------|-------|-------|
| workspace.id | binary_id | Yes | workspaces | Auto-generated |
| workspace.name | string | Yes | workspaces | Min 1 char |
| workspace.slug | string | Yes | workspaces | Unique, auto-generated from name |
| workspace.description | string | No | workspaces | Optional |
| workspace.color | string | No | workspaces | Hex color for UI |
| workspace.is_archived | boolean | Yes | workspaces | Default false |
| member.id | binary_id | Yes | workspace_members | Auto-generated |
| member.email | string | Yes | workspace_members | Case-insensitive |
| member.role | enum | Yes | workspace_members | :owner, :admin, :member, :guest |
| member.workspace_id | binary_id | Yes | workspace_members | FK to workspaces |
| member.user_id | binary_id | No | workspace_members | FK to users, nil for pending |
| member.invited_by | binary_id | No | workspace_members | FK to users |
| member.invited_at | utc_datetime | No | workspace_members | When invited |
| member.joined_at | utc_datetime | No | workspace_members | When accepted, nil if pending |

### Data Relationships

- `Workspace` has many `WorkspaceMember` (via workspace_id)
- `WorkspaceMember` belongs to `Workspace` (workspace_id FK)
- `WorkspaceMember` belongs to `User` (user_id FK) — user is in Identity
- `WorkspaceMember` belongs to `User` as inviter (invited_by FK)
- `Project` belongs to `Workspace` (workspace_id FK) — stays in Jarga, references Identity schema
- `Document` belongs to `Workspace` (workspace_id FK) — stays in Jarga, references Identity schema
- `ChatSession` belongs to `Workspace` (workspace_id FK) — stays in Jarga
- `ApiKey` has `workspace_access` field (array of slugs) — already in Identity

### Data Migration

No data migration is needed. The `workspaces` and `workspace_members` tables stay in the same database. The change is purely in code ownership — which app's Repo and schemas manage these tables. The tables already use `Identity.Repo` at runtime.

Migration file ownership moves from `apps/jarga/priv/repo/migrations/` to `apps/identity/priv/repo/migrations/` for workspace-related migrations.

---

## 6. Technical Requirements

### Architecture Considerations

**Affected Layers**:
- [x] **Domain Layer** — Move `Workspace`, `WorkspaceMember` entities and `SlugGenerator` to Identity. Split `PermissionsPolicy`. Expand `Scope` struct.
- [x] **Application Layer** — Move use cases (`InviteMember`, `RemoveMember`, `ChangeMemberRole`, `CreateNotificationsForPendingInvitations`), policies (`MembershipPolicy`, workspace subset of `PermissionsPolicy`), services (`NotificationService`), and behaviours to Identity.
- [x] **Infrastructure Layer** — Move schemas, repositories, queries, and notifiers to Identity. Update `belongs_to` associations in Jarga schemas.
- [x] **Interface Layer** — Update `jarga_web` LiveViews and `jarga_api` controllers to use Identity (via facade initially, directly later). No user-visible UI changes.

### Affected Boundaries (Phoenix Contexts)

| Context | Why Affected | Changes Needed | Complexity |
|---------|-------------|----------------|------------|
| `Identity` | Receives all workspace modules | Add workspace domain/app/infra layers, expand exports, expand Scope | High |
| `Jarga.Workspaces` | Becomes thin facade | Replace all internal logic with `defdelegate` to Identity | Medium |
| `Jarga.Workspaces.Domain` | Modules move out | Remove boundary, contents move to Identity | Medium |
| `Jarga.Workspaces.Application` | Modules move out | Remove boundary, contents move to Identity | Medium |
| `Jarga.Workspaces.Infrastructure` | Modules move out | Remove boundary, contents move to Identity | Medium |
| `Jarga.Projects` | References workspace schemas/policies | Update aliases to Identity paths | Low |
| `Jarga.Documents` | References workspace schemas/policies | Update aliases to Identity paths | Low |
| `Jarga.Chat` | References workspace schema | Update `belongs_to` alias | Low |
| `Jarga.Agents` | Has workspace_agent_join | Update workspace schema reference | Low |
| `Jarga.Notes` | References workspace schema | Update `belongs_to` alias | Low |
| `Jarga.Notifications` | WorkspaceInvitationSubscriber | No change (uses PubSub, decoupled) | None |
| `JargaWeb` | LiveViews reference Jarga.Workspaces | Works via facade; update aliases to Identity for P1 | Low |
| `JargaApi` | Controllers reference Jarga.Workspaces | Works via facade; update aliases to Identity for P1 | Low |

### Integration Points

**Existing Systems**:

| System/Context | Integration Type | Purpose | Notes |
|---------------|-----------------|---------|-------|
| `Jarga.Projects` | Read | Uses `PermissionsPolicy` for authorization | Must update to use Jarga's domain permissions policy |
| `Jarga.Documents` | Read | Uses `PermissionsPolicy` for authorization | Must update to use Jarga's domain permissions policy |
| `Jarga.Notifications` | Event (PubSub) | Listens to `workspace_invitations` topic | No change — decoupled via PubSub |
| `JargaWeb` LiveViews | Read/Write | Calls `Jarga.Workspaces.*` for CRUD | Works via facade |
| `JargaApi` Controllers | Read | Calls `Jarga.Workspaces.*` for listing | Works via facade |
| `Identity` API Keys | Read | `workspace_access` references workspace slugs | Natural fit — now in same bounded context |

**PubSub Topics** (existing, no changes needed):

- `"workspace_invitations"` — broadcast by `PubSubNotifier` when invitations are created
- `"workspace:#{workspace_id}"` — broadcast for workspace updates (name changes, member joined/removed)
- `"user:#{user_id}"` — broadcast for user-specific events (invitation received)

### Performance Requirements

- **No performance changes expected** — this is a code reorganization, not a functional change
- **Same database queries** — queries move to Identity but execute identically
- **Same Repo** — `Identity.Repo` is already used at runtime; no connection pool changes

### Security Requirements

**Authentication**: No change. Users must be authenticated to access workspace operations.

**Authorization**: 
- [x] Role-based access control (owner, admin, member, guest)
- [x] Workspace membership verification before any workspace operation
- [x] Permission split: Identity owns workspace/membership permissions, Jarga owns domain permissions

**Data Privacy**: No change. Same data, same access patterns, same authorization checks.

---

## 7. Edge Cases & Error Handling

### Edge Case 1: Circular dependency between Identity and Jarga

- **Scenario**: Identity needs to own workspaces, but `InviteMember` use case calls `Jarga.Accounts.get_user_by_email_case_insensitive/1` to look up users.
- **Expected Behavior**: After migration, the use case calls `Identity.get_user_by_email_case_insensitive/1` directly since it's in the same app. The `Jarga.Accounts` dependency is eliminated for workspace operations.
- **Rationale**: This actually simplifies the dependency — workspace use cases no longer need cross-app calls for user lookups.

### Edge Case 2: Jarga schemas referencing Identity schemas

- **Scenario**: `ProjectSchema`, `DocumentSchema`, `NoteSchema`, `SessionSchema` all have `belongs_to(:workspace, Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema)`. After migration, the schema module moves to Identity.
- **Expected Behavior**: Update the `belongs_to` references to `Identity.Infrastructure.Schemas.WorkspaceSchema`. Since Identity already exports its schemas (e.g., `UserSchema` is already referenced by `WorkspaceMemberSchema`), this follows the established pattern.
- **Rationale**: Jarga schemas already reference `Identity.Infrastructure.Schemas.UserSchema` — workspace is the same pattern.

### Edge Case 3: PermissionsPolicy split affects authorization checks

- **Scenario**: `Jarga.Projects.Application.UseCases.CreateProject` currently aliases `Jarga.Workspaces.Application.Policies.PermissionsPolicy` and calls `PermissionsPolicy.can?(:member, :create_project)`.
- **Expected Behavior**: After the split, it aliases the new Jarga-local `DomainPermissionsPolicy` (or similar) that contains project/document permissions. The function signature and return values remain identical.
- **Rationale**: The split is clean because workspace permissions (`:view_workspace`, `:edit_workspace`, `:delete_workspace`, `:invite_member`) and domain permissions (`:create_project`, `:edit_document`, etc.) are already clearly separated in the current policy's function clauses.

### Edge Case 4: Test fixtures across apps

- **Scenario**: `Jarga.WorkspacesFixtures` is used in both `jarga` and `jarga_web` tests. After migration, workspace creation functions should call Identity.
- **Expected Behavior**: Create `Identity.WorkspacesFixtures` in `apps/identity/test/support/`. Update `Jarga.WorkspacesFixtures` to delegate to Identity fixtures (or keep as thin wrapper). `jarga_web` test helpers already import `Jarga.WorkspacesFixtures`, which continues to work via delegation.
- **Rationale**: Follows the same pattern as `Jarga.AccountsFixtures` which delegates to Identity for user creation.

### Edge Case 5: CreateNotificationsForPendingInvitations crosses into Notifications context

- **Scenario**: The `CreateNotificationsForPendingInvitations` use case broadcasts PubSub events that the `Jarga.Notifications` subscriber listens to. After moving to Identity, Identity would broadcast events that a Jarga subscriber consumes.
- **Expected Behavior**: No functional change. The use case moves to Identity but still broadcasts to the same PubSub topics (`"workspace_invitations"`). The Notifications subscriber in Jarga doesn't care which app publishes the event.
- **Rationale**: PubSub is inherently decoupled — publishers and subscribers don't need to know about each other.

### Edge Case 6: Boundary declarations must be updated across all affected apps

- **Scenario**: Multiple `use Boundary` declarations reference `Jarga.Workspaces`, `Jarga.Workspaces.Domain`, `Jarga.Workspaces.Application`, and `Jarga.Workspaces.Infrastructure`. These must be updated to reference Identity or the new Jarga facade.
- **Expected Behavior**: Remove old workspace boundary modules. Update `deps` and `exports` in Identity's boundary. Update all Jarga contexts (`Projects`, `Documents`, `Agents`, `Notes`, `Chat`) to depend on Identity instead of `Jarga.Workspaces`.
- **Rationale**: The Boundary library enforces compile-time checks. Stale references will cause compilation failures, making this a hard requirement.

---

## 8. Validation & Testing Criteria

### Acceptance Criteria

- [ ] **AC1**: All workspace domain entities (`Workspace`, `WorkspaceMember`) exist in `Identity.Domain.Entities` and are exported from the Identity boundary. Verify by: `mix compile` passes with no boundary warnings.

- [ ] **AC2**: All workspace infrastructure (schemas, repos, queries, notifiers) exists in `Identity.Infrastructure` and uses `Identity.Repo`. Verify by: Workspace CRUD operations work via `Identity` context module.

- [ ] **AC3**: All workspace application logic (use cases, policies, services, behaviours) exists in `Identity.Application`. Verify by: Invite, remove, change role use cases execute successfully through `Identity`.

- [ ] **AC4**: `Jarga.Workspaces` is a thin delegation facade matching the `Jarga.Accounts` pattern. Verify by: All existing calls to `Jarga.Workspaces.*` from `jarga`, `jarga_web`, and `jarga_api` continue to work without modification.

- [ ] **AC5**: `Identity.Domain.Scope` has a `workspace` field (`%Scope{user: user, workspace: workspace}`). Verify by: LiveViews can construct and use `Scope` with workspace context.

- [ ] **AC6**: PermissionsPolicy is split — workspace permissions in Identity, domain permissions in Jarga. Verify by: `mix compile` passes; project and document authorization tests pass; workspace authorization tests pass.

- [ ] **AC7**: `mix boundary` passes with zero violations across all apps. Verify by: `mix compile --warnings-as-errors` in the umbrella root.

- [ ] **AC8**: All existing workspace tests pass after migration. Verify by: `mix test` in both `apps/identity` and `apps/jarga` with full green suite.

- [ ] **AC9**: All existing `jarga_web` workspace LiveView tests pass. Verify by: `mix test` in `apps/jarga_web` with full green suite.

- [ ] **AC10**: All existing `jarga_api` workspace controller tests pass. Verify by: `mix test` in `apps/jarga_api` with full green suite.

- [ ] **AC11**: Workspace migration files are owned by `apps/identity/priv/repo/migrations/`. Verify by: `mix ecto.migrate` executes migrations from the identity app.

### Test Scenarios

**Happy Path Tests**:

1. **Scenario**: Create workspace through Identity facade
   **Expected Result**: `Identity.create_workspace(user, attrs)` returns `{:ok, %Identity.Domain.Entities.Workspace{}}`

2. **Scenario**: Create workspace through Jarga facade (backward compat)
   **Expected Result**: `Jarga.Workspaces.create_workspace(user, attrs)` delegates to Identity and returns same result

3. **Scenario**: Invite member through Identity
   **Expected Result**: `Identity.invite_member(inviter, workspace_id, email, role)` returns `{:ok, {:invitation_sent, member}}`

4. **Scenario**: Check workspace permission via Identity policy
   **Expected Result**: `Identity.Application.Policies.WorkspacePermissionsPolicy.can?(:admin, :edit_workspace)` returns `true`

5. **Scenario**: Check project permission via Jarga domain policy
   **Expected Result**: `Jarga.Domain.Policies.DomainPermissionsPolicy.can?(:member, :create_project)` returns `true`

6. **Scenario**: Scope carries workspace context
   **Expected Result**: `%Identity.Domain.Scope{user: user, workspace: workspace}` is constructable and usable

**Edge Case Tests**:

1. **Scenario**: Jarga schema references Identity workspace schema
   **Expected Result**: `ProjectSchema` `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)` compiles and associations load correctly

2. **Scenario**: Permissions policy split doesn't break authorization
   **Expected Result**: All existing permission test cases pass against the split policies

**Boundary Tests**:

1. **Scenario**: Identity does not depend on Jarga for workspace operations
   **Expected Result**: `mix compile` shows no Jarga dependencies in Identity workspace modules

2. **Scenario**: Jarga depends on Identity for workspace data
   **Expected Result**: Jarga contexts list `Identity` in their boundary `deps`

---

## 9. Dependencies & Assumptions

### Dependencies

**Internal Dependencies**:
- `Identity` app must be fully functional (it is — Phase 7 from the previous refactor is complete with `Identity.Repo`)
- `Jarga.Accounts` facade pattern provides the blueprint for `Jarga.Workspaces` facade
- Boundary library enforces architectural rules at compile time

**Data Dependencies**:
- `workspaces` and `workspace_members` tables exist in the database (they do)
- `Identity.Repo` connects to the same database as `Jarga.Repo` (it does)
- No data migration is required — only code ownership changes

### Assumptions

- **Assumption 1**: All workspace operations already use `Identity.Repo` at runtime
  - **Impact if wrong**: If some operations still use `Jarga.Repo`, they need to be identified and switched. From codebase research, this is confirmed — `Jarga.Workspaces` and `MembershipRepository` both alias `Identity.Repo`.

- **Assumption 2**: The `Jarga.Accounts` facade pattern is the accepted approach for gradual migration
  - **Impact if wrong**: If the team prefers a big-bang approach (rewrite all call sites at once), the facade phase can be skipped, but this increases risk.

- **Assumption 3**: The PermissionsPolicy split at the workspace/domain boundary is clean
  - **Impact if wrong**: If some permission checks span both workspace and domain concerns (e.g., "can this role invite members AND create projects?"), the split may need a coordination layer. From analysis, the permission clauses are cleanly separable.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Boundary violations after migration | Medium | Medium | Incremental migration with `mix compile --warnings-as-errors` after each phase |
| Test failures from module path changes | Medium | Low | Facade ensures runtime compatibility; update test imports incrementally |
| Circular dependency between Identity and Jarga | Low | High | InviteMember use case currently calls Jarga.Accounts — after migration it calls Identity directly, eliminating the cross-dependency |
| Migration file confusion (which app owns which migrations) | Low | Low | Document clearly; move relevant migration files |
| PermissionsPolicy split introduces authorization gaps | Low | High | Comprehensive test suite already covers all role/action combinations; run full suite after split |

---

## 10. Implementation Considerations

### Precedent: Identity App Extraction (docs/specs/identity-app-refactor.md)

The `identity` app was previously extracted from `jarga` following a 7-phase approach documented in `docs/specs/identity-app-refactor.md` (852 lines). The same phased pattern should be followed here:

| Phase | Identity Extraction (Precedent) | Workspace Migration (This PRD) |
|-------|-------------------------------|-------------------------------|
| 1 | Create Identity app structure | Already exists — add workspace subdirectories |
| 2 | Move domain layer | Move Workspace, WorkspaceMember, SlugGenerator entities to Identity |
| 3 | Move application layer | Move use cases, policies, services, behaviours to Identity |
| 4 | Move infrastructure layer | Move schemas, repos, queries, notifiers to Identity |
| 5 | Move web layer | N/A — workspace LiveViews stay in jarga_web (P2 decision) |
| 6 | Cleanup — remove deprecated wrappers | Convert Jarga.Workspaces to thin facade |
| 7 | Create Identity.Repo | Already done — formalize migration file ownership |

### Phasing Strategy

**Phase 1: Domain Layer Migration**
- Move `Workspace`, `WorkspaceMember` entities to `Identity.Domain.Entities`
- Move `SlugGenerator` to `Identity.Domain`
- Expand `Identity.Domain.Scope` to include `workspace` field
- Split `PermissionsPolicy` — workspace permissions to Identity, domain permissions stay in Jarga
- Move `MembershipPolicy` to Identity
- Update boundary declarations
- Run `mix compile --warnings-as-errors` and `mix test`

**Phase 2: Infrastructure Layer Migration**
- Move `WorkspaceSchema`, `WorkspaceMemberSchema` to `Identity.Infrastructure.Schemas`
- Move `WorkspaceRepository`, `MembershipRepository` to `Identity.Infrastructure.Repositories`
- Move `Queries` to `Identity.Infrastructure.Queries.WorkspaceQueries`
- Move notifiers (`EmailAndPubSubNotifier`, `PubSubNotifier`, `WorkspaceNotifier`) to `Identity.Infrastructure.Notifiers`
- Update `belongs_to` associations in Jarga schemas (Projects, Documents, Notes, Chat, Agents)
- Move workspace migration files to `apps/identity/priv/repo/migrations/`
- Run `mix compile --warnings-as-errors` and `mix test`

**Phase 3: Application Layer Migration**
- Move use cases (`InviteMember`, `RemoveMember`, `ChangeMemberRole`, `CreateNotificationsForPendingInvitations`, `UseCase`) to `Identity.Application.UseCases`
- Move behaviours to `Identity.Application.Behaviours`
- Move `NotificationService` to `Identity.Application.Services`
- Update `Identity` context module with workspace public API functions
- Run `mix compile --warnings-as-errors` and `mix test`

**Phase 4: Facade & Cleanup**
- Convert `Jarga.Workspaces` to thin delegation facade (defdelegate to Identity)
- Remove old `Jarga.Workspaces.Domain`, `Jarga.Workspaces.Application`, `Jarga.Workspaces.Infrastructure` boundary modules
- Update `Jarga.WorkspacesFixtures` to delegate to Identity fixtures
- Update Identity boundary exports
- Remove stale layer boundary modules from Jarga
- Run full test suite across all apps: `mix test` at umbrella root

**Phase 5: Propagate (P1 items)**
- Update `jarga_web` LiveViews to alias `Identity` instead of `Jarga.Workspaces` (optional — facade works)
- Update `jarga_api` controllers similarly
- Update Jarga contexts (`Projects`, `Documents`) to use the split permission policies
- Final `mix boundary` verification

### Backward Compatibility

The facade pattern ensures **zero breaking changes** during migration:

```elixir
# apps/jarga/lib/workspaces.ex (after migration)
defmodule Jarga.Workspaces do
  @moduledoc """
  Facade for workspace operations.
  
  This module delegates workspace operations to the `Identity` app.
  Direct usage of `Identity` module is preferred for new code.
  """
  
  use Boundary,
    top_level?: true,
    deps: [Identity],
    exports: []

  # All existing public functions become delegations
  defdelegate list_workspaces_for_user(user), to: Identity
  defdelegate create_workspace(user, attrs), to: Identity
  defdelegate get_workspace(user, id), to: Identity
  defdelegate get_workspace!(user, id), to: Identity
  defdelegate get_workspace_by_slug(user, slug), to: Identity
  defdelegate get_workspace_by_slug!(user, slug), to: Identity
  defdelegate get_workspace_and_member_by_slug(user, slug), to: Identity
  defdelegate update_workspace(user, workspace_id, attrs), to: Identity
  # ... (all ~25 public functions)
end
```

### File Inventory

**Files moving FROM `apps/jarga/` to `apps/identity/`** (26 files):

```
# Domain Layer (3 files)
lib/workspaces/domain/entities/workspace.ex
lib/workspaces/domain/entities/workspace_member.ex
lib/workspaces/domain/slug_generator.ex

# Application Layer (10 files)
lib/workspaces/application/use_cases/invite_member.ex
lib/workspaces/application/use_cases/remove_member.ex
lib/workspaces/application/use_cases/change_member_role.ex
lib/workspaces/application/use_cases/create_notifications_for_pending_invitations.ex
lib/workspaces/application/use_cases/use_case.ex
lib/workspaces/application/policies/permissions_policy.ex  (workspace subset)
lib/workspaces/application/policies/membership_policy.ex
lib/workspaces/application/services/notification_service.ex
lib/workspaces/application/behaviours/membership_repository_behaviour.ex
lib/workspaces/application/behaviours/notification_service_behaviour.ex
lib/workspaces/application/behaviours/pub_sub_notifier_behaviour.ex
lib/workspaces/application/behaviours/queries_behaviour.ex

# Infrastructure Layer (8 files)
lib/workspaces/infrastructure/schemas/workspace_schema.ex
lib/workspaces/infrastructure/schemas/workspace_member_schema.ex
lib/workspaces/infrastructure/repositories/workspace_repository.ex
lib/workspaces/infrastructure/repositories/membership_repository.ex
lib/workspaces/infrastructure/queries/queries.ex
lib/workspaces/infrastructure/notifiers/email_and_pubsub_notifier.ex
lib/workspaces/infrastructure/notifiers/pubsub_notifier.ex
lib/workspaces/infrastructure/notifiers/workspace_notifier.ex

# Boundary modules removed (3 files)
lib/workspaces/domain.ex
lib/workspaces/application.ex
lib/workspaces/infrastructure.ex
```

**Files modified in `apps/jarga/`** (~15 files):

```
lib/workspaces.ex                    → becomes thin facade
lib/projects.ex                      → update boundary deps
lib/documents.ex                     → update boundary deps
lib/notes.ex                         → update boundary deps
lib/jarga/domain.ex                  → remove workspace references
lib/jarga/application_layer.ex       → remove workspace references
lib/jarga/infrastructure_layer.ex    → remove workspace references
lib/projects/infrastructure/schemas/project_schema.ex → update belongs_to
lib/documents/infrastructure/schemas/document_schema.ex → update belongs_to
lib/documents/notes/infrastructure/schemas/note_schema.ex → update belongs_to
lib/chat/infrastructure/schemas/session_schema.ex → update belongs_to
lib/agents/infrastructure/schemas/workspace_agent_join_schema.ex → update belongs_to
lib/projects/application/use_cases/create_project.ex → update PermissionsPolicy alias
lib/projects/application/use_cases/delete_project.ex → update PermissionsPolicy alias
lib/documents/application/use_cases/create_document.ex → update PermissionsPolicy alias
```

**Files modified in `apps/identity/`** (~5 files):

```
lib/identity.ex                      → add workspace public API functions
lib/identity/domain/scope.ex         → add workspace field
lib/identity/application_layer.ex    → add workspace use cases/services/behaviours
mix.exs                              → add slugy dependency if needed
```

---

## 11. Success Metrics

### Technical Metrics

- **Boundary compliance**: `mix compile --warnings-as-errors` passes with zero boundary violations across all 6 apps
- **Test suite**: 100% existing tests pass after migration (zero regressions)
- **Facade coverage**: All public functions in `Jarga.Workspaces` delegate to `Identity`
- **Dependency graph**: Identity has zero dependencies on Jarga for workspace operations (eliminating the current cross-dependency where `InviteMember` calls `Jarga.Accounts`)
- **Code ownership**: All workspace-related source files live under `apps/identity/lib/`

---

## 12. Out of Scope

- **Moving workspace LiveViews to IdentityWeb** — Workspace CRUD views stay in `jarga_web` for now. They can be moved later as a P2 enhancement.
- **Creating new workspace features** — This PRD covers only the migration of existing functionality. No new features (e.g., workspace billing, workspace-level settings, workspace deletion cascade changes).
- **Renaming database tables** — The `workspaces` and `workspace_members` tables keep their names. No Ecto migration needed for renaming.
- **Changing the permission model** — The RBAC model (owner/admin/member/guest) is preserved exactly. We're only splitting WHERE the policy code lives.
- **Migrating PubSub topic naming** — Existing topic strings (`"workspace:#{id}"`, `"user:#{id}"`, `"workspace_invitations"`) are preserved.
- **Removing the Jarga.Workspaces facade** — The facade stays indefinitely for backward compatibility. Removal is a future P2 decision.
- **Removing the Jarga.Accounts facade** — Out of scope; separate concern.

---

## 13. Future Considerations

- **Workspace-scoped API keys**: With workspaces in Identity alongside API keys, future work can tightly integrate workspace_access validation with workspace membership checks — no cross-app calls needed.
- **SSO per workspace**: Workspace-level authentication providers become natural extensions of the Identity bounded context.
- **Workspace-level audit logging**: Identity can own audit trails for both user and workspace operations.
- **Scope-based authorization middleware**: With `%Scope{user, workspace}`, a single plug/hook can resolve both user and workspace context, simplifying LiveView and controller authorization.
- **Remove Jarga.Accounts and Jarga.Workspaces facades**: Once all call sites have migrated to `Identity`, these facades can be deleted.

---

## 14. Codebase Context

### Existing Patterns

**Precedent — Identity Extraction**:
- Located in: `docs/specs/identity-app-refactor.md` (852 lines)
- Pattern: 7-phase extraction from `Jarga.Accounts` to `Identity` app
- Key insight: Thin facade (`Jarga.Accounts`) left in place for backward compatibility
- Key insight: `Identity.Repo` created with own migrations for self-contained data ownership

**Facade Pattern — Jarga.Accounts**:
- Located in: `apps/jarga/lib/accounts.ex`
- Pattern: Pure `defdelegate` module forwarding all calls to `Identity`
- Boundary: `deps: [Identity], exports: []`
- This is the exact pattern `Jarga.Workspaces` will follow

**Clean Architecture Layers**:
- Located in: `docs/architecture/bounded_context_structure.md`
- Pattern: Domain → Application → Infrastructure with Boundary enforcement
- Each context has `domain.ex`, `application.ex`, `infrastructure.ex` boundary modules

### Available Infrastructure in Identity

**Already exists** — ready to receive workspace modules:

| Module | Purpose | Can Leverage |
|--------|---------|-------------|
| `Identity.Repo` | Database access | Yes — workspace operations already use it |
| `Identity.Mailer` | Email delivery | Yes — workspace notifiers need email |
| `Identity.Domain.Scope` | Caller context | Yes — will be expanded with workspace field |
| `Identity.Domain.Entities.User` | User entity | Yes — workspace operations reference users |
| `Identity.Infrastructure.Schemas.UserSchema` | User DB schema | Yes — WorkspaceMemberSchema already references it |
| `Identity.ApplicationLayer` | Layer documentation | Yes — will be updated with workspace use cases |
| `Identity.OTPApp` | OTP supervisor | No change needed — Identity.Repo already started |

### Key Reference Documents

- `docs/specs/identity-app-refactor.md` — Previous extraction spec (852 lines, 7 phases)
- `docs/architecture/bounded_context_structure.md` — Clean Architecture pattern with Boundary
- `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md` — Layer rules, dependency injection, testing
- `docs/PERMISSIONS.md` — Full RBAC permission matrix (4 roles x 14 actions)
- `docs/umbrella_apps.md` — Umbrella project patterns and configuration

---

## 15. Open Questions

All key decisions have been resolved:

- [x] **Database ownership**: Formalize under `Identity.Repo` (already using it at runtime)
- [x] **Permissions split**: Identity owns workspace/membership permissions; Jarga keeps domain permissions
- [x] **Facade strategy**: Thin delegation facade matching `Jarga.Accounts` pattern
- [x] **Scope expansion**: Add `workspace` field to `%Scope{user, workspace}`

No remaining blockers.

---

## 16. Approvals & Sign-Off

- [x] **User/Stakeholder Approval** — Decisions confirmed on all 4 key questions (2026-02-14)
- [ ] **Technical Feasibility Confirmed** — Ready for architect review
- [ ] **Security Review** — Not needed (no new security surfaces; same authorization model)
- [ ] **Ready for Architect Review** — Pending this approval

---

**Recommendation**: This PRD is ready for architect review. The architect should create a TDD implementation plan following the 5-phase approach outlined in Section 10, using the Identity extraction spec (`docs/specs/identity-app-refactor.md`) as the primary reference for the migration pattern.

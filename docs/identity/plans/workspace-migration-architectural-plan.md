# Feature: Workspace Migration from Jarga to Identity

## Overview

Migrate workspace and membership modules from `Jarga.Workspaces` to `Identity`, unifying all access-related concepts (users, auth, API keys, workspaces, memberships, roles) in a single bounded context. The existing `Jarga.Workspaces` module becomes a thin delegation facade (matching the `Jarga.Accounts` pattern) to ensure zero breaking changes.

This is a code reorganization — no database tables are renamed, no data migrates, and all existing functionality is preserved.

## Status: ⏳ In Progress

## UI Strategy

- **LiveView coverage**: N/A (no UI changes — this is a backend migration)
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context**: `Identity` (receives all workspace modules)
- **Secondary context**: `Jarga.Workspaces` (becomes thin facade)
- **Dependencies**: `Jarga.Projects`, `Jarga.Documents`, `Jarga.Chat`, `Jarga.Agents`, `Jarga.Notes` (update schema references + permission policy aliases)
- **Exported entities**: `Identity.Domain.Entities.Workspace`, `Identity.Domain.Entities.WorkspaceMember`
- **Exported schemas**: `Identity.Infrastructure.Schemas.WorkspaceSchema`, `Identity.Infrastructure.Schemas.WorkspaceMemberSchema`
- **Exported policies**: `Identity.Application.Policies.WorkspacePermissionsPolicy`, `Identity.Application.Policies.MembershipPolicy`

## Precedent

This migration follows the exact pattern established by the Identity app extraction (documented in `docs/specs/identity-app-refactor.md`). The `Jarga.Accounts` facade in `apps/jarga/lib/accounts.ex` is the blueprint for `Jarga.Workspaces`.

---

## Phase 1: Domain Layer Migration ✓

Move pure domain entities, policies, and services from `Jarga.Workspaces.Domain` to `Identity.Domain`. Expand `Scope` to carry workspace context. Split `PermissionsPolicy`.

### 1.1 Workspace Entity

- [x] **RED**: Write test `apps/identity/test/identity/domain/entities/workspace_test.exs`
  - Tests: `new/1` creates a Workspace struct with defaults
  - Tests: `from_schema/1` converts an infrastructure schema to domain entity
  - Tests: `validate_name/1` returns `:ok` for valid names, `{:error, :invalid_name}` for empty/nil
  - Tests: `archived?/1` returns correct boolean for archived status
- [x] **GREEN**: Create `apps/identity/lib/identity/domain/entities/workspace.ex`
  - Move from `apps/jarga/lib/workspaces/domain/entities/workspace.ex`
  - Rename module to `Identity.Domain.Entities.Workspace`
  - Update `@moduledoc` references to point to `Identity.Infrastructure.Schemas.WorkspaceSchema`
- [x] **REFACTOR**: Ensure struct fields, types, and functions are identical to the original

### 1.2 WorkspaceMember Entity

- [x] **RED**: Write test `apps/identity/test/identity/domain/entities/workspace_member_test.exs`
  - Tests: `new/1` creates a WorkspaceMember struct
  - Tests: `from_schema/1` converts schema to domain entity
  - Tests: `accepted?/1` returns true when `joined_at` is not nil
  - Tests: `pending?/1` returns true when `joined_at` is nil
  - Tests: `owner?/1` returns true only for `:owner` role
  - Tests: `admin_or_owner?/1` returns true for `:owner` and `:admin`
- [x] **GREEN**: Create `apps/identity/lib/identity/domain/entities/workspace_member.ex`
  - Move from `apps/jarga/lib/workspaces/domain/entities/workspace_member.ex`
  - Rename module to `Identity.Domain.Entities.WorkspaceMember`
- [x] **REFACTOR**: Ensure all type specs and function signatures match original

### 1.3 SlugGenerator Domain Service

- [x] **RED**: Write test `apps/identity/test/identity/domain/services/slug_generator_test.exs`
  - Tests: `generate/3` creates a slug from name via Slugy
  - Tests: `generate/3` appends random suffix when slug already exists
  - Tests: `generate/3` strips trailing hyphens
  - Tests: `generate/3` respects `excluding_id` parameter
- [x] **GREEN**: Create `apps/identity/lib/identity/domain/services/slug_generator.ex`
  - Move from `apps/jarga/lib/workspaces/domain/slug_generator.ex`
  - Rename module to `Identity.Domain.Services.SlugGenerator`
- [x] **REFACTOR**: Verify `slugy` dependency is available in `apps/identity/mix.exs`

### 1.4 MembershipPolicy (Domain Policy)

- [x] **RED**: Write test `apps/identity/test/identity/domain/policies/membership_policy_test.exs`
  - Tests: `valid_invitation_role?/1` allows `:admin`, `:member`, `:guest`, denies `:owner`
  - Tests: `valid_role_change?/1` allows `:admin`, `:member`, `:guest`, denies `:owner`
  - Tests: `can_change_role?/1` denies for `:owner`, allows for all others
  - Tests: `can_remove_member?/1` denies for `:owner`, allows for all others
  - Tests: `allowed_invitation_roles/0` returns `[:admin, :member, :guest]`
  - Tests: `protected_roles/0` returns `[:owner]`
- [x] **GREEN**: Create `apps/identity/lib/identity/domain/policies/membership_policy.ex`
  - Move from `apps/jarga/lib/workspaces/application/policies/membership_policy.ex`
  - Rename module to `Identity.Domain.Policies.MembershipPolicy`
  - Note: This was in Application layer in Jarga but is pure domain logic (no deps) — move to Domain layer in Identity
- [x] **REFACTOR**: Verify policy is pure (no I/O, no Repo)

### 1.5 WorkspacePermissionsPolicy (Split from PermissionsPolicy)

Split the current `Jarga.Workspaces.Application.Policies.PermissionsPolicy` into two policies:
1. **Workspace permissions** → `Identity.Domain.Policies.WorkspacePermissionsPolicy` (moves to Identity)
2. **Domain permissions** → `Jarga.Domain.Policies.DomainPermissionsPolicy` (stays in Jarga)

#### 1.5a Identity: WorkspacePermissionsPolicy

- [x] **RED**: Write test `apps/identity/test/identity/domain/policies/workspace_permissions_policy_test.exs`
  - Tests: `:view_workspace` — all roles return true
  - Tests: `:edit_workspace` — only `:admin` and `:owner` return true
  - Tests: `:delete_workspace` — only `:owner` returns true
  - Tests: `:invite_member` — only `:admin` and `:owner` return true
  - Tests: default deny for unknown actions
- [x] **GREEN**: Create `apps/identity/lib/identity/domain/policies/workspace_permissions_policy.ex`
  - Module: `Identity.Domain.Policies.WorkspacePermissionsPolicy`
  - Extract workspace/membership permission clauses from current `PermissionsPolicy`:
    - `:view_workspace`, `:edit_workspace`, `:delete_workspace`, `:invite_member`
  - Same `can?/3` function signature
- [x] **REFACTOR**: Ensure no overlap with domain permissions; both policies cover disjoint action sets

#### 1.5b Jarga: DomainPermissionsPolicy

- [x] **RED**: Write test `apps/jarga/test/jarga/domain/policies/domain_permissions_policy_test.exs`
  - Tests: All project permissions (`:view_project`, `:create_project`, `:edit_project`, `:delete_project`) with role/ownership combinations
  - Tests: All document permissions (`:view_document`, `:create_document`, `:edit_document`, `:delete_document`, `:pin_document`) with role/ownership/visibility combinations
  - Tests: default deny for unknown actions
  - Tests: Exact same behavior as current PermissionsPolicy for project/document actions
- [x] **GREEN**: Create `apps/jarga/lib/jarga/domain/policies/domain_permissions_policy.ex`
  - Module: `Jarga.Domain.Policies.DomainPermissionsPolicy`
  - Extract project/document permission clauses from current `PermissionsPolicy`
  - Same `can?/3` function signature
- [x] **REFACTOR**: Verify every existing permission test case passes against the split policies

### 1.6 Expand Identity.Domain.Scope

- [x] **RED**: Update test `apps/identity/test/identity/domain/scope_test.exs`
  - Tests: `%Scope{user: user, workspace: nil}` is the default (backward compatible)
  - Tests: `%Scope{user: user, workspace: workspace}` carries workspace context
  - Tests: `for_user/1` still works (sets user, workspace defaults to nil)
  - Tests: `for_user_and_workspace/2` sets both user and workspace
- [x] **GREEN**: Modify `apps/identity/lib/identity/domain/scope.ex`
  - Add `workspace: nil` to `defstruct`
  - Add `for_user_and_workspace/2` function
  - Keep `for_user/1` backward compatible (workspace defaults to nil)
- [x] **REFACTOR**: Ensure existing Scope tests still pass

### Phase 1 Validation

- [x] All new Identity domain tests pass (`mix test apps/identity/test/identity/domain/`)
- [x] All new Jarga domain permissions tests pass
- [x] Domain tests run in milliseconds (no I/O, `async: true`)
- [x] No boundary violations (`mix compile --warnings-as-errors`)

---

## Phase 2: Infrastructure Layer Migration ✓

Move schemas, repositories, queries, and notifiers from `Jarga.Workspaces.Infrastructure` to `Identity.Infrastructure`. Update cross-context schema references.

### 2.1 WorkspaceSchema

- [x] **RED**: Write test `apps/identity/test/identity/infrastructure/schemas/workspace_schema_test.exs`
  - Tests: `changeset/2` validates required fields (`:name`, `:slug`)
  - Tests: `changeset/2` validates name minimum length
  - Tests: `changeset/2` enforces slug uniqueness constraint
  - Tests: `to_schema/1` converts domain entity to schema struct
  - Tests: `to_schema/1` returns schema unchanged if already a schema
- [x] **GREEN**: Create `apps/identity/lib/identity/infrastructure/schemas/workspace_schema.ex`
  - Move from `apps/jarga/lib/workspaces/infrastructure/schemas/workspace_schema.ex`
  - Rename module to `Identity.Infrastructure.Schemas.WorkspaceSchema`
  - Update `alias` for domain entity to `Identity.Domain.Entities.Workspace`
  - Update `has_many` association to reference `Identity.Infrastructure.Schemas.WorkspaceMemberSchema`
- [x] **REFACTOR**: Verify changeset behavior is identical

### 2.2 WorkspaceMemberSchema

- [x] **RED**: Write test `apps/identity/test/identity/infrastructure/schemas/workspace_member_schema_test.exs`
  - Tests: `changeset/2` validates required fields (`:workspace_id`, `:email`, `:role`)
  - Tests: `changeset/2` enforces foreign key constraints
  - Tests: `changeset/2` enforces unique constraint on `[:workspace_id, :email]`
  - Tests: `accept_invitation_changeset/2` validates required `:user_id` and `:joined_at`
  - Tests: `to_schema/1` converts domain entity to schema struct
- [x] **GREEN**: Create `apps/identity/lib/identity/infrastructure/schemas/workspace_member_schema.ex`
  - Move from `apps/jarga/lib/workspaces/infrastructure/schemas/workspace_member_schema.ex`
  - Rename module to `Identity.Infrastructure.Schemas.WorkspaceMemberSchema`
  - Update `alias` for domain entity to `Identity.Domain.Entities.WorkspaceMember`
  - Update `belongs_to(:workspace)` to reference `Identity.Infrastructure.Schemas.WorkspaceSchema`
  - `belongs_to(:user)` and `belongs_to(:inviter)` already reference `Identity.Infrastructure.Schemas.UserSchema` — no change needed
- [x] **REFACTOR**: Verify all changeset validations are preserved

### 2.3 WorkspaceQueries

- [x] **RED**: Write test `apps/identity/test/identity/infrastructure/queries/workspace_queries_test.exs`
  - Tests: `base/0` returns WorkspaceSchema queryable
  - Tests: `for_user/2` filters by user membership join
  - Tests: `for_user_by_id/2` finds workspace by ID where user is member
  - Tests: `for_user_by_slug/2` finds workspace by slug where user is member
  - Tests: `for_user_by_slug_with_member/2` preloads member record
  - Tests: `active/1` filters out archived workspaces
  - Tests: `ordered/1` orders by `inserted_at` descending
  - Tests: `exists?/1` returns count for workspace ID
  - Tests: `find_member_by_email/2` finds member case-insensitively
  - Tests: `list_members/1` returns all members ordered by join/invite time
  - Tests: `get_member/2` finds member by user and workspace
  - Tests: `find_pending_invitation/2` finds unaccepted invitation
  - Tests: `find_pending_invitations_by_email/1` finds all pending for email
  - Tests: `with_workspace_and_inviter/1` preloads associations
- [x] **GREEN**: Create `apps/identity/lib/identity/infrastructure/queries/workspace_queries.ex`
  - Move from `apps/jarga/lib/workspaces/infrastructure/queries/queries.ex`
  - Rename module to `Identity.Infrastructure.Queries.WorkspaceQueries`
  - Update all schema aliases to `Identity.Infrastructure.Schemas.*`
  - Update `User` alias to `Identity.Domain.Entities.User`
- [x] **REFACTOR**: Verify query behavior is identical by comparing results

### 2.4 MembershipRepository

- [x] **RED**: Write test `apps/identity/test/identity/infrastructure/repositories/membership_repository_test.exs`
  - Tests: `get_workspace_for_user/2` returns workspace when user is member, nil otherwise
  - Tests: `get_workspace_for_user_by_slug/2` returns workspace by slug
  - Tests: `get_workspace_and_member_by_slug/2` returns `{workspace, member}` tuple
  - Tests: `workspace_exists?/1` returns boolean
  - Tests: `get_member/2` returns member record
  - Tests: `find_member_by_email/2` finds member case-insensitively
  - Tests: `email_is_member?/2` returns boolean
  - Tests: `list_members/1` returns all members as domain entities
  - Tests: `slug_exists?/2` checks slug uniqueness
  - Tests: `create_member/1` creates workspace member
  - Tests: `update_member/2` updates member fields
  - Tests: `delete_member/1` removes member
  - Tests: `member?/2` checks membership by IDs
  - Tests: `member_by_slug?/2` checks membership by user ID + workspace slug
  - Tests: `transact/1` wraps operations in transaction
- [x] **GREEN**: Create `apps/identity/lib/identity/infrastructure/repositories/membership_repository.ex`
  - Move from `apps/jarga/lib/workspaces/infrastructure/repositories/membership_repository.ex`
  - Rename module to `Identity.Infrastructure.Repositories.MembershipRepository`
  - Update all aliases to `Identity.*` paths
  - Update behaviour reference to `Identity.Application.Behaviours.MembershipRepositoryBehaviour`
  - Already uses `Identity.Repo` — no Repo change needed
- [x] **REFACTOR**: Verify all repository operations return correct domain entities

### 2.5 WorkspaceRepository

- [x] **RED**: Write test `apps/identity/test/identity/infrastructure/repositories/workspace_repository_test.exs`
  - Tests: `get_by_id/1` returns workspace entity or nil
  - Tests: `insert/1` creates workspace from attrs
  - Tests: `update/2` updates workspace fields
  - Tests: `insert_changeset/1` inserts from changeset
- [x] **GREEN**: Create `apps/identity/lib/identity/infrastructure/repositories/workspace_repository.ex`
  - Move from `apps/jarga/lib/workspaces/infrastructure/repositories/workspace_repository.ex`
  - Rename module to `Identity.Infrastructure.Repositories.WorkspaceRepository`
  - Update all aliases to `Identity.*` paths
- [x] **REFACTOR**: Verify repository returns domain entities consistently

### 2.6 WorkspaceNotifier (Email)

- [x] **RED**: Write test `apps/identity/test/identity/infrastructure/notifiers/workspace_notifier_test.exs`
  - Tests: `deliver_invitation_to_new_user/4` sends email with correct subject/body
  - Tests: `deliver_invitation_to_existing_user/4` sends email with user name and workspace URL
- [x] **GREEN**: Create `apps/identity/lib/identity/infrastructure/notifiers/workspace_notifier.ex`
  - Move from `apps/jarga/lib/workspaces/infrastructure/notifiers/workspace_notifier.ex`
  - Rename module to `Identity.Infrastructure.Notifiers.WorkspaceNotifier`
  - Update aliases to `Identity.Domain.Entities.*`
  - Change `Jarga.Mailer` to `Identity.Mailer`
- [x] **REFACTOR**: Verify email content is identical

### 2.7 EmailAndPubSubNotifier

- [x] **RED**: Write test `apps/identity/test/identity/infrastructure/notifiers/email_and_pubsub_notifier_test.exs`
  - Tests: `notify_existing_user/3` sends email + broadcasts PubSub
  - Tests: `notify_new_user/3` sends invitation email
  - Tests: `notify_user_removed/2` broadcasts PubSub removal event
  - Tests: `notify_workspace_updated/1` broadcasts PubSub update event
- [x] **GREEN**: Create `apps/identity/lib/identity/infrastructure/notifiers/email_and_pubsub_notifier.ex`
  - Move from `apps/jarga/lib/workspaces/infrastructure/notifiers/email_and_pubsub_notifier.ex`
  - Rename module to `Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier`
  - Update aliases to `Identity.*` paths
  - Update `WorkspaceNotifier` alias to `Identity.Infrastructure.Notifiers.WorkspaceNotifier`
  - Update behaviour reference to `Identity.Application.Behaviours.NotificationServiceBehaviour`
- [x] **REFACTOR**: Verify PubSub topics are unchanged (`"workspace:#{id}"`, `"user:#{id}"`)

### 2.8 PubSubNotifier

- [x] **RED**: Write test `apps/identity/test/identity/infrastructure/notifiers/pubsub_notifier_test.exs`
  - Tests: `broadcast_invitation_created/5` broadcasts to `"workspace_invitations"` topic
- [x] **GREEN**: Create `apps/identity/lib/identity/infrastructure/notifiers/pubsub_notifier.ex`
  - Move from `apps/jarga/lib/workspaces/infrastructure/notifiers/pubsub_notifier.ex`
  - Rename module to `Identity.Infrastructure.Notifiers.PubSubNotifier`
  - Update behaviour reference to `Identity.Application.Behaviours.PubSubNotifierBehaviour`
- [x] **REFACTOR**: Verify PubSub topic string is unchanged

### 2.9 Update Jarga Schema References (belongs_to)

Update all Jarga schemas that reference `Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema` to reference `Identity.Infrastructure.Schemas.WorkspaceSchema`.

- [x] **RED**: Verify existing schema tests still pass after alias change (run existing test suites)
- [x] **GREEN**: Modify the following files:
  - `apps/jarga/lib/projects/infrastructure/schemas/project_schema.ex`
    - Change: `belongs_to(:workspace, Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema)` → `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)`
  - `apps/jarga/lib/documents/infrastructure/schemas/document_schema.ex`
    - Change: `belongs_to(:workspace, Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema, ...)` → `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema, ...)`
  - `apps/jarga/lib/documents/notes/infrastructure/schemas/note_schema.ex`
    - Change: `belongs_to(:workspace, Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema, ...)` → `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema, ...)`
  - `apps/jarga/lib/chat/infrastructure/schemas/session_schema.ex`
    - Change: `belongs_to(:workspace, Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema)` → `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)`
  - `apps/jarga/lib/agents/infrastructure/schemas/workspace_agent_join_schema.ex`
    - Update alias: `Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema` → `Identity.Infrastructure.Schemas.WorkspaceSchema`
- [x] **REFACTOR**: Verify all association queries still load correctly

### Phase 2 Validation

- [x] All new Identity infrastructure tests pass (`mix test apps/identity/test/identity/infrastructure/`)
- [x] All existing Jarga schema tests pass (associations still work)
- [x] `mix compile --warnings-as-errors` passes
- [x] No boundary violations

---

## Phase 3: Application Layer Migration ✓

Move use cases, behaviours, and services from `Jarga.Workspaces.Application` to `Identity.Application`.

### 3.1 UseCase Behaviour

- [x] **RED**: Verify Identity already has a `UseCase` behaviour (check `apps/identity/lib/identity/application/use_cases/use_case.ex`)
  - If exists with same `execute/2` callback: reuse it
  - If not: write test for the behaviour contract
- [x] **GREEN**: Either reuse existing `Identity.Application.UseCases.UseCase` or create new
  - The workspace use cases will reference `Identity.Application.UseCases.UseCase` as their behaviour
- [x] **REFACTOR**: Ensure consistent interface across all Identity use cases

### 3.2 Behaviours

- [x] **RED**: Write minimal tests verifying behaviour modules compile correctly
- [x] **GREEN**: Create the following behaviour modules:
  - `apps/identity/lib/identity/application/behaviours/membership_repository_behaviour.ex`
    - Module: `Identity.Application.Behaviours.MembershipRepositoryBehaviour`
    - Move from `apps/jarga/lib/workspaces/application/behaviours/membership_repository_behaviour.ex`
    - Update type references to `Identity.Domain.Entities.*`
  - `apps/identity/lib/identity/application/behaviours/notification_service_behaviour.ex`
    - Module: `Identity.Application.Behaviours.NotificationServiceBehaviour`
    - Move from `apps/jarga/lib/workspaces/application/behaviours/notification_service_behaviour.ex`
    - Update type references to `Identity.Domain.Entities.*`
  - `apps/identity/lib/identity/application/behaviours/pub_sub_notifier_behaviour.ex`
    - Module: `Identity.Application.Behaviours.PubSubNotifierBehaviour`
    - Move from `apps/jarga/lib/workspaces/application/behaviours/pub_sub_notifier_behaviour.ex`
  - `apps/identity/lib/identity/application/behaviours/workspace_queries_behaviour.ex`
    - Module: `Identity.Application.Behaviours.WorkspaceQueriesBehaviour`
    - Move from `apps/jarga/lib/workspaces/application/behaviours/queries_behaviour.ex`
- [x] **REFACTOR**: Verify all behaviours are referenced correctly by their implementations

### 3.3 NotificationService (Application Service)

- [x] **RED**: Write test `apps/identity/test/identity/application/services/notification_service_test.exs`
  - Tests: Verify the behaviour module defines correct callbacks
- [x] **GREEN**: Create `apps/identity/lib/identity/application/services/notification_service.ex`
  - Move from `apps/jarga/lib/workspaces/application/services/notification_service.ex`
  - Rename module to `Identity.Application.Services.NotificationService`
  - Update entity references to `Identity.Domain.Entities.*`
- [x] **REFACTOR**: Verify callback signatures match implementations

### 3.4 InviteMember Use Case

- [x] **RED**: Write test `apps/identity/test/identity/application/use_cases/invite_member_test.exs`
  - Tests: Happy path — invite existing user creates pending invitation
  - Tests: Happy path — invite non-existing user creates pending invitation with nil user_id
  - Tests: Error — invalid role (:owner) returns `{:error, :invalid_role}`
  - Tests: Error — inviter not a member returns `{:error, :unauthorized}`
  - Tests: Error — workspace not found returns `{:error, :workspace_not_found}`
  - Tests: Error — already a member returns `{:error, :already_member}`
  - Tests: Error — inviter lacks permission (guest role) returns `{:error, :forbidden}`
  - Tests: Verify notification is sent (mock notifier)
  - Mocks: `MembershipRepository` via dependency injection
- [x] **GREEN**: Create `apps/identity/lib/identity/application/use_cases/invite_member.ex`
  - Move from `apps/jarga/lib/workspaces/application/use_cases/invite_member.ex`
  - Rename module to `Identity.Application.UseCases.InviteMember`
  - Key change: Replace `Jarga.Accounts.get_user_by_email_case_insensitive` with `Identity.get_user_by_email_case_insensitive` (same app, no cross-dependency)
  - Update all internal aliases to `Identity.*` paths
  - Update default module attributes to `Identity.Infrastructure.*`
  - Update behaviour to `Identity.Application.UseCases.UseCase`
- [x] **REFACTOR**: Verify the cross-app dependency on `Jarga.Accounts` is eliminated

### 3.5 ChangeMemberRole Use Case

- [x] **RED**: Write test `apps/identity/test/identity/application/use_cases/change_member_role_test.exs`
  - Tests: Happy path — change member's role successfully
  - Tests: Error — invalid role (:owner) returns `{:error, :invalid_role}`
  - Tests: Error — cannot change owner's role returns `{:error, :cannot_change_owner_role}`
  - Tests: Error — member not found returns `{:error, :member_not_found}`
  - Tests: Error — actor not a member returns `{:error, :unauthorized}`
  - Mocks: `MembershipRepository` via dependency injection
- [x] **GREEN**: Create `apps/identity/lib/identity/application/use_cases/change_member_role.ex`
  - Move from `apps/jarga/lib/workspaces/application/use_cases/change_member_role.ex`
  - Rename module to `Identity.Application.UseCases.ChangeMemberRole`
  - Update all aliases to `Identity.*` paths
- [x] **REFACTOR**: Verify policy interactions are preserved

### 3.6 RemoveMember Use Case

- [x] **RED**: Write test `apps/identity/test/identity/application/use_cases/remove_member_test.exs`
  - Tests: Happy path — remove member successfully
  - Tests: Error — cannot remove owner returns `{:error, :cannot_remove_owner}`
  - Tests: Error — member not found returns `{:error, :member_not_found}`
  - Tests: Error — actor not a member returns `{:error, :unauthorized}`
  - Tests: Notification sent to removed user if they had joined
  - Mocks: `MembershipRepository`, `Notifier` via dependency injection
- [x] **GREEN**: Create `apps/identity/lib/identity/application/use_cases/remove_member.ex`
  - Move from `apps/jarga/lib/workspaces/application/use_cases/remove_member.ex`
  - Rename module to `Identity.Application.UseCases.RemoveMember`
  - Key change: Replace `Jarga.Accounts.get_user!` with `Identity.get_user!` (same app)
  - Update all aliases to `Identity.*` paths
- [x] **REFACTOR**: Verify notification flow works with no cross-app dependency

### 3.7 CreateNotificationsForPendingInvitations Use Case

- [x] **RED**: Write test `apps/identity/test/identity/application/use_cases/create_notifications_for_pending_invitations_test.exs`
  - Tests: Happy path — finds pending invitations and broadcasts PubSub events
  - Tests: No pending invitations returns `{:ok, []}`
  - Mocks: `MembershipRepository`, `PubSubNotifier`, `Queries`, `Repo`
- [x] **GREEN**: Create `apps/identity/lib/identity/application/use_cases/create_notifications_for_pending_invitations.ex`
  - Move from `apps/jarga/lib/workspaces/application/use_cases/create_notifications_for_pending_invitations.ex`
  - Rename module to `Identity.Application.UseCases.CreateNotificationsForPendingInvitations`
  - Update all default module attributes to `Identity.Infrastructure.*`
- [x] **REFACTOR**: Verify PubSub broadcast happens after transaction

### 3.8 Update Identity Public API (Facade)

- [x] **RED**: Write test `apps/identity/test/identity/workspace_facade_test.exs` (workspace sections)
  - Tests: `Identity.list_workspaces_for_user/1` returns workspace list
  - Tests: `Identity.create_workspace/2` creates workspace with owner member
  - Tests: `Identity.get_workspace/2` returns workspace or error
  - Tests: `Identity.get_workspace!/2` returns workspace or raises
  - Tests: `Identity.get_workspace_by_slug/2` returns workspace or error
  - Tests: `Identity.get_workspace_by_slug!/2` returns workspace or raises
  - Tests: `Identity.get_workspace_and_member_by_slug/2` returns `{:ok, workspace, member}`
  - Tests: `Identity.update_workspace/3` updates workspace
  - Tests: `Identity.delete_workspace/2` deletes workspace
  - Tests: `Identity.verify_membership/2` verifies user is member
  - Tests: `Identity.member?/2` checks membership by IDs
  - Tests: `Identity.member_by_slug?/2` checks membership by slug
  - Tests: `Identity.get_member/2` gets member record
  - Tests: `Identity.invite_member/4` invites user
  - Tests: `Identity.list_members/1` lists workspace members
  - Tests: `Identity.accept_pending_invitations/1` accepts all pending invitations
  - Tests: `Identity.accept_invitation_by_workspace/2` accepts specific invitation
  - Tests: `Identity.decline_invitation_by_workspace/2` declines invitation
  - Tests: `Identity.list_pending_invitations_with_details/1` lists pending with preloads
  - Tests: `Identity.create_notifications_for_pending_invitations/1` creates notifications
  - Tests: `Identity.change_member_role/4` changes role
  - Tests: `Identity.remove_member/3` removes member
  - Tests: `Identity.change_workspace/0` returns changeset for new workspace
  - Tests: `Identity.change_workspace/2` returns changeset for edit
- [x] **GREEN**: Modify `apps/identity/lib/identity.ex`
  - Add all workspace public API functions (copy from `Jarga.Workspaces`, update aliases)
  - Import workspace-related modules from Identity namespace
  - Each function either delegates to a use case or performs a simple query via Repo
- [x] **REFACTOR**: Verify every public function in `Jarga.Workspaces` has a corresponding function in `Identity`

### 3.9 Update Identity Boundary Exports

- [x] **RED**: Verify `mix compile --warnings-as-errors` passes after export updates
- [x] **GREEN**: Modify `apps/identity/lib/identity.ex` boundary declaration
  - Add to `exports`:
    - `Domain.Entities.Workspace`
    - `Domain.Entities.WorkspaceMember`
    - `Domain.Policies.MembershipPolicy`
    - `Domain.Policies.WorkspacePermissionsPolicy`
    - `Domain.Services.SlugGenerator`
    - `Infrastructure.Schemas.WorkspaceSchema`
    - `Infrastructure.Schemas.WorkspaceMemberSchema`
    - `Application.Policies.MembershipPolicy` (if kept in Application)
  - Add to `deps` if needed (should already have `Identity.ApplicationLayer`, `Identity.Repo`, `Identity.Mailer`)
- [x] **REFACTOR**: Run `mix compile --warnings-as-errors` to verify

### 3.10 Update Identity.ApplicationLayer

- [x] **RED**: Verify `Identity.ApplicationLayer.use_cases/0` includes workspace use cases
- [x] **GREEN**: Modify `apps/identity/lib/identity/application_layer.ex`
  - Add workspace use cases to `use_cases/0`:
    - `Identity.Application.UseCases.InviteMember`
    - `Identity.Application.UseCases.ChangeMemberRole`
    - `Identity.Application.UseCases.RemoveMember`
    - `Identity.Application.UseCases.CreateNotificationsForPendingInvitations`
  - Add workspace services to `services/0`:
    - `Identity.Application.Services.NotificationService`
  - Add workspace behaviours to `behaviours/0`:
    - `Identity.Application.Behaviours.MembershipRepositoryBehaviour`
    - `Identity.Application.Behaviours.NotificationServiceBehaviour`
    - `Identity.Application.Behaviours.PubSubNotifierBehaviour`
    - `Identity.Application.Behaviours.WorkspaceQueriesBehaviour`
- [x] **REFACTOR**: Verify summary counts are updated

### Phase 3 Validation

- [x] All new Identity application tests pass
- [x] All Identity workspace public API tests pass
- [x] `mix compile --warnings-as-errors` passes
- [x] No boundary violations
- [x] Identity has zero runtime dependencies on `Jarga.Accounts` for workspace operations

---

## Phase 4: Facade & Cleanup ⏸

Convert `Jarga.Workspaces` to thin delegation facade. Remove old layer boundary modules. Update fixtures.

### 4.1 Convert Jarga.Workspaces to Thin Facade

- [ ] **RED**: Write test `apps/jarga/test/workspaces_test.exs` (update to test delegation)
  - Tests: `Jarga.Workspaces.list_workspaces_for_user/1` delegates to `Identity.list_workspaces_for_user/1`
  - Tests: `Jarga.Workspaces.create_workspace/2` delegates to `Identity.create_workspace/2`
  - Tests: Every existing public function still works via delegation
  - Tests: Return types are identical (domain entities from Identity)
- [ ] **GREEN**: Rewrite `apps/jarga/lib/workspaces.ex`
  - Replace all implementation with `defdelegate` to `Identity` (following `Jarga.Accounts` pattern)
  - Update boundary declaration:
    ```elixir
    use Boundary,
      top_level?: true,
      deps: [Identity],
      exports: []
    ```
  - Remove all internal aliases (`Queries`, `Schemas`, `Repositories`, etc.)
  - For functions with default args (like `update_workspace/4`, `invite_member/5`), use wrapper functions that call `Identity.*` directly (since `defdelegate` doesn't support default args)
  - Complete list of delegated functions (~25):
    - `list_workspaces_for_user/1`
    - `create_workspace/2`
    - `get_workspace/2`
    - `get_workspace!/2`
    - `get_workspace_by_slug/2`
    - `get_workspace_by_slug!/2`
    - `get_workspace_and_member_by_slug/2`
    - `update_workspace/3` (wrapper for optional opts)
    - `delete_workspace/2`
    - `verify_membership/2`
    - `member?/2`
    - `member_by_slug?/2`
    - `get_member/2`
    - `invite_member/4` (wrapper for optional opts)
    - `list_members/1`
    - `accept_pending_invitations/1`
    - `accept_invitation_by_workspace/2`
    - `decline_invitation_by_workspace/2`
    - `list_pending_invitations_with_details/1`
    - `create_notifications_for_pending_invitations/1`
    - `change_member_role/4`
    - `remove_member/3`
    - `change_workspace/0` and `change_workspace/1` or `change_workspace/2`
- [ ] **REFACTOR**: Verify facade is < 100 lines (pure delegation, no logic)

### 4.2 Remove Old Jarga Workspace Layer Boundaries

- [ ] **RED**: Verify `mix compile` passes after removing old boundary modules
- [ ] **GREEN**: Delete the following files from `apps/jarga/`:
  - `lib/workspaces/domain.ex` (boundary module)
  - `lib/workspaces/application.ex` (boundary module)
  - `lib/workspaces/infrastructure.ex` (boundary module)
  - `lib/workspaces/domain/entities/workspace.ex`
  - `lib/workspaces/domain/entities/workspace_member.ex`
  - `lib/workspaces/domain/slug_generator.ex`
  - `lib/workspaces/application/use_cases/invite_member.ex`
  - `lib/workspaces/application/use_cases/remove_member.ex`
  - `lib/workspaces/application/use_cases/change_member_role.ex`
  - `lib/workspaces/application/use_cases/create_notifications_for_pending_invitations.ex`
  - `lib/workspaces/application/use_cases/use_case.ex`
  - `lib/workspaces/application/policies/permissions_policy.ex`
  - `lib/workspaces/application/policies/membership_policy.ex`
  - `lib/workspaces/application/services/notification_service.ex`
  - `lib/workspaces/application/behaviours/membership_repository_behaviour.ex`
  - `lib/workspaces/application/behaviours/notification_service_behaviour.ex`
  - `lib/workspaces/application/behaviours/pub_sub_notifier_behaviour.ex`
  - `lib/workspaces/application/behaviours/queries_behaviour.ex`
  - `lib/workspaces/infrastructure/schemas/workspace_schema.ex`
  - `lib/workspaces/infrastructure/schemas/workspace_member_schema.ex`
  - `lib/workspaces/infrastructure/repositories/workspace_repository.ex`
  - `lib/workspaces/infrastructure/repositories/membership_repository.ex`
  - `lib/workspaces/infrastructure/queries/queries.ex`
  - `lib/workspaces/infrastructure/notifiers/email_and_pubsub_notifier.ex`
  - `lib/workspaces/infrastructure/notifiers/pubsub_notifier.ex`
  - `lib/workspaces/infrastructure/notifiers/workspace_notifier.ex`
- [ ] **REFACTOR**: Remove empty directories after file deletion

### 4.3 Update Jarga Layer Documentation Modules

- [ ] **RED**: Verify `mix compile` after updates
- [ ] **GREEN**: Modify the following files:
  - `apps/jarga/lib/jarga/infrastructure_layer.ex` — Remove `Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema` and `WorkspaceMemberSchema` references
  - `apps/jarga/lib/jarga/application_layer.ex` — Remove `Jarga.Workspaces.Application.Policies.PermissionsPolicy` and other workspace references
  - `apps/jarga/lib/jarga/domain.ex` — Remove any workspace domain references (if present)
- [ ] **REFACTOR**: Verify documentation modules compile cleanly

### 4.4 Update Test Fixtures

- [ ] **RED**: Verify all existing tests that use `Jarga.WorkspacesFixtures` still pass
- [ ] **GREEN**: Create `apps/identity/test/support/fixtures/workspaces_fixtures.ex`
  - Module: `Identity.WorkspacesFixtures`
  - Implement `workspace_fixture/2`, `add_workspace_member_fixture/3`, `invite_and_accept_member/4`
  - These call `Identity.*` directly (not `Jarga.Workspaces`)
- [ ] **GREEN**: Modify `apps/jarga/test/support/fixtures/workspaces_fixtures.ex`
  - Update `Jarga.WorkspacesFixtures` to delegate to `Identity.WorkspacesFixtures` or call `Identity` directly
  - Update boundary deps to `[Identity]`
  - Remove direct schema/entity references — use `Identity` public API
  - For `add_workspace_member_fixture/3`: Can call `Identity.Infrastructure.Schemas.WorkspaceMemberSchema` directly (it's exported)
- [ ] **REFACTOR**: Run full Jarga test suite to verify no fixture breakage

### 4.5 Move Workspace Tests to Identity

- [ ] **RED**: Verify new test paths exist and run
- [ ] **GREEN**: Move the following test files from `apps/jarga/test/` to `apps/identity/test/`:
  - `workspaces/domain/entities/workspace_test.exs` → `identity/domain/entities/workspace_test.exs`
  - `workspaces/domain/entities/workspace_member_test.exs` → `identity/domain/entities/workspace_member_test.exs`
  - `workspaces/domain/slug_generator_test.exs` → `identity/domain/services/slug_generator_test.exs`
  - `workspaces/application/policies/permissions_policy_test.exs` → `identity/domain/policies/workspace_permissions_policy_test.exs`
  - `workspaces/application/policies/membership_policy_test.exs` → `identity/domain/policies/membership_policy_test.exs`
  - `workspaces/application/use_cases/invite_member_test.exs` → `identity/application/use_cases/invite_member_test.exs`
  - `workspaces/application/use_cases/change_member_role_test.exs` → `identity/application/use_cases/change_member_role_test.exs`
  - `workspaces/application/use_cases/remove_member_test.exs` → `identity/application/use_cases/remove_member_test.exs`
  - `workspaces/application/services/notification_service_test.exs` → `identity/application/services/notification_service_test.exs`
  - `workspaces/infrastructure/queries/queries_test.exs` → `identity/infrastructure/queries/workspace_queries_test.exs`
  - `workspaces/infrastructure/repositories/membership_repository_test.exs` → `identity/infrastructure/repositories/membership_repository_test.exs`
  - `workspaces/infrastructure/notifiers/email_and_pubsub_notifier_test.exs` → `identity/infrastructure/notifiers/email_and_pubsub_notifier_test.exs`
  - `workspaces/infrastructure/notifiers/workspace_notifier_test.exs` → `identity/infrastructure/notifiers/workspace_notifier_test.exs`
  - `workspaces_test.exs` → Keep minimal facade delegation test in Jarga
  - Note: If new tests were written in earlier phases, these moved tests may be replaced/merged. Prefer the new tests written in earlier phases as they use correct Identity module paths.
- [ ] **REFACTOR**: Update all module references in moved test files to `Identity.*` paths

### Phase 4 Validation

- [ ] `Jarga.Workspaces` facade is pure delegation (< 100 lines)
- [ ] All old Jarga workspace source files are deleted
- [ ] All workspace tests are in `apps/identity/test/`
- [ ] `Jarga.WorkspacesFixtures` still works for all Jarga tests that depend on it
- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix test` passes across all apps at umbrella root

---

## Phase 5: Propagation (Update Call Sites) ⏸

Update cross-context references: permission policy aliases, boundary deps. This phase ensures clean architecture with no stale references.

### 5.1 Update PermissionsPolicy References in Jarga Contexts

The following files currently alias `Jarga.Workspaces.Application.Policies.PermissionsPolicy`. They must be updated to use the new split:
- Project/document use cases → `Jarga.Domain.Policies.DomainPermissionsPolicy`
- Workspace-related checks → `Identity.Domain.Policies.WorkspacePermissionsPolicy` (via `Identity` public API)

- [ ] **RED**: Verify existing authorization tests pass after alias updates
- [ ] **GREEN**: Modify the following files:
  - `apps/jarga/lib/projects/application/use_cases/create_project.ex`
    - Change: `alias Jarga.Workspaces.Application.Policies.PermissionsPolicy` → `alias Jarga.Domain.Policies.DomainPermissionsPolicy, as: PermissionsPolicy`
  - `apps/jarga/lib/projects/application/use_cases/delete_project.ex`
    - Change: Same alias update as above
  - `apps/jarga/lib/projects/application/use_cases/update_project.ex`
    - Change: Same alias update as above
  - `apps/jarga/lib/documents/application/use_cases/create_document.ex`
    - Change: Same alias update as above
  - `apps/jarga/lib/documents/application/policies/document_authorization_policy.ex`
    - Change: Same alias update as above
  - `apps/jarga_web/lib/live/permissions_helper.ex`
    - Change: `alias Jarga.Workspaces.Application.Policies.PermissionsPolicy` → Need to decide: either import both policies or keep a unified helper that delegates
    - Recommendation: Update to alias `Jarga.Domain.Policies.DomainPermissionsPolicy` for project/document checks, and call `Identity.Domain.Policies.WorkspacePermissionsPolicy` for workspace checks (both via exports)
- [ ] **REFACTOR**: Run all project/document authorization tests to verify

### 5.2 Update Boundary Dependencies in Jarga Contexts

- [ ] **RED**: `mix compile --warnings-as-errors` catches any missing deps
- [ ] **GREEN**: Modify the following boundary declarations:
  - `apps/jarga/lib/projects.ex` — Update `deps` to include `Identity` (instead of `Jarga.Workspaces` layers)
  - `apps/jarga/lib/documents.ex` — Update `deps` similarly
  - `apps/jarga/lib/notes.ex` — Update `deps` if it references workspace layers
  - `apps/jarga/lib/chat.ex` — Update `deps` if needed
  - `apps/jarga/lib/agents.ex` — Update `deps` if needed
  - `apps/jarga_web/lib/jarga_web.ex` — Update `deps` to replace `Jarga.Workspaces` layers with `Identity`
  - `apps/jarga_api/lib/jarga_api.ex` — Update `deps` if it references workspace layers
  - Remove `Jarga.Workspaces.Domain`, `Jarga.Workspaces.Application`, `Jarga.Workspaces.Infrastructure` from all `deps` lists (these no longer exist)
- [ ] **REFACTOR**: Run `mix compile --warnings-as-errors` to confirm zero violations

### 5.3 Update jarga_web PermissionsHelper

- [ ] **RED**: Verify LiveView permission checks still render correctly
- [ ] **GREEN**: Modify `apps/jarga_web/lib/live/permissions_helper.ex`
  - For workspace permissions: call `Identity.Domain.Policies.WorkspacePermissionsPolicy.can?/3`
  - For domain permissions: call `Jarga.Domain.Policies.DomainPermissionsPolicy.can?/3`
  - Maintain the same public API so LiveViews don't need changes
- [ ] **REFACTOR**: Run LiveView tests to verify UI permission gates work

### 5.4 Migration File Ownership (Optional/Documentation)

- [ ] **GREEN**: Document that workspace-related migration files should be owned by `apps/identity/priv/repo/migrations/`
  - Identify which migrations in `apps/jarga/priv/repo/migrations/` create the `workspaces` and `workspace_members` tables
  - Copy (not move, to avoid breaking existing deployments) these migration files to `apps/identity/priv/repo/migrations/`
  - Add a note in the migration files indicating they were moved from Jarga
  - This is a documentation/ownership concern — `mix ecto.migrate` works regardless of which app owns the migration files since both repos point to the same database

### Phase 5 Validation (Final)

- [ ] `mix compile --warnings-as-errors` passes with zero boundary violations across all 6 apps
- [ ] `mix test` passes across all apps at umbrella root (zero regressions)
- [ ] `mix precommit` passes
- [ ] `mix boundary` reports clean dependency graph
- [ ] All permission policy references point to correct split policies
- [ ] `Identity` has zero dependencies on `Jarga` for workspace operations
- [ ] `Jarga.Workspaces` is pure delegation facade (matching `Jarga.Accounts` pattern)

---

## Pre-Commit Checkpoint

After all phases complete:

- [ ] `mix precommit` passes (compilation, formatting, Credo, tests, boundary)
- [ ] `mix boundary` shows clean architecture
- [ ] `mix test --cover` shows no drop in test coverage

---

## Testing Strategy

### Test Distribution

| Layer | Location | Estimated Tests | Async |
|-------|----------|----------------|-------|
| Domain Entities | `apps/identity/test/identity/domain/entities/` | 12 | Yes |
| Domain Policies | `apps/identity/test/identity/domain/policies/` | 30+ | Yes |
| Domain Services | `apps/identity/test/identity/domain/services/` | 6 | Yes |
| Application Use Cases | `apps/identity/test/identity/application/use_cases/` | 25 | Yes (with mocks) |
| Infrastructure Schemas | `apps/identity/test/identity/infrastructure/schemas/` | 12 | No (DataCase) |
| Infrastructure Queries | `apps/identity/test/identity/infrastructure/queries/` | 15 | No (DataCase) |
| Infrastructure Repos | `apps/identity/test/identity/infrastructure/repositories/` | 20 | No (DataCase) |
| Infrastructure Notifiers | `apps/identity/test/identity/infrastructure/notifiers/` | 10 | No (DataCase) |
| Facade (Identity) | `apps/identity/test/identity_test.exs` | 25 | No (DataCase) |
| Facade (Jarga) | `apps/jarga/test/workspaces_test.exs` | 5 | No (DataCase) |
| DomainPermissionsPolicy | `apps/jarga/test/jarga/domain/policies/` | 25 | Yes |

**Total estimated new/moved tests**: ~185

### Test Principles

1. **Domain tests** (`async: true`): Pure functions, no database, millisecond speed
2. **Application tests** (`async: true` with Mox): Use cases with mocked dependencies
3. **Infrastructure tests** (`DataCase`): Real database, test actual queries and repos
4. **Facade tests** (`DataCase`): Integration-level, verify end-to-end delegation

---

## File Inventory Summary

### New Files in `apps/identity/` (26 source + 14 test files)

#### Source Files
```
lib/identity/domain/entities/workspace.ex
lib/identity/domain/entities/workspace_member.ex
lib/identity/domain/services/slug_generator.ex
lib/identity/domain/policies/membership_policy.ex
lib/identity/domain/policies/workspace_permissions_policy.ex
lib/identity/application/use_cases/invite_member.ex
lib/identity/application/use_cases/change_member_role.ex
lib/identity/application/use_cases/remove_member.ex
lib/identity/application/use_cases/create_notifications_for_pending_invitations.ex
lib/identity/application/services/notification_service.ex
lib/identity/application/behaviours/membership_repository_behaviour.ex
lib/identity/application/behaviours/notification_service_behaviour.ex
lib/identity/application/behaviours/pub_sub_notifier_behaviour.ex
lib/identity/application/behaviours/workspace_queries_behaviour.ex
lib/identity/infrastructure/schemas/workspace_schema.ex
lib/identity/infrastructure/schemas/workspace_member_schema.ex
lib/identity/infrastructure/queries/workspace_queries.ex
lib/identity/infrastructure/repositories/membership_repository.ex
lib/identity/infrastructure/repositories/workspace_repository.ex
lib/identity/infrastructure/notifiers/workspace_notifier.ex
lib/identity/infrastructure/notifiers/email_and_pubsub_notifier.ex
lib/identity/infrastructure/notifiers/pubsub_notifier.ex
test/support/fixtures/workspaces_fixtures.ex
```

#### Modified Files in `apps/identity/`
```
lib/identity.ex                      # Add workspace public API + expand exports
lib/identity/domain/scope.ex         # Add workspace field
lib/identity/application_layer.ex    # Add workspace use cases/services/behaviours
```

### Deleted Files from `apps/jarga/` (26 source files)

```
lib/workspaces/domain.ex
lib/workspaces/application.ex
lib/workspaces/infrastructure.ex
lib/workspaces/domain/entities/workspace.ex
lib/workspaces/domain/entities/workspace_member.ex
lib/workspaces/domain/slug_generator.ex
lib/workspaces/application/use_cases/invite_member.ex
lib/workspaces/application/use_cases/remove_member.ex
lib/workspaces/application/use_cases/change_member_role.ex
lib/workspaces/application/use_cases/create_notifications_for_pending_invitations.ex
lib/workspaces/application/use_cases/use_case.ex
lib/workspaces/application/policies/permissions_policy.ex
lib/workspaces/application/policies/membership_policy.ex
lib/workspaces/application/services/notification_service.ex
lib/workspaces/application/behaviours/membership_repository_behaviour.ex
lib/workspaces/application/behaviours/notification_service_behaviour.ex
lib/workspaces/application/behaviours/pub_sub_notifier_behaviour.ex
lib/workspaces/application/behaviours/queries_behaviour.ex
lib/workspaces/infrastructure/schemas/workspace_schema.ex
lib/workspaces/infrastructure/schemas/workspace_member_schema.ex
lib/workspaces/infrastructure/repositories/workspace_repository.ex
lib/workspaces/infrastructure/repositories/membership_repository.ex
lib/workspaces/infrastructure/queries/queries.ex
lib/workspaces/infrastructure/notifiers/email_and_pubsub_notifier.ex
lib/workspaces/infrastructure/notifiers/pubsub_notifier.ex
lib/workspaces/infrastructure/notifiers/workspace_notifier.ex
```

### Modified Files in `apps/jarga/` (~15 files)

```
lib/workspaces.ex                                              # Becomes thin facade
lib/jarga/infrastructure_layer.ex                              # Remove workspace schema refs
lib/jarga/application_layer.ex                                 # Remove workspace policy refs
lib/projects/infrastructure/schemas/project_schema.ex           # Update belongs_to
lib/documents/infrastructure/schemas/document_schema.ex         # Update belongs_to
lib/documents/notes/infrastructure/schemas/note_schema.ex       # Update belongs_to
lib/chat/infrastructure/schemas/session_schema.ex               # Update belongs_to
lib/agents/infrastructure/schemas/workspace_agent_join_schema.ex # Update alias
lib/projects/application/use_cases/create_project.ex            # Update PermissionsPolicy alias
lib/projects/application/use_cases/delete_project.ex            # Update PermissionsPolicy alias
lib/projects/application/use_cases/update_project.ex            # Update PermissionsPolicy alias
lib/documents/application/use_cases/create_document.ex          # Update PermissionsPolicy alias
lib/documents/application/policies/document_authorization_policy.ex # Update PermissionsPolicy alias
test/support/fixtures/workspaces_fixtures.ex                    # Update to delegate to Identity
```

### New File in `apps/jarga/`

```
lib/jarga/domain/policies/domain_permissions_policy.ex          # Split from PermissionsPolicy
test/jarga/domain/policies/domain_permissions_policy_test.exs   # Tests for split policy
```

### Modified Files in `apps/jarga_web/`

```
lib/live/permissions_helper.ex                                  # Update policy aliases
```

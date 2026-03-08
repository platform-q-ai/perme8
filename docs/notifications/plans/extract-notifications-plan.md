# Feature: Extract Notifications into Standalone App (Phase 1)

**Ticket**: #38
**Ticket**: `docs/notifications/tickets/extract-notifications-ticket.md`
**BDD Features**: `apps/jarga_web/test/features/notifications/notifications.browser.feature` (11 scenarios), `apps/jarga_web/test/features/notifications/notifications.security.feature` (21 scenarios)

## Overview

Extract the notifications bounded context from `apps/jarga/lib/notifications/` (18 source files) into a standalone `apps/notifications/` umbrella app. This enforces the Standalone App Principle: `Notifications.Repo` points to the same shared Postgres DB (same pattern as `Agents.Repo`), domain events move to the new app, accept/decline workspace invitation logic is removed from notifications (jarga_web calls Identity directly then `Notifications.mark_as_read`), and all jarga_web consumers are updated to import from `Notifications.*` instead of `Jarga.Notifications.*`.

## UI Strategy
- **LiveView coverage**: 100% — all notification UI is LiveView (NotificationBell LiveComponent)
- **TypeScript needed**: None

## Affected Boundaries
- **Primary context**: `Notifications` (new standalone app)
- **Dependencies**: `Identity` (source of `MemberInvited` events, accept/decline workspace invitations), `Perme8.Events` (event bus)
- **Exported schemas**: `{Domain.Entities.Notification, []}`
- **New context needed?**: No new context — extracting existing bounded context into standalone app

## Architectural Decisions (Phase 1 Scope)

| Decision | Choice | Reference |
|----------|--------|-----------|
| Repo | `Notifications.Repo` → same shared Postgres DB | Matches `Agents.Repo` pattern |
| Action handling | Removed from Notifications; jarga_web calls Identity directly | Ticket §1.5 |
| `NotificationActionTaken` event | Removed entirely | Ticket §1.2 |
| Schema `user_id` | Raw UUID field, no `belongs_to` to Identity | Ticket §1.4 |
| Migration | No data migration — same DB, just new Repo | Ticket §1.9 |
| NotificationBell | Stays in jarga_web, calls `Notifications` facade | Ticket §1.7 |
| WorkspaceInvitationSubscriber | Moves to `notifications` app | Ticket §1.4 |
| Boundary config | `deps: [Notifications.Repo, Perme8.Events]` | Ticket §1.1 |

## Reference Implementations

- **Agents app** (primary pattern): `apps/agents/lib/agents.ex`, `apps/agents/lib/agents/repo.ex`, `apps/agents/lib/agents/otp_app.ex`, `apps/agents/mix.exs`
- **Existing notification code**: `apps/jarga/lib/notifications/` (18 files)
- **Existing interface code**: `apps/jarga_web/lib/live/notifications_live/` (2 files)

---

## Phase 1: Scaffold Standalone App (phoenix-tdd) ✓

**Goal**: Create `apps/notifications/` with `mix.exs`, `Notifications.Repo`, `Notifications.OTPApp`, test infrastructure, and config entries. No tests yet — this is pure scaffolding.

### 1.1 Create `apps/notifications/mix.exs`
- [x] Create `apps/notifications/mix.exs` following `apps/agents/mix.exs` pattern
  - `app: :notifications`, `mod: {Notifications.OTPApp, []}`
  - `deps`: `{:perme8_events, in_umbrella: true}`, `{:identity, in_umbrella: true}`, `{:boundary, ...}`, `{:ecto_sql, ...}`, `{:postgrex, ...}`, `{:phoenix_pubsub, ...}`, `{:jason, ...}`, `{:mox, only: :test}`
  - `compilers: [:boundary] ++ Mix.compilers()`
  - `boundary: [externals_mode: :relaxed, ignore: [~r/\.Test\./, ~r/\.Mocks\./]]`
  - `elixirc_paths(:test) -> ["lib", "test/support"]`

### 1.2 Create `apps/notifications/lib/notifications/repo.ex`
- [x] Create `Notifications.Repo` with `use Boundary, top_level?: true, deps: []` and `use Ecto.Repo, otp_app: :notifications, adapter: Ecto.Adapters.Postgres`

### 1.3 Create `apps/notifications/lib/notifications/otp_app.ex`
- [x] Create `Notifications.OTPApp` following `Agents.OTPApp` pattern
  - Start `Notifications.Repo` and `WorkspaceInvitationSubscriber` (conditionally in test env)

### 1.4 Add config entries
- [x] Add `Notifications.Repo` config to `config/dev.exs`, `config/test.exs`, `config/runtime.exs`
  - Same DB connection as other repos
  - Add `config :notifications, ecto_repos: [Notifications.Repo]` to `config/config.exs`
  - Add `config :notifications, env: :test` and `pool: Ecto.Adapters.SQL.Sandbox` to `config/test.exs`
  - Add `priv: "priv/repo"` to Repo config

### 1.5 Create test infrastructure
- [x] Create `apps/notifications/test/test_helper.exs` (start ExUnit, set sandbox mode, define Mox mocks)
- [x] Create `apps/notifications/test/support/data_case.ex` (`Notifications.DataCase`)
  - Checkout `Notifications.Repo` and `Identity.Repo` (same shared DB pattern as `Agents.DataCase`)
- [x] Create `apps/notifications/priv/repo/migrations/.gitkeep`

### 1.6 Create empty directory structure
- [x] Create directory tree:
  ```
  apps/notifications/lib/notifications/
  ├── domain/
  │   ├── entities/
  │   ├── events/
  │   └── policies/
  ├── application/
  │   ├── use_cases/
  │   └── behaviours/
  └── infrastructure/
      ├── schemas/
      ├── repositories/
      ├── queries/
      └── subscribers/
  ```

### Phase 1 Validation
- [x] `mix deps.get` succeeds
- [x] `mix compile` succeeds for the new app
- ⏸ `mix ecto.create` for `Notifications.Repo` succeeds (or no-ops since DB exists)

---

## Phase 2: Domain Layer (phoenix-tdd) ✓

**Goal**: Create domain entities, events, and policies with pure-function tests. No I/O, no database.

### 2.1 Notification Entity
- [x] **RED**: Write test `apps/notifications/test/notifications/domain/entities/notification_test.exs`
  - Tests: `new/1` creates struct from attrs map, `from_schema/1` converts schema struct to entity, all fields present (id, user_id, type, title, body, data, read, read_at, action_taken_at, inserted_at, updated_at)
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/domain/entities/notification.ex`
  - Pure struct with `defstruct`, `@type t`, `new/1`, `from_schema/1`
  - Fields: `id`, `user_id`, `type`, `title`, `body`, `data` (default `%{}`), `read` (default `false`), `read_at`, `action_taken_at`, `inserted_at`, `updated_at`
- [x] **REFACTOR**: Clean up

### 2.2 NotificationCreated Event
- [x] **RED**: Write test `apps/notifications/test/notifications/domain/events/notification_created_test.exs`
  - Tests: `new/1` creates event with required fields (`notification_id`, `user_id`, `type`), validates required fields, has `aggregate_type: "notification"`
  - Copy and adapt from `apps/jarga/test/notifications/domain/events/notification_created_test.exs`
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/domain/events/notification_created.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "notification", fields: [notification_id: nil, user_id: nil, type: nil, target_user_id: nil], required: [:notification_id, :user_id, :type]`
- [x] **REFACTOR**: Clean up

### 2.3 NotificationRead Event
- [x] **RED**: Write test `apps/notifications/test/notifications/domain/events/notification_read_test.exs`
  - Tests: `new/1` creates event with required fields (`notification_id`, `user_id`), validates required fields
  - Copy and adapt from `apps/jarga/test/notifications/domain/events/notification_read_test.exs`
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/domain/events/notification_read.ex`
  - `use Perme8.Events.DomainEvent, aggregate_type: "notification", fields: [notification_id: nil, user_id: nil], required: [:notification_id, :user_id]`
- [x] **REFACTOR**: Clean up

### 2.4 NotificationPolicy
- [x] **RED**: Write test `apps/notifications/test/notifications/domain/policies/notification_policy_test.exs`
  - Tests:
    - `belongs_to_user?/2` returns true when notification.user_id matches user_id, false otherwise
    - `can_mark_as_read?/2` returns true when notification belongs to user and is unread
    - `readable?/1` returns true when notification.read is false
    - `valid_type?/1` returns true for "workspace_invitation", false for "unknown"
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/domain/policies/notification_policy.ex`
  - Pure functions, no I/O, no dependencies
- [x] **REFACTOR**: Clean up

### 2.5 Boundary Modules
- [x] Create `apps/notifications/lib/notifications/domain.ex`
  ```elixir
  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Notification,
      Events.NotificationCreated,
      Events.NotificationRead,
      Policies.NotificationPolicy
    ]
  ```

### Phase 2 Validation
- [x] All domain tests pass (`mix test apps/notifications/test/notifications/domain/` — all async, milliseconds, no I/O)
- [x] Domain modules have zero infrastructure dependencies

---

## Phase 3: Application Layer (phoenix-tdd) ✓

**Goal**: Create use cases and the repository behaviour (port). Tests use Mox for dependency injection — no database.

### 3.1 NotificationRepositoryBehaviour
- [x] Create `apps/notifications/lib/notifications/application/behaviours/notification_repository_behaviour.ex`
  - Callbacks: `create/1`, `get/1`, `get_by_user/2`, `mark_as_read/1`, `mark_all_as_read/1`, `list_by_user/2`, `list_unread_by_user/1`, `count_unread_by_user/1`, `transact/1`
  - Note: `mark_action_taken` is intentionally excluded (action handling removed from Notifications)

### 3.2 Define Mox Mock in test_helper.exs
- [x] Add to `apps/notifications/test/test_helper.exs`:
  ```elixir
  Mox.defmock(Notifications.Mocks.NotificationRepositoryMock,
    for: Notifications.Application.Behaviours.NotificationRepositoryBehaviour
  )
  ```

### 3.3 CreateNotification Use Case
- [x] **RED**: Write test `apps/notifications/test/notifications/application/use_cases/create_notification_test.exs`
  - Tests:
    - Creates notification via repository and emits `NotificationCreated` event
    - Returns `{:ok, notification}` on success
    - Returns `{:error, changeset}` on validation failure
    - Emits event with correct fields (notification_id, user_id, type, target_user_id)
    - Builds title/body from params for workspace_invitation type
  - Mocks: `notification_repository`, `event_bus` (use `Perme8.Events.TestEventBus`)
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/application/use_cases/create_notification.ex`
  - Generic notification creation (replaces `CreateWorkspaceInvitationNotification`)
  - Accepts `params` with `user_id`, `type`, `title`, `body`, `data`
  - For `type: "workspace_invitation"` — auto-builds title/body from `data` fields if not provided
  - Emits `NotificationCreated` event after successful creation
  - DI via `opts`: `notification_repository`, `event_bus`
- [x] **REFACTOR**: Clean up

### 3.4 MarkAsRead Use Case
- [x] **RED**: Write test `apps/notifications/test/notifications/application/use_cases/mark_as_read_test.exs`
  - Tests:
    - Marks notification as read via repository
    - Returns `{:error, :not_found}` when notification doesn't exist
    - Returns `{:error, :not_found}` when notification belongs to different user
  - Mocks: `notification_repository`
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/application/use_cases/mark_as_read.ex`
- [x] **REFACTOR**: Clean up

### 3.5 MarkAllAsRead Use Case
- [x] **RED**: Write test `apps/notifications/test/notifications/application/use_cases/mark_all_as_read_test.exs`
  - Tests: Calls `mark_all_as_read/1` on repository, returns `{:ok, count}`
  - Mocks: `notification_repository`
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/application/use_cases/mark_all_as_read.ex`
- [x] **REFACTOR**: Clean up

### 3.6 GetUnreadCount Use Case
- [x] **RED**: Write test `apps/notifications/test/notifications/application/use_cases/get_unread_count_test.exs`
  - Tests: Calls `count_unread_by_user/1` on repository, returns integer count
  - Mocks: `notification_repository`
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/application/use_cases/get_unread_count.ex`
- [x] **REFACTOR**: Clean up

### 3.7 ListNotifications Use Case
- [x] **RED**: Write test `apps/notifications/test/notifications/application/use_cases/list_notifications_test.exs`
  - Tests: Calls `list_by_user/2` on repository, passes through opts (limit)
  - Mocks: `notification_repository`
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/application/use_cases/list_notifications.ex`
- [x] **REFACTOR**: Clean up

### 3.8 ListUnreadNotifications Use Case
- [x] **RED**: Write test `apps/notifications/test/notifications/application/use_cases/list_unread_notifications_test.exs`
  - Tests: Calls `list_unread_by_user/1` on repository
  - Mocks: `notification_repository`
  - Test `async: true`, `use ExUnit.Case`
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/application/use_cases/list_unread_notifications.ex`
- [x] **REFACTOR**: Clean up

### 3.9 Application Boundary Module
- [x] Create `apps/notifications/lib/notifications/application.ex`
  ```elixir
  use Boundary,
    top_level?: true,
    deps: [Notifications.Domain, Perme8.Events],
    exports: [
      UseCases.CreateNotification,
      UseCases.MarkAsRead,
      UseCases.MarkAllAsRead,
      UseCases.GetUnreadCount,
      UseCases.ListNotifications,
      UseCases.ListUnreadNotifications,
      Behaviours.NotificationRepositoryBehaviour
    ]
  ```
  - Note: NO dependency on `Jarga.Workspaces` — action handling removed

### Phase 3 Validation
- [x] All application tests pass with Mox mocks (`mix test apps/notifications/test/notifications/application/` — async, fast)
- [x] No boundary violations for domain/application layers

---

## Phase 4: Infrastructure Layer (phoenix-tdd) ✓

**Goal**: Create schema, repository, queries, and subscriber. Tests use the real database via `Notifications.DataCase`.

### 4.1 NotificationSchema
- [x] **RED**: Write test `apps/notifications/test/notifications/infrastructure/schemas/notification_schema_test.exs`
  - Tests (adapted from `apps/jarga/test/notifications/infrastructure/schemas/notification_schema_test.exs`):
    - `create_changeset/1` validates required fields (`user_id`, `type`, `title`)
    - `create_changeset/1` rejects invalid notification types
    - `create_changeset/1` accepts valid `workspace_invitation` type
    - `create_changeset/1` defaults `read` to false and `data` to empty map
    - `mark_read_changeset/1` sets `read: true` and `read_at` timestamp
    - Schema uses raw `user_id` UUID field (NO `belongs_to` to Identity)
  - Test `async: true`, `use ExUnit.Case` (schema tests are pure — no DB needed)
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/infrastructure/schemas/notification_schema.ex`
  - `@primary_key {:id, :binary_id, autogenerate: true}`
  - `field :user_id, :binary_id` (raw UUID — NO `belongs_to`)
  - Fields: `type`, `title`, `body`, `data` (map, default %{}), `read` (boolean, default false), `read_at`, `action_taken_at`
  - `timestamps(type: :utc_datetime)`
  - `create_changeset/1`, `mark_read_changeset/1,2`
  - Keep `mark_action_taken_changeset` for backward compat with existing data (kept in schema, not exposed in new use cases)
- [x] **REFACTOR**: Clean up

### 4.2 NotificationQueries
- [x] **RED**: Write test `apps/notifications/test/notifications/infrastructure/queries/notification_queries_test.exs`
  - Tests (require DB — `use Notifications.DataCase, async: true`):
    - `base/0` returns base query for NotificationSchema
    - `by_user/2` filters by user_id
    - `unread/1` filters where read == false
    - `ordered_by_recent/1` orders by inserted_at desc
    - `limited/2` applies limit
  - Needs fixture helpers — create test support module first
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/infrastructure/queries/notification_queries.ex`
  - Composable query functions returning Ecto queryables (not results)
  - `base/0`, `by_user/2`, `by_id/2`, `unread/1`, `ordered_by_recent/1`, `limited/2`
- [x] **REFACTOR**: Clean up

### 4.3 NotificationRepository
- [x] **RED**: Write test `apps/notifications/test/notifications/infrastructure/repositories/notification_repository_test.exs`
  - Tests (adapted from `apps/jarga/test/notifications/infrastructure/repositories/notification_repository_test.exs`, `use Notifications.DataCase, async: true`):
    - `create/1` creates notification in DB via `Notifications.Repo`
    - `get/1` retrieves by ID
    - `get_by_user/2` returns notification scoped to user, nil for other users
    - `list_by_user/2` returns all notifications for user ordered by recent, respects limit option
    - `list_unread_by_user/1` returns only unread notifications
    - `count_unread_by_user/1` returns integer count
    - `mark_as_read/1` updates read + read_at
    - `mark_all_as_read/1` batch updates all unread, returns `{:ok, count}`
    - `transact/1` wraps in transaction
  - Needs: notification fixture helper
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/infrastructure/repositories/notification_repository.ex`
  - `@behaviour Notifications.Application.Behaviours.NotificationRepositoryBehaviour`
  - Uses `Notifications.Repo` (NOT `Identity.Repo`)
  - Uses `NotificationQueries` for query building
- [x] **REFACTOR**: Clean up

### 4.4 Test Fixtures
- [x] Create `apps/notifications/test/support/fixtures/notifications_fixtures.ex`
  - `notification_fixture/2` creates a notification via repository (not via use case to avoid event emission in fixtures)
  - `valid_notification_attrs/1` returns valid attrs map
  - Pattern follows existing `Jarga.NotificationsFixtures`

### 4.5 WorkspaceInvitationSubscriber
- [x] **RED**: Write test `apps/notifications/test/notifications/infrastructure/subscribers/workspace_invitation_subscriber_test.exs`
  - Tests:
    - `subscriptions/0` returns `["events:identity:workspace_member"]`
    - `handle_event/1` with `%MemberInvited{}` event calls `CreateNotification` use case with correct params
    - `handle_event/1` with unknown event returns `:ok`
  - Mock: `CreateNotification` use case (or test integration with DB)
  - Test `use Notifications.DataCase` (subscriber interacts with DB via use case)
- [x] **GREEN**: Implement `apps/notifications/lib/notifications/infrastructure/subscribers/workspace_invitation_subscriber.ex`
  - `use Perme8.Events.EventHandler`
  - Subscribes to `["events:identity:workspace_member"]`
  - Handles `%Identity.Domain.Events.MemberInvited{}` → calls `Notifications.Application.UseCases.CreateNotification.execute/2`
  - Extracts `user_id`, `workspace_id`, `workspace_name`, `invited_by_name`, `role` from event
- [x] **REFACTOR**: Clean up

### 4.6 Infrastructure Boundary Module
- [x] Create `apps/notifications/lib/notifications/infrastructure.ex`
  ```elixir
  use Boundary,
    top_level?: true,
    deps: [
      Notifications.Application,
      Notifications.Domain,
      Notifications.Repo,
      Identity,
      Perme8.Events
    ],
    exports: [
      Schemas.NotificationSchema,
      Repositories.NotificationRepository,
      Subscribers.WorkspaceInvitationSubscriber
    ]
  ```
  - Note: NO dependency on `Identity.Repo` (uses `Notifications.Repo`), NO dependency on `Jarga.Workspaces`

### Phase 4 Validation
- [x] All infrastructure tests pass (`mix test apps/notifications/test/notifications/infrastructure/` — 38 tests, 0 failures)
- [x] Repository uses `Notifications.Repo` (verified by test sandbox setup)
- [x] Schema uses raw `user_id` field (no `belongs_to` to Identity)

---

## Phase 5: Public Facade (phoenix-tdd) ✓

**Goal**: Create the `Notifications` facade module that delegates to use cases and repositories.

### 5.1 Notifications Facade
- [x] **RED**: Write test `apps/notifications/test/notifications_test.exs`
  - Tests (integration — `use Notifications.DataCase, async: true`):
    - `create_notification/1` creates notification and returns `{:ok, notification}`
    - `get_notification/2` returns notification for user, nil for other users
    - `list_notifications/2` returns all for user, respects limit
    - `list_unread_notifications/1` returns only unread
    - `mark_as_read/2` marks read, returns `{:ok, notification}`
    - `mark_as_read/2` returns `{:error, :not_found}` for wrong user
    - `mark_all_as_read/1` marks all read, returns `{:ok, count}`
    - `unread_count/1` returns integer count
    - User scoping: notifications from user A not visible to user B
  - Needs: user fixture from Identity
- [x] **GREEN**: Implement `apps/notifications/lib/notifications.ex`
  ```elixir
  use Boundary,
    top_level?: true,
    deps: [
      Notifications.Domain,
      Notifications.Application,
      Notifications.Infrastructure,
      Notifications.Repo
    ],
    exports: [
      {Domain.Entities.Notification, []}
    ]
  ```
  - Functions:
    - `create_notification/1` → `CreateNotification.execute/1`
    - `get_notification/2` → `NotificationRepository.get_by_user/2`
    - `list_notifications/2` → `ListNotifications.execute/2`
    - `list_unread_notifications/1` → `ListUnreadNotifications.execute/1`
    - `mark_as_read/2` → `MarkAsRead.execute/2`
    - `mark_all_as_read/1` → `MarkAllAsRead.execute/1`
    - `unread_count/1` → `GetUnreadCount.execute/1`
  - NO: `accept_workspace_invitation`, `decline_workspace_invitation` (removed)
  - Keep: `update_for_test/2` for test fixtures (test-only function)
- [x] **REFACTOR**: Clean up

### Phase 5 Validation
- [x] All facade tests pass (integration with real DB)
- [x] `mix boundary` passes for `Notifications` app
- [x] `mix test apps/notifications/` — all tests pass (99 tests, 0 failures)

---

## Phase 6: Update Interface Layer — jarga_web (phoenix-tdd) ✓

**Goal**: Update all jarga_web files to import from `Notifications` instead of `Jarga.Notifications`. Update NotificationBell to call Identity directly for accept/decline. Remove `NotificationActionTaken` event handling.

### 6.1 Update jarga_web Boundary
- ⏸ Edit `apps/jarga_web/lib/jarga_web.ex`:
  - Replace `Jarga.Notifications` with `Notifications` in `deps`
  - Replace `Jarga.Notifications.Domain` with `Notifications.Domain` in `deps`
  - Add `Identity` to deps if not already present (for accept/decline)

### 6.2 Update NotificationBell LiveComponent
- ⏸ **RED**: Write/update test `apps/jarga_web/test/live/notifications_live/notification_bell_test.exs`
  - Tests:
    - Renders bell with unread count badge
    - Opens/closes dropdown
    - Lists notifications in dropdown
    - Mark single notification as read
    - Mark all notifications as read
    - Accept workspace invitation: calls `Identity.accept_invitation_by_workspace/2` then `Notifications.mark_as_read/2`
    - Decline workspace invitation: calls `Identity.decline_invitation_by_workspace/2` then `Notifications.mark_as_read/2`
    - Empty state shows "No notifications"
    - Badge shows "99+" for counts > 99
    - data-testid attributes present for BDD feature selectors:
      - `notification-bell`, `notification-badge`, `notification-dropdown`
      - `notification-item`, `notification-item-unread`
      - `notification-invitation`, `accept-invitation`, `decline-invitation`
  - Test `use JargaWeb.ConnCase`
- ⏸ **GREEN**: Edit `apps/jarga_web/lib/live/notifications_live/notification_bell.ex`
  - Change `alias Jarga.Notifications` → `alias Notifications`
  - Update `handle_event("accept_invitation", ...)`:
    - Call `Identity.accept_invitation_by_workspace(workspace_id, user_id)` (extract workspace_id from notification data)
    - On success, call `Notifications.mark_as_read(notification_id, user_id)`
    - Flash: "Invitation accepted"
  - Update `handle_event("decline_invitation", ...)`:
    - Call `Identity.decline_invitation_by_workspace(workspace_id, user_id)` (extract workspace_id from notification data)
    - On success, call `Notifications.mark_as_read(notification_id, user_id)`
    - Flash: "Invitation declined"
  - Add `data-testid` attributes to template elements for BDD feature file selectors:
    - Bell button: `data-testid="notification-bell"`
    - Badge: `data-testid="notification-badge"`
    - Dropdown: `data-testid="notification-dropdown"`
    - Each notification item: `data-testid="notification-item"`, unread items also get `data-testid="notification-item-unread"`
    - Workspace invitation items: `data-testid="notification-invitation"`
    - Accept button: `data-testid="accept-invitation"`
    - Decline button: `data-testid="decline-invitation"`
    - Mark all read button: update text to "Mark all as read" (BDD expects this exact text)
- ⏸ **REFACTOR**: Clean up, ensure thin component delegating to facades

### 6.3 Update OnMount
- ⏸ **RED**: Update test `apps/jarga_web/test/live/notifications_live/on_mount_test.exs`
  - Change `alias Jarga.Notifications.Domain.Events.NotificationCreated` → `alias Notifications.Domain.Events.NotificationCreated`
- ⏸ **GREEN**: Edit `apps/jarga_web/lib/live/notifications_live/on_mount.ex`
  - Change `alias Jarga.Notifications.Domain.Events.NotificationCreated` → `alias Notifications.Domain.Events.NotificationCreated`
- ⏸ **REFACTOR**: Clean up

### 6.4 Update ChatLive.MessageHandlers
- ⏸ **RED**: Update test `apps/jarga_web/test/live/chat_live/message_handlers_test.exs`
  - Change `alias Jarga.Notifications.Domain.Events.NotificationCreated` → `alias Notifications.Domain.Events.NotificationCreated`
- ⏸ **GREEN**: Edit `apps/jarga_web/lib/live/chat_live/message_handlers.ex`
  - Change `alias Jarga.Notifications.Domain.Events.NotificationCreated` → `alias Notifications.Domain.Events.NotificationCreated`
- ⏸ **REFACTOR**: Clean up

### 6.5 Update WorkspacesLive.Show — Remove NotificationActionTaken
- ⏸ **RED**: Update test `apps/jarga_web/test/live/app_live/workspaces/show_test.exs`
  - Remove `alias Jarga.Notifications.Domain.Events.NotificationActionTaken`
  - Replace `NotificationActionTaken` tests with `Identity.Domain.Events.MemberJoined` or `MemberRemoved` tests (or remove if no replacement event exists — the workspace show page can rely on existing `MemberRemoved` events)
  - **Decision**: The `NotificationActionTaken` event was used to refresh the members list when someone accepted/declined. Since this event is removed, the workspace show page should instead react to `Identity.Domain.Events.MemberInvited` (already available) or rely on explicit refresh. For Phase 1, simply remove the handlers — real-time member refresh on accept/decline is a nice-to-have.
- ⏸ **GREEN**: Edit `apps/jarga_web/lib/live/app_live/workspaces/show.ex`
  - Remove `alias Jarga.Notifications.Domain.Events.NotificationActionTaken`
  - Remove `handle_info(%NotificationActionTaken{action: "accepted"}, socket)` handler
  - Remove `handle_info(%NotificationActionTaken{action: "declined"}, socket)` handler
- ⏸ **REFACTOR**: Clean up

### 6.6 Update WorkspacesLive.Index — Remove NotificationActionTaken
- ⏸ **RED**: Update test `apps/jarga_web/test/live/app_live/workspaces_test.exs`
  - Remove `alias Jarga.Notifications.Domain.Events.NotificationActionTaken`
  - Remove or update `NotificationActionTaken` tests
  - **Decision**: When a user accepts an invitation, the workspace list should refresh. Since `accept_invitation_by_workspace` in Identity already emits domain events (e.g., `WorkspaceUpdated` or member status change), the Index page can react to those instead. For Phase 1, remove the `NotificationActionTaken` handler — the user can navigate/refresh to see the new workspace.
- ⏸ **GREEN**: Edit `apps/jarga_web/lib/live/app_live/workspaces/index.ex`
  - Remove `alias Jarga.Notifications.Domain.Events.NotificationActionTaken`
  - Remove `handle_info(%NotificationActionTaken{...}, socket)` handler
- ⏸ **REFACTOR**: Clean up

### 6.7 Update Dashboard — Remove NotificationActionTaken
- ⏸ **RED**: Update test `apps/jarga_web/test/live/app_live/dashboard_test.exs`
  - Remove `alias Jarga.Notifications.Domain.Events.NotificationActionTaken`
  - Remove or update `NotificationActionTaken` tests
- ⏸ **GREEN**: Edit `apps/jarga_web/lib/live/app_live/dashboard.ex`
  - Remove `alias Jarga.Notifications.Domain.Events.NotificationActionTaken`
  - Remove `handle_info(%NotificationActionTaken{...}, socket)` handler
- ⏸ **REFACTOR**: Clean up

### 6.8 Update Integration Tests
- ⏸ Update `apps/jarga_web/test/integration/user_signup_and_confirmation_test.exs`
  - Replace all `Jarga.Notifications.*` references with `Notifications.*`
  - Update `Jarga.Notifications.accept_workspace_invitation(...)` → use Identity directly + `Notifications.mark_as_read(...)`
  - Update `Jarga.Notifications.list_notifications(...)` → `Notifications.list_notifications(...)`

### 6.9 Update jarga_web mix.exs
- ⏸ Add `{:notifications, in_umbrella: true}` to `apps/jarga_web/mix.exs` deps

### Phase 6 Validation
- ⏸ All jarga_web notification tests pass
- ⏸ All updated test files compile without `Jarga.Notifications` references
- ⏸ `mix boundary` passes for jarga_web

---

## Phase 7: Clean Up Jarga (phoenix-tdd) ✓

**Goal**: Remove all notification code from the jarga app. This is the final extraction step.

### 7.1 Remove Jarga Notification Source Files
- [x] Delete `apps/jarga/lib/notifications.ex` (facade)
- [x] Delete `apps/jarga/lib/notifications/` directory (all 18 files):
  - `domain.ex`, `application.ex`, `infrastructure.ex`
  - `domain/events/notification_created.ex`
  - `domain/events/notification_read.ex`
  - `domain/events/notification_action_taken.ex`
  - `application/behaviours/notification_repository_behaviour.ex`
  - `application/use_cases/create_workspace_invitation_notification.ex`
  - `application/use_cases/accept_workspace_invitation.ex`
  - `application/use_cases/decline_workspace_invitation.ex`
  - `application/use_cases/mark_as_read.ex`
  - `application/use_cases/mark_all_as_read.ex`
  - `application/use_cases/get_unread_count.ex`
  - `application/use_cases/list_notifications.ex`
  - `application/use_cases/list_unread_notifications.ex`
  - `infrastructure/schemas/notification_schema.ex`
  - `infrastructure/repositories/notification_repository.ex`
  - `infrastructure/subscribers/workspace_invitation_subscriber.ex`

### 7.2 Remove Jarga Notification Test Files
- [x] Delete `apps/jarga/test/notifications_test.exs`
- [x] Delete `apps/jarga/test/notifications/` directory (all test files):
  - `domain/events/notification_created_test.exs`
  - `domain/events/notification_read_test.exs`
  - `domain/events/notification_action_taken_test.exs`
  - `infrastructure/schemas/notification_schema_test.exs`
  - `infrastructure/repositories/notification_repository_test.exs`
- [x] Delete `apps/jarga/test/support/fixtures/notifications_fixtures.ex`

### 7.3 Update Jarga Application Supervisor
- [x] Edit `apps/jarga/lib/application.ex`:
  - Remove `WorkspaceInvitationSubscriber` from `pubsub_subscribers/0`
  - If no other subscribers remain, simplify or remove `pubsub_subscribers/0`

### 7.4 Update Jarga Boundary Config
- [x] Edit `apps/jarga/lib/jarga.ex` or wherever `Jarga.Notifications` boundary is declared:
  - Remove `Jarga.Notifications` boundary deps from any module that references it
- [x] Edit `apps/jarga/test/support/data_case.ex`:
  - Remove `Jarga.Notifications` and `Jarga.Notifications.Infrastructure` from Boundary deps
  - Update `WorkspaceInvitationSubscriber` reference to `Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber` for integration tests
  - Keep `Notifications.Repo` in sandbox checkout (for cross-repo tests)

### 7.5 Update jarga mix.exs
- [x] Remove any notification-specific deps from `apps/jarga/mix.exs` that are no longer needed
- [x] Ensure `apps/jarga/mix.exs` does not depend on `{:notifications, in_umbrella: true}` (jarga should NOT depend on notifications — they are independent)

### 7.6 Additional Cleanup
- [x] Update `apps/jarga/lib/jarga/application_layer.ex` — remove notification use case references
- [x] Update `apps/jarga/lib/jarga/infrastructure_layer.ex` — remove notification repo/schema references
- [x] Update `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs` — replace `Jarga.Notifications` events with `Notifications` events, add `Identity.Domain.Events.MemberJoined`

### Phase 7 Validation
- [x] `apps/jarga/lib/notifications/` directory is completely removed
- [x] `apps/jarga/lib/notifications.ex` facade is removed
- [x] `mix compile --warnings-as-errors` succeeds with no notification references
- [x] `mix test apps/jarga/` passes — 762 tests, 0 failures
- [x] No `Jarga.Notifications` references remain in source code (only in Credo check comment)

---

## Phase 8: Final Integration Validation ✓

**Goal**: Verify the entire extraction works end-to-end.

### 8.1 Full Test Suite
- [x] `mix test apps/notifications/` — 99 tests, 0 failures
- [x] `mix test apps/jarga/` — 762 tests, 0 failures
- [x] `mix test apps/jarga_web/` — 498 tests, 0 failures (13 excluded)
- [x] `mix test` — full umbrella passes (6 pre-existing perme8_dashboard failures unrelated to extraction)

### 8.2 Boundary Verification
- [x] `mix compile --force --warnings-as-errors` — clean, no boundary violations
  - `Notifications` has no dependency on `Jarga`
  - `jarga_web` depends on `Notifications` (not `Jarga.Notifications`)
  - `Notifications.Infrastructure` uses `Notifications.Repo` (not `Identity.Repo`)

### 8.3 Pre-commit Validation
- ⏸ `mix precommit` passes (compile + boundary + format + credo + test)

### 8.4 BDD Feature File Alignment
- ⏸ Verify BDD feature files have correct `data-testid` selectors matching NotificationBell template
- ⏸ Browser feature scenarios (11): all testids present in template
  - `notification-bell`, `notification-badge`, `notification-dropdown`
  - `notification-item`, `notification-item-unread`
  - `notification-invitation`, `accept-invitation`, `decline-invitation`
  - "Mark all as read" button text matches
  - "No notifications" empty state text matches
  - "Invitation accepted" / "Invitation declined" flash messages match
- ⏸ Security feature scenarios (21): pages render correctly at `/app` and `/app/workspaces/:slug`

---

## Testing Strategy

### Test Distribution

| Layer | Test Count (est.) | Test Type | Speed |
|-------|------------------|-----------|-------|
| Domain entities | 5 | ExUnit.Case, async | < 10ms |
| Domain events | 6 | ExUnit.Case, async | < 10ms |
| Domain policies | 8 | ExUnit.Case, async | < 10ms |
| Application use cases | 18 | ExUnit.Case + Mox, async | < 50ms |
| Infrastructure schema | 6 | ExUnit.Case, async | < 10ms |
| Infrastructure queries | 6 | DataCase, async | < 200ms |
| Infrastructure repository | 12 | DataCase, async | < 300ms |
| Infrastructure subscriber | 3 | DataCase | < 200ms |
| Facade (integration) | 12 | DataCase, async | < 300ms |
| Interface (LiveView) | 15 | ConnCase | < 500ms |
| **Total** | **~91** | | |

### Test Pyramid
- **Domain (19 tests)**: Pure functions, millisecond execution, no I/O
- **Application (18 tests)**: Mocked dependencies, no database
- **Infrastructure (27 tests)**: Real database via sandbox
- **Facade (12 tests)**: End-to-end integration through facade
- **Interface (15 tests)**: LiveView rendering and events

### BDD Acceptance Tests
- **Browser (11 scenarios)**: Run via exo-bdd browser adapter against running app
- **Security (21 scenarios)**: Run via exo-bdd security adapter (ZAP scanning)

---

## Files Summary

### Files to Create (Phase 1 new app: ~22 source + ~14 test files)

**App scaffolding:**
- `apps/notifications/mix.exs`
- `apps/notifications/lib/notifications.ex` (facade)
- `apps/notifications/lib/notifications/repo.ex`
- `apps/notifications/lib/notifications/otp_app.ex`

**Domain layer:**
- `apps/notifications/lib/notifications/domain.ex` (boundary)
- `apps/notifications/lib/notifications/domain/entities/notification.ex`
- `apps/notifications/lib/notifications/domain/events/notification_created.ex`
- `apps/notifications/lib/notifications/domain/events/notification_read.ex`
- `apps/notifications/lib/notifications/domain/policies/notification_policy.ex`

**Application layer:**
- `apps/notifications/lib/notifications/application.ex` (boundary)
- `apps/notifications/lib/notifications/application/behaviours/notification_repository_behaviour.ex`
- `apps/notifications/lib/notifications/application/use_cases/create_notification.ex`
- `apps/notifications/lib/notifications/application/use_cases/mark_as_read.ex`
- `apps/notifications/lib/notifications/application/use_cases/mark_all_as_read.ex`
- `apps/notifications/lib/notifications/application/use_cases/get_unread_count.ex`
- `apps/notifications/lib/notifications/application/use_cases/list_notifications.ex`
- `apps/notifications/lib/notifications/application/use_cases/list_unread_notifications.ex`

**Infrastructure layer:**
- `apps/notifications/lib/notifications/infrastructure.ex` (boundary)
- `apps/notifications/lib/notifications/infrastructure/schemas/notification_schema.ex`
- `apps/notifications/lib/notifications/infrastructure/repositories/notification_repository.ex`
- `apps/notifications/lib/notifications/infrastructure/queries/notification_queries.ex`
- `apps/notifications/lib/notifications/infrastructure/subscribers/workspace_invitation_subscriber.ex`

**Test infrastructure:**
- `apps/notifications/test/test_helper.exs`
- `apps/notifications/test/support/data_case.ex`
- `apps/notifications/test/support/fixtures/notifications_fixtures.ex`
- `apps/notifications/priv/repo/migrations/.gitkeep`

**Test files:**
- `apps/notifications/test/notifications_test.exs`
- `apps/notifications/test/notifications/domain/entities/notification_test.exs`
- `apps/notifications/test/notifications/domain/events/notification_created_test.exs`
- `apps/notifications/test/notifications/domain/events/notification_read_test.exs`
- `apps/notifications/test/notifications/domain/policies/notification_policy_test.exs`
- `apps/notifications/test/notifications/application/use_cases/create_notification_test.exs`
- `apps/notifications/test/notifications/application/use_cases/mark_as_read_test.exs`
- `apps/notifications/test/notifications/application/use_cases/mark_all_as_read_test.exs`
- `apps/notifications/test/notifications/application/use_cases/get_unread_count_test.exs`
- `apps/notifications/test/notifications/application/use_cases/list_notifications_test.exs`
- `apps/notifications/test/notifications/application/use_cases/list_unread_notifications_test.exs`
- `apps/notifications/test/notifications/infrastructure/schemas/notification_schema_test.exs`
- `apps/notifications/test/notifications/infrastructure/queries/notification_queries_test.exs`
- `apps/notifications/test/notifications/infrastructure/repositories/notification_repository_test.exs`
- `apps/notifications/test/notifications/infrastructure/subscribers/workspace_invitation_subscriber_test.exs`

### Files to Modify

**Config:**
- `config/config.exs` — add `config :notifications, ecto_repos: [Notifications.Repo]`
- `config/dev.exs` — add `Notifications.Repo` config
- `config/test.exs` — add `Notifications.Repo` config with sandbox pool
- `config/runtime.exs` — add `Notifications.Repo` runtime config

**jarga_web:**
- `apps/jarga_web/mix.exs` — add `{:notifications, in_umbrella: true}` dep
- `apps/jarga_web/lib/jarga_web.ex` — update Boundary deps (replace `Jarga.Notifications*` with `Notifications*`)
- `apps/jarga_web/lib/live/notifications_live/notification_bell.ex` — `alias Notifications`, update accept/decline handlers, add data-testid attrs
- `apps/jarga_web/lib/live/notifications_live/on_mount.ex` — update event alias
- `apps/jarga_web/lib/live/chat_live/message_handlers.ex` — update event alias
- `apps/jarga_web/lib/live/app_live/workspaces/show.ex` — remove `NotificationActionTaken` handling
- `apps/jarga_web/lib/live/app_live/workspaces/index.ex` — remove `NotificationActionTaken` handling
- `apps/jarga_web/lib/live/app_live/dashboard.ex` — remove `NotificationActionTaken` handling

**jarga_web tests:**
- `apps/jarga_web/test/live/notifications_live/notification_bell_test.exs` — update aliases + test accept/decline flow
- `apps/jarga_web/test/live/notifications_live/on_mount_test.exs` — update alias
- `apps/jarga_web/test/live/chat_live/message_handlers_test.exs` — update alias
- `apps/jarga_web/test/live/app_live/workspaces/show_test.exs` — remove `NotificationActionTaken` tests
- `apps/jarga_web/test/live/app_live/workspaces_test.exs` — remove `NotificationActionTaken` tests
- `apps/jarga_web/test/live/app_live/dashboard_test.exs` — remove `NotificationActionTaken` tests
- `apps/jarga_web/test/integration/user_signup_and_confirmation_test.exs` — update `Jarga.Notifications` → `Notifications`

**jarga:**
- `apps/jarga/lib/application.ex` — remove `WorkspaceInvitationSubscriber` from supervisor
- `apps/jarga/test/support/data_case.ex` — remove notification boundary deps, update sandbox checkout

### Files to Delete

- `apps/jarga/lib/notifications.ex`
- `apps/jarga/lib/notifications/` (entire directory — 18 files)
- `apps/jarga/test/notifications_test.exs`
- `apps/jarga/test/notifications/` (entire directory — 5 test files)
- `apps/jarga/test/support/fixtures/notifications_fixtures.ex`

---

## Dependency Graph After Extraction

```
perme8_events
  ^      ^
  |      |
identity  notifications ──→ identity (MemberInvited events only)
  ^            ^
  |           /
  |          /
jarga_web ──→ notifications (facade calls)
  |
  ↓
jarga (no longer has notifications)
```

## Key Constraints

1. **No data migration**: `Notifications.Repo` reads/writes the existing `notifications` table created by Jarga's migration
2. **No new migrations**: The table already exists; future schema changes go in `apps/notifications/priv/repo/migrations/`
3. **`action_taken_at` column kept**: For backward compatibility with existing data, but no new code writes to it via use cases
4. **Accept/decline in jarga_web**: NotificationBell calls Identity facade directly, then `Notifications.mark_as_read` — simpler than creating new Identity use cases
5. **`NotificationActionTaken` removed entirely**: No event struct, no handlers, no emission — the event concept doesn't exist in the extracted app
6. **BDD data-testid alignment**: Template must have exact `data-testid` attributes matching the browser feature file selectors

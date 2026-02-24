# PRD: Extract Notifications into Standalone App

**Ticket**: #38
**Status**: 10% complete (existing bounded context in Jarga)
**Phases**: 3 (Extract, Browser Push, Preferences & Registry)

---

## Summary

- **Problem**: Notifications currently lives inside Jarga as a bounded context, violating the Standalone App Principle. It uses `Identity.Repo` instead of its own Repo, and its accept/decline workspace invitation use cases create tight coupling with `Jarga.Workspaces` (which delegates to `Identity`). As the platform grows, notifications must react to events from multiple domain apps (agents, projects, documents, chat) — this is only sustainable as an independent, event-driven service.
- **Value**: A standalone notifications app enables independent deployment, clean event-driven architecture, and extensible notification delivery across in-app, browser push, and future mobile push channels. Removing action-handling from notifications clarifies its single responsibility: receive events, create notifications, deliver them.
- **Users**: All authenticated users of the platform who need to be informed about workspace invitations, document changes, project activity, agent events, and other domain events across the system.

---

## Background & Current State

### What Exists Today

The notifications bounded context lives at `apps/jarga/lib/notifications/` with 18 source files:

**Facade** (`Jarga.Notifications`):
- `get_notification/2`, `create_workspace_invitation_notification/1`
- `list_unread_notifications/1`, `list_notifications/2`
- `mark_as_read/2`, `mark_all_as_read/1`, `unread_count/1`
- `accept_workspace_invitation/3`, `decline_workspace_invitation/3`

**Domain Events** (3):
- `NotificationCreated` — fields: `notification_id`, `user_id`, `type`, `target_user_id`
- `NotificationRead` — fields: `notification_id`, `user_id`
- `NotificationActionTaken` — fields: `notification_id`, `user_id`, `action`

**Use Cases** (8):
- `CreateWorkspaceInvitationNotification` — creates notification + emits `NotificationCreated`
- `AcceptWorkspaceInvitation` — calls `Jarga.Workspaces.accept_invitation_by_workspace` (delegates to `Identity`)
- `DeclineWorkspaceInvitation` — calls `Jarga.Workspaces.decline_invitation_by_workspace`
- `MarkAsRead`, `MarkAllAsRead`, `GetUnreadCount`, `ListNotifications`, `ListUnreadNotifications`

**Infrastructure**:
- `NotificationSchema` — Ecto schema with fields: `user_id`, `type`, `title`, `body`, `data` (map), `read`, `read_at`, `action_taken_at`
- `NotificationRepository` — uses `Identity.Repo` (not `Jarga.Repo`)
- `WorkspaceInvitationSubscriber` — `EventHandler` subscribing to `events:identity:workspace_member`, handles `MemberInvited` events
- Migration: `20251107175147_create_notifications.exs` (in `apps/jarga/priv/repo/migrations/`)

**Interface Layer** (in `jarga_web`):
- `NotificationBell` LiveComponent (307 lines) — bell icon with unread count badge, dropdown panel, workspace invitation accept/decline buttons, mark as read
- `NotificationsLive.OnMount` — subscribes to `events:user:#{user_id}`, forwards `NotificationCreated` events to `NotificationBell` component

**Cross-App Dependencies**:
- `NotificationRepository` uses `Identity.Repo` for all DB operations
- `NotificationSchema` has `belongs_to` to `Identity.Infrastructure.Schemas.UserSchema`
- `WorkspaceInvitationSubscriber` pattern-matches on `Identity.Domain.Events.MemberInvited`
- `AcceptWorkspaceInvitation`/`DeclineWorkspaceInvitation` call `Jarga.Workspaces` facade (delegates to `Identity`)
- In `Identity`: `CreateNotificationsForPendingInvitations` use case emits `MemberInvited` events for pending invitations at login

**Consumers of Notification Events in `jarga_web`**:
- `NotificationsLive.OnMount` — listens for `NotificationCreated`
- `ChatLive.MessageHandlers` — listens for `NotificationCreated`
- `WorkspacesLive.Index/Show` — listens for `NotificationActionTaken`
- `Dashboard` — listens for `NotificationActionTaken`

**Supervisor**: `WorkspaceInvitationSubscriber` is started in `Jarga.Application.pubsub_subscribers/0` (skipped in test env unless explicitly enabled).

### Key Problem: Action Handling Violates SRP

The current `AcceptWorkspaceInvitation` and `DeclineWorkspaceInvitation` use cases inside Notifications handle workspace membership logic. This creates a direct dependency on `Jarga.Workspaces`/`Identity` and conflates notification delivery with domain action handling. Notifications should be purely: **receive events -> create notifications -> deliver them**.

---

## Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Repo strategy | New `Notifications.Repo` pointing to same shared Postgres DB | Matches the Agents pattern; enables standalone app principle |
| Action handling (accept/decline) | Remove from Notifications entirely; move to Identity/Workspaces | Notifications is delivery-only; action handling belongs in the domain that owns the action |
| UI home | `NotificationBell` stays in `jarga_web`, calls `Notifications` facade | Matches the agents pattern (jarga_web renders agent LiveViews calling `Agents` facade) |
| OS notifications | Web Push API (Service Workers) for browser push; mobile push API for future mobile | Web + mobile product, not Tauri/Electron |
| Delivery preferences | Per-type + per-channel | Users choose which notification types they receive AND via which channel |
| Subscription management | Extensible registry system | Any domain app can register notification types without code changes in notifications app |
| Domain events location | Notification domain events move to `notifications` app | Per "domain events live in the emitting app" rule |
| Event subscriber location | `WorkspaceInvitationSubscriber` moves to `notifications` app | Subscriber belongs in the app that reacts to the event |
| Migration approach | Phased (3 phases) | Reduces risk; each phase delivers value independently |

---

## User Stories

- As a **platform user**, I want to receive in-app notifications about workspace invitations and other important events, so that I stay informed about activity relevant to me.
- As a **platform user**, I want to receive browser push notifications for important events even when the tab is not focused, so that I don't miss time-sensitive information.
- As a **platform user**, I want to control which types of notifications I receive and through which channels, so that I'm not overwhelmed by irrelevant alerts.
- As a **domain app developer**, I want to register new notification types without modifying the notifications app code, so that I can add notifications for new features independently.

---

## Functional Requirements

### Phase 1: Extract into Standalone App (P0 — Must Have)

#### 1.1 Create Standalone Umbrella App
1. Create `apps/notifications/` with `Notifications` module as the public facade
2. Create `Notifications.Repo` pointing to the shared Postgres database (same connection config pattern as `Agents.Repo`)
3. Create `Notifications.OTPApp` application supervisor that starts `Notifications.Repo` and event subscribers
4. Configure Boundary: `deps: [Notifications.Repo, Perme8.Events]`, `exports: [{Domain.Entities.Notification, []}]`
5. Create `mix.exs` with dependencies on `identity`, `perme8_events`

#### 1.2 Migrate Domain Layer
1. Create `Notifications.Domain.Entities.Notification` — pure struct (no Ecto) with `new/1` and `from_schema/1`
2. Move domain events to `Notifications.Domain.Events.*`:
   - `NotificationCreated` (keep existing fields)
   - `NotificationRead` (keep existing fields)
   - `NotificationActionTaken` — **remove entirely** (no more action handling in notifications)
3. Create `Notifications.Domain.Policies.NotificationPolicy` — pure business rules (e.g., `belongs_to_user?/2`, `can_mark_as_read?/2`)

#### 1.3 Migrate Application Layer
1. Move use cases to `Notifications.Application.UseCases.*`:
   - `CreateNotification` — generic notification creation (replaces `CreateWorkspaceInvitationNotification`)
   - `MarkAsRead`
   - `MarkAllAsRead`
   - `GetUnreadCount`
   - `ListNotifications`
   - `ListUnreadNotifications`
2. **Remove** `AcceptWorkspaceInvitation` and `DeclineWorkspaceInvitation` use cases — these do NOT move to the notifications app
3. Create `Notifications.Application.Behaviours.NotificationRepositoryBehaviour` (port)

#### 1.4 Migrate Infrastructure Layer
1. Create `Notifications.Infrastructure.Schemas.NotificationSchema` — Ecto schema referencing `users` table via `user_id` (UUID foreign key, no `belongs_to` association to Identity schema — just a raw UUID field to avoid cross-app schema dependency)
2. Create `Notifications.Infrastructure.Repositories.NotificationRepository` using `Notifications.Repo`
3. Create `Notifications.Infrastructure.Queries.NotificationQueries`
4. Move `WorkspaceInvitationSubscriber` to `Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber` — still subscribes to `events:identity:workspace_member`, handles `MemberInvited`
5. Create new migration in `apps/notifications/priv/repo/migrations/` — the `notifications` table already exists in the shared DB from the Jarga migration, so this migration should be a no-op or handled via a "claim existing table" pattern

#### 1.5 Move Accept/Decline to Identity
1. Create `Identity.Application.UseCases.AcceptWorkspaceInvitationFromNotification` use case (or extend existing `AcceptInvitation` flow)
2. Create `Identity.Application.UseCases.DeclineWorkspaceInvitationFromNotification` use case
3. These use cases accept a `notification_id` parameter, call `Notifications.mark_as_read/2` after processing (or emit a domain event that Notifications subscribes to)
4. Alternatively: the UI in `jarga_web` calls `Identity` directly for accept/decline, then calls `Notifications.mark_as_read/2` — this is simpler and avoids Identity depending on Notifications

#### 1.6 Update Public Facade
1. `Notifications` facade exposes:
   - `create_notification/1` — generic notification creation with type, title, body, data, user_id
   - `get_notification/2` — get by ID for user
   - `list_notifications/2` — list all for user with opts (limit, offset)
   - `list_unread_notifications/1`
   - `mark_as_read/2`
   - `mark_all_as_read/1`
   - `unread_count/1`
2. Remove all workspace invitation action functions from the facade

#### 1.7 Update Interface Layer (jarga_web)
1. Update `NotificationBell` to import from `Notifications` instead of `Jarga.Notifications`
2. Remove accept/decline button handling from `NotificationBell` — delegate to Identity/Workspaces (either via direct call from the component or through a separate WorkspaceInvitation component)
3. Update `NotificationsLive.OnMount` to import `Notifications.Domain.Events.NotificationCreated`
4. Update `ChatLive.MessageHandlers` to import from `Notifications.Domain.Events.NotificationCreated`
5. Update `WorkspacesLive.Index/Show` and `Dashboard` — remove `NotificationActionTaken` event handling (or replace with a new event from Identity if needed for workspace list refresh)
6. Update `jarga_web` Boundary deps to include `Notifications`

#### 1.8 Clean Up Jarga
1. Remove `apps/jarga/lib/notifications/` directory entirely (all 18 files)
2. Remove `apps/jarga/lib/notifications.ex` facade
3. Remove `Jarga.Notifications` from `Jarga.Application` supervisor (WorkspaceInvitationSubscriber)
4. Remove `Jarga.Notifications` from `jarga` Boundary deps in `jarga.ex` or wherever it's declared
5. Update `jarga_web` Boundary deps: remove `Jarga.Notifications`, add `Notifications`
6. Remove notification-related test files from `apps/jarga/test/`
7. Update `user_session_controller.ex` in `jarga_web` — `create_notifications_for_pending_invitations` call should remain (it goes to Identity which emits `MemberInvited` events, and the new `WorkspaceInvitationSubscriber` in the notifications app picks them up)

#### 1.9 Data Migration
1. The `notifications` table already exists in the shared Postgres database (created by `Jarga.Repo.Migrations.CreateNotifications`)
2. `Notifications.Repo` points to the same database, so it can read/write the existing `notifications` table immediately
3. No data migration needed — only the Repo that accesses the table changes
4. Future migrations for the `notifications` table go in `apps/notifications/priv/repo/migrations/`

### Phase 2: Browser Push Notification Delivery (P1 — Should Have)

#### 2.1 Web Push Infrastructure
1. Add `web_push` library dependency (e.g., `web_push_elixir` or similar)
2. Generate VAPID key pair for push notification signing
3. Store VAPID keys in application config (not in code)

#### 2.2 Push Subscription Management
1. Create `push_subscriptions` table: `id`, `user_id`, `endpoint` (string), `p256dh_key` (string), `auth_key` (string), `user_agent` (string), `inserted_at`, `updated_at`
2. Create `PushSubscriptionSchema`, `PushSubscriptionRepository`
3. Create use cases: `RegisterPushSubscription`, `UnregisterPushSubscription`, `ListUserPushSubscriptions`

#### 2.3 Notification Delivery Pipeline
1. Create `Notifications.Infrastructure.Delivery.InAppDelivery` — current behaviour (emit PubSub event for LiveView)
2. Create `Notifications.Infrastructure.Delivery.WebPushDelivery` — sends push notification via Web Push API
3. Create `Notifications.Application.Behaviours.DeliveryChannel` behaviour with `deliver/2` callback
4. Update `CreateNotification` use case to invoke delivery pipeline after persisting notification

#### 2.4 Service Worker & Client-Side (jarga_web)
1. Create Service Worker for push notification handling (`sw.js`)
2. Add push subscription JavaScript (request permission, subscribe, send subscription to server)
3. Create API endpoint in `jarga_web` (or `notifications_api` if created) for registering/unregistering push subscriptions
4. Handle push notification click events (navigate to relevant page)

### Phase 3: Delivery Preferences & Extensible Registry (P2 — Nice to Have)

#### 3.1 Notification Type Registry
1. Create `Notifications.Application.Behaviours.NotificationTypeProvider` behaviour:
   ```
   @callback notification_types() :: [notification_type_spec()]
   ```
   where each spec defines: `type` (string key), `label` (human-readable), `description`, `default_channels` (list of delivery channels enabled by default)
2. Create compile-time or runtime registry that collects notification types from all registered provider modules (similar to `ToolProvider.Loader` pattern in Agents)
3. Seed with `WorkspaceInvitationNotificationType` as the first provider

#### 3.2 Delivery Preferences
1. Create `delivery_preferences` table: `id`, `user_id`, `notification_type` (string), `channel` (string enum: `in_app`, `browser_push`, `mobile_push`), `enabled` (boolean), `inserted_at`, `updated_at`
2. Unique constraint on `(user_id, notification_type, channel)`
3. Create use cases: `GetUserPreferences`, `UpdateUserPreference`, `GetDefaultPreferences`
4. When no preference exists for a user+type+channel, fall back to the default from the registry
5. Update delivery pipeline to check preferences before delivering

#### 3.3 Preferences UI
1. Create notification preferences page/panel in `jarga_web`
2. List all registered notification types grouped by source app
3. Toggle channels (in-app, browser push, mobile push) per notification type
4. Save preferences via `Notifications` facade

#### 3.4 Extensible Event-to-Notification Mapping
1. Each `NotificationTypeProvider` defines which domain events trigger which notification type, including how to extract `user_id`, `title`, `body`, and `data` from the event
2. Create a generic `DomainEventSubscriber` that subscribes to configured topics and routes events through the registry to create appropriate notifications
3. This replaces individual subscribers (like `WorkspaceInvitationSubscriber`) with a single, registry-driven subscriber — though individual subscribers can coexist for complex mapping logic

---

## User Workflows

### Workflow 1: Receive In-App Notification (Phase 1)
1. Domain event occurs (e.g., `MemberInvited` emitted by Identity)
2. `WorkspaceInvitationSubscriber` in notifications app receives the event
3. Subscriber calls `CreateNotification` use case with notification attributes
4. Use case persists notification via `NotificationRepository`
5. Use case emits `NotificationCreated` domain event via EventBus
6. EventBus broadcasts to `events:user:{target_user_id}` topic
7. `NotificationsLive.OnMount` in jarga_web receives the event
8. OnMount forwards to `NotificationBell` LiveComponent with `force_reload: true`
9. NotificationBell re-fetches notifications and updates unread count badge

### Workflow 2: Accept Workspace Invitation After Extraction (Phase 1)
1. User sees workspace invitation notification in NotificationBell dropdown
2. User clicks "Accept" button
3. `jarga_web` calls `Identity.accept_invitation_by_workspace/2` directly
4. `jarga_web` calls `Notifications.mark_as_read/2` to mark the notification as read
5. UI reloads notifications to reflect updated state

### Workflow 3: Receive Browser Push Notification (Phase 2)
1. User has granted browser notification permission and subscribed
2. Domain event triggers notification creation (same as Workflow 1, steps 1-4)
3. Delivery pipeline checks user's push subscriptions
4. `WebPushDelivery` sends push notification to each registered endpoint
5. Service Worker receives push event and displays OS notification
6. User clicks notification — Service Worker opens/focuses the app tab

### Workflow 4: Configure Delivery Preferences (Phase 3)
1. User navigates to notification preferences
2. System loads registered notification types from registry
3. System loads user's current preferences (with defaults for unset types)
4. User toggles channels per notification type (e.g., disable browser push for document changes)
5. System persists preferences
6. Future notifications respect these preferences in the delivery pipeline

---

## Data Requirements

### Existing: `notifications` Table (Phase 1 — no schema change, new Repo)
| Field | Type | Constraints |
|-------|------|-------------|
| `id` | `binary_id` | PK, auto-generated |
| `user_id` | `binary_id` | FK to `users`, NOT NULL, indexed |
| `type` | `string` | NOT NULL, indexed |
| `title` | `string` | NOT NULL |
| `body` | `text` | nullable |
| `data` | `map` | NOT NULL, default `{}` |
| `read` | `boolean` | NOT NULL, default `false` |
| `read_at` | `utc_datetime` | nullable |
| `action_taken_at` | `utc_datetime` | nullable (kept for backward compat with existing data) |
| `inserted_at` | `utc_datetime` | auto |
| `updated_at` | `utc_datetime` | auto |

Indexes: `(user_id)`, `(user_id, read)`, `(type)`, `(inserted_at)`

### New: `push_subscriptions` Table (Phase 2)
| Field | Type | Constraints |
|-------|------|-------------|
| `id` | `binary_id` | PK, auto-generated |
| `user_id` | `binary_id` | FK to `users`, NOT NULL, indexed |
| `endpoint` | `string` | NOT NULL, unique |
| `p256dh_key` | `string` | NOT NULL |
| `auth_key` | `string` | NOT NULL |
| `user_agent` | `string` | nullable |
| `inserted_at` | `utc_datetime` | auto |
| `updated_at` | `utc_datetime` | auto |

### New: `delivery_preferences` Table (Phase 3)
| Field | Type | Constraints |
|-------|------|-------------|
| `id` | `binary_id` | PK, auto-generated |
| `user_id` | `binary_id` | FK to `users`, NOT NULL |
| `notification_type` | `string` | NOT NULL |
| `channel` | `string` | NOT NULL (enum: `in_app`, `browser_push`, `mobile_push`) |
| `enabled` | `boolean` | NOT NULL, default `true` |
| `inserted_at` | `utc_datetime` | auto |
| `updated_at` | `utc_datetime` | auto |

Unique constraint: `(user_id, notification_type, channel)`

### Relationships
- `notifications.user_id` references `users.id` (no Ecto association — raw UUID to avoid cross-app schema dependency)
- `push_subscriptions.user_id` references `users.id`
- `delivery_preferences.user_id` references `users.id`

---

## Technical Considerations

### Affected Layers
| Layer | Phase 1 | Phase 2 | Phase 3 |
|-------|---------|---------|---------|
| Domain | Entities, events, policies | — | — |
| Application | Use cases, behaviours | Delivery pipeline, push subscription use cases | Preferences use cases, registry |
| Infrastructure | Schema, repo, queries, subscriber | Push delivery, push subscription schema/repo | Preferences schema/repo, generic event subscriber |
| Interface | Update jarga_web imports + NotificationBell | Service Worker, push subscription API | Preferences UI |

### Integration Points
- **Perme8.Events**: EventBus for emitting notification domain events; EventHandler for subscribing to domain events from other apps
- **Identity**: Source of `MemberInvited` events; accepts workspace invitation actions directly
- **jarga_web**: Hosts `NotificationBell` component, renders notification UI, will host Service Worker and preferences UI
- **All domain apps** (future): Will register notification type providers

### Performance
- Notification queries are user-scoped — indexes on `(user_id)` and `(user_id, read)` ensure fast lookups
- `unread_count` should be O(1) via aggregate query on indexed column
- Push notification delivery should be async (fire-and-forget via Task or GenServer) — do NOT block notification creation on push delivery
- NotificationBell limits to 20 most recent notifications per load

### Security
- Notifications are strictly user-scoped: all queries filter by `user_id`
- Push subscription endpoints contain auth tokens — store securely, transmit over HTTPS only
- VAPID keys must not be committed to source code — use environment config
- Push subscription registration must verify the requesting user is authenticated
- No notification data should leak across users or workspaces

### Deployment Considerations
- Phase 1 is zero-downtime: the `notifications` table already exists in the shared DB; switching from `Identity.Repo` to `Notifications.Repo` (same DB) is transparent
- VAPID key generation (Phase 2) is a one-time setup task before deploying push support
- The Service Worker file must be served from the root path (`/sw.js`) for proper scope

---

## Edge Cases & Error Handling

### Phase 1
1. **Duplicate notification delivery**: If `WorkspaceInvitationSubscriber` receives the same `MemberInvited` event twice (PubSub at-least-once) -> **Expected**: Use idempotency check (e.g., check for existing notification with same `type` + `user_id` + `data.workspace_id`) or accept duplicate and let UI handle it gracefully
2. **User deleted while notifications exist**: FK constraint `on_delete: :delete_all` ensures notifications are cleaned up when user is deleted
3. **Notification for non-existent user**: If `MemberInvited` event contains a `user_id` that doesn't exist in `users` table -> **Expected**: FK constraint rejects insert; subscriber logs error and returns `{:error, reason}`
4. **Concurrent mark_all_as_read**: Two simultaneous calls for same user -> **Expected**: Both succeed; second call updates zero rows (idempotent)
5. **Subscriber not started in test env**: -> **Expected**: Subscriber is conditionally started (same pattern as current Jarga.Application); tests that need it explicitly start it

### Phase 2
6. **Push subscription endpoint expired/invalid**: -> **Expected**: Web Push API returns 404/410; delivery service removes stale subscription from DB
7. **User revokes browser notification permission**: -> **Expected**: Push delivery fails silently; in-app delivery continues unaffected
8. **Service Worker registration fails**: -> **Expected**: Fall back to in-app notifications only; log warning to console

### Phase 3
9. **Unknown notification type in preferences**: If a notification type is deregistered but preferences remain -> **Expected**: Preferences for unknown types are ignored; preference cleanup on registry change is optional
10. **No delivery preferences set**: -> **Expected**: Fall back to defaults defined in the notification type registry

---

## Scenarios (Given/When/Then for BDD Feature Generation)

### Phase 1: Core Extraction

#### Scenario: Create notification from domain event
```
Given a user exists with id "user-1"
And the WorkspaceInvitationSubscriber is running
When a MemberInvited event is emitted for user "user-1" to workspace "ws-1"
Then a notification is created with type "workspace_invitation"
And the notification belongs to user "user-1"
And a NotificationCreated event is emitted
```

#### Scenario: List notifications for a user
```
Given a user exists with id "user-1"
And user "user-1" has 3 notifications
When I list notifications for user "user-1"
Then I receive 3 notifications ordered by most recent first
```

#### Scenario: List unread notifications
```
Given a user exists with id "user-1"
And user "user-1" has 2 unread and 1 read notification
When I list unread notifications for user "user-1"
Then I receive 2 notifications
And all returned notifications have read as false
```

#### Scenario: Mark notification as read
```
Given a user exists with id "user-1"
And user "user-1" has an unread notification with id "notif-1"
When I mark notification "notif-1" as read for user "user-1"
Then the notification "notif-1" has read as true
And the notification "notif-1" has a read_at timestamp
```

#### Scenario: Mark all notifications as read
```
Given a user exists with id "user-1"
And user "user-1" has 3 unread notifications
When I mark all notifications as read for user "user-1"
Then all 3 notifications have read as true
And the unread count for user "user-1" is 0
```

#### Scenario: Get unread count
```
Given a user exists with id "user-1"
And user "user-1" has 5 unread notifications
When I get the unread count for user "user-1"
Then the count is 5
```

#### Scenario: Notification scoped to user
```
Given user "user-1" has 3 notifications
And user "user-2" has 2 notifications
When I list notifications for user "user-1"
Then I receive exactly 3 notifications
And none of the notifications belong to user "user-2"
```

#### Scenario: Real-time notification delivery via PubSub
```
Given a user is viewing the notification bell in the browser
When a NotificationCreated event is emitted for that user
Then the notification bell unread count updates without page reload
And the new notification appears in the dropdown
```

#### Scenario: Accept workspace invitation (moved out of notifications)
```
Given a user has a workspace invitation notification
When the user clicks "Accept" in the notification bell
Then Identity.accept_invitation_by_workspace is called
And the notification is marked as read
And the workspace appears in the user's workspace list
```

### Phase 2: Browser Push

#### Scenario: Register push subscription
```
Given a user is logged in
And the user grants browser notification permission
When the browser generates a push subscription
Then the subscription endpoint and keys are saved for the user
```

#### Scenario: Deliver browser push notification
```
Given a user has a registered push subscription
When a notification is created for that user
Then a Web Push message is sent to the subscription endpoint
And the browser displays an OS notification
```

#### Scenario: Handle expired push subscription
```
Given a user has a push subscription with an expired endpoint
When a notification delivery is attempted
Then the push delivery fails with a 410 status
And the expired subscription is removed from the database
And the in-app notification is still delivered
```

### Phase 3: Preferences & Registry

#### Scenario: Register notification type
```
Given the WorkspaceInvitationNotificationType provider is registered
When the notification type registry is queried
Then it contains "workspace_invitation" with label "Workspace Invitation"
And the default channels include "in_app"
```

#### Scenario: Respect delivery preferences
```
Given a user has disabled browser_push for "workspace_invitation" type
When a workspace invitation notification is created for that user
Then the notification is delivered via in-app channel
And no browser push notification is sent
```

#### Scenario: Default preferences for new notification type
```
Given a new notification type "document_shared" is registered with default channels ["in_app", "browser_push"]
And a user has no explicit preferences for "document_shared"
When a "document_shared" notification is created
Then it is delivered via both in_app and browser_push channels
```

---

## Acceptance Criteria

### Phase 1 (Extract into Standalone App)
- [ ] `apps/notifications/` exists as standalone umbrella app with `mix.exs`, `Notifications.Repo`, and `Notifications.OTPApp`
- [ ] `Notifications` facade provides: `create_notification/1`, `get_notification/2`, `list_notifications/2`, `list_unread_notifications/1`, `mark_as_read/2`, `mark_all_as_read/1`, `unread_count/1`
- [ ] `Notifications.Repo` connects to the shared Postgres database
- [ ] `NotificationSchema` in notifications app uses `Notifications.Repo` (not `Identity.Repo`)
- [ ] `NotificationSchema` uses raw `user_id` UUID field (no Ecto `belongs_to` to Identity schemas)
- [ ] Domain events (`NotificationCreated`, `NotificationRead`) live in `Notifications.Domain.Events.*`
- [ ] `NotificationActionTaken` event is removed
- [ ] `WorkspaceInvitationSubscriber` runs in `Notifications.OTPApp` supervisor
- [ ] `WorkspaceInvitationSubscriber` successfully receives `MemberInvited` events and creates notifications
- [ ] `AcceptWorkspaceInvitation` and `DeclineWorkspaceInvitation` use cases are NOT in the notifications app
- [ ] Workspace invitation accept/decline works via Identity from `jarga_web` with notification marked as read afterward
- [ ] `NotificationBell` in `jarga_web` imports from `Notifications` (not `Jarga.Notifications`)
- [ ] Real-time notification updates work (PubSub → LiveView)
- [ ] `apps/jarga/lib/notifications/` directory is completely removed
- [ ] `apps/jarga/lib/notifications.ex` facade is removed
- [ ] All existing notification tests pass (relocated to `apps/notifications/test/`)
- [ ] Boundary compilation has no new warnings
- [ ] `mix precommit` passes

### Phase 2 (Browser Push)
- [ ] VAPID keys configured via environment/application config
- [ ] `push_subscriptions` table exists with proper schema and indexes
- [ ] Users can register/unregister push subscriptions via API endpoint
- [ ] Service Worker is registered and handles push events
- [ ] Notifications trigger Web Push delivery to all user's active subscriptions
- [ ] Expired/invalid subscriptions are cleaned up automatically
- [ ] Push delivery failures do not affect in-app notification delivery
- [ ] Push notification click navigates to the relevant page in the app

### Phase 3 (Preferences & Registry)
- [ ] `NotificationTypeProvider` behaviour exists and is implementable by any app
- [ ] At least one provider is registered (`WorkspaceInvitationNotificationType`)
- [ ] `delivery_preferences` table exists with proper schema and unique constraint
- [ ] Users can view and update delivery preferences per notification type and channel
- [ ] Delivery pipeline respects user preferences before sending
- [ ] Unset preferences fall back to registry defaults

---

## Codebase Context

### Existing Patterns (Reference Implementations)

| Pattern | Reference | Location |
|---------|-----------|----------|
| Standalone app with own Repo | Agents app | `apps/agents/lib/agents/repo.ex`, `apps/agents/lib/agents/otp_app.ex` |
| OTP Application supervisor | Agents.OTPApp | `apps/agents/lib/agents/otp_app.ex` |
| Public facade (thin delegation) | Agents module | `apps/agents/lib/agents.ex` |
| Boundary configuration | Agents module | `apps/agents/lib/agents.ex` (lines 32-43) |
| Domain events | Agent events | `apps/agents/lib/agents/domain/events/` |
| EventHandler subscriber | WorkspaceInvitationSubscriber | `apps/jarga/lib/notifications/infrastructure/subscribers/workspace_invitation_subscriber.ex` |
| DomainEvent macro | All events | `apps/perme8_events/lib/perme8_events/domain_event.ex` |
| Use case with DI | CreateWorkspaceInvitationNotification | `apps/jarga/lib/notifications/application/use_cases/create_workspace_invitation_notification.ex` |
| Extensible provider registry | ToolProvider + Loader | `apps/agents/lib/agents/infrastructure/mcp/tool_provider.ex`, `tool_provider/loader.ex` |
| Cross-app facade call from jarga_web | Agents in jarga_web | jarga_web depends on Agents facade; NotificationBell should follow same pattern |

### Affected Contexts / Files

**Files to create** (Phase 1):
- `apps/notifications/mix.exs`
- `apps/notifications/lib/notifications.ex` (facade)
- `apps/notifications/lib/notifications/repo.ex`
- `apps/notifications/lib/notifications/otp_app.ex`
- `apps/notifications/lib/notifications/domain/entities/notification.ex`
- `apps/notifications/lib/notifications/domain/events/notification_created.ex`
- `apps/notifications/lib/notifications/domain/events/notification_read.ex`
- `apps/notifications/lib/notifications/domain/policies/notification_policy.ex`
- `apps/notifications/lib/notifications/application/use_cases/create_notification.ex`
- `apps/notifications/lib/notifications/application/use_cases/mark_as_read.ex`
- `apps/notifications/lib/notifications/application/use_cases/mark_all_as_read.ex`
- `apps/notifications/lib/notifications/application/use_cases/get_unread_count.ex`
- `apps/notifications/lib/notifications/application/use_cases/list_notifications.ex`
- `apps/notifications/lib/notifications/application/use_cases/list_unread_notifications.ex`
- `apps/notifications/lib/notifications/application/behaviours/notification_repository_behaviour.ex`
- `apps/notifications/lib/notifications/infrastructure/schemas/notification_schema.ex`
- `apps/notifications/lib/notifications/infrastructure/repositories/notification_repository.ex`
- `apps/notifications/lib/notifications/infrastructure/queries/notification_queries.ex`
- `apps/notifications/lib/notifications/infrastructure/subscribers/workspace_invitation_subscriber.ex`

**Files to modify** (Phase 1):
- `apps/jarga_web/lib/live/notifications_live/notification_bell.ex` — change alias from `Jarga.Notifications` to `Notifications`; update accept/decline to call Identity directly then mark_as_read
- `apps/jarga_web/lib/live/notifications_live/on_mount.ex` — change alias from `Jarga.Notifications.Domain.Events.NotificationCreated` to `Notifications.Domain.Events.NotificationCreated`
- `apps/jarga_web/lib/live/chat_live/message_handlers.ex` — update NotificationCreated alias
- `apps/jarga_web/lib/live/app_live/workspaces/show.ex` — remove/update `NotificationActionTaken` handling
- `apps/jarga_web/lib/live/app_live/workspaces/index.ex` — remove/update `NotificationActionTaken` handling
- `apps/jarga_web/lib/live/app_live/dashboard.ex` — remove/update `NotificationActionTaken` handling
- `apps/jarga_web/lib/components/layouts.ex` — no change needed (NotificationBell component reference stays same)
- `apps/jarga_web/lib/jarga_web.ex` or equivalent — update Boundary deps
- `apps/jarga/lib/application.ex` — remove WorkspaceInvitationSubscriber from supervisor
- Root `mix.exs` or umbrella config — add `notifications` app

**Files to delete** (Phase 1):
- `apps/jarga/lib/notifications.ex`
- `apps/jarga/lib/notifications/` (entire directory — 18 files)
- All notification tests under `apps/jarga/test/` related to notifications

### Available Infrastructure
- `Perme8.Events.EventBus` — for emitting domain events
- `Perme8.Events.EventHandler` — for subscribing to domain events (GenServer-based)
- `Perme8.Events.DomainEvent` — macro for defining typed event structs
- `Perme8.Events.TestEventBus` — for testing event emission
- `Perme8.Events.PubSub` — Phoenix PubSub server
- `Identity` facade — for accept/decline workspace invitation operations

---

## Open Questions

- [ ] **Phase 1 — Migration ownership**: Should the existing Jarga migration (`20251107175147_create_notifications.exs`) be left in place in Jarga, or should it be moved/duplicated into the notifications app? Since `Notifications.Repo` points to the same DB and the table already exists, no new migration is strictly needed — but the migration "history" lives in Jarga's Repo. **Recommendation**: Leave the existing migration in Jarga (it's historical), and any future schema changes go in `apps/notifications/priv/repo/migrations/`.
- [ ] **Phase 1 — `action_taken_at` column**: With `NotificationActionTaken` event removed and action handling moved out, should the `action_taken_at` column be kept on the schema for backward compatibility with existing data, or dropped in a later migration? **Recommendation**: Keep for now; deprecate in a future cleanup.
- [ ] **Phase 1 — Accept/decline UI approach**: Should accept/decline buttons remain in the `NotificationBell` component (calling Identity directly), or should they be extracted into a separate `WorkspaceInvitationAction` component? The former is simpler; the latter is cleaner separation.
- [ ] **Phase 2 — Web Push library**: Which Elixir library for Web Push? Options include `web_push_encryption`, `pigeon`, or a custom implementation using `jose` for VAPID signing. Needs spike research.
- [ ] **Phase 2 — Notifications API app**: Should push subscription registration go through an existing API endpoint in `jarga_web`/`jarga_api`, or should a new `notifications_api` app be created? **Recommendation**: Start with an endpoint in `jarga_web` (it already hosts the NotificationBell); extract to `notifications_api` only if the API surface grows.
- [ ] **Phase 3 — Registry loading**: Should the notification type registry use compile-time loading (like ToolProvider.Loader with `Application.compile_env`) or runtime registration (apps register types on boot)? Compile-time is simpler but less dynamic; runtime allows hot-loading. **Recommendation**: Compile-time (matches existing ToolProvider pattern).

---

## Out of Scope

- **Mobile push notifications**: Phase 2 covers browser push only. Mobile push (APNs/FCM) is a future phase dependent on mobile app development.
- **Email notification delivery**: Email notifications (e.g., "you have unread notifications") are not part of this extraction. Email remains a responsibility of each domain's own notifiers (e.g., `WorkspaceNotifier` in Identity).
- **Notification templates/i18n**: Notification title/body construction remains hardcoded per notification type for now. A templating system is not in scope.
- **Notification grouping/batching**: Grouping multiple notifications (e.g., "3 new documents created") or digest emails are not in scope.
- **Notification retention/archival**: No automatic cleanup of old notifications. This can be addressed in a future maintenance ticket.
- **Chat app extraction**: The chat bounded context extraction (#37) is a separate effort. Notifications will subscribe to chat events once chat is extracted, via the extensible registry.
- **Read receipts or delivery confirmation**: No tracking of whether a push notification was received/opened.

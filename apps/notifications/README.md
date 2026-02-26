# Notifications

Standalone domain app for notification creation, delivery, and management. Extracted from `Jarga` as part of the Standalone App Principle.

## Responsibilities

- Notification CRUD (create, list, mark as read)
- Event-driven notification creation (subscribes to domain events from other apps)
- Real-time delivery via PubSub (consumed by LiveView components in `jarga_web`)

## Dependencies

- `identity` — source of `MemberInvited` events
- `perme8_events` — event bus infrastructure (`EventBus`, `EventHandler`, `DomainEvent`)

## Architecture

```
Notifications (facade)
├── Domain
│   ├── Entities/Notification     — pure struct
│   ├── Events/NotificationCreated, NotificationRead
│   └── Policies/NotificationPolicy
├── Application
│   ├── Behaviours/NotificationRepositoryBehaviour
│   └── UseCases/ (CreateNotification, MarkAsRead, MarkAllAsRead, etc.)
└── Infrastructure
    ├── Schemas/NotificationSchema
    ├── Repositories/NotificationRepository
    ├── Queries/NotificationQueries
    └── Subscribers/WorkspaceInvitationSubscriber
```

## Public API

```elixir
Notifications.create_notification(params)
Notifications.create_workspace_invitation_notification(params)
Notifications.get_notification(id, user_id)
Notifications.list_notifications(user_id, opts \\ [])
Notifications.list_unread_notifications(user_id)
Notifications.mark_as_read(notification_id, user_id)
Notifications.mark_all_as_read(user_id)
Notifications.unread_count(user_id)
```

## Database

Uses `Notifications.Repo` pointing to the shared Postgres database. The `notifications` table was originally created by a Jarga migration and is now owned by this app. Future schema changes go in `apps/notifications/priv/repo/migrations/`.

## Testing

```bash
mix test apps/notifications/test/
```

99 tests covering domain (27), application (16), infrastructure (38), and facade (18) layers.

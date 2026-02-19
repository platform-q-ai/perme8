# Jarga

Core domain logic for the Perme8 platform. Contains all primary bounded contexts: Workspaces, Projects, Documents, Notes, Chat, and Notifications. Owns the main database (`Jarga.Repo`), mailer, and PubSub system. Also hosts the shared `Perme8.Events` event-driven infrastructure (EventBus, EventHandler, TestEventBus).

## Architecture

Jarga is organized as a collection of bounded contexts, each following Clean Architecture with compile-time boundary enforcement:

```
Application (Use Cases, Behaviours)
    |
Domain (Entities, Policies, Services, Events)
    |
Infrastructure (Ecto Schemas, Repositories, Queries, Subscribers)
```

## Perme8.Events (Shared Event Infrastructure)

This app hosts the core event-driven infrastructure used by all umbrella apps:

| Module | Purpose |
|--------|---------|
| `Perme8.Events` | Top-level boundary; provides `subscribe/1` and `unsubscribe/1` helpers |
| `Perme8.Events.EventBus` | Central event dispatcher; wraps `Phoenix.PubSub` with topic-based routing |
| `Perme8.Events.EventHandler` | Behaviour + macro for GenServer-based event subscribers |
| `Perme8.Events.TestEventBus` | In-memory event bus for unit test assertions |

> **Note**: The `Perme8.Events.DomainEvent` macro lives in the `identity` app due to compile-time dependency constraints (agents cannot depend on jarga).

### Topic Routing

Each event is broadcast to multiple topics:
- `events:{context}` (e.g., `events:projects`)
- `events:{context}:{aggregate_type}` (e.g., `events:projects:project`)
- `events:workspace:{workspace_id}` (workspace-scoped)
- `events:user:{target_user_id}` (user-scoped)

### Event Emission Pattern

All use cases emit structured domain events via `opts[:event_bus]` dependency injection:

```elixir
@default_event_bus Perme8.Events.EventBus

def execute(params, opts \\ []) do
  event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

  result = Repo.transact(fn -> ... end)

  case result do
    {:ok, entity} ->
      event_bus.emit(%ProjectCreated{...})
      {:ok, entity}
    error -> error
  end
end
```

## Bounded Contexts

### Workspaces

Multi-tenant workspace management with role-based membership.

| Layer | Modules |
|-------|---------|
| Domain | `Workspace`, `WorkspaceMember` entities; `SlugGenerator` |
| Application | `InviteMember`, `RemoveMember`, `CreateNotificationsForPendingInvitations` use cases |
| Infrastructure | `WorkspaceSchema`, `WorkspaceMemberSchema`, `WorkspaceRepository`, `WorkspaceMemberRepository` |

Roles: Owner, Admin, Member, Guest

### Projects

Project management within workspaces.

| Layer | Modules |
|-------|---------|
| Domain | `Project` entity; `ProjectCreated`, `ProjectUpdated`, `ProjectDeleted`, `ProjectArchived` events |
| Application | `CreateProject`, `UpdateProject`, `DeleteProject` use cases |
| Infrastructure | `ProjectSchema`, `ProjectRepository` |

### Documents

Collaborative document management with component-based structure and agent query support.

| Layer | Modules |
|-------|---------|
| Domain | `Document`, `DocumentComponent` entities; `DocumentCreated`, `DocumentDeleted`, `DocumentTitleChanged`, `DocumentVisibilityChanged`, `DocumentPinnedChanged` events; `SlugGenerator`, `AgentQueryParser`, `DocumentAccessPolicy` |
| Application | `CreateDocument`, `UpdateDocument`, `DeleteDocument`, `ExecuteAgentQuery` use cases; authorization module |
| Infrastructure | `DocumentSchema`, `DocumentComponentSchema`, repositories, queries, `ComponentLoader` |

### Documents.Notes

Note-taking within documents with content hashing for change detection.

| Layer | Modules |
|-------|---------|
| Domain | `Note` entity, `ContentHash` |
| Infrastructure | `NoteSchema`, `NoteRepository`, `AuthorizationRepository`, queries |

### Chat

Chat sessions and messaging tied to agents.

| Layer | Modules |
|-------|---------|
| Domain | `Session`, `Message` entities; `ChatSessionStarted`, `ChatMessageSent`, `ChatSessionDeleted` events |
| Infrastructure | `SessionSchema`, `MessageSchema`, repositories, queries |

### Notifications

Real-time notification system with EventHandler-based subscribers.

| Layer | Modules |
|-------|---------|
| Domain | `NotificationCreated`, `NotificationRead`, `NotificationActionTaken` events |
| Application | `AcceptWorkspaceInvitation`, `CreateWorkspaceInvitationNotification`, `DeclineWorkspaceInvitation`, `GetUnreadCount`, `ListNotifications`, `MarkAsRead` use cases |
| Infrastructure | `NotificationSchema`, `WorkspaceInvitationSubscriber` (EventHandler) |

### Accounts

Thin facade module delegating to the `identity` app for user-related operations.

## Dependencies

- **`identity`** (in_umbrella) -- user authentication and API key verification
- Phoenix, Ecto, Postgrex -- web framework and database
- Swoosh -- email delivery
- Finch, Req -- HTTP clients (for LLM integration)
- Slugy -- slug generation
- Mdex -- Markdown processing
- Boundary -- compile-time boundary enforcement

## Database

`Jarga.Repo` is the primary PostgreSQL database, containing tables for workspaces, workspace_members, projects, documents, document_components, notes, agents, workspace_agents, chat_sessions, chat_messages, and notifications.

## Testing

```bash
# Run all jarga tests
mix test apps/jarga/test

# Run tests for a specific context
mix test apps/jarga/test/jarga/workspaces/
mix test apps/jarga/test/jarga/documents/
```

Uses `Perme8.Events.TestEventBus` for event emission assertions, Mox for dependency mocking, and Bypass for HTTP client testing.

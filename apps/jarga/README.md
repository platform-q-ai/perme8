# Jarga

Core domain logic for the Perme8 platform. Contains all primary bounded contexts: Workspaces, Projects, Documents, Notes, Agents, Chat, and Notifications. Owns the main database (`Jarga.Repo`), mailer, and PubSub system.

## Architecture

Jarga is organized as a collection of bounded contexts, each following Clean Architecture with compile-time boundary enforcement:

```
Application (Use Cases, Behaviours)
    |
Domain (Entities, Policies, Services)
    |
Infrastructure (Ecto Schemas, Repositories, Queries, Notifiers)
```

## Bounded Contexts

### Workspaces

Multi-tenant workspace management with role-based membership.

| Layer | Modules |
|-------|---------|
| Domain | `Workspace`, `WorkspaceMember` entities; `SlugGenerator` |
| Application | `InviteMember`, `RemoveMember`, `CreateNotificationsForPendingInvitations` use cases |
| Infrastructure | `WorkspaceSchema`, `WorkspaceMemberSchema`, `WorkspaceRepository`, `WorkspaceMemberRepository`, PubSub notifier |

Roles: Owner, Admin, Member, Guest

### Projects

Project management within workspaces.

| Layer | Modules |
|-------|---------|
| Domain | `Project` entity |
| Infrastructure | `ProjectSchema`, `ProjectRepository` |

### Documents

Collaborative document management with component-based structure and agent query support.

| Layer | Modules |
|-------|---------|
| Domain | `Document`, `DocumentComponent` entities; `SlugGenerator`, `AgentQueryParser`, `DocumentAccessPolicy` |
| Application | `CreateDocument`, `UpdateDocument`, `DeleteDocument`, `ExecuteAgentQuery` use cases; authorization module |
| Infrastructure | `DocumentSchema`, `DocumentComponentSchema`, repositories, queries, PubSub notifier, `ComponentLoader` |

### Documents.Notes

Note-taking within documents with content hashing for change detection.

| Layer | Modules |
|-------|---------|
| Domain | `Note` entity, `ContentHash` |
| Infrastructure | `NoteSchema`, `NoteRepository`, `AuthorizationRepository`, queries |

### Agents

AI agent configuration per workspace with LLM client integration.

| Layer | Modules |
|-------|---------|
| Domain | Agent entities |
| Infrastructure | `AgentSchema`, `WorkspaceAgentJoinSchema`, `LLMClient`, repositories, PubSub |

### Chat

Chat sessions and messaging tied to agents.

| Layer | Modules |
|-------|---------|
| Domain | `Session`, `Message` entities |
| Infrastructure | `SessionSchema`, `MessageSchema`, repositories, queries |

### Notifications

Real-time notification system with PubSub subscribers.

| Layer | Modules |
|-------|---------|
| Infrastructure | `NotificationSchema`, `WorkspaceInvitationSubscriber` |

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

Uses Mox for dependency mocking and Bypass for HTTP client testing.

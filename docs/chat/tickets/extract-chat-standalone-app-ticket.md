# Ticket: Extract Chat into Standalone Umbrella App

## Summary
- **Problem**: Chat is a bounded context currently embedded inside the `jarga` app. It violates the Standalone App Principle by borrowing `Identity.Repo`, coupling to Identity/Jarga schemas via `belongs_to` associations, and embedding Jarga-specific concepts (documents, notes, projects) into its use cases. This makes it impossible to use chat independently and blocks future multi-user chat features (#276).
- **Value**: Extracting chat into a standalone app enforces domain boundaries, enables independent development and testing, removes cross-app schema coupling, and creates the architectural foundation for real-time multi-user chat, notifications integration, and push notifications.
- **Users**: Developers working on the perme8 platform (extraction is an internal architectural improvement). End users benefit indirectly through faster iteration on chat features and future multi-user capabilities.

## User Stories
- As a platform developer, I want chat to be a standalone umbrella app with its own Repo, so that it follows the Standalone App Principle and can be developed, tested, and deployed independently.
- As a platform developer, I want chat schemas decoupled from Identity and Jarga schemas, so that the chat app has no compile-time or runtime dependencies on other apps' internal modules.
- As a platform developer, I want the chat web layer in its own `chat_web` app, so that LiveViews, components, hooks, and feature files are owned by the correct app boundary.
- As a platform developer, I want `jarga_web` to become a thin mount point for chat, so that it renders `chat_web` components without owning chat domain logic.
- As a platform developer, I want all 90 existing BDD scenarios to continue passing after extraction, so that no regression is introduced.

## Functional Requirements

### Must Have (P0)

1. **`chat` umbrella app** created at `apps/chat/` following the established app structure pattern (see `notifications` as reference):
   - `Chat` facade module with Boundary configuration
   - `Chat.Repo` (own Ecto Repo, same database, `otp_app: :chat`)
   - `Chat.OTPApp` (Application module starting `Chat.Repo`)
   - `mix.exs` with umbrella dependencies on `identity`, `perme8_events`
   - Boundary library enforcement with `compilers: [:boundary] ++ Mix.compilers()`

2. **Domain layer migrated** to `apps/chat/lib/chat/domain/`:
   - `Chat.Domain.Entities.Session` -- pure struct (currently `Jarga.Chat.Domain.Entities.Session`)
   - `Chat.Domain.Entities.Message` -- pure struct (currently `Jarga.Chat.Domain.Entities.Message`)
   - `Chat.Domain.Events.ChatSessionStarted` -- domain event
   - `Chat.Domain.Events.ChatMessageSent` -- domain event
   - `Chat.Domain.Events.ChatSessionDeleted` -- domain event
   - Boundary module `Chat.Domain` with exports for entities and events

3. **Application layer migrated** to `apps/chat/lib/chat/application/`:
   - All 7 use cases: `CreateSession`, `SaveMessage`, `DeleteSession`, `DeleteMessage`, `LoadSession`, `ListSessions`, `PrepareContext`
   - Repository behaviours: `SessionRepositoryBehaviour`, `MessageRepositoryBehaviour`
   - Boundary module `Chat.Application`

4. **Infrastructure layer migrated** to `apps/chat/lib/chat/infrastructure/`:
   - `Chat.Infrastructure.Schemas.SessionSchema` -- decoupled from Identity/Jarga schemas (see requirement 6)
   - `Chat.Infrastructure.Schemas.MessageSchema` -- internal `belongs_to` to `SessionSchema` retained
   - `Chat.Infrastructure.Repositories.SessionRepository` -- uses `Chat.Repo` instead of `Identity.Repo`
   - `Chat.Infrastructure.Repositories.MessageRepository` -- uses `Chat.Repo` instead of `Identity.Repo`
   - `Chat.Infrastructure.Queries.Queries` -- all query objects migrated
   - Boundary module `Chat.Infrastructure`

5. **Migrations handled** for the new `Chat.Repo`:
   - New migration in `apps/chat/priv/repo/migrations/` that creates `chat_sessions` and `chat_messages` tables (for fresh database setup)
   - The existing tables already exist in the shared database. Since `Chat.Repo` connects to the same database, a migration approach is needed that works for both fresh installs and existing databases. Options:
     - Mark the original migrations in `apps/jarga/` as no-ops (tables already exist) and add corresponding migrations in `apps/chat/` using `CREATE TABLE IF NOT EXISTS`
     - Or use a data migration that transfers ownership without re-creating tables
   - Original Jarga migrations for chat tables should be preserved as-is (they've already run on existing databases) but the foreign key constraints to `users`, `workspaces`, and `projects` tables must be dropped in a new migration since chat now uses plain UUID fields

6. **Schema decoupling** -- remove all `belongs_to` associations that reference other apps' schemas:
   - `SessionSchema`: Remove `belongs_to(:user, Identity.Infrastructure.Schemas.UserSchema)`, replace with `field(:user_id, :binary_id)`
   - `SessionSchema`: Remove `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)`, replace with `field(:workspace_id, :binary_id)`
   - `SessionSchema`: Remove `belongs_to(:project, Jarga.Projects.Infrastructure.Schemas.ProjectSchema)`, replace with `field(:project_id, :binary_id)`
   - Remove `foreign_key_constraint` calls for `:user_id`, `:workspace_id`, `:project_id` from changesets (constraints won't exist in the database after migration)
   - Retain the internal `has_many(:messages, ...)` / `belongs_to(:chat_session, ...)` associations between `SessionSchema` and `MessageSchema`

7. **`PrepareContext` decoupling** -- the use case currently reads Jarga-specific LiveView assigns (`:note`, `:document`, `:current_workspace`, `:current_project`). After extraction:
   - `PrepareContext` must accept a generic context map rather than raw LiveView assigns
   - Define a clear input contract: `%{user_email: String.t(), workspace_name: String.t(), project_name: String.t(), document_title: String.t(), document_content: String.t(), document_info: map() | nil}`
   - The calling web layer is responsible for extracting these fields from LiveView assigns before calling `PrepareContext`
   - The hardcoded "Jarga" reference in the system message ("You are a helpful assistant for Jarga...") should be made configurable or generic

8. **Facade (`Chat`) updated** with the same public API surface as `Jarga.Chat`:
   - `create_session/1`
   - `save_message/1`
   - `list_sessions/2`
   - `load_session/1`
   - `delete_session/2`
   - `delete_message/2`
   - `prepare_chat_context/1` (renamed input contract per requirement 7)
   - `build_system_message/1`
   - `build_system_message_with_agent/2`

9. **Queries decoupling** -- the `with_preloads/1` query currently preloads `:user`, `:workspace`, and `:project` associations. After schema decoupling, these preloads must be removed (only `:messages` preload remains). The LoadSession use case should return a domain entity with plain UUID fields instead of loaded associations.

10. **`chat_web` umbrella app** created at `apps/chat_web/` owning the interface layer:
    - `ChatWeb.ChatLive.Panel` -- migrated from `JargaWeb.ChatLive.Panel`
    - `ChatWeb.ChatLive.Components.Message` -- migrated from `JargaWeb.ChatLive.Components.Message`
    - `ChatWeb.ChatLive.MessageHandlers` -- migrated from `JargaWeb.ChatLive.MessageHandlers`
    - TypeScript hook `chat-panel-hook.ts` -- migrated from `jarga_web` assets
    - CSS `chat.css` -- migrated from `jarga_web` assets
    - SVG assets (7 chat-related SVGs) -- migrated from `jarga_web` assets/vendor
    - HEEx template `panel.html.heex` -- migrated from `jarga_web`

11. **`jarga_web` updated** to be a thin mount point:
    - Remove `JargaWeb.ChatLive.Panel`, `MessageHandlers`, `Components.Message` from `jarga_web`
    - Import/render `ChatWeb.ChatLive.Panel` component from `chat_web` instead
    - Update `jarga_web` Boundary deps to include `Chat` and `ChatWeb` (remove `Jarga.Chat`)
    - Remove `Jarga.Chat` from `jarga_web.ex` Boundary deps list
    - The `MessageHandlers` macro will need updating to reference `ChatWeb.ChatLive.Panel` instead of `JargaWeb.ChatLive.Panel`

12. **Panel decoupling from Jarga.Accounts** -- the Panel currently calls `Jarga.Accounts.get_selected_agent_id/2` and `Jarga.Accounts.set_selected_agent_id/3`. These are delegate functions that call `Identity` directly. After extraction:
    - The `chat_web` Panel should call `Identity.get_selected_agent_id/2` and `Identity.set_selected_agent_id/3` directly (since `Identity` is an allowed dependency)
    - Or accept agent selection as assigns passed from the parent LiveView

13. **Panel decoupling from Agents** -- the Panel currently calls `Agents.chat_stream/3` and `Agents.get_workspace_agents_list/3`. After extraction:
    - `chat_web` can declare a dependency on `Agents` (it's a legitimate cross-app dependency for LLM streaming)
    - Alternatively, agent integration can be injected via assigns from the parent LiveView, making `chat_web` agent-agnostic
    - Decision: declare `Agents` as a dependency of `chat_web` for now (pragmatic), with a TODO to abstract via a behaviour/callback for #276

14. **Test migration**:
    - 16 unit test files moved from `apps/jarga/test/chat/` to `apps/chat/test/chat/`
    - Test fixtures (`ChatFixtures`) moved to `apps/chat/test/support/fixtures/`
    - `Chat.DataCase` test support module created
    - 7 BDD feature files (44 scenarios) moved from `apps/jarga_web/test/features/chat/` to `apps/chat_web/test/features/chat/`
    - 1 JS test file moved from `apps/jarga_web/assets/js/__tests__/` to `apps/chat_web/assets/js/__tests__/`
    - Step helpers in `apps/jarga_web/test/support/step_helpers.ex` updated to reference `Chat` instead of `Jarga.Chat`

15. **Jarga cleanup** -- remove all chat code from `jarga`:
    - Delete `apps/jarga/lib/chat.ex` (the facade)
    - Delete `apps/jarga/lib/chat/` directory (22 files)
    - Delete `apps/jarga/test/chat/` directory (16 test files)
    - Delete `apps/jarga/test/support/fixtures/chat_fixtures.ex`
    - Remove `Jarga.Chat` from `jarga` module's Boundary configuration
    - Update `jarga`'s `mix.exs` deps if chat was referenced

16. **Documentation updates**:
    - Update `docs/app_ownership.md`: Change `chat` from "planned, currently in `jarga`" to active standalone app with `Chat.Repo`
    - Update `docs/app_ownership.md`: Add `chat_web` as interface app
    - Update domain event ownership table: Move chat events from `jarga (chat)` to `chat`
    - Remove the "Pending Changes" entry about chat extraction

### Should Have (P1)

1. **Independent app spec** -- a brief `docs/chat/README.md` documenting:
   - Chat app purpose and responsibilities
   - Public API surface
   - Dependencies (`identity`, `perme8_events`)
   - Domain events emitted
   - Database tables owned

2. **Precommit and CI pass** -- `mix precommit` succeeds with no boundary warnings for the new `chat` and `chat_web` apps.

### Nice to Have (P2)

1. **Consolidate `PrepareContext` system message building** -- the current implementation has significant code duplication between `build_system_message/1` and `build_combined_message/2`. The extraction is an opportunity to clean this up without changing behaviour.

## User Workflows

This is a developer-facing architectural extraction. The user-facing workflows remain unchanged:

1. User opens chat panel → System loads most recent session → Panel displays messages (no change to UX)
2. User sends message → System creates/loads session → Saves user message → Streams LLM response → Saves assistant message (no change to UX)
3. User manages sessions (list, load, delete, new conversation) → System performs CRUD operations (no change to UX)

**Developer workflow for the extraction:**

1. Create `apps/chat/` and `apps/chat_web/` umbrella apps with scaffolding
2. Migrate domain layer (entities, events) -- rename modules from `Jarga.Chat.*` to `Chat.*`
3. Migrate application layer (use cases, behaviours) -- rename modules, decouple `PrepareContext`
4. Migrate infrastructure layer (schemas, repos, queries) -- rename modules, replace `Identity.Repo` with `Chat.Repo`, decouple schemas
5. Create `Chat.Repo` and `Chat.OTPApp`, configure database
6. Handle migration strategy for existing tables
7. Create `Chat` facade with public API
8. Migrate web layer to `chat_web` -- LiveViews, components, hooks, assets
9. Update `jarga_web` to mount `chat_web` components
10. Migrate all tests and BDD feature files
11. Clean up `jarga` -- remove all chat code
12. Update documentation and verify boundary compliance

## Data Requirements

### Existing Data (No Schema Changes to Tables)
- **`chat_sessions`** table: `id` (binary_id PK), `title` (string), `user_id` (binary_id, NOT NULL), `workspace_id` (binary_id, nullable), `project_id` (binary_id, nullable), `inserted_at`, `updated_at`
- **`chat_messages`** table: `id` (binary_id PK), `chat_session_id` (binary_id FK to chat_sessions, NOT NULL), `role` (string, NOT NULL), `content` (text, NOT NULL), `context_chunks` (array of binary_id), `inserted_at`, `updated_at`

### Schema Changes (Elixir-Level Only)
- `SessionSchema`: `belongs_to` associations replaced with plain `field` declarations for `user_id`, `workspace_id`, `project_id`
- Foreign key constraints in the database should be dropped via migration (user_id FK to users, workspace_id FK to workspaces, project_id FK to projects) since the chat app cannot guarantee those tables exist in its Repo scope

### Migration Strategy
- A new migration in `apps/chat/priv/repo/migrations/` drops the foreign key constraints on `chat_sessions` that reference `users`, `workspaces`, and `projects` tables
- The `chat_messages` FK to `chat_sessions` is retained (internal to chat)
- Tables themselves are NOT recreated (they already exist from `jarga` migrations)
- For fresh databases: `chat` migrations should use `CREATE TABLE IF NOT EXISTS` or be sequenced after `jarga` migrations via timestamps

### Relationships
- `Session` 1:N `Message` (internal to chat, retained)
- `Session.user_id` → Identity user (external reference, plain UUID, no FK)
- `Session.workspace_id` → Identity workspace (external reference, plain UUID, no FK)
- `Session.project_id` → Jarga project (external reference, plain UUID, no FK)

## Technical Considerations

### Affected Layers
- **Domain**: All 5 domain modules (2 entities, 3 events) migrated and renamed
- **Application**: All 9 application modules (7 use cases, 2 behaviours) migrated and renamed; `PrepareContext` decoupled
- **Infrastructure**: All 5 infrastructure modules (2 schemas, 2 repositories, 1 queries) migrated, renamed, and decoupled from `Identity.Repo` and cross-app schemas
- **Interface**: All 4 web layer files (1 LiveComponent, 1 macro module, 1 function component, 1 HEEx template) plus 1 TypeScript hook, 1 CSS file, and 7 SVG assets migrated to `chat_web`

### Integration Points
- **`identity`**: Chat stores `user_id` and `workspace_id` as plain UUIDs. The web layer may call `Identity` for agent preferences. No schema-level coupling.
- **`agents`**: The `chat_web` Panel calls `Agents.chat_stream/3` for LLM streaming and `Agents.get_workspace_agents_list/3` for agent listing. This is a legitimate interface-layer dependency.
- **`perme8_events`**: Domain events use `Perme8.Events.DomainEvent` macro and `Perme8.Events.EventBus` for emission. No change to this integration.
- **`jarga_web`**: Becomes a thin mount point rendering `ChatWeb.ChatLive.Panel`. The `MessageHandlers` macro moves to `chat_web` but is still `use`d by LiveViews in `jarga_web`.
- **Database**: `Chat.Repo` connects to the same PostgreSQL database as all other Repos. No data migration needed.

### Performance
- No performance changes expected. The extraction is a structural refactor with identical runtime behaviour.
- Database queries remain the same (same tables, same indexes, same connection pool to same database).

### Security
- Session ownership verification (`verify_session_ownership/2`) is retained in the Panel.
- Message deletion authorization (via `get_message_by_id_and_user/3`) is retained.
- No new auth concerns introduced. The web layer continues to rely on `current_user` and `current_workspace` assigns from the auth pipeline.

## Edge Cases & Error Handling

1. **Scenario**: Fresh database with no existing tables → **Expected**: `Chat.Repo` migrations create `chat_sessions` and `chat_messages` tables; `IF NOT EXISTS` guards prevent conflicts with `jarga` migrations if both run.

2. **Scenario**: Existing database with tables already created by `jarga` migrations → **Expected**: `Chat.Repo` migration uses `IF NOT EXISTS` or is a no-op for table creation; FK constraint drop migration runs cleanly.

3. **Scenario**: `chat_web` component rendered in `jarga_web` layout but `chat` app not started → **Expected**: OTP application dependency ensures `chat` starts before `jarga_web`. Add `chat` and `chat_web` to `jarga_web`'s extra_applications or mix deps.

4. **Scenario**: `PrepareContext` called with old-style LiveView assigns (during transition) → **Expected**: If transition is phased, `PrepareContext` should handle both old assign-based input and new explicit context map, or the web layer adapter handles conversion.

5. **Scenario**: Boundary violation detected during compilation → **Expected**: All module references updated from `Jarga.Chat.*` to `Chat.*`. `mix compile` produces zero boundary warnings.

6. **Scenario**: Feature file references `Jarga.Chat` or `Jarga.ChatFixtures` after migration → **Expected**: All step helpers and fixtures updated to reference `Chat` and `Chat.ChatFixtures`.

## Acceptance Criteria

- [ ] `apps/chat/` exists as a standalone umbrella app with `Chat.Repo`, `Chat.OTPApp`, and `Chat` facade
- [ ] `apps/chat_web/` exists as a standalone umbrella app with LiveViews, components, hooks, and assets
- [ ] All domain modules use `Chat.*` namespace (not `Jarga.Chat.*`)
- [ ] `Chat.Repo` is configured and connects to the shared database
- [ ] `SessionSchema` has NO `belongs_to` associations referencing Identity or Jarga schemas -- uses plain `field(:user_id, :binary_id)` etc.
- [ ] `SessionSchema` retains `has_many(:messages, ...)` internal association
- [ ] No chat code remains in `apps/jarga/lib/chat/` or `apps/jarga/lib/chat.ex`
- [ ] No chat tests remain in `apps/jarga/test/chat/`
- [ ] No chat feature files remain in `apps/jarga_web/test/features/chat/`
- [ ] No chat LiveView/component files remain in `apps/jarga_web/lib/live/chat_live/`
- [ ] `PrepareContext` accepts a generic context map, not raw LiveView assigns with Jarga-specific keys
- [ ] `jarga_web` renders chat panel via `ChatWeb.ChatLive.Panel` (not `JargaWeb.ChatLive.Panel`)
- [ ] `MessageHandlers` macro references `ChatWeb.ChatLive.Panel`
- [ ] All 44 existing BDD scenarios pass (7 feature files)
- [ ] All 16 unit test files pass in `apps/chat/test/`
- [ ] JS test for chat-panel-hook passes in `apps/chat_web/`
- [ ] `mix compile` produces zero boundary warnings for `chat`, `chat_web`, `jarga`, and `jarga_web`
- [ ] `mix precommit` passes
- [ ] `docs/app_ownership.md` updated to reflect chat as active standalone app
- [ ] Domain event ownership table updated (chat events under `chat`, not `jarga (chat)`)

## Codebase Context

### Existing Patterns (Extraction Reference: `notifications`)
- **`apps/notifications/`**: Successfully extracted from `jarga` in #38. Same pattern to follow:
  - `Notifications.Repo` at `lib/notifications/repo.ex` -- own Ecto Repo, `otp_app: :notifications`
  - `Notifications.OTPApp` at `lib/notifications/otp_app.ex` -- Application module, starts Repo + subscribers
  - `Notifications` facade at `lib/notifications.ex` -- public API with Boundary configuration
  - Layered structure: `domain/`, `application/`, `infrastructure/` under `lib/notifications/`
  - `mix.exs` with `{:perme8_events, in_umbrella: true}`, `{:identity, in_umbrella: true}`
  - Boundary config: `externals_mode: :relaxed`, `ignore: [~r/\.Test\./, ~r/\.Mocks\./]`

### Source Files to Migrate

**Domain (apps/jarga/lib/chat/) → apps/chat/lib/chat/**
| Source | Target | Changes |
|--------|--------|---------|
| `chat/domain.ex` | `chat/domain.ex` | Rename module `Jarga.Chat.Domain` → `Chat.Domain` |
| `chat/domain/entities/session.ex` | `chat/domain/entities/session.ex` | Rename module, remove `Jarga.` prefix |
| `chat/domain/entities/message.ex` | `chat/domain/entities/message.ex` | Rename module, remove `Jarga.` prefix |
| `chat/domain/events/chat_session_started.ex` | `chat/domain/events/chat_session_started.ex` | Rename module |
| `chat/domain/events/chat_message_sent.ex` | `chat/domain/events/chat_message_sent.ex` | Rename module |
| `chat/domain/events/chat_session_deleted.ex` | `chat/domain/events/chat_session_deleted.ex` | Rename module |

**Application (apps/jarga/lib/chat/) → apps/chat/lib/chat/**
| Source | Target | Changes |
|--------|--------|---------|
| `chat/application.ex` | `chat/application.ex` | Rename module, update deps |
| `chat/application/use_cases/create_session.ex` | Same relative path | Rename module, update aliases |
| `chat/application/use_cases/save_message.ex` | Same relative path | Rename module, update aliases |
| `chat/application/use_cases/delete_session.ex` | Same relative path | Rename module, update aliases |
| `chat/application/use_cases/delete_message.ex` | Same relative path | Rename module, update aliases |
| `chat/application/use_cases/load_session.ex` | Same relative path | Rename module, update aliases |
| `chat/application/use_cases/list_sessions.ex` | Same relative path | Rename module, update aliases |
| `chat/application/use_cases/prepare_context.ex` | Same relative path | Rename module, decouple from LiveView assigns, accept generic context map |
| `chat/application/behaviours/session_repository_behaviour.ex` | Same relative path | Rename module |
| `chat/application/behaviours/message_repository_behaviour.ex` | Same relative path | Rename module |

**Infrastructure (apps/jarga/lib/chat/) → apps/chat/lib/chat/**
| Source | Target | Changes |
|--------|--------|---------|
| `chat/infrastructure.ex` | `chat/infrastructure.ex` | Rename module, update Boundary deps to `Chat.Repo` |
| `chat/infrastructure/schemas/session_schema.ex` | Same relative path | Rename module, remove `belongs_to` for user/workspace/project, add plain fields |
| `chat/infrastructure/schemas/message_schema.ex` | Same relative path | Rename module, update SessionSchema reference |
| `chat/infrastructure/repositories/session_repository.ex` | Same relative path | Rename module, use `Chat.Repo` |
| `chat/infrastructure/repositories/message_repository.ex` | Same relative path | Rename module, use `Chat.Repo` |
| `chat/infrastructure/queries/queries.ex` | Same relative path | Rename module, remove `:user`/`:workspace`/`:project` preloads from `with_preloads/1` |

**Interface (apps/jarga_web/) → apps/chat_web/**
| Source | Target | Changes |
|--------|--------|---------|
| `lib/live/chat_live/panel.ex` | `lib/chat_web/live/chat_live/panel.ex` | Rename module `JargaWeb.ChatLive.Panel` → `ChatWeb.ChatLive.Panel`, replace `Jarga.Chat` with `Chat`, replace `Jarga.Accounts` with `Identity` for agent prefs |
| `lib/live/chat_live/panel.html.heex` | `lib/chat_web/live/chat_live/panel.html.heex` | No content changes expected |
| `lib/live/chat_live/message_handlers.ex` | `lib/chat_web/live/chat_live/message_handlers.ex` | Rename module, update Panel reference |
| `lib/live/chat_live/components/message.ex` | `lib/chat_web/live/chat_live/components/message.ex` | Rename module |
| `assets/js/presentation/hooks/chat-panel-hook.ts` | `assets/js/hooks/chat-panel-hook.ts` | No content changes expected |
| `assets/css/chat.css` | `assets/css/chat.css` | No content changes expected |
| `assets/js/__tests__/.../chat-panel-hook.test.ts` | `assets/js/__tests__/hooks/chat-panel-hook.test.ts` | No content changes expected |
| 7 SVG assets in `assets/vendor/chat-*` | `assets/vendor/chat-*` | No content changes |

**Tests**
| Source | Target | Changes |
|--------|--------|---------|
| `apps/jarga/test/chat/` (16 files) | `apps/chat/test/chat/` | Rename modules |
| `apps/jarga/test/support/fixtures/chat_fixtures.ex` | `apps/chat/test/support/fixtures/chat_fixtures.ex` | Rename module, update references |
| `apps/jarga_web/test/features/chat/` (7 files, 44 scenarios) | `apps/chat_web/test/features/chat/` | Update step definitions if needed |
| `apps/jarga_web/assets/js/__tests__/.../chat-panel-hook.test.ts` | `apps/chat_web/assets/js/__tests__/` | No content changes |

### Cross-Boundary Dependencies to Sever

| Current Coupling | Resolution |
|-----------------|------------|
| `alias Identity.Repo, as: Repo` in both repositories | Replace with `alias Chat.Repo` |
| `belongs_to(:user, Identity.Infrastructure.Schemas.UserSchema)` | Replace with `field(:user_id, :binary_id)` |
| `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)` | Replace with `field(:workspace_id, :binary_id)` |
| `belongs_to(:project, Jarga.Projects.Infrastructure.Schemas.ProjectSchema)` | Replace with `field(:project_id, :binary_id)` |
| `Jarga.Accounts.get_selected_agent_id/2` in Panel | Call `Identity.get_selected_agent_id/2` directly |
| `Jarga.Accounts.set_selected_agent_id/3` in Panel | Call `Identity.set_selected_agent_id/3` directly |
| `Agents.chat_stream/3` in Panel | Retain as `chat_web` → `agents` dependency |
| `Agents.get_workspace_agents_list/3` in Panel | Retain as `chat_web` → `agents` dependency |
| `Agents.list_user_agents/1` in Panel | Retain as `chat_web` → `agents` dependency |
| `PrepareContext` reading `:note`, `:document` assigns | Accept generic context map |
| `with_preloads` loading `:user`, `:workspace`, `:project` | Remove these preloads |
| `Jarga.Chat` in `jarga_web.ex` Boundary deps | Replace with `Chat` and add `ChatWeb` |

### Available Infrastructure to Leverage
- `Perme8.Events.DomainEvent` macro for domain events (already used)
- `Perme8.Events.EventBus` for event emission (already used)
- `Boundary` library for compile-time boundary enforcement (already configured)
- `Notifications` app as extraction pattern reference (complete working example)
- Umbrella project structure with shared build/config paths

## Future Considerations (#276 Architecture Alignment)

The extraction architecture should accommodate these future #276 requirements without implementing them:

| #276 Requirement | Architectural Decision in Extraction | Future Work |
|------------------|--------------------------------------|-------------|
| Multi-user real-time messaging | `Session` entity structured as a conversation (already has `user_id`, `workspace_id`). No `Conversation` concept added yet, but the clean namespace allows adding `Chat.Domain.Entities.Conversation` later without conflicts. | Add `Conversation` entity, `Participant` entity, refactor Session → Conversation |
| Participant tracking | `SessionSchema` retains `user_id` as single owner. Adding a `chat_participants` join table is straightforward since there are no FK constraints to other apps. | Add `ParticipantSchema`, `ConversationParticipant` entity |
| Phoenix Channels / PubSub | `chat_web` app can add a `ChatWeb.ChatChannel` and `ChatWeb.Presence` module independently. No PubSub is set up in extraction. | Add `ChatChannel`, integrate with Phoenix Presence for typing/online |
| Identity auth for WebSocket | Chat's own Repo and decoupled schemas mean auth is handled at the web layer (same `current_user` pipeline). | Add token auth for WebSocket connections via Identity |
| Workspace membership enforcement | `workspace_id` stored as plain UUID. The web layer can call `Identity.member_of?/2` before allowing access. | Add authorization policy in `Chat.Domain.Policies` |
| Notifications integration | Domain events (`ChatMessageSent`) already emitted. Notifications app can subscribe to these events. | Add `Notifications.Infrastructure.Subscribers.ChatMessageSubscriber` |
| Push notifications | Domain events provide the hook. The extraction ensures `ChatMessageSent` includes all necessary data (workspace_id, user_id, session_id). | Add push notification subscriber + delivery infrastructure |
| Message delivery status | `MessageSchema` can be extended with a `status` field later. No FK constraints to remove. | Add `status` field, `MessageDelivered` event |
| Online/typing presence | `chat_web` app is the natural home for Phoenix Presence integration. | Add `ChatWeb.Presence` module |
| Direct messages vs. group conversations | The `Session` → `Conversation` evolution path is clear. Conversation type (dm, group, workspace) is a new field. | Add `type` field to Conversation entity |

## Open Questions

- [ ] **Migration sequencing**: What is the preferred approach for handling existing `chat_sessions` and `chat_messages` tables? Option A: `CREATE TABLE IF NOT EXISTS` in chat migrations (allows fresh DB setup). Option B: Empty migrations in chat that assume tables exist from jarga migrations (simpler but fragile). Option C: Move the original migrations from jarga to chat and update timestamps.
- [ ] **`chat_web` Phoenix Endpoint**: Does `chat_web` need its own Phoenix Endpoint, or will it share `JargaWeb.Endpoint`? (Following `agents_web` pattern -- likely shares the endpoint but has its own router/routes)
- [ ] **Agent preference storage**: The `get/set_selected_agent_id` functions delegate through `Jarga.Accounts` → `Identity`. After extraction, should `chat_web` call `Identity` directly, or should agent selection be the parent LiveView's responsibility (passed as assigns)? Both work; the question is about coupling preference.
- [ ] **Feature file step definitions**: The 44 BDD scenarios use step helpers defined in `apps/jarga_web/test/support/step_helpers.ex`. Will `chat_web` have its own step helpers, or will the shared helpers be extracted? The step_helpers file contains non-chat steps too.

## Out of Scope

- **Multi-user chat features** (#276) -- No Conversation entity, no participant tracking, no Channels/PubSub, no presence indicators. The extraction creates the foundation for these but does not implement them.
- **Push notifications** -- No push notification infrastructure. Domain events are emitted but no subscribers for push delivery exist.
- **Notifications integration** -- No `ChatMessageSubscriber` in the notifications app. Events are emitted but not consumed.
- **New UI features** -- No changes to the chat panel UI, styling, or user-facing behaviour.
- **Agent integration refactoring** -- The `chat_web` → `agents` dependency is retained as-is. Abstracting agent integration behind a behaviour/callback is deferred to #276.
- **Data migration** -- No data is moved between databases. All apps share the same PostgreSQL database.
- **Performance optimization** -- No query optimization, caching, or connection pool changes.

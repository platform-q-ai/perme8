# Feature: Extract Chat as Standalone Umbrella App

## Overview

Extract the Chat bounded context from `jarga` into its own standalone umbrella app (`chat` + `chat_web`). This is a **structural extraction** — the code already exists and passes tests. The goal is to sever all cross-boundary coupling (Identity.Repo usage, belongs_to associations to Identity/Jarga schemas, Jarga.Accounts calls) so `chat` can boot independently per the Standalone App Principle.

**Reference pattern**: `apps/notifications/` (extracted from `jarga` in [#38](https://github.com/platform-q-ai/perme8/issues/38)).

## App Ownership

| Attribute | Value |
|-----------|-------|
| **Owning app** | `chat` (NEW) |
| **Repo** | `Chat.Repo` (NEW) |
| **Domain path** | `apps/chat/lib/chat/` |
| **Web path** | `apps/chat_web/lib/chat_web/` |
| **Migration path** | `apps/chat/priv/repo/migrations/` |
| **Feature file path** | `apps/chat_web/test/features/chat/` |
| **Test path (domain)** | `apps/chat/test/chat/` |
| **Test path (web)** | `apps/chat_web/test/chat_web/` |
| **Fixtures path** | `apps/chat/test/support/fixtures/` |
| **Dependencies** | `identity` (auth), `agents` (LLM streaming), `perme8_events` (domain events) |

## UI Strategy

- **LiveView coverage**: 100% — chat panel is a LiveComponent mounted within jarga_web's layout
- **TypeScript needed**: ChatPanelHook (existing, migrates from jarga_web to chat_web)

## Affected Boundaries

- **Primary context**: `Chat` (top-level facade)
- **Dependencies**: `Identity` (user preferences: `get_selected_agent_id/2`, `set_selected_agent_id/3`), `Agents` (LLM streaming: `chat_stream/3`, `get_workspace_agents_list/3`, `list_user_agents/1`), `Perme8.Events` (event bus)
- **Exported schemas**: `Chat.Domain.Entities.Session`, `Chat.Domain.Entities.Message`, `Chat.Domain.Events.ChatSessionStarted`, `Chat.Domain.Events.ChatMessageSent`, `Chat.Domain.Events.ChatSessionDeleted`
- **New context needed?**: No — Chat is already a well-defined bounded context

## Cross-Boundary Dependencies to Sever

| Current Coupling | Resolution |
|-----------------|------------|
| `alias Identity.Repo, as: Repo` in repos | Replace with `alias Chat.Repo` |
| `belongs_to(:user, Identity.Infrastructure.Schemas.UserSchema)` | Replace with `field(:user_id, :binary_id)` |
| `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)` | Replace with `field(:workspace_id, :binary_id)` |
| `belongs_to(:project, Jarga.Projects.Infrastructure.Schemas.ProjectSchema)` | Replace with `field(:project_id, :binary_id)` |
| `Jarga.Accounts.get_selected_agent_id/2` in Panel | Call `Identity.get_selected_agent_id/2` directly |
| `Jarga.Accounts.set_selected_agent_id/3` in Panel | Call `Identity.set_selected_agent_id/3` directly |
| `with_preloads` loading `:user`, `:workspace`, `:project` | Remove these, keep only `:messages` |
| `Jarga.Chat` in jarga_web.ex Boundary deps | Replace with `Chat` |
| `JargaWeb.ChatLive.Panel` references | Replace with `ChatWeb.ChatLive.Panel` |
| `Jarga.ChatFixtures` in test support | Replace with `Chat.ChatFixtures` |

---

## Phase 1: Scaffold New Apps

⏸ Status: Not Started

### 1.1 Generate `chat` Domain App

- [ ] **RED**: Verify `apps/chat/` does not exist
- [ ] **GREEN**: Generate app scaffold:
  - `apps/chat/mix.exs` — define `:chat` app with deps: `[:perme8_events, :identity, :agents, :ecto_sql, :postgrex, :boundary, :phoenix_pubsub, :jason, :mox]`
  - `apps/chat/lib/chat/repo.ex` — `Chat.Repo` (use Ecto.Repo, otp_app: :chat)
  - `apps/chat/lib/chat/otp_app.ex` — `Chat.OTPApp` (Application, starts Chat.Repo)
  - `apps/chat/lib/chat.ex` — placeholder facade module
  - `apps/chat/test/test_helper.exs`
  - `apps/chat/test/support/data_case.ex` — `Chat.DataCase` (sandbox setup for Chat.Repo)
  - `apps/chat/priv/repo/migrations/` — empty directory
- [ ] **REFACTOR**: Verify `mix compile` succeeds for the chat app

### 1.2 Generate `chat_web` Interface App

- [ ] **RED**: Verify `apps/chat_web/` does not exist
- [ ] **GREEN**: Generate app scaffold:
  - `apps/chat_web/mix.exs` — define `:chat_web` app with deps: `[:chat, :identity, :agents, :phoenix_live_view, :boundary]`
  - `apps/chat_web/lib/chat_web.ex` — module with `use Boundary` config
  - `apps/chat_web/test/test_helper.exs`
  - `apps/chat_web/test/support/conn_case.ex` — `ChatWeb.ConnCase`
- [ ] **REFACTOR**: Verify `mix compile` succeeds for chat_web

### 1.3 Configure Chat.Repo

- [ ] **GREEN**: Add configuration entries:
  - `config/config.exs` — `config :chat, ecto_repos: [Chat.Repo], generators: [...]`
  - `config/dev.exs` — `config :chat, Chat.Repo, url: database_url, ...`
  - `config/test.exs` — `config :chat, Chat.Repo, url: database_url, pool: Ecto.Adapters.SQL.Sandbox, ...`
  - `config/runtime.exs` — `config :chat, Chat.Repo, url: database_url, ...`
- [ ] **REFACTOR**: Verify `mix ecto.create` and `mix ecto.migrate` work for chat

### Phase 1 Validation

- [ ] `mix compile` succeeds with no errors
- [ ] `mix ecto.create` creates the chat database (shared PostgreSQL DB)
- [ ] Both apps boot standalone

---

## Phase 2: Domain Layer (phoenix-tdd)

⏸ Status: Not Started

### 2.1 Session Entity

- [ ] **RED**: Write test `apps/chat/test/chat/domain/entities/session_test.exs`
  - Tests: `new/1` creates struct with defaults, `from_schema/1` converts schema with messages, handles nil/NotLoaded messages
  - Module: `Chat.Domain.Entities.Session`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/domain/entities/session.ex`
  - Copy from `Jarga.Chat.Domain.Entities.Session`, rename module to `Chat.Domain.Entities.Session`
  - Update internal alias from `Jarga.Chat.Domain.Entities.Message` to `Chat.Domain.Entities.Message`
- [ ] **REFACTOR**: Ensure pure struct, no Ecto dependencies

### 2.2 Message Entity

- [ ] **RED**: Write test `apps/chat/test/chat/domain/entities/message_test.exs`
  - Tests: `new/1` creates struct with defaults, `from_schema/1` converts schema, handles nil context_chunks
  - Module: `Chat.Domain.Entities.Message`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/domain/entities/message.ex`
  - Copy from `Jarga.Chat.Domain.Entities.Message`, rename module to `Chat.Domain.Entities.Message`
- [ ] **REFACTOR**: Ensure pure struct, no Ecto dependencies

### 2.3 ChatSessionStarted Event

- [ ] **RED**: Write test `apps/chat/test/chat/domain/events/chat_session_started_test.exs`
  - Tests: `new/1` creates event with required fields, validates aggregate_type is "chat_session"
  - Module: `Chat.Domain.Events.ChatSessionStarted`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/domain/events/chat_session_started.ex`
  - Copy from `Jarga.Chat.Domain.Events.ChatSessionStarted`, rename module
- [ ] **REFACTOR**: Clean up

### 2.4 ChatMessageSent Event

- [ ] **RED**: Write test `apps/chat/test/chat/domain/events/chat_message_sent_test.exs`
  - Tests: `new/1` creates event with required fields (message_id, session_id, user_id, role)
  - Module: `Chat.Domain.Events.ChatMessageSent`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/domain/events/chat_message_sent.ex`
  - Copy from `Jarga.Chat.Domain.Events.ChatMessageSent`, rename module
- [ ] **REFACTOR**: Clean up

### 2.5 ChatSessionDeleted Event

- [ ] **RED**: Write test `apps/chat/test/chat/domain/events/chat_session_deleted_test.exs`
  - Tests: `new/1` creates event with required fields (session_id, user_id)
  - Module: `Chat.Domain.Events.ChatSessionDeleted`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/domain/events/chat_session_deleted.ex`
  - Copy from `Jarga.Chat.Domain.Events.ChatSessionDeleted`, rename module
- [ ] **REFACTOR**: Clean up

### 2.6 Domain Boundary Module

- [ ] **GREEN**: Create `apps/chat/lib/chat/domain.ex`
  - `Chat.Domain` with `use Boundary`, exports entities and events
  - Pattern: copy from `Jarga.Chat.Domain`, update all module references
- [ ] **REFACTOR**: Verify boundary config is correct

### Phase 2 Validation

- [ ] All domain tests pass with `mix test apps/chat/test/chat/domain/` (fast, no I/O)
- [ ] No boundary violations (`mix boundary`)
- [ ] Domain entities are pure structs with zero Ecto dependencies

---

## Phase 3: Application Layer (phoenix-tdd)

⏸ Status: Not Started

### 3.1 SessionRepositoryBehaviour

- [ ] **GREEN**: Create `apps/chat/lib/chat/application/behaviours/session_repository_behaviour.ex`
  - `Chat.Application.Behaviours.SessionRepositoryBehaviour`
  - Copy callbacks from `Jarga.Chat.Application.Behaviours.SessionRepositoryBehaviour`
  - Add missing callbacks from actual SessionRepository usage: `get_session_by_id/1`, `get_session_by_id_and_user/2`, `list_user_sessions/2`, `get_first_message_content/1`, `delete_session/1`
- [ ] **REFACTOR**: Ensure all callbacks cover the full repository interface

### 3.2 MessageRepositoryBehaviour

- [ ] **GREEN**: Create `apps/chat/lib/chat/application/behaviours/message_repository_behaviour.ex`
  - `Chat.Application.Behaviours.MessageRepositoryBehaviour`
  - Copy callbacks from `Jarga.Chat.Application.Behaviours.MessageRepositoryBehaviour`
- [ ] **REFACTOR**: Ensure all callbacks match repository implementation

### 3.3 CreateSession Use Case

- [ ] **RED**: Write test `apps/chat/test/chat/application/use_cases/create_session_test.exs`
  - Tests: creates session with valid attrs, generates title from first_message, truncates long auto-titles, emits ChatSessionStarted event, returns error on invalid attrs
  - Mocks: `session_repository` (Mox), `event_bus` (Perme8.Events.TestEventBus)
  - Module: `Chat.Application.UseCases.CreateSession`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/application/use_cases/create_session.ex`
  - Copy from `Jarga.Chat.Application.UseCases.CreateSession`, rename all modules
  - Default repos change: `@default_session_repository Chat.Infrastructure.Repositories.SessionRepository`
- [ ] **REFACTOR**: Clean up

### 3.4 SaveMessage Use Case

- [ ] **RED**: Write test `apps/chat/test/chat/application/use_cases/save_message_test.exs`
  - Tests: saves message with valid attrs, emits ChatMessageSent event, returns error on invalid attrs
  - Mocks: `message_repository`, `session_repository`, `event_bus`
  - Module: `Chat.Application.UseCases.SaveMessage`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/application/use_cases/save_message.ex`
  - Copy from `Jarga.Chat.Application.UseCases.SaveMessage`, rename all modules
- [ ] **REFACTOR**: Clean up

### 3.5 DeleteSession Use Case

- [ ] **RED**: Write test `apps/chat/test/chat/application/use_cases/delete_session_test.exs`
  - Tests: deletes session when user owns it, returns `:not_found` for missing/unauthorized, emits ChatSessionDeleted event
  - Mocks: `session_repository`, `event_bus`
  - Module: `Chat.Application.UseCases.DeleteSession`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/application/use_cases/delete_session.ex`
  - Copy from `Jarga.Chat.Application.UseCases.DeleteSession`, rename all modules
- [ ] **REFACTOR**: Clean up

### 3.6 DeleteMessage Use Case

- [ ] **RED**: Write test `apps/chat/test/chat/application/use_cases/delete_message_test.exs`
  - Tests: deletes message when user owns session, returns `:not_found` for missing/unauthorized
  - Mocks: `session_repository`, `message_repository`
  - Module: `Chat.Application.UseCases.DeleteMessage`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/application/use_cases/delete_message.ex`
  - Copy from `Jarga.Chat.Application.UseCases.DeleteMessage`, rename all modules
- [ ] **REFACTOR**: Clean up

### 3.7 LoadSession Use Case

- [ ] **RED**: Write test `apps/chat/test/chat/application/use_cases/load_session_test.exs`
  - Tests: loads session by ID, returns `:not_found` for missing session
  - Mocks: `session_repository`
  - Module: `Chat.Application.UseCases.LoadSession`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/application/use_cases/load_session.ex`
  - Copy from `Jarga.Chat.Application.UseCases.LoadSession`, rename all modules
- [ ] **REFACTOR**: Clean up

### 3.8 ListSessions Use Case

- [ ] **RED**: Write test `apps/chat/test/chat/application/use_cases/list_sessions_test.exs`
  - Tests: lists sessions for user, applies limit, adds preview from first message, truncates long previews
  - Mocks: `session_repository`
  - Module: `Chat.Application.UseCases.ListSessions`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/application/use_cases/list_sessions.ex`
  - Copy from `Jarga.Chat.Application.UseCases.ListSessions`, rename all modules
- [ ] **REFACTOR**: Clean up

### 3.9 PrepareContext Use Case

- [ ] **RED**: Write test `apps/chat/test/chat/application/use_cases/prepare_context_test.exs`
  - Tests: extracts context from assigns, handles missing fields, builds system message, builds system message with agent custom prompt
  - Module: `Chat.Application.UseCases.PrepareContext`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/application/use_cases/prepare_context.ex`
  - Copy from `Jarga.Chat.Application.UseCases.PrepareContext`, rename all modules
  - **KEY CHANGE**: Update the default system message text from "Jarga" to "Perme8" (or make it configurable)
- [ ] **REFACTOR**: Clean up

### 3.10 PrepareContext with Agent Test

- [ ] **RED**: Write test `apps/chat/test/chat/application/use_cases/prepare_context_with_agent_test.exs`
  - Tests: builds combined message when agent has custom prompt, falls back to default when no custom prompt
  - Module: `Chat.Application.UseCases.PrepareContext`
- [ ] **GREEN**: Already covered by 3.9 implementation
- [ ] **REFACTOR**: Clean up

### 3.11 Application Boundary Module

- [ ] **GREEN**: Create `apps/chat/lib/chat/application.ex`
  - `Chat.Application` with `use Boundary`, deps on `Chat.Domain` and `Perme8.Events`
  - Exports: all use cases and behaviours
- [ ] **REFACTOR**: Verify boundary config matches actual exports

### Phase 3 Validation

- [ ] All application tests pass with `mix test apps/chat/test/chat/application/` (with mocks)
- [ ] No boundary violations
- [ ] All use cases accept dependency injection via opts

---

## Phase 4: Infrastructure Layer (phoenix-tdd)

⏸ Status: Not Started

### 4.1 Chat Migrations

- [ ] **GREEN**: Create `apps/chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_chat_sessions.exs`
  - Use `CREATE TABLE IF NOT EXISTS` pattern for fresh DB support
  - Create `chat_sessions` table: id (binary_id PK), title (string), user_id (binary_id NOT NULL, no FK), workspace_id (binary_id, no FK), project_id (binary_id, no FK)
  - **CRITICAL**: No foreign key constraints to users/workspaces/projects (standalone principle)
  - Indexes: user_id, workspace_id, project_id, inserted_at
  - Timestamps (utc_datetime)

- [ ] **GREEN**: Create `apps/chat/priv/repo/migrations/YYYYMMDDHHMMSS_create_chat_messages.exs`
  - Use `CREATE TABLE IF NOT EXISTS` pattern
  - Create `chat_messages` table: id (binary_id PK), chat_session_id (references chat_sessions, on_delete: delete_all), role (string NOT NULL), content (text NOT NULL), context_chunks (array of binary_id)
  - Indexes: chat_session_id, inserted_at
  - Timestamps (utc_datetime)

- [ ] **GREEN**: Create `apps/chat/priv/repo/migrations/YYYYMMDDHHMMSS_drop_chat_fk_constraints.exs`
  - Drop FK constraints from existing chat_sessions table: user_id, workspace_id, project_id
  - This ensures the tables work without Identity/Jarga schemas being loaded

- [ ] **REFACTOR**: Verify `mix ecto.migrate` runs cleanly for chat app

### 4.2 SessionSchema

- [ ] **RED**: Write test `apps/chat/test/chat/infrastructure/schemas/session_schema_test.exs`
  - Tests: changeset validates user_id required, changeset accepts optional title/workspace_id/project_id, trims title, validates title max length 255, title_changeset works
  - Module: `Chat.Infrastructure.Schemas.SessionSchema`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/infrastructure/schemas/session_schema.ex`
  - Copy from `Jarga.Chat.Infrastructure.Schemas.SessionSchema`, rename module
  - **CRITICAL CHANGES**:
    - Replace `belongs_to(:user, Identity.Infrastructure.Schemas.UserSchema)` → `field(:user_id, :binary_id)`
    - Replace `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)` → `field(:workspace_id, :binary_id)`
    - Replace `belongs_to(:project, Jarga.Projects.Infrastructure.Schemas.ProjectSchema)` → `field(:project_id, :binary_id)`
    - Keep `has_many(:messages, Chat.Infrastructure.Schemas.MessageSchema, foreign_key: :chat_session_id)`
    - Remove `foreign_key_constraint(:user_id)`, `foreign_key_constraint(:workspace_id)`, `foreign_key_constraint(:project_id)` from changeset
- [ ] **REFACTOR**: Verify schema has no cross-app dependencies

### 4.3 MessageSchema

- [ ] **RED**: Write test `apps/chat/test/chat/infrastructure/schemas/message_schema_test.exs`
  - Tests: changeset validates required fields (chat_session_id, role, content), validates role inclusion ("user"/"assistant"), trims content, rejects blank content
  - Module: `Chat.Infrastructure.Schemas.MessageSchema`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/infrastructure/schemas/message_schema.ex`
  - Copy from `Jarga.Chat.Infrastructure.Schemas.MessageSchema`, rename module
  - Update `belongs_to(:chat_session, Chat.Infrastructure.Schemas.SessionSchema)`
- [ ] **REFACTOR**: Clean up

### 4.4 Queries

- [ ] **RED**: Write test `apps/chat/test/chat/infrastructure/queries/queries_test.exs`
  - Tests: `by_id/1` filters by session ID, `for_user/1` filters by user, `by_id_and_user/2` filters both, `with_preloads/0` only preloads `:messages` (NOT `:user`, `:workspace`, `:project`), `ordered_by_recent/0`, `with_message_count/0`, `first_message_content/1`, `message_by_id_and_user/2`
  - Module: `Chat.Infrastructure.Queries.Queries`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/infrastructure/queries/queries.ex`
  - Copy from `Jarga.Chat.Infrastructure.Queries.Queries`, rename all modules
  - **CRITICAL CHANGE**: `with_preloads/1` — remove `:user`, `:workspace`, `:project` preloads. Only preload `messages: ^messages_ordered()`
- [ ] **REFACTOR**: Verify all queries return Ecto queryables, not results

### 4.5 SessionRepository

- [ ] **RED**: Write test `apps/chat/test/chat/infrastructure/repositories/session_repository_test.exs`
  - Tests: `get_session_by_id/1`, `list_user_sessions/2`, `get_first_message_content/1`, `get_session_by_id_and_user/2`, `get_message_by_id_and_user/2`, `create_session/1`, `delete_session/1`
  - Module: `Chat.Infrastructure.Repositories.SessionRepository`
  - Uses `Chat.DataCase`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/infrastructure/repositories/session_repository.ex`
  - Copy from `Jarga.Chat.Infrastructure.Repositories.SessionRepository`, rename all modules
  - **CRITICAL CHANGE**: Replace `alias Identity.Repo, as: Repo` → `alias Chat.Repo`
  - Update behaviour: `@behaviour Chat.Application.Behaviours.SessionRepositoryBehaviour`
  - Update query alias: `alias Chat.Infrastructure.Queries.Queries`
- [ ] **REFACTOR**: Clean up

### 4.6 MessageRepository

- [ ] **RED**: Write test `apps/chat/test/chat/infrastructure/repositories/message_repository_test.exs`
  - Tests: `get/1`, `create_message/1`, `delete_message/1`
  - Module: `Chat.Infrastructure.Repositories.MessageRepository`
  - Uses `Chat.DataCase`
- [ ] **GREEN**: Implement `apps/chat/lib/chat/infrastructure/repositories/message_repository.ex`
  - Copy from `Jarga.Chat.Infrastructure.Repositories.MessageRepository`, rename all modules
  - **CRITICAL CHANGE**: Replace `alias Identity.Repo, as: Repo` → `alias Chat.Repo`
  - Update behaviour: `@behaviour Chat.Application.Behaviours.MessageRepositoryBehaviour`
  - Update schema alias: `alias Chat.Infrastructure.Schemas.MessageSchema`
- [ ] **REFACTOR**: Clean up

### 4.7 Infrastructure Boundary Module

- [ ] **GREEN**: Create `apps/chat/lib/chat/infrastructure.ex`
  - `Chat.Infrastructure` with `use Boundary`
  - deps: `[Chat.Domain, Chat.Application, Chat.Repo]`
  - Exports: schemas, repositories, queries
- [ ] **REFACTOR**: Verify boundary config

### Phase 4 Validation

- [ ] All infrastructure tests pass with `mix test apps/chat/test/chat/infrastructure/`
- [ ] Migrations run cleanly: `mix ecto.migrate`
- [ ] No cross-app Repo usage (no `Identity.Repo`, no `Jarga.Repo`)
- [ ] No cross-app schema references (no `Identity.Infrastructure.Schemas.*`, no `Jarga.Projects.Infrastructure.Schemas.*`)
- [ ] No boundary violations

---

## Phase 5: Chat Facade (phoenix-tdd)

⏸ Status: Not Started

### 5.1 Chat Public API Facade

- [ ] **RED**: Write test `apps/chat/test/chat_test.exs`
  - Tests: all 7 delegated functions work via facade (`create_session/1`, `list_sessions/1`, `load_session/1`, `delete_session/2`, `save_message/1`, `delete_message/2`, `prepare_chat_context/1`, `build_system_message/1`, `build_system_message_with_agent/2`)
  - Uses `Chat.DataCase` for integration testing
- [ ] **GREEN**: Implement `apps/chat/lib/chat.ex`
  - Copy from `apps/jarga/lib/chat.ex`, rename all modules from `Jarga.Chat.*` to `Chat.*`
  - Update Boundary config:
    ```elixir
    use Boundary,
      top_level?: true,
      deps: [
        Chat.Domain,
        Chat.Application,
        Chat.Infrastructure,
        Chat.Repo
      ],
      exports: [
        {Domain.Entities.Session, []},
        {Domain.Entities.Message, []},
        {Domain.Events.ChatSessionStarted, []},
        {Domain.Events.ChatMessageSent, []},
        {Domain.Events.ChatSessionDeleted, []}
      ]
    ```
  - **CRITICAL**: Remove deps on `Jarga.Accounts`, `Jarga.Workspaces`, `Jarga.Projects`, `Agents`
- [ ] **REFACTOR**: Verify facade is thin (only delegations)

### 5.2 Chat Test Fixtures

- [ ] **GREEN**: Create `apps/chat/test/support/fixtures/chat_fixtures.ex`
  - `Chat.ChatFixtures` — copy from `Jarga.ChatFixtures`
  - Update all `Jarga.Chat` calls to `Chat`
  - Update `Jarga.Accounts` calls to `Identity` (for user lookup)
  - Update `Jarga.AccountsFixtures` and `Jarga.WorkspacesFixtures` imports to point to identity test fixtures
  - Note: Fixture dependencies on Identity are allowed (Identity is a permitted dependency)
- [ ] **REFACTOR**: Verify fixtures work with Chat.Repo

### Phase 5 Validation

- [ ] All facade tests pass
- [ ] `Chat.create_session/1` creates a session in Chat.Repo
- [ ] `Chat.save_message/1` persists a message
- [ ] Full chat app test suite passes: `mix test apps/chat/`
- [ ] No boundary violations

---

## Phase 6: Web Layer Migration (phoenix-tdd)

⏸ Status: Not Started

### 6.1 Message Component

- [ ] **RED**: Write test `apps/chat_web/test/chat_web/live/components/message_test.exs`
  - Tests: renders user message, renders assistant message with markdown, shows insert link when applicable, shows delete link when message has ID, formats timestamps
  - Module: `ChatWeb.ChatLive.Components.Message`
- [ ] **GREEN**: Implement `apps/chat_web/lib/chat_web/live/chat_live/components/message.ex`
  - Copy from `JargaWeb.ChatLive.Components.Message`, rename module to `ChatWeb.ChatLive.Components.Message`
  - Change `use Phoenix.Component` (keep as-is, no JargaWeb dependency)
- [ ] **REFACTOR**: Clean up

### 6.2 MessageHandlers Macro

- [ ] **RED**: Write test `apps/chat_web/test/chat_web/live/chat_live/message_handlers_test.exs`
  - Tests: verify the macro defines handle_info for :chunk, :done, :error, :assistant_response, :llm_done, :llm_chunk, :llm_error, :put_flash
  - Module: `ChatWeb.ChatLive.MessageHandlers`
- [ ] **GREEN**: Implement `apps/chat_web/lib/chat_web/live/chat_live/message_handlers.ex`
  - Copy from `JargaWeb.ChatLive.MessageHandlers`, rename module
  - **CRITICAL CHANGES**:
    - Replace `JargaWeb.ChatLive.Panel` → `ChatWeb.ChatLive.Panel`
    - Keep `JargaWeb.NotificationsLive.NotificationBell` reference (this is a jarga_web component — the notification handler should stay in jarga_web's handler or be split out)
    - **Decision**: The notification `handle_info` for `NotificationCreated` should remain in jarga_web's own handler since it references `JargaWeb.NotificationsLive.NotificationBell`. The chat MessageHandlers should only contain chat-specific handlers.
- [ ] **REFACTOR**: Remove notification-specific handlers from chat's MessageHandlers (they stay in jarga_web)

### 6.3 Panel LiveComponent

- [ ] **RED**: Write test `apps/chat_web/test/chat_web/live/chat_live/panel_test.exs`
  - Tests: mounts with default assigns, toggles panel, sends message, clears chat, shows conversations, loads session, deletes session, selects agent, cancel streaming
  - Module: `ChatWeb.ChatLive.Panel`
- [ ] **GREEN**: Implement `apps/chat_web/lib/chat_web/live/chat_live/panel.ex`
  - Copy from `JargaWeb.ChatLive.Panel`, rename module
  - **CRITICAL CHANGES**:
    - Replace `use JargaWeb, :live_component` → appropriate use macro for chat_web
    - Replace `import JargaWeb.ChatLive.Components.Message` → `import ChatWeb.ChatLive.Components.Message`
    - Replace `alias Jarga.Chat` → `alias Chat`
    - Replace `Jarga.Accounts.get_selected_agent_id(...)` → `Identity.get_selected_agent_id(...)`
    - Replace `Jarga.Accounts.set_selected_agent_id(...)` → `Identity.set_selected_agent_id(...)`
    - Replace all `Chat.` facade calls (already correct after rename)
    - Keep `alias Agents` (permitted dependency)
- [ ] **REFACTOR**: Ensure no Jarga references remain

### 6.4 Panel Template

- [ ] **GREEN**: Copy `apps/jarga_web/lib/live/chat_live/panel.html.heex` to `apps/chat_web/lib/chat_web/live/chat_live/panel.html.heex`
  - No changes needed — template uses component-relative references (`@myself`, `@id`, etc.)
- [ ] **REFACTOR**: Verify template renders correctly

### 6.5 ChatPanelHook (TypeScript)

- [ ] **RED**: Verify JS test exists at `apps/jarga_web/assets/js/__tests__/presentation/hooks/chat-panel-hook.test.ts`
- [ ] **GREEN**: Copy TypeScript hook and test to chat_web:
  - `apps/chat_web/assets/js/presentation/hooks/chat-panel-hook.ts` — copy from jarga_web
  - `apps/chat_web/assets/js/__tests__/presentation/hooks/chat-panel-hook.test.ts` — copy from jarga_web
  - **Note**: The hook stays in jarga_web's assets directory for now since chat_web shares JargaWeb.Endpoint. The hook is registered in jarga_web's app.js. This is the same pattern as agents_web sharing the endpoint. The hook code itself has no jarga-specific logic.
  - **Decision**: Keep the hook in jarga_web's assets (since it's registered in jarga_web's app.js which is bundled by JargaWeb.Endpoint) but document that it belongs to the chat domain. A future cleanup can move asset ownership when chat_web gets its own endpoint.
- [ ] **REFACTOR**: Ensure hook registration still works

### 6.6 chat_web.ex Module Setup

- [ ] **GREEN**: Implement `apps/chat_web/lib/chat_web.ex` with proper macros:
  - `:live_component` macro for use in Panel
  - `:html` macro for components
  - Boundary config:
    ```elixir
    use Boundary,
      deps: [Chat, Chat.Domain, Identity, Agents, Agents.Domain, Perme8.Events],
      exports: []
    ```
- [ ] **REFACTOR**: Verify boundary config allows all needed access

### Phase 6 Validation

- [ ] All chat_web tests pass
- [ ] Panel LiveComponent renders correctly
- [ ] MessageHandlers macro injects correct handlers
- [ ] No references to `Jarga.Chat`, `Jarga.Accounts`, or `JargaWeb.ChatLive.*` in chat_web code
- [ ] No boundary violations

---

## Phase 7: Integration — Update jarga_web to Use chat_web

⏸ Status: Not Started

### 7.1 Update jarga_web Boundary Config

- [ ] **GREEN**: Edit `apps/jarga_web/lib/jarga_web.ex`
  - Replace `Jarga.Chat` in deps with `Chat` and `Chat.Domain`
  - Add `ChatWeb` to deps if needed (for importing chat components)
- [ ] **REFACTOR**: Verify no boundary violations

### 7.2 Update jarga_web References

- [ ] **GREEN**: Update all files in `apps/jarga_web/` that reference chat modules:
  - Replace `Jarga.Chat` → `Chat` in any remaining references
  - Replace `JargaWeb.ChatLive.Panel` → `ChatWeb.ChatLive.Panel` in layouts/templates
  - Replace `JargaWeb.ChatLive.MessageHandlers` → `ChatWeb.ChatLive.MessageHandlers` in LiveViews that import it
  - Replace `JargaWeb.ChatLive.Components.Message` → `ChatWeb.ChatLive.Components.Message` if directly imported anywhere
  - Replace `Jarga.ChatFixtures` → `Chat.ChatFixtures` in test files
  - Update `apps/jarga_web/mix.exs` to add `:chat` and `:chat_web` as deps
- [ ] **REFACTOR**: Verify all references updated

### 7.3 Update jarga_web MessageHandlers in LiveViews

- [ ] **GREEN**: For each LiveView that calls `handle_chat_messages()`:
  - Change import from `JargaWeb.ChatLive.MessageHandlers` to `ChatWeb.ChatLive.MessageHandlers`
  - **Note**: The `NotificationCreated` handler remains in a jarga_web-specific handler, not in chat's MessageHandlers
  - If ChatWeb.ChatLive.MessageHandlers no longer includes NotificationCreated handling, ensure it's handled separately in jarga_web
- [ ] **REFACTOR**: Verify all LiveViews still compile

### 7.4 Update Layout Templates

- [ ] **GREEN**: Update layout templates that mount the chat panel:
  - Find all HEEx templates that reference `JargaWeb.ChatLive.Panel`
  - Replace with `ChatWeb.ChatLive.Panel`
  - Ensure the component ID remains `"global-chat-panel"` for consistency
- [ ] **REFACTOR**: Verify panel renders in all layout contexts

### Phase 7 Validation

- [ ] `mix compile` succeeds for jarga_web with no warnings
- [ ] No boundary violations for jarga_web
- [ ] Chat panel still renders in the browser when navigating to any authenticated page
- [ ] All existing jarga_web tests pass

---

## Phase 8: Migrate Tests and BDD Feature Files

⏸ Status: Not Started

### 8.1 Migrate Unit Tests

- [ ] **GREEN**: Copy all test files from `apps/jarga/test/chat/` to `apps/chat/test/chat/` (already created in Phases 2-4 as new tests; verify parity):
  - `domain/entities/session_test.exs`
  - `domain/entities/message_test.exs`
  - `domain/events/chat_session_started_test.exs`
  - `domain/events/chat_message_sent_test.exs`
  - `domain/events/chat_session_deleted_test.exs`
  - `application/use_cases/create_session_test.exs`
  - `application/use_cases/save_message_test.exs`
  - `application/use_cases/delete_session_test.exs`
  - `application/use_cases/delete_message_test.exs`
  - `application/use_cases/load_session_test.exs`
  - `application/use_cases/list_sessions_test.exs`
  - `application/use_cases/prepare_context_test.exs`
  - `application/use_cases/prepare_context_with_agent_test.exs`
  - `infrastructure/schemas/session_schema_test.exs`
  - `infrastructure/schemas/message_schema_test.exs`
  - `infrastructure/queries/queries_test.exs`
- [ ] **REFACTOR**: Verify all test references point to `Chat.*` modules, not `Jarga.Chat.*`

### 8.2 Migrate BDD Feature Files

- [ ] **GREEN**: Copy BDD feature files from `apps/jarga_web/test/features/chat/` to `apps/chat_web/test/features/chat/`:
  - `panel.browser.feature` (7 scenarios)
  - `messaging.browser.feature` (8 scenarios)
  - `streaming.browser.feature` (6 scenarios)
  - `sessions.browser.feature` (6 scenarios)
  - `editor.browser.feature` (6 scenarios)
  - `context.browser.feature` (5 scenarios)
  - `agents.browser.feature` (6 scenarios)
  - **Note**: Feature files are MIGRATED, not regenerated. Content stays the same since the UI behaviour is unchanged.
  - **Note**: Feature files still test against the same URLs since chat_web shares JargaWeb.Endpoint
- [ ] **REFACTOR**: Verify feature file paths are correct per app_ownership.md

### 8.3 Migrate Step Helpers

- [ ] **GREEN**: Extract chat-specific step helpers from `apps/jarga_web/test/support/step_helpers.ex`:
  - Create `apps/chat_web/test/support/step_helpers.ex` with chat-specific helpers
  - Functions to extract: `setup_chat_context/2`, `chat_panel_target/0`, `chat_messages_target/0`, `chat_form_target/0`, `send_chat_message/2`, and all chat session/message assertion helpers
  - Update references from `Jarga.Chat` → `Chat`, `Jarga.ChatFixtures` → `Chat.ChatFixtures`
  - Update `JargaWeb.ChatLive.Panel` → `ChatWeb.ChatLive.Panel`
  - Keep non-chat step helpers in jarga_web's step_helpers.ex
- [ ] **REFACTOR**: Verify both step helper files compile cleanly

### Phase 8 Validation

- [ ] All unit tests pass in `apps/chat/`: `mix test apps/chat/`
- [ ] All BDD feature files exist in `apps/chat_web/test/features/chat/`
- [ ] Feature file step helpers compile and reference correct modules
- [ ] Total: 44 BDD scenarios across 7 feature files

---

## Phase 9: Clean Up jarga — Remove All Chat Code

⏸ Status: Not Started

### 9.1 Remove Chat Domain Code from jarga

- [ ] **GREEN**: Delete the following files/directories from `apps/jarga/`:
  - `lib/chat.ex` (facade)
  - `lib/chat/` (entire directory — domain.ex, application.ex, infrastructure.ex, and all subdirectories)
- [ ] **REFACTOR**: Verify jarga compiles without chat code

### 9.2 Remove Chat Tests from jarga

- [ ] **GREEN**: Delete:
  - `test/chat/` (entire directory)
  - `test/support/fixtures/chat_fixtures.ex`
- [ ] **REFACTOR**: Verify jarga test suite passes

### 9.3 Remove Chat References from jarga Boundary Config

- [ ] **GREEN**: Edit `apps/jarga/lib/jarga.ex` (if it exists as a root module):
  - Remove `Jarga.Chat` from any boundary deps/exports
- [ ] **GREEN**: Edit `apps/jarga_web/lib/jarga_web.ex`:
  - Remove `Jarga.Chat` from Boundary deps (should already be replaced with `Chat` in Phase 7)
  - Remove `Jarga.Chat.Domain` if listed
  - Remove `Jarga.Chat.Application` if listed
  - Remove `Jarga.Chat.Infrastructure` if listed
- [ ] **REFACTOR**: Verify boundary config is clean

### 9.4 Update jarga_web Step Helpers

- [ ] **GREEN**: Remove chat-specific functions from `apps/jarga_web/test/support/step_helpers.ex`:
  - Remove `Jarga.Chat` and `Jarga.ChatFixtures` from boundary deps
  - Remove chat-related imports
  - Remove extracted chat functions (they now live in chat_web step_helpers)
  - Keep any shared helper functions used by non-chat tests
- [ ] **REFACTOR**: Verify remaining step helpers still compile

### 9.5 Clean Up jarga_web Mix Dependencies

- [ ] **GREEN**: Ensure `apps/jarga_web/mix.exs` includes `:chat` and `:chat_web` in deps
- [ ] **GREEN**: Ensure `apps/jarga/mix.exs` does NOT include `:chat` in deps (jarga should not depend on chat)
- [ ] **REFACTOR**: Verify dependency graph is correct

### 9.6 Remove Chat BDD Features from jarga_web

- [ ] **GREEN**: Delete `apps/jarga_web/test/features/chat/` directory (all 7 feature files)
  - These have been migrated to `apps/chat_web/test/features/chat/` in Phase 8
- [ ] **REFACTOR**: Verify jarga_web tests pass without chat features

### Phase 9 Validation

- [ ] `mix compile` succeeds for jarga and jarga_web
- [ ] `mix test apps/jarga/` passes (no chat tests remain)
- [ ] `mix test apps/jarga_web/` passes (no chat features remain)
- [ ] No references to `Jarga.Chat` anywhere in jarga or jarga_web code
- [ ] No boundary violations

---

## Phase 10: Documentation Updates

⏸ Status: Not Started

### 10.1 Update app_ownership.md

- [ ] **GREEN**: Edit `docs/app_ownership.md`:
  - Move `chat` from "Pending Changes" to the main ownership table
  - Update entry: `chat | Domain context | Chat sessions, messages, real-time messaging | Chat.Repo | identity, agents, perme8_events`
  - Add `chat_web | Interface (LiveView) | Chat panel UI, agent selection | None | chat, identity, agents`
  - Remove chat from jarga's "Owns" column
  - Update jarga deps (remove chat references)
  - Add `chat_web` to jarga_web deps
  - Update Domain Event Ownership table: move chat events from jarga to chat
  - Update Feature File Ownership examples if needed
  - Remove "chat" from Pending Changes section
- [ ] **REFACTOR**: Verify document is accurate

### 10.2 Update umbrella_apps.md

- [ ] **GREEN**: Edit `docs/umbrella_apps.md`:
  - Add `chat` and `chat_web` to the apps table
  - Update dependency graph to show chat's position
  - Update jarga description (remove "chat" from its responsibilities)
  - Add jarga_web dep on chat_web
- [ ] **REFACTOR**: Verify document is accurate

### 10.3 Update Config Files

- [ ] **GREEN**: Verify all config files have correct Chat.Repo settings:
  - `config/config.exs` — `:chat` app config
  - `config/dev.exs` — Chat.Repo dev config
  - `config/test.exs` — Chat.Repo test config (sandbox)
  - `config/runtime.exs` — Chat.Repo runtime config
- [ ] **REFACTOR**: Verify configs are consistent with notifications pattern

### Phase 10 Validation

- [ ] `docs/app_ownership.md` reflects chat as independent app
- [ ] `docs/umbrella_apps.md` includes chat and chat_web
- [ ] All config files are consistent

---

## Phase 11: Final Verification

⏸ Status: Not Started

### 11.1 Boundary Compliance

- [ ] Run `mix boundary` — zero violations across all apps
- [ ] Verify chat app has no deps on jarga
- [ ] Verify jarga has no deps on chat
- [ ] Verify chat_web has no deps on jarga_web (only on chat, identity, agents)

### 11.2 Full Test Suite

- [ ] `mix test apps/chat/` — all unit tests pass
- [ ] `mix test apps/chat_web/` — all web tests pass
- [ ] `mix test apps/jarga/` — all jarga tests pass (no chat tests)
- [ ] `mix test apps/jarga_web/` — all jarga_web tests pass (no chat features)
- [ ] `mix test` — full umbrella test suite passes

### 11.3 Pre-commit Checks

- [ ] `mix precommit` passes:
  - Compilation with warnings as errors
  - Boundary checks
  - Code formatting
  - Credo
  - Full test suite

### 11.4 BDD Feature File Verification

- [ ] All 44 BDD scenarios across 7 feature files exist in `apps/chat_web/test/features/chat/`:
  - `panel.browser.feature` — 7 scenarios
  - `messaging.browser.feature` — 8 scenarios
  - `streaming.browser.feature` — 6 scenarios
  - `sessions.browser.feature` — 6 scenarios
  - `editor.browser.feature` — 6 scenarios
  - `context.browser.feature` — 5 scenarios
  - `agents.browser.feature` — 6 scenarios
- [ ] Feature files reference correct CSS selectors (unchanged — UI is identical)
- [ ] Feature file step helpers in chat_web reference correct modules

### 11.5 Standalone Boot Verification

- [ ] Chat app boots standalone: `mix run --no-halt` in apps/chat
- [ ] Chat.Repo connects to database
- [ ] Chat.create_session works with valid user_id (binary_id)
- [ ] No crashes from missing Identity/Jarga modules at boot time

---

## Testing Strategy

### Test Distribution

| Layer | Location | Count (est.) | Async? |
|-------|----------|-------------|--------|
| Domain entities | `apps/chat/test/chat/domain/entities/` | 2 files, ~10 tests | Yes |
| Domain events | `apps/chat/test/chat/domain/events/` | 3 files, ~9 tests | Yes |
| Application use cases | `apps/chat/test/chat/application/use_cases/` | 8 files, ~30 tests | Yes (mocked) |
| Infrastructure schemas | `apps/chat/test/chat/infrastructure/schemas/` | 2 files, ~12 tests | No (DB) |
| Infrastructure queries | `apps/chat/test/chat/infrastructure/queries/` | 1 file, ~10 tests | No (DB) |
| Infrastructure repositories | `apps/chat/test/chat/infrastructure/repositories/` | 2 files, ~14 tests | No (DB) |
| Facade integration | `apps/chat/test/chat_test.exs` | 1 file, ~9 tests | No (DB) |
| Web components | `apps/chat_web/test/chat_web/live/` | 3 files, ~15 tests | No (LiveView) |
| BDD features | `apps/chat_web/test/features/chat/` | 7 files, 44 scenarios | No (browser) |
| **Total** | | **~29 files, ~153 tests + 44 BDD scenarios** | |

### Test Pyramid

```
       /  BDD Features (44 scenarios)  \     ← Browser integration
      /   Web Component Tests (15)      \    ← LiveView unit tests
     /    Infrastructure Tests (36)      \   ← DB integration tests
    /     Application Tests (30)          \  ← Mocked unit tests
   /      Domain Tests (19)                \ ← Pure unit tests (fastest)
```

### Key Testing Patterns

1. **Domain tests**: `ExUnit.Case, async: true` — no DB, no I/O, millisecond execution
2. **Application tests**: `Chat.DataCase, async: true` with Mox mocks — no real DB calls
3. **Infrastructure tests**: `Chat.DataCase` with sandbox — real DB queries
4. **Web tests**: `ChatWeb.ConnCase` — LiveView rendering and events
5. **BDD features**: Browser tests via exo-bdd — full end-to-end validation

---

## Migration Safety Notes

1. **No data migration needed**: Tables already exist in the shared PostgreSQL database. Chat.Repo connects to the same database. The `CREATE TABLE IF NOT EXISTS` pattern in chat migrations handles both fresh and existing databases.

2. **FK constraint removal**: A dedicated migration drops foreign key constraints from `chat_sessions` to `users`, `workspaces`, and `projects`. This is required for standalone boot but is safe because:
   - Referential integrity is maintained at the application level
   - User/workspace/project IDs are still stored as binary_id fields
   - Cascade deletes are no longer needed (chat sessions persist independently)

3. **Backward compatibility**: During the transition, both `Jarga.Chat` and `Chat` facades can coexist. The jarga facade can delegate to the chat app if needed for a staged rollout.

4. **Keep original jarga migrations**: The migrations in `apps/jarga/priv/repo/migrations/` for chat_sessions and chat_messages should NOT be deleted. They are needed for existing databases that have already run them.

5. **Shared endpoint**: `chat_web` shares `JargaWeb.Endpoint` (same pattern as `agents_web`). No new endpoint or port configuration is needed.

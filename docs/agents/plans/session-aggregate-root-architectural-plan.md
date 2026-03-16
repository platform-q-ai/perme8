# Feature: Session Aggregate Root with Durable Interactions, Explicit Ticket Linking, and Transactional Container Management

## Ticket
[#448](https://github.com/platform-q-ai/perme8/issues/448)

## Status: ⏸ Not Started

## App Ownership

| Artifact | Owning App | Path |
|----------|-----------|------|
| Domain entities | `agents` | `apps/agents/lib/agents/sessions/domain/entities/` |
| Domain policies | `agents` | `apps/agents/lib/agents/sessions/domain/policies/` |
| Domain events | `agents` | `apps/agents/lib/agents/sessions/domain/events/` |
| Application use cases | `agents` | `apps/agents/lib/agents/sessions/application/use_cases/` |
| Application behaviours | `agents` | `apps/agents/lib/agents/sessions/application/behaviours/` |
| Infrastructure schemas | `agents` | `apps/agents/lib/agents/sessions/infrastructure/schemas/` |
| Infrastructure queries | `agents` | `apps/agents/lib/agents/sessions/infrastructure/queries/` |
| Infrastructure repositories | `agents` | `apps/agents/lib/agents/sessions/infrastructure/repositories/` |
| Migrations | `agents` | `apps/agents/priv/repo/migrations/` |
| Repo | `agents` | `Agents.Repo` |
| LiveViews | `agents_web` | `apps/agents_web/lib/agents_web/live/` or `apps/agents_web/lib/live/` |
| Browser feature files | `agents_web` | `apps/agents_web/test/features/dashboard/` |
| HTTP feature files | `agents` | `apps/agents/test/features/sessions/` |
| Security feature files | `agents_web` | `apps/agents_web/test/features/dashboard/` |
| Tickets context | `agents` | `apps/agents/lib/agents/tickets/` |

## Overview

Refactor the `agents` app Sessions bounded context from virtual "sessions" (derived via `GROUP BY container_id` on `sessions_tasks`) into a first-class Session aggregate root with its own `sessions` table. This is a 5-phase, zero-downtime migration that:

1. Creates a `sessions` table as the aggregate root, migrating container metadata and lifecycle state from tasks
2. Introduces `session_interactions` for durable question/answer/instruction history, replacing `pending_question`
3. Migrates ticket linking from `task_id` to `session_id` FK
4. Wraps container creation in a saga pattern with startup reconciliation
5. Moves the session lifecycle state machine from the web layer to the domain layer

## UI Strategy
- **LiveView coverage**: 100% — no new TypeScript needed
- **TypeScript needed**: None (existing hooks remain unchanged)

## Affected Boundaries
- **Owning app**: `agents`
- **Repo**: `Agents.Repo`
- **Migrations**: `apps/agents/priv/repo/migrations/`
- **Feature files**: `apps/agents_web/test/features/dashboard/`, `apps/agents/test/features/sessions/`
- **Primary context**: `Agents.Sessions`
- **Dependencies**: `Agents.Tickets` (for ticket-session linking), `Identity` (for user auth)
- **Exported schemas**: `Session` entity will be exported from `Agents.Sessions`
- **New context needed?**: No — this extends the existing `Agents.Sessions` context. The Session becomes the aggregate root, Task becomes a child entity.

## Architecture Decisions

### Session as Aggregate Root
The `Session` entity owns: container metadata (container_id, port, image, container_status), lifecycle state (status, paused_at, resumed_at), SDK session tracking (sdk_session_id), user association, title, and ticket link. Tasks become children of sessions via `session_id` FK.

### Container Status vs Session Status
- **container_status**: `pending → starting → running → stopped → removed` — tracks Docker container lifecycle
- **session status**: `active → paused → completed → failed` — tracks business lifecycle

### Queue System Interaction
The QueueOrchestrator/QueueEngine/QueuePolicy continue to operate on individual tasks. Tasks are the unit of work; Sessions are the aggregate container. The queue promotes tasks, and the TaskRunner updates both the task status AND the parent session's container_status. No changes to queue internals.

### Domain Event Migration Strategy
Existing events using `task_id` as aggregate_id are preserved for backward compatibility. New session-level events use `session_id` as aggregate_id. Events that currently carry `container_id` gain a `session_id` field.

### Backward Compatibility per Phase
Each phase adds new tables/columns BEFORE code starts using them. Old columns are deprecated in a later phase and only removed after all code references are updated.

---

## Phase 1: Session Aggregate Root ⏸

**Goal**: Create `sessions` table, add `session_id` FK on tasks, backfill existing data, simplify `list_sessions_for_user` to a direct query.

**BDD Scenarios Satisfied**:
- Browser: "Session list displays sessions from the sessions table", "Session card displays container metadata", "Session detail shows tasks belonging to the session", "Session status reflects lifecycle state — active/paused/completed/failed", "Container status pending/running/stopped is displayed on session card"
- HTTP: "List sessions returns session entities from sessions table", "Session detail includes container metadata", "Session includes lifecycle timestamps", "Tasks reference sessions via foreign key"
- Security: "Unauthenticated user cannot list sessions", "User cannot access another user's session"

### Phase 1.1: Migration — Create Sessions Table

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_create_sessions_table.exs`
  - **up**: Create `sessions` table with columns:
    - `id` (uuid, PK, autogenerate)
    - `user_id` (uuid, NOT NULL, FK → identity users)
    - `title` (string)
    - `status` (string, NOT NULL, default "active") — values: active, paused, completed, failed
    - `container_id` (string)
    - `container_port` (integer)
    - `container_status` (string, default "pending") — values: pending, starting, running, stopped, removed
    - `image` (string, default "perme8-opencode")
    - `sdk_session_id` (string) — the opencode SDK session ID
    - `paused_at` (utc_datetime)
    - `resumed_at` (utc_datetime)
    - `timestamps(type: :utc_datetime)`
  - Add index on `user_id`
  - Add index on `container_id`
  - **down**: Drop `sessions` table

### Phase 1.2: Migration — Add session_id FK to Tasks

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_add_session_id_to_tasks.exs`
  - **up**: Add `session_id` (uuid) column to `sessions_tasks`, FK → `sessions(id)` ON DELETE SET NULL
  - Add index on `session_id`
  - **down**: Remove `session_id` column from `sessions_tasks`

### Phase 1.3: Migration — Backfill Sessions from Tasks

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_backfill_sessions_from_tasks.exs`
  - **up**: SQL that groups tasks by `container_id` where `container_id IS NOT NULL`:
    - For each unique `(container_id, user_id)` pair:
      - INSERT a session with `container_id`, `container_port` (from latest task), `image` (from first task), `user_id`, `title` (from first task's instruction), `sdk_session_id` (from latest task's `session_id`), `status` derived from latest task status (active if running/pending/starting/queued, completed if completed, failed if failed, active otherwise), `container_status` (running if any task is running/starting/pending, stopped otherwise)
      - UPDATE all tasks with that `container_id` to set `session_id` = new session id
  - **down**: SET `session_id` to NULL on all tasks, DELETE all sessions

### Phase 1.4: Domain — Session Entity

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/session_entity_test.exs`
  - Tests: `new/1` creates session with defaults, `from_schema/1` converts from schema, `active?/1`, `paused?/1`, `completed?/1`, `failed?/1` status predicates, container status predicates
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/domain/entities/session.ex`
  - Add new struct fields: `id`, `title`, `status` (active/paused/completed/failed), `container_status` (pending/starting/running/stopped/removed), `container_id`, `container_port`, `image`, `sdk_session_id`, `paused_at`, `resumed_at`, `inserted_at`, `updated_at`
  - Add `from_schema/1` to convert from `SessionSchema`
  - Keep existing `from_task/1` for backward compatibility during migration
  - Add status predicates: `active?/1`, `paused?/1`, `completed?/1`, `failed?/1`
  - Add container status predicates: `container_running?/1`, `container_stopped?/1`
- [ ] ⏸ **REFACTOR**: Ensure no existing tests break from the extended struct

### Phase 1.5: Infrastructure — Session Schema

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/schemas/session_schema_test.exs`
  - Tests: changeset validates required fields (`user_id`), validates `status` inclusion, validates `container_status` inclusion, `status_changeset/2` accepts mutable fields
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/infrastructure/schemas/session_schema.ex`
  - Ecto schema for `sessions` table
  - `changeset/2` for creation
  - `status_changeset/2` for updates (status, container_status, container_id, container_port, sdk_session_id, paused_at, resumed_at)
  - `has_many :tasks, TaskSchema, foreign_key: :session_id`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1.6: Infrastructure — Session Queries

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/queries/session_queries_test.exs`
  - Tests: `base/0`, `for_user/2`, `by_id/2`, `with_task_count/1`, `active/1`, `recent_first/1`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/infrastructure/queries/session_queries.ex`
  - Composable query functions: `base/0`, `for_user/2`, `by_id/2`, `by_container_id/2`, `with_task_count/1` (left join + count), `active/1`, `recent_first/1`, `limit/2`
- [ ] ⏸ **REFACTOR**: Ensure queries return queryables, not results

### Phase 1.7: Infrastructure — Session Repository

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/repositories/session_repository_test.exs`
  - Tests: `create_session/1`, `get_session/1`, `get_session_for_user/2`, `update_session_status/2`, `list_sessions_for_user/2`, `delete_session/1`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/infrastructure/repositories/session_repository.ex`
  - Implement `SessionRepositoryBehaviour`
  - Uses `SessionQueries` for composable queries
  - `list_sessions_for_user/2` replaces the current `GROUP BY container_id` query
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1.8: Application — Session Repository Behaviour

- [ ] ⏸ **RED**: Behaviour already tested via repository tests
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/application/behaviours/session_repository_behaviour.ex`
  - Callbacks: `create_session/1`, `get_session/1`, `get_session_for_user/2`, `update_session_status/2`, `list_sessions_for_user/2`, `delete_session/1`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1.9: Application — Update CreateTask Use Case

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/application/use_cases/create_task_test.exs`
  - Add tests: creating a task also creates a session if `session_id` not provided, task receives `session_id` FK, session has `status: "active"`, `container_status: "pending"`
  - Existing tests still pass (backward compat)
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex`
  - After creating the task record, create a corresponding session record (or find existing by container_id)
  - Set `session_id` on the task
  - Accept optional `session_id` in attrs to reuse an existing session (for resume/multi-task)
- [ ] ⏸ **REFACTOR**: Extract session creation into a separate private function

### Phase 1.10: Application — Update DeleteSession Use Case

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/application/use_cases/delete_session_test.exs`
  - Add tests: deleting by session_id (not just container_id), session record is deleted along with tasks
  - Existing container_id-based deletion still works
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/application/use_cases/delete_session.ex`
  - Accept `session_id` as alternative to `container_id`
  - Delete session record after deleting tasks
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1.11: Update Sessions Facade

- [ ] ⏸ **RED**: Update test for facade `apps/agents/test/agents/sessions_test.exs` (if exists) or verify via integration
  - Test: `list_sessions/2` returns session entities (not grouped-task maps)
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions.ex`
  - `list_sessions/2` delegates to `SessionRepository.list_sessions_for_user/2` instead of `TaskRepository.list_sessions_for_user/2`
  - Export `Session` entity from boundary
  - Add `get_session/2`, `get_session_for_user/3`
- [ ] ⏸ **REFACTOR**: Mark old `TaskRepository.list_sessions_for_user/2` as deprecated

### Phase 1.12: Update TaskRunner to Track Session

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - Tests: TaskRunner updates session `container_status` when container starts, when task completes (stopped), when task fails (stopped)
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - On container start: update session `container_id`, `container_port`, `container_status: "running"`
  - On SDK session created: update session `sdk_session_id`
  - On task completion: update session `container_status: "stopped"`
  - On task failure: update session `container_status: "stopped"`
  - Inject session_repo as dependency
- [ ] ⏸ **REFACTOR**: Extract session status updates into helper module

### Phase 1.13: Existing Test Updates

The following existing test files need updates for Phase 1:
- `apps/agents/test/agents/sessions/infrastructure/queries/task_queries_test.exs` — `sessions_for_user` query tests still pass (deprecated path)
- `apps/agents/test/agents/sessions/infrastructure/repositories/task_repository_test.exs` — `list_sessions_for_user` tests marked as deprecated
- `apps/agents/test/agents/sessions/application/use_cases/create_task_test.exs` — task creation now also creates session
- `apps/agents/test/agents/sessions/application/use_cases/delete_session_test.exs` — session deletion uses session_id
- `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs` — TaskRunner updates session container_status
- `apps/agents/test/agents/sessions/domain/entities/session_test.exs` — session entity extended with new fields

### Phase 1 Validation
- [ ] ⏸ All domain tests pass (milliseconds, no I/O)
- [ ] ⏸ All application tests pass (with mocks)
- [ ] ⏸ All infrastructure tests pass (with DB)
- [ ] ⏸ Migrations run forward and backward (`mix ecto.migrate` / `mix ecto.rollback`)
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ `mix precommit` passes

---

## Phase 2: Interactions Table ⏸

**Goal**: Create `session_interactions` table, replace `pending_question` with interaction records, persist follow-up messages and resume instructions as interactions.

**BDD Scenarios Satisfied**:
- Browser: "Session detail shows interaction history", "Pending question is displayed from interaction record", "Answering a question creates an answer interaction", "Follow-up messages survive page reload", "Resume instruction appears in interaction history"
- HTTP: "Create a question interaction for a session", "Answer a question interaction with matching correlation ID", "List interaction history for a session", "Resume instruction is stored as an interaction record", "Follow-up message is persisted as an interaction"
- Security: "User cannot view another user's interaction history", "User cannot answer another user's pending question", "User cannot send follow-up messages to another user's session", "Delivered interaction records cannot be modified", "Session deletion cascades to interactions cleanly"

### Phase 2.1: Migration — Create Session Interactions Table

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_create_session_interactions.exs`
  - **up**: Create `session_interactions` table:
    - `id` (uuid, PK, autogenerate)
    - `session_id` (uuid, NOT NULL, FK → `sessions(id)` ON DELETE CASCADE)
    - `task_id` (uuid, FK → `sessions_tasks(id)` ON DELETE SET NULL) — optional, links to specific task
    - `type` (string, NOT NULL) — values: question, answer, instruction, queued_response
    - `direction` (string, NOT NULL) — values: inbound, outbound
    - `payload` (map/jsonb, NOT NULL) — flexible content
    - `correlation_id` (string) — for pairing questions with answers
    - `status` (string, NOT NULL, default "pending") — values: pending, delivered, expired, cancelled, rolled_back, timed_out
    - `timestamps(type: :utc_datetime)`
  - Add indexes: `session_id`, `correlation_id`, `(session_id, type)`, `(session_id, status)`
  - **down**: Drop `session_interactions` table

### Phase 2.2: Domain — Interaction Entity

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/entities/interaction_test.exs`
  - Tests: `new/1` creates interaction with defaults, `from_schema/1`, `question?/1`, `answer?/1`, `instruction?/1`, `queued_response?/1`, `pending?/1`, `delivered?/1`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/domain/entities/interaction.ex`
  - Pure struct: `id`, `session_id`, `task_id`, `type`, `direction`, `payload`, `correlation_id`, `status`, `inserted_at`, `updated_at`
  - Type predicates: `question?/1`, `answer?/1`, `instruction?/1`, `queued_response?/1`
  - Status predicates: `pending?/1`, `delivered?/1`, `expired?/1`
  - `new/1`, `from_schema/1`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2.3: Domain — Interaction Policy

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/interaction_policy_test.exs`
  - Tests: valid types, valid directions, valid statuses, `can_modify?/1` returns false for delivered interactions, `can_answer?/1` returns true only for pending questions
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/domain/policies/interaction_policy.ex`
  - Pure functions: `valid_type?/1`, `valid_direction?/1`, `valid_status?/1`, `can_modify?/1` (false for delivered/expired), `can_answer?/1` (true only for pending questions with matching correlation_id)
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2.4: Infrastructure — Interaction Schema

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/schemas/interaction_schema_test.exs`
  - Tests: changeset validates required fields, validates type inclusion, validates direction inclusion, validates status inclusion
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/infrastructure/schemas/interaction_schema.ex`
  - Ecto schema for `session_interactions`
  - `changeset/2` for creation
  - `status_changeset/2` for status updates
  - `belongs_to :session, SessionSchema`
  - `belongs_to :task, TaskSchema`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2.5: Infrastructure — Interaction Queries

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/queries/interaction_queries_test.exs`
  - Tests: `for_session/2`, `by_type/2`, `by_correlation_id/2`, `pending/1`, `chronological/1`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/infrastructure/queries/interaction_queries.ex`
  - Composable: `base/0`, `for_session/2`, `by_type/2`, `by_correlation_id/2`, `pending/1`, `chronological/1`, `latest_pending_question/1`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2.6: Infrastructure — Interaction Repository

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/repositories/interaction_repository_test.exs`
  - Tests: `create_interaction/1`, `list_for_session/2`, `get_pending_question/1`, `update_status/2`, `delete_for_session/1`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/infrastructure/repositories/interaction_repository.ex`
  - `create_interaction/1`, `list_for_session/2` (chronological), `get_pending_question/1` (latest pending question for session), `update_status/2`, `delete_for_session/1`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2.7: Application — CreateInteraction Use Case

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/create_interaction_test.exs`
  - Tests: creates question interaction, creates answer interaction paired by correlation_id, creates instruction interaction, validates type, validates direction, rejects answer without matching question
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/application/use_cases/create_interaction.ex`
  - Validates type, direction, payload
  - For answer type: finds pending question by correlation_id, marks it as delivered
  - Persists interaction record
  - Emits domain event
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2.8: Application — Update TaskRunner Question Handling

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - Tests: `question.asked` event creates interaction record (not just `pending_question` map), answer creates answer interaction, question timeout creates expired interaction
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - On `question.asked`: create interaction record (type: question, direction: outbound, status: pending) AND continue writing to `pending_question` for backward compat
  - On answer: create interaction record (type: answer, direction: inbound) and mark question as delivered
  - On timeout: mark question interaction as timed_out
- [ ] ⏸ **REFACTOR**: Once all consumers read from interactions, remove `pending_question` writes

### Phase 2.9: Application — Update ResumeTask to Store Instruction as Interaction

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/application/use_cases/resume_task_test.exs`
  - Tests: resume creates an instruction interaction record, no longer overwrites `pending_question`
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/application/use_cases/resume_task.ex`
  - Create instruction interaction (type: instruction, direction: inbound, payload: `%{text: instruction}`)
  - Keep writing `pending_question.resume_prompt` for backward compat initially
- [ ] ⏸ **REFACTOR**: Remove `pending_question.resume_prompt` writes once all consumers migrate

### Phase 2.10: Migration — Deprecate pending_question Column

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_deprecate_pending_question.exs`
  - **up**: Add comment to column (no removal yet — Phase 2 leaves column in place, Phase 5 removes it after all code migrates)
  - **down**: No-op

### Phase 2.11: Update Sessions Facade

- [ ] ⏸ **RED**: Verify via integration tests
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions.ex`
  - Add `create_interaction/2`, `list_interactions/2`, `get_pending_question/1`
  - Export `Interaction` entity from boundary
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2 Validation
- [ ] ⏸ All domain tests pass
- [ ] ⏸ All application tests pass
- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ Migrations run forward and backward
- [ ] ⏸ `pending_question` writes continue for backward compat
- [ ] ⏸ No boundary violations
- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ `mix precommit` passes

---

## Phase 3: Ticket-Session Link Migration ⏸

**Goal**: Migrate ticket linking from `task_id` to `session_id` FK, with explicit linking at session creation time.

**BDD Scenarios Satisfied**:
- Browser: "Starting a session from a ticket links the ticket to the session", "Ticket-session link survives page reload", "Clicking a linked ticket navigates to its session"
- HTTP: "Ticket references session instead of task", "Creating a session for a ticket sets the link explicitly", "Ticket enrichment includes session lifecycle state"
- Security: (covered by session-level access control from Phase 1)

### Phase 3.1: Migration — Add session_id to Tickets

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_add_session_id_to_project_tickets.exs`
  - **up**: Add `session_id` (uuid) column to `sessions_project_tickets`, FK → `sessions(id)` ON DELETE SET NULL
  - Add index on `session_id`
  - **down**: Remove `session_id` column

### Phase 3.2: Migration — Backfill Ticket Session Links

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_backfill_ticket_session_links.exs`
  - **up**: SQL that joins `sessions_project_tickets.task_id` → `sessions_tasks.id` → `sessions_tasks.session_id` to populate `sessions_project_tickets.session_id`
  - **down**: SET `session_id` to NULL on all tickets

### Phase 3.3: Domain — Update Ticket Entity

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/tickets/domain/entities/ticket_test.exs`
  - Tests: ticket entity has `session_id` field, `associated_session_id` field for enrichment
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/tickets/domain/entities/ticket.ex`
  - Add `session_id`, `associated_session_id` fields
  - Add `session_lifecycle_state`, `session_container_status`, `session_title` enrichment fields
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3.4: Infrastructure — Update Ticket Schema

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/tickets/infrastructure/schemas/project_ticket_schema_test.exs`
  - Tests: changeset accepts `session_id`, FK constraint works
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex`
  - Add `field(:session_id, Ecto.UUID)`
  - Add `belongs_to :session, Agents.Sessions.Infrastructure.Schemas.SessionSchema` (or just FK field)
  - Keep `task_id` for backward compat
  - Add `session_id` to changeset cast list
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3.5: Domain — Update Ticket Enrichment Policy

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/tickets/domain/policies/ticket_enrichment_policy_test.exs`
  - Tests: enrichment uses `session_id` when available, falls back to `task_id`, enrichment includes session lifecycle state and container status
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/tickets/domain/policies/ticket_enrichment_policy.ex`
  - Add session-based resolution: if ticket has `session_id`, look up session for enrichment
  - Fall back to task-based resolution for backward compat
  - Populate `session_lifecycle_state`, `session_container_status`, `session_title`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3.6: Application — Update Ticket Linking

- [ ] ⏸ **RED**: Update test for `Agents.Tickets` facade
  - Tests: `link_ticket_to_session/2` sets session_id on ticket, `create_session_for_ticket/2` creates session AND sets link
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/tickets.ex` (facade)
  - Add `link_ticket_to_session/2` — sets `session_id` on ticket record
  - Modify `link_ticket_to_task/2` — also sets `session_id` if the task has a session
  - Keep `link_ticket_to_task/2` for backward compat
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3.7: Web — Update TicketSessionLinker

- [ ] ⏸ **RED**: Update test `apps/agents_web/test/live/dashboard/ticket_session_linker_test.exs`
  - Tests: linker uses session_id instead of task_id for linking, explicit linking at session creation
- [ ] ⏸ **GREEN**: Modify `apps/agents_web/lib/live/dashboard/ticket_session_linker.ex`
  - `link_and_refresh/2` now calls `Tickets.link_ticket_to_session/2` when session_id is available
  - Remove regex-based ticket number extraction for new sessions (explicit linking only)
  - Keep regex fallback for legacy sessions without explicit links
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3.8: Application — CreateTask Accepts ticket_id

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/application/use_cases/create_task_test.exs`
  - Tests: when `ticket_id` is provided, session is created AND ticket is linked to session
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex`
  - Accept optional `ticket_id` in attrs
  - After creating session, call `Tickets.link_ticket_to_session/2` if `ticket_id` present
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3.9: Migration — Deprecate task_id on Tickets

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_deprecate_task_id_on_tickets.exs`
  - **up**: Add comment marking `task_id` as deprecated (no removal yet)
  - **down**: No-op

### Phase 3 Validation
- [ ] ⏸ All domain tests pass
- [ ] ⏸ All application tests pass
- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ Ticket enrichment works with both session_id and task_id paths
- [ ] ⏸ Migrations run forward and backward
- [ ] ⏸ No boundary violations
- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ `mix precommit` passes

---

## Phase 4: Transactional Container Management ⏸

**Goal**: Wrap container creation + session persistence in a saga pattern. Add startup reconciliation.

**BDD Scenarios Satisfied**:
- HTTP: "Session creation starts with container status pending", "Container status transitions are persisted on the session", "Startup reconciliation resolves orphaned containers"
- Security: "Session response does not expose Docker host paths", "Session response does not leak internal port mappings"

### Phase 4.1: Domain — Container Lifecycle Policy

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/container_lifecycle_policy_test.exs`
  - Tests: valid container status transitions (pending → starting → running → stopped → removed), `can_transition?/2`, compensation rules
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/domain/policies/container_lifecycle_policy.ex`
  - Pure functions: `valid_status?/1`, `can_transition?/2`, `compensation_action/2` (what to do on failure at each stage)
  - Valid statuses: pending, starting, running, stopped, removed
  - Transitions: pending → starting, starting → running, running → stopped, stopped → removed, any → removed (forced)
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 4.2: Application — CreateSessionWithContainer Use Case (Saga)

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/create_session_with_container_test.exs`
  - Tests:
    - Happy path: creates session (pending) → starts container → updates session (starting → running)
    - Container start fails: session record is deleted (compensated)
    - DB update fails after container start: container is stopped and removed (compensated)
    - Session has correct container_status at each stage
  - Mocks: container_provider, session_repo
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/application/use_cases/create_session_with_container.ex`
  - Step 1: Create session with `container_status: "pending"`, `status: "active"`
  - Step 2: Call `container_provider.start(image, [])`
  - Step 3: Update session with `container_id`, `container_port`, `container_status: "starting"`
  - On Step 2 failure: Delete session record (compensate)
  - On Step 3 failure: Stop and remove container (compensate)
  - DockerAdapter interface unchanged
- [ ] ⏸ **REFACTOR**: Extract compensation logic into named functions

### Phase 4.3: Application — Update TaskRunner to Use Session Container Status

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - Tests: container start persists `container_status: "starting"` on session, health check pass persists `container_status: "running"`, task completion persists `container_status: "stopped"`
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - On `:start_container` success: update session `container_status: "starting"`
  - On health check pass + session creation: update session `container_status: "running"`, `sdk_session_id`
  - On task complete/fail/cancel: update session `container_status: "stopped"`
  - On terminate (container cleanup): update session `container_status: "stopped"`
  - All updates through injected `session_repo`
- [ ] ⏸ **REFACTOR**: Ensure no duplicate container_status transitions

### Phase 4.4: Infrastructure — Startup Reconciliation

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/infrastructure/startup_reconciliation_test.exs`
  - Tests:
    - Session with `container_status: "running"` but container not found → mark session `container_status: "removed"`, `status: "failed"`
    - Session with `container_status: "running"` and container actually running → no change
    - Session with `container_status: "starting"` but no container → mark as failed
    - Returns reconciliation stats
  - Mocks: container_provider, session_repo
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/infrastructure/startup_reconciliation.ex`
  - Queries all sessions with `container_status` in `["pending", "starting", "running"]`
  - For each: check actual container state via `container_provider.status/1`
  - Resolve discrepancies:
    - DB says running, container not found → mark session `container_status: "removed"`, `status: "failed"`
    - DB says running, container stopped → mark `container_status: "stopped"`
    - DB says pending/starting, container not found → mark `container_status: "removed"`, `status: "failed"`
  - Return `%{reconciled: N, orphaned_containers_cleaned: N, stale_sessions_marked: N}`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 4.5: Update OrphanRecovery to Use Sessions

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/infrastructure/orphan_recovery_test.exs`
  - Tests: orphan recovery reads from sessions table for container state, marks orphaned sessions as failed
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/orphan_recovery.ex`
  - Query sessions with active `container_status` instead of tasks with active status
  - Mark sessions as failed/removed when orphaned
  - Continue marking individual tasks as failed for backward compat
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 4.6: Domain Event — SessionContainerStatusChanged

- [ ] ⏸ **RED**: Write test for event struct
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/domain/events/session_container_status_changed.ex`
  - Fields: `session_id`, `user_id`, `from_status`, `to_status`, `container_id`
- [ ] ⏸ **REFACTOR**: Emit from TaskRunner and CreateSessionWithContainer use case

### Phase 4 Validation
- [ ] ⏸ All tests pass
- [ ] ⏸ Saga compensates correctly on every failure path
- [ ] ⏸ Startup reconciliation resolves all discrepancies
- [ ] ⏸ DockerAdapter interface is unchanged
- [ ] ⏸ No boundary violations
- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ `mix precommit` passes

---

## Phase 5: Session Lifecycle State Machine (Domain Level) ⏸

**Goal**: Move the session lifecycle state machine from the web layer to the domain layer. Session entity enforces valid transitions. Web-layer `SessionStateMachine` becomes a thin projection.

**BDD Scenarios Satisfied**:
- Browser: "Pausing a session shows paused state with timestamp", "Resuming a paused session shows active state with timestamp", "Completed sessions cannot be paused"
- HTTP: "Pausing a session sets status and timestamps", "Resuming a paused session sets status and creates resume task", "Invalid lifecycle transition is rejected", "Session status reflects domain-level state machine"
- Security: "User cannot pause another user's session", "User cannot resume another user's session"

### Phase 5.1: Domain — Session Lifecycle State Machine

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/domain/policies/session_state_machine_test.exs`
  - Tests:
    - Valid transitions: active → paused, paused → active, active → completed, active → failed
    - Invalid transitions: completed → paused (rejected), failed → active (rejected), paused → completed (rejected)
    - `can_pause?/1` — true only for active
    - `can_resume?/1` — true only for paused
    - `can_complete?/1` — true only for active
    - `can_fail?/1` — true for active or paused
    - `transition/2` returns `{:ok, new_status}` or `{:error, :invalid_transition}`
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/domain/policies/session_state_machine_policy.ex`
  - Valid transitions: `{:active, :paused}`, `{:paused, :active}`, `{:active, :completed}`, `{:active, :failed}`, `{:paused, :failed}`
  - `can_pause?/1`, `can_resume?/1`, `can_complete?/1`, `can_fail?/1`
  - `transition/2` — validates and returns new status
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 5.2: Application — PauseSession Use Case

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/pause_session_test.exs`
  - Tests:
    - Pausing active session: sets `status: "paused"`, `paused_at`, `container_status: "stopped"`
    - Pausing non-active session: returns `{:error, :invalid_transition}`
    - Pausing non-owned session: returns `{:error, :not_found}`
    - Emits SessionStateChanged event
  - Mocks: session_repo, container_provider, event_bus
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/application/use_cases/pause_session.ex`
  - Validate ownership via session_repo
  - Validate transition via `SessionStateMachinePolicy.can_pause?/1`
  - Update session: `status: "paused"`, `paused_at: DateTime.utc_now()`
  - Stop container via container_provider
  - Update session: `container_status: "stopped"`
  - Cancel active TaskRunner processes for this session's tasks
  - Emit `SessionStateChanged` event
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 5.3: Application — ResumeSession Use Case

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/resume_session_test.exs`
  - Tests:
    - Resuming paused session: sets `status: "active"`, `resumed_at`, creates resume task, creates instruction interaction
    - Resuming non-paused session: returns `{:error, :invalid_transition}`
    - Resuming non-owned session: returns `{:error, :not_found}`
    - Resume instruction is stored as interaction (not pending_question)
    - Emits SessionStateChanged event
  - Mocks: session_repo, task_repo, interaction_repo, event_bus
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/application/use_cases/resume_session.ex`
  - Validate ownership
  - Validate transition via `SessionStateMachinePolicy.can_resume?/1`
  - Create a new task with type "resume" linked to this session
  - Create instruction interaction (type: instruction, direction: inbound, payload: `%{text: instruction}`)
  - Update session: `status: "active"`, `resumed_at: DateTime.utc_now()`
  - Queue the resume task for processing
  - Emit `SessionStateChanged` event
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 5.4: Application — CompleteSession Use Case

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/complete_session_test.exs`
  - Tests: completing active session sets `status: "completed"`, invalid transition rejected
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/application/use_cases/complete_session.ex`
  - Called when the last task in a session completes
  - Validate transition, update session status
  - Emit event
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 5.5: Application — FailSession Use Case

- [ ] ⏸ **RED**: Write test `apps/agents/test/agents/sessions/application/use_cases/fail_session_test.exs`
  - Tests: failing active/paused session sets `status: "failed"`, invalid transition rejected
- [ ] ⏸ **GREEN**: Create `apps/agents/lib/agents/sessions/application/use_cases/fail_session.ex`
  - Called when a task fails and the session should be marked failed
  - Validate transition, update session status
  - Emit event
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 5.6: Update TaskRunner to Trigger Session Lifecycle

- [ ] ⏸ **RED**: Update test `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs`
  - Tests: task completion triggers `CompleteSession`, task failure triggers `FailSession`
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex`
  - On `complete_task`: call `CompleteSession.execute/2` if this is the last/only task
  - On `fail_task`: call `FailSession.execute/2`
  - Session lifecycle transitions happen in domain, not TaskRunner
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 5.7: Web — Update SessionStateMachine to Read from Domain

- [ ] ⏸ **RED**: Update test `apps/agents_web/test/live/dashboard/session_state_machine_test.exs`
  - Tests: `state_from_session/1` reads from session entity's `status` field, not derived from task
- [ ] ⏸ **GREEN**: Modify `apps/agents_web/lib/live/dashboard/session_state_machine.ex`
  - Add `state_from_session/1` that reads session `status` directly
  - `state_from_task/1` continues to work for task-level granularity
  - State machine becomes a thin projection: reads from domain, does NOT own state
  - Remove `lifecycle_state` derivation logic (now in domain)
- [ ] ⏸ **REFACTOR**: Simplify and document the delegation pattern

### Phase 5.8: Update Sessions Facade

- [ ] ⏸ **RED**: Verify via integration
- [ ] ⏸ **GREEN**: Modify `apps/agents/lib/agents/sessions.ex`
  - Add `pause_session/2`, `resume_session/3`, `complete_session/2`, `fail_session/2`
  - Wire to respective use cases
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 5.9: Domain Events — Update Existing Events

- [ ] ⏸ **RED**: Verify event structs compile with new fields
- [ ] ⏸ **GREEN**: Update existing domain events to include `session_id` where they currently use `container_id`:
  - `SessionStateChanged` — add `session_id` field
  - `TaskCompleted`, `TaskFailed`, `TaskCancelled` — add `session_id` field
  - `TaskCreated`, `TaskQueued`, `TaskPromoted` — add `session_id` field
  - New: `SessionPaused`, `SessionResumed` events
- [ ] ⏸ **REFACTOR**: Ensure backward compat (old consumers that don't pattern match on `session_id` still work)

### Phase 5.10: Migration — Remove pending_question Column

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_remove_pending_question_from_tasks.exs`
  - **up**: Remove `pending_question` column from `sessions_tasks`
  - **down**: Add `pending_question` (map) column back to `sessions_tasks`
  - **NOTE**: Only deploy this migration AFTER all code paths have been updated to use interactions instead of pending_question

### Phase 5.11: Migration — Remove task_id from Tickets

- [ ] ⏸ Create migration `apps/agents/priv/repo/migrations/TIMESTAMP_remove_task_id_from_project_tickets.exs`
  - **up**: Remove `task_id` column from `sessions_project_tickets`
  - **down**: Add `task_id` (uuid) column back
  - **NOTE**: Only deploy this migration AFTER all code paths have been updated to use session_id

### Phase 5.12: Existing Test Updates for Phase 5

The following test files need updates:
- `apps/agents/test/agents/sessions/application/use_cases/resume_task_test.exs` — resume now goes through session, interaction stored
- `apps/agents/test/agents/sessions/infrastructure/task_runner_test.exs` — completion/failure triggers session lifecycle
- `apps/agents/test/agents/sessions/infrastructure/orphan_recovery_test.exs` — reads sessions for reconciliation
- `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs` — queue still operates on tasks (verify no regressions)
- `apps/agents_web/test/live/dashboard/session_state_machine_test.exs` — state machine reads from domain session
- `apps/agents_web/test/live/dashboard/ticket_session_linker_test.exs` — linker uses session_id
- All existing feature files referencing task-level status derivation

### Phase 5 Validation
- [ ] ⏸ All domain tests pass
- [ ] ⏸ All application tests pass
- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ All interface tests pass
- [ ] ⏸ Session lifecycle is controlled by domain, not web layer
- [ ] ⏸ Web SessionStateMachine is a thin projection
- [ ] ⏸ `pending_question` column removed (all consumers migrated)
- [ ] ⏸ `task_id` on tickets removed (all consumers migrated)
- [ ] ⏸ No boundary violations
- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ `mix precommit` passes
- [ ] ⏸ `mix boundary` passes

---

## Pre-Commit Checkpoint (After All Phases)

- [ ] ⏸ `mix precommit` passes (compilation, formatting, credo, tests)
- [ ] ⏸ `mix boundary` passes (no cross-boundary violations)
- [ ] ⏸ All 55 BDD scenarios addressed:
  - 21 browser scenarios (session-aggregate-root.browser.feature)
  - 19 HTTP scenarios (session-aggregate-root.http.feature)
  - 15 security scenarios (session-aggregate-root.security.feature)
- [ ] ⏸ All existing test files updated and green
- [ ] ⏸ DockerAdapter interface unchanged
- [ ] ⏸ Domain events reference `session_id` where applicable
- [ ] ⏸ Zero-downtime migration verified (each phase independently deployable)

---

## Testing Strategy

### New Test Files (by phase)

| Phase | Test File | Type | Async |
|-------|-----------|------|-------|
| 1 | `sessions/domain/entities/session_entity_test.exs` | Domain | Yes |
| 1 | `sessions/infrastructure/schemas/session_schema_test.exs` | Infrastructure | No |
| 1 | `sessions/infrastructure/queries/session_queries_test.exs` | Infrastructure | No |
| 1 | `sessions/infrastructure/repositories/session_repository_test.exs` | Infrastructure | No |
| 2 | `sessions/domain/entities/interaction_test.exs` | Domain | Yes |
| 2 | `sessions/domain/policies/interaction_policy_test.exs` | Domain | Yes |
| 2 | `sessions/infrastructure/schemas/interaction_schema_test.exs` | Infrastructure | No |
| 2 | `sessions/infrastructure/queries/interaction_queries_test.exs` | Infrastructure | No |
| 2 | `sessions/infrastructure/repositories/interaction_repository_test.exs` | Infrastructure | No |
| 2 | `sessions/application/use_cases/create_interaction_test.exs` | Application | No |
| 3 | (updates to existing ticket tests) | Various | Mixed |
| 4 | `sessions/domain/policies/container_lifecycle_policy_test.exs` | Domain | Yes |
| 4 | `sessions/application/use_cases/create_session_with_container_test.exs` | Application | No |
| 4 | `sessions/infrastructure/startup_reconciliation_test.exs` | Infrastructure | No |
| 5 | `sessions/domain/policies/session_state_machine_test.exs` | Domain | Yes |
| 5 | `sessions/application/use_cases/pause_session_test.exs` | Application | No |
| 5 | `sessions/application/use_cases/resume_session_test.exs` | Application | No |
| 5 | `sessions/application/use_cases/complete_session_test.exs` | Application | No |
| 5 | `sessions/application/use_cases/fail_session_test.exs` | Application | No |

### Existing Test Files Requiring Updates

| Test File | Phases | Reason |
|-----------|--------|--------|
| `create_task_test.exs` | 1, 3 | Task creation also creates session; accepts ticket_id |
| `resume_task_test.exs` | 2, 5 | Resume stores instruction as interaction |
| `delete_session_test.exs` | 1 | Accepts session_id; deletes session record |
| `task_runner_test.exs` | 1, 2, 4, 5 | Updates session container_status; interactions; lifecycle triggers |
| `orphan_recovery_test.exs` | 4 | Reads from sessions table |
| `queue_orchestrator_test.exs` | (verify) | No structural changes, but verify no regressions |
| `session_state_machine_test.exs` (web) | 5 | Reads from domain session state |
| `ticket_session_linker_test.exs` (web) | 3 | Uses session_id for linking |
| `ticket_enrichment_policy_test.exs` | 3 | Session-based enrichment |
| `project_ticket_schema_test.exs` | 3 | session_id field added |
| `task_queries_test.exs` | 1 | sessions_for_user deprecated |
| `task_repository_test.exs` | 1 | list_sessions_for_user deprecated |
| `session_test.exs` (domain entity) | 1 | Extended fields |

### Test Distribution Estimate

- **Domain (pure, fast)**: ~30 tests (entities, policies, state machines)
- **Application (mocked)**: ~35 tests (use cases with mocked repos/providers)
- **Infrastructure (DB)**: ~25 tests (schemas, queries, repositories, reconciliation)
- **Interface (ConnCase)**: ~10 tests (LiveView/controller updates)
- **Total new tests**: ~100
- **Existing test updates**: ~50 files touched

---

## File Summary

### New Files to Create

| File | Phase |
|------|-------|
| `apps/agents/priv/repo/migrations/TIMESTAMP_create_sessions_table.exs` | 1 |
| `apps/agents/priv/repo/migrations/TIMESTAMP_add_session_id_to_tasks.exs` | 1 |
| `apps/agents/priv/repo/migrations/TIMESTAMP_backfill_sessions_from_tasks.exs` | 1 |
| `apps/agents/lib/agents/sessions/infrastructure/schemas/session_schema.ex` | 1 |
| `apps/agents/lib/agents/sessions/infrastructure/queries/session_queries.ex` | 1 |
| `apps/agents/lib/agents/sessions/infrastructure/repositories/session_repository.ex` | 1 |
| `apps/agents/lib/agents/sessions/application/behaviours/session_repository_behaviour.ex` | 1 |
| `apps/agents/priv/repo/migrations/TIMESTAMP_create_session_interactions.exs` | 2 |
| `apps/agents/lib/agents/sessions/domain/entities/interaction.ex` | 2 |
| `apps/agents/lib/agents/sessions/domain/policies/interaction_policy.ex` | 2 |
| `apps/agents/lib/agents/sessions/infrastructure/schemas/interaction_schema.ex` | 2 |
| `apps/agents/lib/agents/sessions/infrastructure/queries/interaction_queries.ex` | 2 |
| `apps/agents/lib/agents/sessions/infrastructure/repositories/interaction_repository.ex` | 2 |
| `apps/agents/lib/agents/sessions/application/use_cases/create_interaction.ex` | 2 |
| `apps/agents/priv/repo/migrations/TIMESTAMP_add_session_id_to_project_tickets.exs` | 3 |
| `apps/agents/priv/repo/migrations/TIMESTAMP_backfill_ticket_session_links.exs` | 3 |
| `apps/agents/lib/agents/sessions/domain/policies/container_lifecycle_policy.ex` | 4 |
| `apps/agents/lib/agents/sessions/application/use_cases/create_session_with_container.ex` | 4 |
| `apps/agents/lib/agents/sessions/infrastructure/startup_reconciliation.ex` | 4 |
| `apps/agents/lib/agents/sessions/domain/events/session_container_status_changed.ex` | 4 |
| `apps/agents/lib/agents/sessions/domain/policies/session_state_machine_policy.ex` | 5 |
| `apps/agents/lib/agents/sessions/application/use_cases/pause_session.ex` | 5 |
| `apps/agents/lib/agents/sessions/application/use_cases/resume_session.ex` | 5 |
| `apps/agents/lib/agents/sessions/application/use_cases/complete_session.ex` | 5 |
| `apps/agents/lib/agents/sessions/application/use_cases/fail_session.ex` | 5 |
| `apps/agents/lib/agents/sessions/domain/events/session_paused.ex` | 5 |
| `apps/agents/lib/agents/sessions/domain/events/session_resumed.ex` | 5 |
| `apps/agents/priv/repo/migrations/TIMESTAMP_remove_pending_question_from_tasks.exs` | 5 |
| `apps/agents/priv/repo/migrations/TIMESTAMP_remove_task_id_from_project_tickets.exs` | 5 |

### Existing Files to Modify

| File | Phase(s) |
|------|----------|
| `apps/agents/lib/agents/sessions/domain/entities/session.ex` | 1 |
| `apps/agents/lib/agents/sessions/domain/entities/task.ex` | 1 (add session_id field) |
| `apps/agents/lib/agents/sessions/infrastructure/schemas/task_schema.ex` | 1 (add session_id FK) |
| `apps/agents/lib/agents/sessions/application/use_cases/create_task.ex` | 1, 3 |
| `apps/agents/lib/agents/sessions/application/use_cases/delete_session.ex` | 1 |
| `apps/agents/lib/agents/sessions/application/use_cases/resume_task.ex` | 2, 5 |
| `apps/agents/lib/agents/sessions/infrastructure/task_runner.ex` | 1, 2, 4, 5 |
| `apps/agents/lib/agents/sessions/infrastructure/orphan_recovery.ex` | 4 |
| `apps/agents/lib/agents/sessions/infrastructure/repositories/task_repository.ex` | 1 |
| `apps/agents/lib/agents/sessions/infrastructure/queries/task_queries.ex` | 1 |
| `apps/agents/lib/agents/sessions/application/behaviours/task_repository_behaviour.ex` | 1 |
| `apps/agents/lib/agents/sessions.ex` | 1, 2, 3, 5 |
| `apps/agents/lib/agents/tickets/infrastructure/schemas/project_ticket_schema.ex` | 3 |
| `apps/agents/lib/agents/tickets/domain/entities/ticket.ex` | 3 |
| `apps/agents/lib/agents/tickets/domain/policies/ticket_enrichment_policy.ex` | 3 |
| `apps/agents/lib/agents/tickets.ex` | 3 |
| `apps/agents_web/lib/live/dashboard/session_state_machine.ex` | 5 |
| `apps/agents_web/lib/live/dashboard/ticket_session_linker.ex` | 3 |
| `apps/agents/lib/agents/sessions/domain/events/session_state_changed.ex` | 5 |
| `apps/agents/lib/agents/sessions/domain/events/task_completed.ex` | 5 |
| `apps/agents/lib/agents/sessions/domain/events/task_failed.ex` | 5 |
| `apps/agents/lib/agents/sessions/domain/events/task_cancelled.ex` | 5 |
| `apps/agents/lib/agents/sessions/domain/events/task_created.ex` | 5 |
| `apps/agents/lib/agents/sessions/domain/events/task_queued.ex` | 5 |

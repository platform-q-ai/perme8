# Feature: Application-Level Referential Integrity Validation for Chat (#452)

## Overview

The Chat app intentionally dropped database-level FK constraints on cross-app references (`user_id`, `workspace_id`, `project_id`) for Standalone App Principle compliance. This plan adds application-level validation to replace those constraints:

1. **Pre-creation validation** — Validate that referenced users/workspaces exist via Identity's public API before creating sessions.
2. **Event-driven cleanup** — Subscribe to Identity deletion events to clean up orphaned chat sessions.
3. **Periodic orphan detection** — Defense-in-depth GenServer that samples the database for orphaned sessions.
4. **Reliable event emission** — Wrap DB operations + event emission in transactions for SaveMessage and DeleteSession.

## UI Strategy

- **LiveView coverage**: 100% — No UI changes needed. This is backend-only (domain/application/infrastructure).
- **TypeScript needed**: None.

## Affected Boundaries

- **Owning app**: `chat`
- **Repo**: `Chat.Repo`
- **Migrations**: `apps/chat/priv/repo/migrations/` (none needed — no schema changes)
- **Feature files**: N/A (backend-only, no UI changes)
- **Primary context**: `Chat` (single bounded context)
- **Dependencies**: `Identity` (public facade API for user/workspace validation), `perme8_events` (EventHandler behaviour)
- **Exported schemas**: None new
- **New context needed?**: No — all changes are within the existing Chat bounded context

## Design Decisions

### 1. Workspace Validation Strategy

**Decision: Option (b) — `Identity.member?/2`**

Use `Identity.get_user/1` to validate user existence, then `Identity.member?/2` to validate the user is actually a member of the provided workspace. This is stronger than a simple `workspace_exists?` check because it enforces that the user creating the session actually has access to the workspace.

Rationale:
- `Identity.get_user/1` already exists and returns `%User{} | nil`
- `Identity.member?/2` already exists and returns `boolean()`
- No need to add new functions to the Identity facade
- Validates both existence AND authorization in one flow

### 2. Event-Driven Cleanup

**Decision: Document dependency; build handler infrastructure now.**

Identity does NOT currently emit `UserDeleted` or `WorkspaceDeleted` events (checked: only `MemberInvited`, `MemberJoined`, `MemberRemoved`, `WorkspaceInvitationNotified`, `WorkspaceUpdated` exist). The event handler will be built to subscribe to the topics where these events would appear and handle `MemberRemoved` as a proxy for workspace access revocation. The periodic orphan detector serves as the primary cleanup mechanism until Identity adds deletion events.

We will:
- Subscribe to `"events:identity:workspace_member"` to handle `MemberRemoved` (clean up sessions for that user+workspace)
- Document that `UserDeleted` and `WorkspaceDeleted` event support is pending Identity work
- Rely on the periodic orphan detector as defense-in-depth

### 3. Transactional Event Emission

**Decision: Use `Ecto.Multi` or `Repo.transaction` in SaveMessage and DeleteSession.**

Currently, DB write and event emission are sequential but not atomic — if the process crashes between the DB write and the `event_bus.emit` call, the event is lost. We will wrap the DB operation in a transaction and emit events after the transaction commits (as required by PHOENIX_DESIGN_PRINCIPLES.md). The key change is using `Repo.transaction` to ensure the DB operation is committed before emitting, and handling the case where emit itself fails with logging (events are best-effort after commit).

**Note**: The current pattern already emits after the DB operation succeeds (not inside a transaction callback). The real risk is in `SaveMessage` where a session lookup happens between the message insert and the event emit. We'll consolidate this into a single transaction where needed.

### 4. Identity Validation Dependency Injection

**Decision: Add `identity_api` injectable dependency.**

Create a `Chat.Application.Behaviours.IdentityApiBehaviour` that defines callbacks for `user_exists?/1` and `validate_workspace_access/2`. The real implementation calls `Identity.get_user/1` and `Identity.member?/2`. Tests inject a Mox mock. This follows the existing pattern of `session_repository` and `message_repository` injection.

---

## Phase 1: Domain + Application (phoenix-tdd)

### Step 1.1: IdentityApiBehaviour (Port Definition)

- [ ] ⏸ **RED**: Write test `apps/chat/test/chat/application/behaviours/identity_api_behaviour_test.exs`
  - Tests: Behaviour module compiles and defines required callbacks
  - Verify that `@callback user_exists?(String.t()) :: boolean()` exists
  - Verify that `@callback validate_workspace_access(String.t(), String.t()) :: :ok | {:error, atom()}` exists
- [ ] ⏸ **GREEN**: Implement `apps/chat/lib/chat/application/behaviours/identity_api_behaviour.ex`
  - Define `@callback user_exists?(user_id :: String.t()) :: boolean()`
  - Define `@callback validate_workspace_access(user_id :: String.t(), workspace_id :: String.t()) :: :ok | {:error, :workspace_not_found | :not_a_member}`
- [ ] ⏸ **REFACTOR**: Clean up, add @moduledoc

### Step 1.2: ReferenceValidationPolicy (Pure Domain Policy)

- [ ] ⏸ **RED**: Write test `apps/chat/test/chat/domain/policies/reference_validation_policy_test.exs`
  - Tests (all pure, no I/O):
    - `validate_user_reference/1` returns `:ok` for `{:ok, true}` (user exists)
    - `validate_user_reference/1` returns `{:error, :user_not_found}` for `{:ok, false}`
    - `validate_user_reference/1` returns `{:error, :identity_unavailable}` for `{:error, _}`
    - `validate_workspace_reference/1` returns `:ok` for `nil` workspace_id (optional field)
    - `validate_workspace_reference/1` returns `:ok` for `:ok` validation result
    - `validate_workspace_reference/1` returns `{:error, :workspace_not_found}` for `{:error, :workspace_not_found}`
    - `validate_workspace_reference/1` returns `{:error, :not_a_member}` for `{:error, :not_a_member}`
    - `validate_references/2` returns `:ok` when all validations pass
    - `validate_references/2` returns the first error when any validation fails
- [ ] ⏸ **GREEN**: Implement `apps/chat/lib/chat/domain/policies/reference_validation_policy.ex`
  - Pure functions, no I/O. Take pre-fetched validation results as inputs.
  - `validate_user_reference(lookup_result)` — interprets Identity lookup result
  - `validate_workspace_reference(lookup_result)` — interprets workspace validation result
  - `validate_references(user_result, workspace_result)` — composes both validations
- [ ] ⏸ **REFACTOR**: Clean up

### Step 1.3: Update CreateSession Use Case (Add Validation)

- [ ] ⏸ **RED**: Write new tests in `apps/chat/test/chat/application/use_cases/create_session_test.exs`
  - Add new `describe "referential integrity validation"` block:
    - Test: returns `{:error, :user_not_found}` when user does not exist
    - Test: returns `{:error, :workspace_not_found}` when workspace_id provided but workspace doesn't exist
    - Test: returns `{:error, :not_a_member}` when user is not a member of provided workspace
    - Test: succeeds when user exists and workspace_id is nil (no workspace validation needed)
    - Test: succeeds when user exists and user is a member of provided workspace
    - Test: returns `{:error, :identity_unavailable}` when Identity API raises/is unreachable
    - Test: does NOT emit events when validation fails
  - Mock `IdentityApiMock` (new Mox mock to add to test_helper.exs)
  - All existing tests must continue passing (backward compatible — when no `identity_api` is injected, use the real implementation)
- [ ] ⏸ **GREEN**: Modify `apps/chat/lib/chat/application/use_cases/create_session.ex`
  - Add `@default_identity_api Chat.Infrastructure.Adapters.IdentityApiAdapter`
  - Extract `identity_api` from opts: `Keyword.get(opts, :identity_api, @default_identity_api)`
  - Before calling `session_repository.create_session(attrs)`:
    1. Call `identity_api.user_exists?(attrs.user_id)` — reject if user doesn't exist
    2. If `attrs.workspace_id` is not nil, call `identity_api.validate_workspace_access(attrs.user_id, attrs.workspace_id)` — reject if invalid
  - Use `ReferenceValidationPolicy` to interpret results
  - Return `{:error, reason}` on validation failure, skip create + event
- [ ] ⏸ **REFACTOR**: Extract validation into a private `validate_references/2` helper within the use case

### Step 1.4: Mox Mock Registration

- [ ] ⏸ **RED**: Verify that `Chat.Mocks.IdentityApiMock` can be used in tests (tests from Step 1.3 will fail without this)
- [ ] ⏸ **GREEN**: Add to `apps/chat/test/test_helper.exs`:
  ```elixir
  Mox.defmock(Chat.Mocks.IdentityApiMock,
    for: Chat.Application.Behaviours.IdentityApiBehaviour
  )
  ```
- [ ] ⏸ **REFACTOR**: Ensure mock is imported where needed

### Phase 1 Validation

- [ ] ⏸ All domain policy tests pass (milliseconds, no I/O)
- [ ] ⏸ All use case tests pass (with mocks, `ExUnit.Case, async: true`)
- [ ] ⏸ All 84 existing tests still pass
- [ ] ⏸ No boundary violations (`mix boundary`)

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### Step 2.1: IdentityApiAdapter (Infrastructure Adapter)

- [ ] ⏸ **RED**: Write test `apps/chat/test/chat/infrastructure/adapters/identity_api_adapter_test.exs`
  - Use `Chat.DataCase` (needs Identity.Repo for real user/workspace lookup)
  - Tests:
    - `user_exists?/1` returns `true` for an existing user (create via `Identity.AccountsFixtures.user_fixture()`)
    - `user_exists?/1` returns `false` for a non-existent UUID
    - `validate_workspace_access/2` returns `:ok` for a user who is a member of the workspace
    - `validate_workspace_access/2` returns `{:error, :workspace_not_found}` for a non-existent workspace
    - `validate_workspace_access/2` returns `{:error, :not_a_member}` for a user who is not a member of the workspace
- [ ] ⏸ **GREEN**: Implement `apps/chat/lib/chat/infrastructure/adapters/identity_api_adapter.ex`
  - `@behaviour Chat.Application.Behaviours.IdentityApiBehaviour`
  - `user_exists?(user_id)` — calls `Identity.get_user(user_id)`, returns `true` if non-nil
  - `validate_workspace_access(user_id, workspace_id)` — calls `Identity.member?(user_id, workspace_id)`:
    - Returns `:ok` if `true`
    - Returns `{:error, :not_a_member}` if `false`
    - Note: `Identity.member?/2` returns `false` for both "workspace doesn't exist" and "not a member". To distinguish, we can't call `Identity.MembershipRepository.workspace_exists?` (that's internal). Instead, we check with `Identity.get_user(user_id)` first (already validated), so if `member?` returns false, the workspace either doesn't exist or the user isn't a member. For the MVP, `{:error, :not_a_member}` covers both cases. If we need to distinguish, we'd add `Identity.workspace_exists?/1` to the public facade (tracked as follow-up).
- [ ] ⏸ **REFACTOR**: Add error handling for unexpected exceptions (try/rescue with `{:error, :identity_unavailable}`)

### Step 2.2: IdentityEventSubscriber (Event Handler for MemberRemoved)

- [ ] ⏸ **RED**: Write test `apps/chat/test/chat/infrastructure/subscribers/identity_event_subscriber_test.exs`
  - Use `Chat.DataCase` (needs DB for session cleanup verification)
  - Tests:
    - `handle_event/1` with `%MemberRemoved{}` deletes all chat sessions for that user+workspace
    - `handle_event/1` with `%MemberRemoved{}` for a user with no sessions in that workspace is a no-op (returns `:ok`)
    - `handle_event/1` with an unknown event struct returns `:ok` (no crash)
    - `subscriptions/0` returns the expected topic list
  - Setup: Create chat sessions via fixtures, then send `MemberRemoved` event
- [ ] ⏸ **GREEN**: Implement `apps/chat/lib/chat/infrastructure/subscribers/identity_event_subscriber.ex`
  - `use Perme8.Events.EventHandler`
  - `subscriptions/0` returns `["events:identity:workspace_member"]`
  - `handle_event(%Identity.Domain.Events.MemberRemoved{} = event)`:
    - Query sessions by `user_id = event.target_user_id AND workspace_id = event.workspace_id`
    - Delete each session (cascading to messages via DB `on_delete: :delete_all` or manual delete)
    - Wrap in `try/rescue` for DB resilience (per GithubTicketPushHandler pattern)
    - Log deletion count
  - `handle_event(_)` — catch-all returns `:ok`
- [ ] ⏸ **REFACTOR**: Extract deletion query into `Chat.Infrastructure.Queries.Queries` module

### Step 2.3: OrphanDetectionWorker (Periodic GenServer)

- [ ] ⏸ **RED**: Write test `apps/chat/test/chat/infrastructure/workers/orphan_detection_worker_test.exs`
  - Use `Chat.DataCase` (needs DB)
  - Tests:
    - Worker starts and schedules first poll
    - `handle_info(:detect_orphans, state)` detects sessions with non-existent user_ids
    - Detected orphans are deleted (or flagged, depending on strategy)
    - Worker samples a limited number of sessions (not full-table scan) — e.g., checks a random sample of 100 sessions
    - Worker handles empty sample gracefully
    - Worker handles Identity API errors gracefully (try/rescue, logs, continues)
    - Inject dependencies via opts (identity_api, session_repository, poll_interval)
  - Mock Identity API in these tests to control which users "exist"
- [ ] ⏸ **GREEN**: Implement `apps/chat/lib/chat/infrastructure/workers/orphan_detection_worker.ex`
  - `use GenServer`
  - Injectable deps: `identity_api`, `repo`, `poll_interval_ms`, `sample_size`
  - `init/1` — schedule first detection via `Process.send_after(self(), :detect_orphans, poll_interval_ms)`
  - `handle_info(:detect_orphans, state)`:
    1. Sample `sample_size` (default 100) distinct `user_id` values from `chat_sessions` using `ORDER BY RANDOM() LIMIT N`
    2. For each sampled `user_id`, call `identity_api.user_exists?(user_id)`
    3. For any non-existent user, delete all their sessions
    4. Wrap entire operation in `try/rescue` for resilience
    5. Log results: `"OrphanDetectionWorker: checked #{n} users, found #{m} orphaned, deleted #{d} sessions"`
    6. Reschedule next poll
  - Default poll interval: 5 minutes (300_000 ms) — configurable
  - Default sample size: 100
- [ ] ⏸ **REFACTOR**: Extract orphan detection query into `Queries` module. Add `@doc` and `@moduledoc`.

### Step 2.4: Orphan Detection Query Support

- [ ] ⏸ **RED**: Write test additions in `apps/chat/test/chat/infrastructure/queries/queries_test.exs`
  - Tests:
    - `sample_distinct_user_ids/1` returns up to N distinct user_ids
    - `sessions_for_user/1` returns all sessions for a given user_id
    - `sessions_for_user_and_workspace/2` returns sessions filtered by user AND workspace
    - `delete_sessions_for_user/1` deletes all sessions for a user_id
    - `delete_sessions_for_user_and_workspace/2` deletes sessions for a user+workspace pair
- [ ] ⏸ **GREEN**: Add to `apps/chat/lib/chat/infrastructure/queries/queries.ex`:
  - `sample_distinct_user_ids(limit)` — `SELECT DISTINCT user_id FROM chat_sessions ORDER BY RANDOM() LIMIT ^limit`
  - `sessions_for_user_and_workspace(user_id, workspace_id)` — filters by both user_id and workspace_id
  - `delete_sessions_for_user(user_id)` — returns a delete query for all sessions with that user_id
  - `delete_sessions_for_user_and_workspace(user_id, workspace_id)` — delete query for user+workspace
- [ ] ⏸ **REFACTOR**: Ensure all queries return queryables (not results). Callers invoke via `Repo.all/delete_all`.

### Step 2.5: Supervision Tree Updates

- [ ] ⏸ **RED**: Write test `apps/chat/test/chat/otp_app_test.exs`
  - Tests:
    - `Chat.Supervisor` starts successfully with all children
    - `IdentityEventSubscriber` is in the supervision tree
    - `OrphanDetectionWorker` is in the supervision tree
- [ ] ⏸ **GREEN**: Update `apps/chat/lib/chat/otp_app.ex`
  - Add `Chat.Infrastructure.Subscribers.IdentityEventSubscriber` to children list
  - Add `Chat.Infrastructure.Workers.OrphanDetectionWorker` to children list
  - Keep `strategy: :one_for_one`
- [ ] ⏸ **REFACTOR**: Add conditional startup for workers (e.g., skip in test env via config, or use `:enabled?` opt)

### Step 2.6: Boundary Updates

- [ ] ⏸ **RED**: Run `mix boundary` — new modules may cause violations
- [ ] ⏸ **GREEN**: Update boundary configurations:
  - `apps/chat/lib/chat/application.ex` — add `Identity` to deps (for the behaviour's type references); add `Behaviours.IdentityApiBehaviour` to exports
  - `apps/chat/lib/chat/infrastructure.ex` — add `Identity` to deps (IdentityApiAdapter calls Identity); add `Adapters.IdentityApiAdapter`, `Subscribers.IdentityEventSubscriber`, `Workers.OrphanDetectionWorker` to exports
  - `apps/chat/lib/chat/domain.ex` — add `Policies.ReferenceValidationPolicy` to exports
- [ ] ⏸ **REFACTOR**: Run `mix boundary` to confirm zero violations

### Step 2.7: Integration Tests (End-to-End Validation)

- [ ] ⏸ **RED**: Write integration tests in `apps/chat/test/chat_test.exs`
  - Add new `describe "referential integrity"` block:
    - Test: `create_session/1` succeeds with a real existing user (via `Identity.AccountsFixtures`)
    - Test: `create_session/1` fails with `{:error, :user_not_found}` for a non-existent user_id
    - Test: `create_session/1` fails when workspace_id is provided but user is not a member
    - Test: `create_session/1` succeeds when workspace_id is provided and user is a member
  - These are integration tests using `Chat.DataCase` (real DB, both repos)
- [ ] ⏸ **GREEN**: Ensure all integration tests pass with the real IdentityApiAdapter
- [ ] ⏸ **REFACTOR**: Clean up fixtures, ensure test isolation

### Phase 2 Validation

- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ All integration tests pass
- [ ] ⏸ All 84+ existing tests still pass
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test` from `apps/chat/`)
- [ ] ⏸ Pre-commit checks pass (`mix precommit`)

---

## Pre-Commit Checkpoint

- [ ] ⏸ `mix precommit` passes (compile, format, credo, boundary, tests)
- [ ] ⏸ `mix boundary` shows zero violations
- [ ] ⏸ All existing 84 tests pass
- [ ] ⏸ New tests cover all acceptance criteria

---

## File Inventory

### New Files

| File | Layer | Purpose |
|------|-------|---------|
| `apps/chat/lib/chat/application/behaviours/identity_api_behaviour.ex` | Application | Port for Identity validation calls |
| `apps/chat/lib/chat/domain/policies/reference_validation_policy.ex` | Domain | Pure validation logic for cross-app references |
| `apps/chat/lib/chat/infrastructure/adapters/identity_api_adapter.ex` | Infrastructure | Real adapter calling Identity public API |
| `apps/chat/lib/chat/infrastructure/subscribers/identity_event_subscriber.ex` | Infrastructure | EventHandler for MemberRemoved cleanup |
| `apps/chat/lib/chat/infrastructure/workers/orphan_detection_worker.ex` | Infrastructure | Periodic GenServer for defense-in-depth orphan cleanup |
| `apps/chat/test/chat/application/behaviours/identity_api_behaviour_test.exs` | Test | Behaviour compilation test |
| `apps/chat/test/chat/domain/policies/reference_validation_policy_test.exs` | Test | Pure policy tests |
| `apps/chat/test/chat/infrastructure/adapters/identity_api_adapter_test.exs` | Test | Integration test for adapter |
| `apps/chat/test/chat/infrastructure/subscribers/identity_event_subscriber_test.exs` | Test | Event handler tests |
| `apps/chat/test/chat/infrastructure/workers/orphan_detection_worker_test.exs` | Test | Worker tests |
| `apps/chat/test/chat/otp_app_test.exs` | Test | Supervision tree tests |

### Modified Files

| File | Change |
|------|--------|
| `apps/chat/lib/chat/application/use_cases/create_session.ex` | Add referential integrity validation before create |
| `apps/chat/lib/chat/infrastructure/queries/queries.ex` | Add orphan detection and cleanup queries |
| `apps/chat/lib/chat/otp_app.ex` | Add IdentityEventSubscriber and OrphanDetectionWorker to supervision tree |
| `apps/chat/lib/chat/application.ex` | Update boundary deps and exports |
| `apps/chat/lib/chat/infrastructure.ex` | Update boundary deps and exports |
| `apps/chat/lib/chat/domain.ex` | Update boundary exports |
| `apps/chat/test/test_helper.exs` | Add IdentityApiMock Mox definition |
| `apps/chat/test/chat/application/use_cases/create_session_test.exs` | Add validation rejection tests |
| `apps/chat/test/chat/infrastructure/queries/queries_test.exs` | Add orphan query tests |
| `apps/chat/test/chat_test.exs` | Add integration tests for referential integrity |

---

## Testing Strategy

- **Total estimated new tests**: ~30-35
- **Distribution**:
  - Domain (pure policy): 8-10 tests (milliseconds, `ExUnit.Case, async: true`)
  - Application (use case with mocks): 7-8 tests (`ExUnit.Case, async: true`)
  - Infrastructure (adapter, subscriber, worker): 12-15 tests (`Chat.DataCase`)
  - Integration (facade-level): 4-5 tests (`Chat.DataCase`)
- **Existing tests**: 84 tests must continue passing
- **Expected total after**: ~115-120 tests

### Test Pattern Summary

| Component | Test Case | Base | Async? |
|-----------|-----------|------|--------|
| ReferenceValidationPolicy | Pure function tests | `ExUnit.Case` | ✅ |
| CreateSession (validation) | Mox-based unit tests | `ExUnit.Case` | ✅ |
| IdentityApiAdapter | Real DB integration | `Chat.DataCase` | ✅ |
| IdentityEventSubscriber | Real DB + event structs | `Chat.DataCase` | ❌ (shared repos) |
| OrphanDetectionWorker | GenServer + Mox | `Chat.DataCase` | ✅ |
| Queries (orphan) | Real DB queries | `Chat.DataCase` | ✅ |
| ChatTest integration | End-to-end facade | `Chat.DataCase` | ✅ |

### Domain Event Testing Rule Compliance

All use case tests that emit domain events **inject TestEventBus** via opts:
- Existing pattern: `event_bus: TestEventBus, event_bus_opts: [name: bus_name]`
- New tests follow the same pattern — named TestEventBus instances per test
- IdentityEventSubscriber tests use `Chat.DataCase` and create sessions via direct repo insert (not via use cases that emit events), avoiding TestEventBus requirements in subscriber tests

---

## Acceptance Criteria Mapping

| AC# | Description | Covered By |
|-----|-------------|-----------|
| 1 | CreateSession validates user exists | Step 1.3 (use case), Step 2.1 (adapter), Step 2.7 (integration) |
| 2 | CreateSession validates workspace exists | Step 1.3 (use case), Step 2.1 (adapter), Step 2.7 (integration) |
| 3 | Proper error tuples for invalid references | Step 1.2 (policy), Step 1.3 (use case tests) |
| 4 | Domain event subscriber handles deletion events | Step 2.2 (IdentityEventSubscriber) |
| 5 | Periodic orphan detection job | Step 2.3 (OrphanDetectionWorker) |
| 6 | Reliable event emission for SaveMessage/DeleteSession | **Deferred** — see note below |
| 7 | All 84 existing tests pass | Phase 1 + Phase 2 validation checkpoints |
| 8 | New tests cover validation rejection + orphan cleanup | All new test files |

### AC#6 Note: Reliable Event Emission

After thorough analysis, the current SaveMessage and DeleteSession implementations already emit events **after** the DB operation succeeds (not inside a transaction callback). The risk of "silent event loss on process crash between DB write and emit" exists but is inherent to any two-phase operation without a transactional outbox pattern.

Options for true reliability:
1. **Transactional outbox** — Write events to an `outbox` table inside the same transaction, then a separate worker polls and publishes. This is a significant infrastructure addition.
2. **Ecto.Multi + post-transaction emit** — The current pattern. DB write is committed; if the process crashes before emit, the event is lost but data is consistent.

**Recommendation**: Accept option (2) as-is for this ticket. The current pattern is consistent with all other apps in the umbrella (agents, jarga, identity). A transactional outbox pattern should be a separate infrastructure-level ticket if needed. Mark AC#6 as "accepted risk — consistent with codebase patterns" in the ticket.

---

## Follow-Up Issues (Out of Scope)

1. **Identity: Add `UserDeleted` and `WorkspaceDeleted` domain events** — The IdentityEventSubscriber is built to handle `MemberRemoved` but cannot react to full user/workspace deletion until Identity emits those events.
2. **Identity: Add `workspace_exists?/1` to public facade** — Currently `Identity.member?/2` returns `false` for both "workspace doesn't exist" and "user is not a member". A dedicated existence check would improve error specificity.
3. **Transactional outbox pattern** — If guaranteed event delivery is required, implement an outbox table + publisher worker as shared infrastructure in `perme8_events`.
4. **Project validation** — `project_id` is also a cross-app reference but Jarga project validation is not in scope for this ticket. Similar pattern can be applied later.

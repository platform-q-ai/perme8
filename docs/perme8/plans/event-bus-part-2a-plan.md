# Feature: Convert Cross-App Subscribers to EventHandlers (Event Bus Part 2a)

## Status: ⏸ Not Started
## Ticket: #133
## Date: 2026-02-19

---

## Overview

Phase 4 of the Event Bus migration. Phases 1-3 (Part 1, PR #131) established the event infrastructure, 27 domain event structs, and migrated all use cases to emit structured events via `EventBus`. However, the **identity app** still has no domain event structs and the lone cross-app subscriber (`WorkspaceInvitationSubscriber`) still uses legacy PubSub tuple matching.

This plan:
1. Creates the first identity domain event struct (`MemberInvited`)
2. Updates identity use cases to emit structured events alongside legacy PubSub
3. Converts `WorkspaceInvitationSubscriber` from a raw GenServer to an `EventHandler`
4. Adds `LegacyBridge` translation for the new event
5. Updates boundary configs, supervision tree, and event type uniqueness test

**Value**: Demonstrates the subscriber-to-EventHandler migration pattern. Once complete, every future subscriber conversion follows the same recipe.

## UI Strategy

- **LiveView coverage**: 100% — no UI changes
- **TypeScript needed**: None — purely backend infrastructure

## Affected Boundaries

- **Primary contexts**: `Identity` (new event struct + use case emission), `Jarga.Notifications.Infrastructure` (subscriber conversion)
- **Dependencies**: `Perme8.Events` (EventHandler behaviour, EventBus, DomainEvent macro)
- **Exported schemas**: `Identity.Domain.Events.MemberInvited` must be exported from `Identity` boundary
- **New context needed?**: No — extends existing contexts

## Dependency Impact

```
identity (adds MemberInvited event struct, use cases emit via EventBus)
  ^
  |
jarga (WorkspaceInvitationSubscriber converts to EventHandler,
       LegacyBridge gets new translation,
       event type uniqueness test updated)
```

The identity app's `InviteMember` and `CreateNotificationsForPendingInvitations` use cases will need `Perme8.Events.EventBus` as a dependency. Since `Perme8.Events.DomainEvent` already lives in the identity app (with `check: [in: false]`), the event struct itself has no dependency issues. The `EventBus` module lives in `jarga`, but identity use cases inject it via `opts[:event_bus]` — the identity app doesn't compile-time depend on `jarga`. The default value `@default_event_bus Perme8.Events.EventBus` will need the jarga app available at runtime (which it already is).

**Important**: The `Perme8.Events.EventBus` module is in the `jarga` app. Identity use cases reference it as a default value via `@default_event_bus`. This works at runtime because `jarga` is started after `identity` in the umbrella. In tests, `TestEventBus` is injected via `opts[:event_bus]`, so there's no compile-time dependency issue.

---

## Phase 1: Domain Event Struct (Identity) ✓

**Goal**: Create the `MemberInvited` domain event struct in the identity app.
**Commit message**: `feat(events): add Identity.Domain.Events.MemberInvited event struct`

### 1.1 MemberInvited Event Struct

- [x] ✓ **RED**: Write test `apps/identity/test/identity/domain/events/member_invited_test.exs`
  - Tests:
    - `event_type/0` returns `"identity.member_invited"` (DomainEvent macro derives from `Identity.Domain.Events.MemberInvited`)
    - `aggregate_type/0` returns `"workspace_member"`
    - `new/1` creates event with auto-generated `event_id` and `occurred_at`
    - Required fields enforced: `user_id`, `workspace_id`, `workspace_name`, `invited_by_name`, `role`
    - Base required fields enforced: `aggregate_id`, `actor_id`
    - `workspace_id` is NOT nil (it's a required custom field here, even though base `workspace_id` is optional)
    - `metadata` defaults to `%{}`
    - Raises `ArgumentError` when required fields are missing
  - Test module pattern: `use ExUnit.Case, async: true` (pure struct, no I/O)

- [x] ✓ **GREEN**: Implement `apps/identity/lib/identity/domain/events/member_invited.ex`
  ```elixir
  defmodule Identity.Domain.Events.MemberInvited do
    @moduledoc """
    Domain event emitted when a member is invited to a workspace.

    Emitted by `InviteMember` and `CreateNotificationsForPendingInvitations`
    use cases after the invitation is created and notification broadcast occurs.
    """

    use Perme8.Events.DomainEvent,
      aggregate_type: "workspace_member",
      fields: [
        user_id: nil,
        workspace_id: nil,
        workspace_name: nil,
        invited_by_name: nil,
        role: nil
      ],
      required: [:user_id, :workspace_id, :workspace_name, :invited_by_name, :role]
  end
  ```
  **Note**: The field `workspace_id` is declared both as a base field (optional, in the DomainEvent macro) and as a custom field. The custom field declaration overrides the base default (`nil`) but does NOT add it to enforce_keys twice since the macro concatenates `base_required ++ custom_required`. The base `workspace_id` field allows the event to carry `workspace_id` for topic derivation (`events:workspace:{id}`). Listing it in `:required` ensures it's in `@enforce_keys`. Since `defstruct` handles duplicate keys by taking the last value, and the custom fields come after base fields, the custom `workspace_id: nil` will be the one used. However, to avoid potential confusion, verify that the macro produces the correct struct by running the test.

- [x] ✓ **REFACTOR**: Ensure field naming matches the existing `PubSubNotifier.broadcast_invitation_created/5` params exactly

### 1.2 Update Identity Boundary to Export MemberInvited

- [x] ✓ **UPDATE**: `apps/identity/lib/identity.ex`
  - Add `Domain.Events.MemberInvited` to the `exports` list in the `use Boundary` call
  - This allows `jarga` (the subscriber / LegacyBridge) to import and pattern-match on the event struct

### 1.3 Update Event Type Uniqueness Test

- [x] ✓ **RED**: Update `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs`
  - Add `Identity.Domain.Events.MemberInvited` to `@all_event_modules` list
  - Update count assertion from 27 to 28
  - Test should fail initially since the module doesn't exist yet — run test AFTER creating the struct

- [x] ✓ **GREEN**: The struct from step 1.1 satisfies the uniqueness test

- [x] ✓ **REFACTOR**: Add comment section `# Identity (1)` to group the new event

### Phase 1 Validation

- [x] ✓ All event struct tests pass: `mix test apps/identity/test/identity/domain/events/`
- [x] ✓ Event type uniqueness test passes: `mix test apps/jarga/test/perme8_events/event_type_uniqueness_test.exs`
- [x] ✓ `mix boundary` passes — MemberInvited properly exported
- [x] ✓ No changes to existing use cases or notifiers yet

---

## Phase 2: Identity Use Case Migration

**Goal**: Update `InviteMember` and `CreateNotificationsForPendingInvitations` to emit `MemberInvited` events alongside existing PubSub broadcasts.
**Commit message**: `feat(events): identity use cases emit MemberInvited event`

### 2.1 Update InviteMember Use Case

- [ ] ⏸ **RED**: Write/update test `apps/identity/test/identity/application/use_cases/invite_member_test.exs`
  - New test: `"emits MemberInvited event via event_bus for existing users"` — inject `TestEventBus` via `opts[:event_bus]`, assert `MemberInvited` event with correct fields
  - New test: `"does not emit MemberInvited event for non-existing users"` — when the invitee is not an existing user, no PubSub notification is sent, so no event should be emitted either
  - Existing tests: continue passing unchanged (notifier/pubsub_notifier mocks still work)
  - Pattern:
    ```elixir
    test "emits MemberInvited event via event_bus for existing users" do
      {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      invitee = user_fixture()

      params = %{
        inviter: owner,
        workspace_id: workspace.id,
        email: invitee.email,
        role: :admin
      }

      opts = [
        notifier: MockNotifier,
        event_bus: Perme8.Events.TestEventBus
      ]

      assert {:ok, {:invitation_sent, _}} = InviteMember.execute(params, opts)
      events = Perme8.Events.TestEventBus.get_events()
      assert [%Identity.Domain.Events.MemberInvited{} = event] = events
      assert event.user_id == invitee.id
      assert event.workspace_id == workspace.id
      assert event.workspace_name == workspace.name
      assert event.role == "admin"
    end
    ```

- [ ] ⏸ **GREEN**: Update `apps/identity/lib/identity/application/use_cases/invite_member.ex`
  - Add `@default_event_bus Perme8.Events.EventBus`
  - Extract `event_bus = Keyword.get(opts, :event_bus, @default_event_bus)` in `execute/2`
  - Pass `event_bus` through to `create_pending_invitation/9` and then to `maybe_create_notification/6`
  - In `maybe_create_notification/6` (the non-nil user clause), AFTER the `pubsub_notifier.broadcast_invitation_created(...)` call, emit the structured event:
    ```elixir
    event = Identity.Domain.Events.MemberInvited.new(%{
      aggregate_id: "#{workspace.id}:#{user.id}",
      actor_id: inviter.id,
      user_id: user.id,
      workspace_id: workspace.id,
      workspace_name: workspace.name,
      invited_by_name: inviter_name,
      role: to_string(role)
    })
    event_bus.emit(event)
    ```
  - **Keep** the `pubsub_notifier.broadcast_invitation_created(...)` call — it will be removed when all consumers have migrated

- [ ] ⏸ **REFACTOR**: Clean up, ensure event is emitted AFTER transaction commits (it already is — `maybe_create_notification` is called after `Repo.transact`)

### 2.2 Update CreateNotificationsForPendingInvitations Use Case

- [ ] ⏸ **RED**: Write/update test `apps/identity/test/identity/application/use_cases/create_notifications_for_pending_invitations_test.exs`
  - New test: `"emits MemberInvited events for each pending invitation"` — inject `TestEventBus`, create user with pending invitations, assert events emitted
  - If the test file doesn't exist yet, create it with proper setup using `Identity.DataCase`
  - Pattern:
    ```elixir
    test "emits MemberInvited events via event_bus" do
      {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
      # ... setup user with pending invitations ...

      opts = [
        pubsub_notifier: MockPubSubNotifier,
        event_bus: Perme8.Events.TestEventBus
      ]

      {:ok, _} = CreateNotificationsForPendingInvitations.execute(%{user: user}, opts)
      events = Perme8.Events.TestEventBus.get_events()
      assert length(events) == expected_count
      assert Enum.all?(events, &match?(%Identity.Domain.Events.MemberInvited{}, &1))
    end
    ```

- [ ] ⏸ **GREEN**: Update `apps/identity/lib/identity/application/use_cases/create_notifications_for_pending_invitations.ex`
  - Add `@default_event_bus Perme8.Events.EventBus`
  - Extract `event_bus = Keyword.get(opts, :event_bus, @default_event_bus)` in `execute/2`
  - In `broadcast_invitation_notification/3` (or after the `Enum.each` loop), emit a `MemberInvited` event for each invitation:
    ```elixir
    defp broadcast_invitation_notification(user, invitation_schema, pubsub_notifier, event_bus) do
      inviter_name = get_inviter_name(invitation_schema.inviter)

      pubsub_notifier.broadcast_invitation_created(
        user.id,
        invitation_schema.workspace_id,
        invitation_schema.workspace.name,
        inviter_name,
        to_string(invitation_schema.role)
      )

      event = Identity.Domain.Events.MemberInvited.new(%{
        aggregate_id: "#{invitation_schema.workspace_id}:#{user.id}",
        actor_id: invitation_schema.invited_by || user.id,
        user_id: user.id,
        workspace_id: invitation_schema.workspace_id,
        workspace_name: invitation_schema.workspace.name,
        invited_by_name: inviter_name,
        role: to_string(invitation_schema.role)
      })
      event_bus.emit(event)
    end
    ```
  - Update the `Enum.each` call in `execute/2` to pass `event_bus` as 4th argument

- [ ] ⏸ **REFACTOR**: Clean up parameter threading

### Phase 2 Validation

- [ ] ⏸ All identity use case tests pass: `mix test apps/identity/test/identity/application/use_cases/`
- [ ] ⏸ `mix boundary` passes
- [ ] ⏸ Existing subscriber test still passes (it receives legacy PubSub tuples from the unchanged `PubSubNotifier`)

---

## Phase 3: LegacyBridge Translation

**Goal**: Add a `translate/1` clause for `MemberInvited` so the EventBus can also broadcast on the legacy `"workspace_invitations"` topic for backward compat during migration.
**Commit message**: `feat(events): add LegacyBridge translation for Identity.Domain.Events.MemberInvited`

### 3.1 LegacyBridge Translation for MemberInvited

- [ ] ⏸ **RED**: Write test in `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs`
  - New test: `"translates MemberInvited to legacy workspace_invitations tuple"`
    ```elixir
    test "translates MemberInvited to legacy workspace_invitations tuple" do
      event = Identity.Domain.Events.MemberInvited.new(%{
        aggregate_id: "ws-123:user-456",
        actor_id: "inviter-789",
        user_id: "user-456",
        workspace_id: "ws-123",
        workspace_name: "Test Workspace",
        invited_by_name: "John Doe",
        role: "member"
      })

      translations = LegacyBridge.translate(event)

      assert [
        {"workspace_invitations",
         {:workspace_invitation_created,
          %{
            user_id: "user-456",
            workspace_id: "ws-123",
            workspace_name: "Test Workspace",
            invited_by_name: "John Doe",
            role: "member"
          }}}
      ] = translations
    end
    ```

- [ ] ⏸ **GREEN**: Update `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex`
  - Add translation clause BEFORE the catch-all:
    ```elixir
    # --- Identity Context ---

    def translate(%Identity.Domain.Events.MemberInvited{} = event) do
      [
        {"workspace_invitations",
         {:workspace_invitation_created,
          %{
            user_id: event.user_id,
            workspace_id: event.workspace_id,
            workspace_name: event.workspace_name,
            invited_by_name: event.invited_by_name,
            role: event.role
          }}}
      ]
    end
    ```

- [ ] ⏸ **REFACTOR**: Verify the translation produces EXACTLY the same tuple/map shape that `PubSubNotifier.broadcast_invitation_created/5` currently produces

### 3.2 Update LegacyBridge Boundary Dependencies

- [ ] ⏸ **UPDATE**: Check if `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex` or its parent boundary needs `Identity` added to deps
  - The LegacyBridge already pattern-matches on `Jarga.*` and `Agents.*` event modules
  - Adding `Identity.Domain.Events.MemberInvited` pattern-match requires `Identity` in the boundary deps
  - The `Perme8.Events` boundary module at `apps/jarga/lib/perme8_events.ex` may need `Identity` in its deps list, OR the `Infrastructure.LegacyBridge` may be in a sub-boundary
  - Check current boundary config and update accordingly

### Phase 3 Validation

- [ ] ⏸ LegacyBridge tests pass: `mix test apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs`
- [ ] ⏸ `mix boundary` passes
- [ ] ⏸ Dual-publish verified: both legacy PubSub AND structured events work

---

## Phase 4: Convert WorkspaceInvitationSubscriber to EventHandler ✓

**Goal**: Convert the subscriber from a raw GenServer to an EventHandler that receives structured `MemberInvited` events.
**Commit message**: `feat(events): convert WorkspaceInvitationSubscriber to EventHandler`

### 4.1 Update WorkspaceInvitationSubscriber Implementation

- [x] ✓ **RED**: Update test `apps/jarga/test/notifications/infrastructure/workspace_invitation_subscriber_test.exs`
  - Replace tuple-based event sending with structured `MemberInvited` event:
    ```elixir
    test "creates notification when MemberInvited event is received" do
      {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
      Sandbox.allow(Repo, self(), pid)

      user = user_fixture()
      workspace_id = Ecto.UUID.generate()

      event = Identity.Domain.Events.MemberInvited.new(%{
        aggregate_id: "#{workspace_id}:#{user.id}",
        actor_id: Ecto.UUID.generate(),
        user_id: user.id,
        workspace_id: workspace_id,
        workspace_name: "Test Workspace",
        invited_by_name: "Test Inviter",
        role: "member"
      })

      # Send structured event (EventHandler routes structs to handle_event/1)
      send(pid, event)

      :timer.sleep(50)

      notifications = Notifications.list_notifications(user.id)
      assert length(notifications) == 1

      notification = hd(notifications)
      assert notification.type == "workspace_invitation"
      assert notification.data["workspace_id"] == workspace_id
      assert notification.data["workspace_name"] == "Test Workspace"
    end
    ```
  - Update `"handles unknown messages gracefully"` test — now non-struct messages are handled by EventHandler's catch-all `handle_info/2` which logs debug and returns `:noreply`
  - Add new test: `"ignores non-MemberInvited events"` — send a different event struct (e.g., `NotificationCreated`) and verify no notification is created
  - Tests should initially FAIL because the subscriber still uses the old GenServer pattern

- [x] ✓ **GREEN**: Rewrite `apps/jarga/lib/notifications/infrastructure/subscribers/workspace_invitation_subscriber.ex`
  ```elixir
  defmodule Jarga.Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber do
    @moduledoc """
    EventHandler that listens for workspace invitation events
    and creates corresponding notifications.

    Subscribes to identity context events and reacts to MemberInvited
    events by creating workspace invitation notifications via the
    CreateWorkspaceInvitationNotification use case.

    ## Migration Note

    Converted from a raw GenServer (legacy PubSub tuple subscriber) to an
    EventHandler (structured domain event handler) as part of Event Bus Part 2a.
    """

    use Perme8.Events.EventHandler

    alias Identity.Domain.Events.MemberInvited

    @default_create_notification_use_case Jarga.Notifications.Application.UseCases.CreateWorkspaceInvitationNotification

    @impl Perme8.Events.EventHandler
    def subscriptions do
      [
        "events:identity",
        "events:identity:workspace_member"
      ]
    end

    @impl Perme8.Events.EventHandler
    def handle_event(%MemberInvited{} = event) do
      use_case = get_use_case()

      params = %{
        user_id: event.user_id,
        workspace_id: event.workspace_id,
        workspace_name: event.workspace_name,
        invited_by_name: event.invited_by_name,
        role: event.role
      }

      case use_case.execute(params) do
        {:ok, _notification} ->
          Logger.debug("Created notification for workspace invitation: #{event.workspace_id}")
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl Perme8.Events.EventHandler
    def handle_event(_event), do: :ok

    defp get_use_case do
      # Extract use case from opts stored in GenServer state
      # The EventHandler stores opts in %{opts: opts}
      # However, GenServer.call(self(), ...) would deadlock.
      # Instead, use the module attribute default.
      # DI is handled by overriding start_link to store the use_case
      # in the process dictionary or using Application.get_env.
      @default_create_notification_use_case
    end
  end
  ```

  **DI Strategy Decision**: The existing subscriber passes `use_case` via init state (`%{use_case: use_case}`). The EventHandler macro sets state to `%{opts: opts}`. We have two options:

  **Option A (Simpler)**: Drop runtime DI for the use case. Use `@default_create_notification_use_case` directly. The subscriber test already starts the subscriber with `start_link([])` and uses the real `CreateWorkspaceInvitationNotification` use case. Tests inject dependencies into the use case itself (e.g., `notification_repository`, `notifier`), not into the subscriber.

  **Option B (Preserve DI)**: Override `start_link/1` to accept `opts[:create_notification_use_case]` and store it. Access via `GenServer.call(self(), :get_state)` — but this deadlocks in `handle_event` since we're already in the GenServer process.

  **Decision**: Go with **Option A**. The subscriber test already uses the real use case. DI is better handled at the use case level. If needed later, the use case module can be stored in the process dictionary during init.

  **Alternative for DI preservation**: Override `init/1` to store the use case in the process dictionary:
  ```elixir
  defoverridable init: 1

  @impl GenServer
  def init(opts) do
    use_case = Keyword.get(opts, :create_notification_use_case, @default_create_notification_use_case)
    Process.put(:create_notification_use_case, use_case)
    super(opts)
  end

  defp get_use_case do
    Process.get(:create_notification_use_case, @default_create_notification_use_case)
  end
  ```

  Use this alternative ONLY if tests specifically need to inject a mock use case. Given the existing test pattern, Option A is preferred.

- [x] ✓ **REFACTOR**: Clean up, verify Logger is available (EventHandler macro includes `require Logger`)

### 4.2 Update Notifications Infrastructure Boundary

- [x] ✓ **UPDATE**: `apps/jarga/lib/notifications/infrastructure.ex`
  - Add `Perme8.Events` to `deps` list (for `EventHandler` behaviour)
  - `Identity` already in `deps` list (for `Identity.Domain.Events.MemberInvited` pattern matching)
  - Verified no circular dependencies — `mix compile --warnings-as-errors` passes clean

### 4.3 Update Supervision Tree

- [x] ✓ **UPDATE**: `apps/jarga/lib/application.ex`
  - The `pubsub_subscribers/0` function currently returns `[WorkspaceInvitationSubscriber]`
  - The EventHandler macro generates `child_spec/1` that accepts opts and defaults `start_link([])` — so `WorkspaceInvitationSubscriber` as a bare module name still works (Supervisor calls `child_spec/1` with `[]`)
  - **No change needed** if using Option A (no DI). The existing entry works because:
    1. Supervisor sees `WorkspaceInvitationSubscriber` (a module)
    2. Calls `WorkspaceInvitationSubscriber.child_spec([])`
    3. EventHandler's `child_spec/1` returns `%{start: {__MODULE__, :start_link, [[]]}}`
    4. `start_link([])` starts the GenServer, `init([])` subscribes to topics
  - **Optional**: Rename the function from `pubsub_subscribers/0` to `event_handlers/0` to reflect the new pattern (deferred to a follow-up chore)

### 4.4 Update DataCase Test Support

- [x] ✓ **UPDATE**: `apps/jarga/test/support/data_case.ex`
  - The `enable_pubsub_subscribers/0` function references `WorkspaceInvitationSubscriber.start_link([])`
  - This still works with the EventHandler-based subscriber since `start_link/1` accepts `opts`
  - **No change needed** — the call signature is compatible
  - Verify by running integration tests

### Phase 4 Validation

- [x] ✓ Subscriber test passes: `mix test apps/jarga/test/notifications/infrastructure/workspace_invitation_subscriber_test.exs`
- [x] ✓ `mix boundary` passes (verified via `mix compile --warnings-as-errors`)
- [x] ✓ Existing integration tests still pass — all 85 notification tests pass, full jarga suite 943/945 pass (2 pre-existing ERM-related failures unrelated to this change)

---

## Phase 5: Dual-Publish Deduplication Prevention

**Goal**: Ensure that when `InviteMember` emits `MemberInvited` AND calls `pubsub_notifier.broadcast_invitation_created(...)`, the subscriber doesn't create duplicate notifications. The EventBus emits to `events:identity:workspace_member`, and the LegacyBridge also broadcasts to `"workspace_invitations"`. Since the subscriber now listens on `events:identity:workspace_member` (NOT `"workspace_invitations"`), there's no double-delivery issue.
**Commit message**: `feat(events): verify no duplicate notifications during dual-publish period`

### 5.1 Verify No Duplicate Delivery

- [ ] ⏸ **ANALYSIS**: Confirm that the converted subscriber subscribes to `events:identity` and `events:identity:workspace_member` (structured event topics), NOT `"workspace_invitations"` (legacy topic).
  - The LegacyBridge translates `MemberInvited` → broadcasts to `"workspace_invitations"`, but NO handler listens there anymore (the subscriber was converted)
  - The identity use case calls BOTH:
    1. `pubsub_notifier.broadcast_invitation_created(...)` → broadcasts to `"workspace_invitations"` → NO handler (subscriber was converted away from this topic)
    2. `event_bus.emit(event)` → broadcasts to `events:identity`, `events:identity:workspace_member`, `events:workspace:{wid}` → subscriber handles it
  - The EventBus also calls `LegacyBridge.broadcast_legacy(event)` → broadcasts to `"workspace_invitations"` → NO handler
  - **Result**: Two broadcasts to `"workspace_invitations"` (one from PubSubNotifier, one from LegacyBridge), but nothing listens there anymore. One delivery via `events:identity:workspace_member` to the subscriber. **No duplicates**.

- [ ] ⏸ **RED**: Write integration test `apps/jarga/test/notifications/infrastructure/workspace_invitation_subscriber_integration_test.exs`
  - Tag with `@tag :integration`
  - Test the full flow: emit a `MemberInvited` event via the real `EventBus`, verify exactly ONE notification is created
  - Use `Jarga.DataCase, async: false` with integration setup
  ```elixir
  @tag :integration
  test "creates exactly one notification when MemberInvited is emitted via EventBus" do
    user = user_fixture()
    workspace_id = Ecto.UUID.generate()

    event = Identity.Domain.Events.MemberInvited.new(%{
      aggregate_id: "#{workspace_id}:#{user.id}",
      actor_id: Ecto.UUID.generate(),
      user_id: user.id,
      workspace_id: workspace_id,
      workspace_name: "Test Workspace",
      invited_by_name: "Test Inviter",
      role: "member"
    })

    Perme8.Events.EventBus.emit(event)

    # Wait for async processing
    :timer.sleep(100)

    notifications = Notifications.list_notifications(user.id)
    assert length(notifications) == 1
  end
  ```

- [ ] ⏸ **GREEN**: No code change needed — the architecture naturally prevents duplicates

- [ ] ⏸ **REFACTOR**: Add comments in `InviteMember` explaining the dual-publish is safe during migration

### Phase 5 Validation

- [ ] ⏸ Integration test passes
- [ ] ⏸ No duplicate notifications in any test scenario

---

## Phase 6: Remove Legacy PubSub from Identity Use Cases (Optional — can defer)

**Goal**: Since the subscriber no longer listens on `"workspace_invitations"`, and the LegacyBridge handles backward compat for any OTHER consumers on that topic, we can optionally remove the `pubsub_notifier` calls from identity use cases NOW if no other consumers exist on `"workspace_invitations"`.

**Decision**: **DEFER** this to a separate ticket. The dual-publish is harmless (broadcasts to a topic with no listeners) and removing it now adds risk. Mark as a follow-up for when the full legacy bridge removal happens in Part 2b+.

---

## Pre-Commit Checkpoint

- [ ] ⏸ `mix precommit` passes (compile + format + credo + boundary + tests)
- [ ] ⏸ `mix boundary` explicitly verified — no violations
- [ ] ⏸ Full test suite passes: `mix test`
- [ ] ⏸ Event type uniqueness test includes all 28 events
- [ ] ⏸ WorkspaceInvitationSubscriber uses EventHandler pattern
- [ ] ⏸ LegacyBridge translates MemberInvited correctly
- [ ] ⏸ No duplicate notifications during dual-publish period

---

## Testing Strategy

### Test Distribution

| Category | Count | Location | Async? |
|----------|-------|----------|--------|
| MemberInvited event struct | ~3 | `apps/identity/test/identity/domain/events/member_invited_test.exs` | Yes |
| InviteMember event emission | ~2 | `apps/identity/test/identity/application/use_cases/invite_member_test.exs` | Yes |
| CreateNotificationsForPendingInvitations event emission | ~1 | `apps/identity/test/identity/application/use_cases/create_notifications_for_pending_invitations_test.exs` | Varies |
| LegacyBridge MemberInvited translation | ~1 | `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs` | Yes |
| WorkspaceInvitationSubscriber (converted) | ~3 | `apps/jarga/test/notifications/infrastructure/workspace_invitation_subscriber_test.exs` | No |
| Integration test (no duplicates) | ~1 | `apps/jarga/test/notifications/infrastructure/workspace_invitation_subscriber_integration_test.exs` | No |
| Event type uniqueness (updated) | ~0 (existing tests, updated list) | `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs` | Yes |
| **Total new/modified tests** | **~11** | | |

### Test Patterns

**Event struct tests** (async: true, pure):
```elixir
defmodule Identity.Domain.Events.MemberInvitedTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Events.MemberInvited

  @valid_attrs %{
    aggregate_id: "ws-123:user-456",
    actor_id: "inviter-789",
    user_id: "user-456",
    workspace_id: "ws-123",
    workspace_name: "Test Workspace",
    invited_by_name: "John Doe",
    role: "member"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert MemberInvited.event_type() == "identity.member_invited"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert MemberInvited.aggregate_type() == "workspace_member"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = MemberInvited.new(@valid_attrs)
      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "identity.member_invited"
      assert event.aggregate_type == "workspace_member"
      assert event.user_id == "user-456"
      assert event.workspace_id == "ws-123"
      assert event.workspace_name == "Test Workspace"
      assert event.invited_by_name == "John Doe"
      assert event.role == "member"
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        MemberInvited.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
```

**Use case event emission tests** (with TestEventBus):
```elixir
test "emits MemberInvited event via event_bus" do
  {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
  # ... setup ...
  {:ok, {:invitation_sent, _}} = InviteMember.execute(params, event_bus: TestEventBus)
  assert [%MemberInvited{} = event] = TestEventBus.get_events()
  assert event.user_id == invitee.id
end
```

**LegacyBridge translation tests** (async: true, pure):
```elixir
test "translates MemberInvited to legacy tuple" do
  event = MemberInvited.new(%{...})
  translations = LegacyBridge.translate(event)
  assert [{"workspace_invitations", {:workspace_invitation_created, params}}] = translations
  assert params.user_id == "user-456"
end
```

**EventHandler subscriber tests** (async: false, PubSub):
```elixir
test "creates notification when MemberInvited event is received" do
  {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
  Sandbox.allow(Repo, self(), pid)
  event = MemberInvited.new(%{...})
  send(pid, event)  # EventHandler routes struct to handle_event/1
  :timer.sleep(50)
  assert length(Notifications.list_notifications(user.id)) == 1
end
```

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| MemberInvited event lives in `identity` domain | Identity owns the invitation concept. The event struct uses `DomainEvent` macro which is already in the identity app. |
| `aggregate_type: "workspace_member"` | The invitation creates a `workspace_member` record. This maps to the `WorkspaceMember` entity. |
| `event_type: "identity.member_invited"` derived from module name | Consistent with all 27 existing events. Auto-derived by `DomainEvent.derive_event_type/1`. |
| Subscriber subscribes to `events:identity` and `events:identity:workspace_member` | Follows EventBus topic derivation: context topic + context:aggregate topic. The subscriber will receive ALL identity events but only handles `MemberInvited`. |
| Drop use case DI from subscriber (Option A) | The existing test already uses the real use case. DI is properly handled at the use case layer (inject `notification_repository`, `notifier`, `event_bus`). |
| Keep `pubsub_notifier` calls during migration | Harmless broadcasts to `"workspace_invitations"` with no listeners. Will be cleaned up in a future ticket. |
| LegacyBridge translation produces exact legacy tuple | Ensures backward compat if any other (unknown) consumer still listens on `"workspace_invitations"`. |
| No supervision tree changes needed | EventHandler's `child_spec/1` is compatible with the existing bare module name in the children list. |

---

## File Summary

### New Files

| File | Purpose |
|------|---------|
| `apps/identity/lib/identity/domain/events/member_invited.ex` | `MemberInvited` domain event struct |
| `apps/identity/test/identity/domain/events/member_invited_test.exs` | Event struct tests |
| `apps/jarga/test/notifications/infrastructure/workspace_invitation_subscriber_integration_test.exs` | Integration test for no-duplicate verification |

### Modified Files

| File | Change |
|------|--------|
| `apps/identity/lib/identity.ex` | Add `Domain.Events.MemberInvited` to boundary exports |
| `apps/identity/lib/identity/application/use_cases/invite_member.ex` | Add `event_bus` injection, emit `MemberInvited` event for existing users |
| `apps/identity/lib/identity/application/use_cases/create_notifications_for_pending_invitations.ex` | Add `event_bus` injection, emit `MemberInvited` event per pending invitation |
| `apps/identity/test/identity/application/use_cases/invite_member_test.exs` | Add tests for event emission |
| `apps/identity/test/identity/application/use_cases/create_notifications_for_pending_invitations_test.exs` | Add tests for event emission (create if doesn't exist) |
| `apps/jarga/lib/perme8_events/infrastructure/legacy_bridge.ex` | Add `MemberInvited` → legacy tuple translation |
| `apps/jarga/test/perme8_events/infrastructure/legacy_bridge_test.exs` | Add translation test |
| `apps/jarga/lib/notifications/infrastructure/subscribers/workspace_invitation_subscriber.ex` | Convert from `use GenServer` to `use Perme8.Events.EventHandler` |
| `apps/jarga/test/notifications/infrastructure/workspace_invitation_subscriber_test.exs` | Update to send structured events instead of tuples |
| `apps/jarga/lib/notifications/infrastructure.ex` | Add `Perme8.Events` and `Identity` to boundary deps |
| `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs` | Add `MemberInvited` to event list, update count to 28 |

### Unchanged Files (Verified Compatible)

| File | Why Unchanged |
|------|---------------|
| `apps/jarga/lib/application.ex` | Supervision tree entry works with EventHandler's `child_spec/1` |
| `apps/jarga/test/support/data_case.ex` | `start_link([])` call is compatible with EventHandler |
| `apps/identity/lib/identity/infrastructure/notifiers/pubsub_notifier.ex` | Kept as-is during dual-publish period |
| `apps/identity/lib/identity/application_layer.ex` | No boundary change needed — uses `top_level?: true, deps: []` |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| `DomainEvent` macro workspace_id field conflict (base + custom) | Test that struct creation works correctly with the field defined in both base and custom fields. The macro's `defstruct` handles it (last wins). |
| Identity boundary doesn't export the event → compile error in jarga | Phase 1.2 updates the export list. Verified by `mix boundary`. |
| LegacyBridge needs `Identity` in its boundary deps | Phase 3.2 updates the boundary config. |
| Dual-publish causes duplicate notifications | Phase 5 analysis proves no duplication: subscriber listens on new topics, not legacy topic. Integration test verifies. |
| EventHandler state doesn't carry use_case for DI | Decision: use module attribute default (Option A). Tests already work this way. |
| `TestEventBus` not started in identity tests | Each test that asserts events starts `TestEventBus` in setup. Documented in test patterns. |
| `Perme8.Events.EventBus` compile-time reference in identity app | It's a runtime reference via `@default_event_bus`. The atom is resolved at runtime when `execute/2` reads the opts. In tests, `TestEventBus` is injected. |

---

## What's Deferred

- **Remove `pubsub_notifier` calls from identity use cases** — harmless during dual-publish, clean up in Part 2b+
- **Remove `"workspace_invitations"` legacy topic entirely** — when ALL consumers are migrated
- **Migrate LiveViews to structured event subscriptions** — Part 2b (Phase 5)
- **Remove LegacyBridge entirely** — Part 2c+ (Phase 6)
- **Event persistence** — Part 3 (Phase 7a)
- **Additional identity events** (e.g., `MemberJoined`, `MemberRemoved`, `WorkspaceCreated`) — future tickets

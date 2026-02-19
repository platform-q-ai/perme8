# Event-Driven Testing Guide

## Overview

This guide covers best practices for testing the event-driven system in Perme8. All real-time communication between use cases, LiveViews, and cross-context subscribers uses **structured domain event structs** dispatched through the `Perme8.Events.EventBus`.

> **Key Principle**: Events are typed structs, not bare tuples. Use cases emit events via `opts[:event_bus]` injection. LiveViews subscribe to topic strings and pattern-match on event structs in `handle_info/2`.

## Architecture Quick Reference

```
Use Case
  │  event_bus.emit(%ProjectCreated{...})
  ▼
EventBus (wraps Phoenix.PubSub)
  │  broadcasts to derived topics:
  │    events:projects
  │    events:projects:project
  │    events:workspace:{workspace_id}
  ▼
Subscribers
  ├─ LiveViews (handle_info/2 pattern matching)
  └─ EventHandlers (GenServer-based cross-context subscribers)
```

## Testing Tiers

### Tier 1: Use Case Event Emission (Unit Tests)

Verify that use cases emit the correct domain events using `TestEventBus`.

```elixir
defmodule Jarga.Projects.Application.UseCases.CreateProjectTest do
  use Jarga.DataCase, async: true

  alias Jarga.Projects.Application.UseCases.CreateProject
  alias Jarga.Projects.Domain.Events.ProjectCreated

  setup do
    {:ok, _pid} = Perme8.Events.TestEventBus.start_link(name: :"test_bus_#{System.unique_integer()}")
    :ok
  end

  test "emits ProjectCreated event on success", %{test: test_name} do
    bus_name = :"test_bus_#{System.unique_integer()}"
    {:ok, _pid} = Perme8.Events.TestEventBus.start_link(name: bus_name)

    user = insert(:user)
    workspace = insert(:workspace)

    {:ok, project} =
      CreateProject.execute(
        %{user: user, workspace_id: workspace.id, attrs: %{name: "New Project"}},
        event_bus: Perme8.Events.TestEventBus,
        event_bus_opts: [name: bus_name]
      )

    events = Perme8.Events.TestEventBus.get_events(name: bus_name)

    assert [%ProjectCreated{} = event] = events
    assert event.aggregate_id == project.id
    assert event.actor_id == user.id
    assert event.workspace_id == workspace.id
    assert event.name == "New Project"
  end
end
```

**Key Points:**
- Inject `event_bus: Perme8.Events.TestEventBus` via `opts`
- Use named instances (`name: :my_bus`) for async test isolation
- Assert on the **event struct type** and its fields
- No PubSub subscription needed -- TestEventBus stores events in memory

### Tier 2: LiveView Event Handling (Integration Tests)

Test that LiveViews process structured event messages and update the UI.

```elixir
defmodule JargaWeb.WorkspaceLive.ShowTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jarga.Projects.Domain.Events.ProjectCreated

  test "handles ProjectCreated event and shows new project", %{conn: conn} do
    user = insert(:user)
    workspace = insert(:workspace)
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    # Send a structured domain event to the LiveView process
    project = insert(:project, workspace_id: workspace.id)

    send(view.pid, %ProjectCreated{
      event_id: Ecto.UUID.generate(),
      event_type: "projects.project_created",
      aggregate_type: "project",
      aggregate_id: project.id,
      actor_id: user.id,
      workspace_id: workspace.id,
      occurred_at: DateTime.utc_now(),
      name: project.name,
      metadata: %{}
    })

    html = render(view)
    assert html =~ project.name
  end
end
```

**Key Points:**
- Use `send(view.pid, %EventStruct{...})` to simulate events
- LiveViews pattern-match on event structs in `handle_info/2`
- Verify UI updates with `render(view)`
- No need to subscribe to PubSub -- send directly to the LiveView process

### Tier 3: Full Integration (EventBus Round-Trip)

Test the complete flow: use case -> EventBus -> LiveView subscription.

```elixir
test "project creation broadcasts to workspace subscribers", %{conn: conn} do
  user = insert(:user)
  workspace = insert(:workspace)
  conn = log_in_user(conn, user)

  # Mount LiveView (auto-subscribes to events:workspace:{id})
  {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

  # Execute the use case with the real EventBus
  {:ok, project} =
    Jarga.Projects.create_project(user, workspace.id, %{name: "Integration Test"})

  # Wait briefly for PubSub delivery, then verify UI
  :timer.sleep(100)
  html = render(view)
  assert html =~ "Integration Test"
end
```

**Key Points:**
- This tests the real PubSub delivery pipeline
- LiveView must be mounted before the use case executes (subscribe before publish)
- Use sparingly -- Tier 1 and Tier 2 cover most needs

### Tier 4: Browser Tests (Exo-BDD)

For end-to-end validation through the actual browser. These are black-box tests that don't need to know about event internals.

```gherkin
Scenario: Project creation appears in workspace view
  Given I am logged in as "alice@example.com"
  And I am viewing workspace "product-team"
  When I create a project with name "New Project"
  Then I should see "New Project" in the project list
```

## Event Struct Reference

All events use the `Perme8.Events.DomainEvent` macro which provides base fields:

| Field | Type | Description |
|-------|------|-------------|
| `event_id` | UUID | Auto-generated unique event identifier |
| `event_type` | String | Derived from module name (e.g., `"projects.project_created"`) |
| `aggregate_type` | String | The aggregate this event belongs to (e.g., `"project"`) |
| `aggregate_id` | UUID | ID of the affected aggregate |
| `actor_id` | UUID | ID of the user who caused the event |
| `workspace_id` | UUID | Workspace scope (nil for global events) |
| `occurred_at` | DateTime | Auto-generated UTC timestamp |
| `metadata` | Map | Extensible metadata (default `%{}`) |

Each event struct adds its own domain-specific fields. Example:

```elixir
defmodule Jarga.Projects.Domain.Events.ProjectCreated do
  use Perme8.Events.DomainEvent,
    aggregate_type: "project",
    fields: [name: nil, slug: nil],
    required: [:name]
end
```

## Topic Routing

The `EventBus` derives multiple topics per event:

| Topic Pattern | Example | Subscribers |
|---------------|---------|-------------|
| `events:{context}` | `events:projects` | Context-wide listeners |
| `events:{context}:{aggregate}` | `events:projects:project` | Aggregate-specific listeners |
| `events:workspace:{id}` | `events:workspace:abc-123` | Workspace-scoped LiveViews |
| `events:user:{id}` | `events:user:def-456` | User-scoped LiveViews |

### LiveView Subscription Pattern

```elixir
# In mount/3
def mount(_params, _session, socket) do
  if connected?(socket) do
    workspace_id = socket.assigns.workspace.id
    Perme8.Events.subscribe("events:workspace:#{workspace_id}")
  end
  {:ok, socket}
end

# In handle_info/2
def handle_info(%ProjectCreated{} = event, socket) do
  # Reload or update assigns based on the event
  {:noreply, stream_insert(socket, :projects, load_project(event.aggregate_id))}
end

def handle_info(%ProjectDeleted{} = event, socket) do
  {:noreply, stream_delete_by_dom_id(socket, :projects, "projects-#{event.aggregate_id}")}
end
```

### EventHandler Subscription Pattern

```elixir
defmodule Jarga.Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber do
  use Perme8.Events.EventHandler

  @impl true
  def subscriptions do
    ["events:identity:workspace_member"]
  end

  @impl true
  def handle_event(%Identity.Domain.Events.MemberInvited{} = event) do
    # Create a notification for the invited user
    :ok
  end

  @impl true
  def handle_event(_event), do: :ok
end
```

## Use Case Event Emission Pattern

All use cases follow this pattern for emitting events:

```elixir
defmodule MyContext.Application.UseCases.MyOperation do
  @default_event_bus Perme8.Events.EventBus

  def execute(params, opts \\ []) do
    repo = Keyword.get(opts, :repo, Repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    result = repo.transact(fn ->
      # ... database operations ...
      {:ok, entity}
    end)

    # Emit event AFTER transaction commits
    case result do
      {:ok, entity} ->
        event_bus.emit(%MyEvent{
          aggregate_id: entity.id,
          actor_id: params.user.id,
          workspace_id: params.workspace_id,
          # ... domain-specific fields ...
        })
        {:ok, entity}

      error ->
        error
    end
  end
end
```

## Testing Checklist

For each feature that involves real-time updates:

- [ ] **Use case emits correct event** -- TestEventBus captures the right struct with correct fields (Tier 1)
- [ ] **Event struct is well-formed** -- Has all required fields, correct event_type and aggregate_type
- [ ] **LiveView handles the event** -- `handle_info/2` pattern matches and updates assigns (Tier 2)
- [ ] **UI reflects the change** -- `render(view)` shows expected content after event (Tier 2)
- [ ] **Event emitted after transaction** -- Not inside `Repo.transact` block (enforced by Credo check)
- [ ] **Topic routing is correct** -- Event reaches workspace/user-scoped subscribers

## Common Pitfalls

### Do Not Use Bare Tuples

```elixir
# WRONG -- legacy pattern, no longer used
send(view.pid, {:project_added, project.id})

# CORRECT -- use structured event structs
send(view.pid, %ProjectCreated{
  aggregate_id: project.id,
  actor_id: user.id,
  workspace_id: workspace.id,
  name: project.name,
  # ... base fields ...
})
```

### Do Not Call Phoenix.PubSub Directly in Use Cases

```elixir
# WRONG -- bypasses EventBus, no topic derivation
Phoenix.PubSub.broadcast(Jarga.PubSub, "workspace:#{id}", {:project_added, project.id})

# CORRECT -- use the injected event_bus
event_bus.emit(%ProjectCreated{...})
```

### Subscribe Before Action

```elixir
# WRONG -- event already fired before subscription
{:ok, project} = Projects.create_project(user, workspace.id, attrs)
Perme8.Events.subscribe("events:workspace:#{workspace.id}")
# Will never receive the event!

# CORRECT -- subscribe first, then act
Perme8.Events.subscribe("events:workspace:#{workspace.id}")
{:ok, project} = Projects.create_project(user, workspace.id, attrs)
assert_receive %ProjectCreated{}, 1000
```

### Store LiveView for Later Assertions

```elixir
# WRONG -- LiveView reference is lost
{:ok, _view, _html} = live(conn, path)

# CORRECT -- keep the view for sending events and rendering
{:ok, view, html} = live(conn, path)
send(view.pid, %SomeEvent{...})
assert render(view) =~ "expected content"
```

## Summary

1. **Tier 1 (TestEventBus)** -- Always test that use cases emit correct event structs
2. **Tier 2 (LiveView send)** -- Test that LiveViews handle events and update UI
3. **Tier 3 (Full integration)** -- Use sparingly for critical round-trip flows
4. **Tier 4 (Exo-BDD browser)** -- Black-box tests for end-to-end user scenarios
5. **Always use structured event structs** -- Never bare tuples
6. **Always use `opts[:event_bus]` injection** -- Never call PubSub directly from use cases
7. **Always emit after transaction commits** -- Enforced by Credo `NoBroadcastInTransaction` check

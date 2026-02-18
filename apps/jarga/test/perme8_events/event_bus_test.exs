defmodule Perme8.Events.EventBusTest do
  use Jarga.DataCase, async: false

  alias Perme8.Events.EventBus

  # Define a test event for use in tests
  defmodule TestProjectCreated do
    use Perme8.Events.DomainEvent,
      aggregate_type: "project",
      fields: [project_id: nil, name: nil],
      required: [:project_id, :name]
  end

  defmodule TestGlobalEvent do
    use Perme8.Events.DomainEvent,
      aggregate_type: "global",
      fields: [data: nil],
      required: []
  end

  defp build_event(overrides \\ %{}) do
    defaults = %{
      aggregate_id: "proj-123",
      actor_id: "user-456",
      workspace_id: "ws-789",
      project_id: "proj-123",
      name: "Test Project"
    }

    TestProjectCreated.new(Map.merge(defaults, overrides))
  end

  defp build_global_event(overrides \\ %{}) do
    defaults = %{
      aggregate_id: "global-1",
      actor_id: "user-456"
    }

    TestGlobalEvent.new(Map.merge(defaults, overrides))
  end

  describe "emit/2" do
    test "broadcasts event to events:{context} topic" do
      event = build_event()
      context = event.event_type |> String.split(".") |> List.first()
      Phoenix.PubSub.subscribe(Jarga.PubSub, "events:#{context}")

      EventBus.emit(event)

      assert_receive %TestProjectCreated{project_id: "proj-123"}
    end

    test "broadcasts event to events:{context}:{aggregate_type} topic" do
      event = build_event()
      context = event.event_type |> String.split(".") |> List.first()
      Phoenix.PubSub.subscribe(Jarga.PubSub, "events:#{context}:#{event.aggregate_type}")

      EventBus.emit(event)

      assert_receive %TestProjectCreated{project_id: "proj-123"}
    end

    test "broadcasts event to events:workspace:{workspace_id} topic when workspace_id present" do
      event = build_event(%{workspace_id: "ws-789"})
      Phoenix.PubSub.subscribe(Jarga.PubSub, "events:workspace:ws-789")

      EventBus.emit(event)

      assert_receive %TestProjectCreated{workspace_id: "ws-789"}
    end

    test "skips workspace topic when workspace_id is nil" do
      event = build_global_event(%{workspace_id: nil})

      # Subscribe to what would be the workspace topic if it existed
      Phoenix.PubSub.subscribe(Jarga.PubSub, "events:workspace:")

      EventBus.emit(event)

      refute_receive _, 100
    end

    test "returns :ok" do
      event = build_event()
      assert :ok = EventBus.emit(event)
    end
  end

  describe "emit_all/2" do
    test "broadcasts multiple events" do
      event1 = build_event(%{aggregate_id: "proj-1", project_id: "proj-1", name: "Project 1"})
      event2 = build_event(%{aggregate_id: "proj-2", project_id: "proj-2", name: "Project 2"})

      context = event1.event_type |> String.split(".") |> List.first()
      Phoenix.PubSub.subscribe(Jarga.PubSub, "events:#{context}")

      EventBus.emit_all([event1, event2])

      assert_receive %TestProjectCreated{project_id: "proj-1"}
      assert_receive %TestProjectCreated{project_id: "proj-2"}
    end

    test "returns :ok" do
      event = build_event()
      assert :ok = EventBus.emit_all([event])
    end
  end
end

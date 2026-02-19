defmodule Perme8.Events.DomainEventTest do
  use ExUnit.Case, async: true

  alias Perme8.Events.DomainEventTest.Agents.Domain.Events.AgentUpdated
  alias Perme8.Events.DomainEventTest.EntityRelationshipManager.Domain.Events.EntityCreated
  alias Perme8.Events.DomainEventTest.Jarga.Projects.Domain.Events.ProjectCreated

  # Test helper module using the DomainEvent macro
  defmodule TestEvent do
    use Perme8.Events.DomainEvent,
      aggregate_type: "test",
      fields: [name: nil, value: nil],
      required: [:name]
  end

  # Test module simulating a nested context structure
  defmodule Jarga.Projects.Domain.Events.ProjectCreated do
    use Perme8.Events.DomainEvent,
      aggregate_type: "project",
      fields: [project_id: nil, name: nil, slug: nil],
      required: [:project_id, :name, :slug]
  end

  # Test module simulating an agents context
  defmodule Agents.Domain.Events.AgentUpdated do
    use Perme8.Events.DomainEvent,
      aggregate_type: "agent",
      fields: [agent_id: nil],
      required: [:agent_id]
  end

  # Test module with underscored context name
  defmodule EntityRelationshipManager.Domain.Events.EntityCreated do
    use Perme8.Events.DomainEvent,
      aggregate_type: "entity",
      fields: [entity_id: nil],
      required: [:entity_id]
  end

  describe "struct definition" do
    test "creates a struct with base fields and custom fields" do
      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", name: "test"})

      # Base fields
      assert Map.has_key?(event, :event_id)
      assert Map.has_key?(event, :event_type)
      assert Map.has_key?(event, :aggregate_type)
      assert Map.has_key?(event, :aggregate_id)
      assert Map.has_key?(event, :actor_id)
      assert Map.has_key?(event, :workspace_id)
      assert Map.has_key?(event, :occurred_at)
      assert Map.has_key?(event, :metadata)

      # Custom fields
      assert Map.has_key?(event, :name)
      assert Map.has_key?(event, :value)
    end

    test "metadata defaults to empty map" do
      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", name: "test"})
      assert event.metadata == %{}
    end

    test "workspace_id is optional (nil for global events)" do
      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", name: "test"})
      assert event.workspace_id == nil
    end
  end

  describe "enforce_keys" do
    test "enforces aggregate_id and actor_id as required" do
      assert_raise ArgumentError, fn ->
        TestEvent.new(%{name: "test"})
      end
    end

    test "enforces custom required fields" do
      assert_raise ArgumentError, fn ->
        TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1"})
      end
    end
  end

  describe "new/1" do
    test "auto-generates event_id as UUID" do
      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", name: "test"})

      assert event.event_id != nil
      # UUID v4 format: 8-4-4-4-12 hex characters
      assert String.match?(
               event.event_id,
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
             )
    end

    test "auto-generates occurred_at as DateTime" do
      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", name: "test"})

      assert %DateTime{} = event.occurred_at
      # Should be recent (within last few seconds)
      diff = DateTime.diff(DateTime.utc_now(), event.occurred_at, :second)
      assert diff >= 0 and diff < 5
    end

    test "auto-populates event_type from module name" do
      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", name: "test"})
      assert event.event_type == TestEvent.event_type()
    end

    test "auto-populates aggregate_type" do
      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", name: "test"})
      assert event.aggregate_type == "test"
    end

    test "sets custom fields from attrs" do
      event =
        TestEvent.new(%{
          aggregate_id: "agg-1",
          actor_id: "act-1",
          name: "my-name",
          value: 42
        })

      assert event.name == "my-name"
      assert event.value == 42
    end

    test "allows setting metadata" do
      event =
        TestEvent.new(%{
          aggregate_id: "agg-1",
          actor_id: "act-1",
          name: "test",
          metadata: %{source: "test"}
        })

      assert event.metadata == %{source: "test"}
    end

    test "allows setting workspace_id" do
      event =
        TestEvent.new(%{
          aggregate_id: "agg-1",
          actor_id: "act-1",
          name: "test",
          workspace_id: "ws-123"
        })

      assert event.workspace_id == "ws-123"
    end
  end

  describe "event_type/0" do
    test "derives context.event_name from full module name" do
      assert ProjectCreated.event_type() ==
               "projects.project_created"
    end

    test "derives from agents context" do
      assert AgentUpdated.event_type() == "agents.agent_updated"
    end

    test "derives from underscored context name" do
      assert EntityCreated.event_type() ==
               "entity_relationship_manager.entity_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns the aggregate type string" do
      assert TestEvent.aggregate_type() == "test"
      assert ProjectCreated.aggregate_type() == "project"
      assert AgentUpdated.aggregate_type() == "agent"
    end
  end
end

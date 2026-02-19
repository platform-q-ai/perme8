defmodule Agents.Domain.Events.AgentUpdatedTest do
  use ExUnit.Case, async: true

  alias Agents.Domain.Events.AgentUpdated

  @valid_attrs %{
    aggregate_id: "agent-123",
    actor_id: "user-123",
    agent_id: "agent-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert AgentUpdated.event_type() == "agents.agent_updated"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert AgentUpdated.aggregate_type() == "agent"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = AgentUpdated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "agents.agent_updated"
      assert event.agent_id == "agent-123"
      assert event.user_id == "user-123"
    end

    test "optional workspace_ids defaults to empty list" do
      event = AgentUpdated.new(@valid_attrs)
      assert event.workspace_ids == []
    end

    test "optional changes defaults to empty map" do
      event = AgentUpdated.new(@valid_attrs)
      assert event.changes == %{}
    end

    test "accepts optional fields" do
      event =
        AgentUpdated.new(
          Map.merge(@valid_attrs, %{
            workspace_ids: ["ws-1", "ws-2"],
            changes: %{name: "New Name"}
          })
        )

      assert event.workspace_ids == ["ws-1", "ws-2"]
      assert event.changes == %{name: "New Name"}
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        AgentUpdated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end

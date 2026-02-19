defmodule Agents.Domain.Events.AgentDeletedTest do
  use ExUnit.Case, async: true

  alias Agents.Domain.Events.AgentDeleted

  @valid_attrs %{
    aggregate_id: "agent-123",
    actor_id: "user-123",
    agent_id: "agent-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert AgentDeleted.event_type() == "agents.agent_deleted"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert AgentDeleted.aggregate_type() == "agent"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = AgentDeleted.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "agents.agent_deleted"
      assert event.agent_id == "agent-123"
      assert event.user_id == "user-123"
    end

    test "optional workspace_ids defaults to empty list" do
      event = AgentDeleted.new(@valid_attrs)
      assert event.workspace_ids == []
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        AgentDeleted.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end

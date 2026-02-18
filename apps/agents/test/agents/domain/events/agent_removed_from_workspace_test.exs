defmodule Agents.Domain.Events.AgentRemovedFromWorkspaceTest do
  use ExUnit.Case, async: true

  alias Agents.Domain.Events.AgentRemovedFromWorkspace

  @valid_attrs %{
    aggregate_id: "agent-123",
    actor_id: "user-123",
    agent_id: "agent-123",
    workspace_id: "ws-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert AgentRemovedFromWorkspace.event_type() == "agents.agent_removed_from_workspace"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert AgentRemovedFromWorkspace.aggregate_type() == "agent"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = AgentRemovedFromWorkspace.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "agents.agent_removed_from_workspace"
      assert event.agent_id == "agent-123"
      assert event.workspace_id == "ws-123"
      assert event.user_id == "user-123"
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        AgentRemovedFromWorkspace.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end

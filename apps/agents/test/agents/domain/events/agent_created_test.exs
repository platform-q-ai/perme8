defmodule Agents.Domain.Events.AgentCreatedTest do
  use ExUnit.Case, async: true

  alias Agents.Domain.Events.AgentCreated

  @valid_attrs %{
    aggregate_id: "agent-123",
    actor_id: "user-123",
    agent_id: "agent-123",
    user_id: "user-123",
    name: "My Agent"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert AgentCreated.event_type() == "agents.agent_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert AgentCreated.aggregate_type() == "agent"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = AgentCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "agents.agent_created"
      assert event.aggregate_type == "agent"
      assert event.agent_id == "agent-123"
      assert event.user_id == "user-123"
      assert event.name == "My Agent"
    end

    test "workspace_id is optional and defaults to nil" do
      event = AgentCreated.new(@valid_attrs)
      assert event.workspace_id == nil
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        AgentCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end

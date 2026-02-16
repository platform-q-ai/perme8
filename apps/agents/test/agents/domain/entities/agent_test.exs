defmodule Agents.Domain.Entities.AgentTest do
  use ExUnit.Case, async: true

  alias Agents.Domain.Entities.Agent

  describe "Agent.new/1" do
    test "creates a new agent entity with required fields" do
      attrs = %{
        user_id: "user-123",
        name: "Test Agent",
        system_prompt: "You are helpful"
      }

      agent = Agent.new(attrs)

      assert %Agent{} = agent
      assert agent.user_id == "user-123"
      assert agent.name == "Test Agent"
      assert agent.system_prompt == "You are helpful"
    end

    test "sets default values for optional fields" do
      attrs = %{
        user_id: "user-123",
        name: "Test Agent"
      }

      agent = Agent.new(attrs)

      assert agent.visibility == "PRIVATE"
      assert agent.enabled == true
      assert agent.temperature == 0.7
    end

    test "allows overriding default values" do
      attrs = %{
        user_id: "user-123",
        name: "Test Agent",
        visibility: "SHARED",
        enabled: false,
        temperature: 1.0
      }

      agent = Agent.new(attrs)

      assert agent.visibility == "SHARED"
      assert agent.enabled == false
      assert agent.temperature == 1.0
    end

    test "includes all fields in struct" do
      agent = Agent.new(%{user_id: "user-123", name: "Agent"})

      assert Map.has_key?(agent, :id)
      assert Map.has_key?(agent, :name)
      assert Map.has_key?(agent, :description)
      assert Map.has_key?(agent, :system_prompt)
      assert Map.has_key?(agent, :model)
      assert Map.has_key?(agent, :temperature)
      assert Map.has_key?(agent, :input_token_cost)
      assert Map.has_key?(agent, :cached_input_token_cost)
      assert Map.has_key?(agent, :output_token_cost)
      assert Map.has_key?(agent, :cached_output_token_cost)
      assert Map.has_key?(agent, :visibility)
      assert Map.has_key?(agent, :enabled)
      assert Map.has_key?(agent, :user_id)
      assert Map.has_key?(agent, :inserted_at)
      assert Map.has_key?(agent, :updated_at)
    end
  end

  describe "Agent.from_schema/1" do
    test "converts a schema to a domain entity" do
      schema = %{
        __struct__: SomeSchema,
        id: "agent-123",
        name: "Schema Agent",
        description: "A description",
        system_prompt: "System prompt",
        model: "claude-3",
        temperature: 0.8,
        input_token_cost: Decimal.new("0.01"),
        cached_input_token_cost: Decimal.new("0.005"),
        output_token_cost: Decimal.new("0.02"),
        cached_output_token_cost: Decimal.new("0.01"),
        visibility: "SHARED",
        enabled: false,
        user_id: "user-456",
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-02 00:00:00Z]
      }

      agent = Agent.from_schema(schema)

      assert %Agent{} = agent
      assert agent.id == "agent-123"
      assert agent.name == "Schema Agent"
      assert agent.description == "A description"
      assert agent.system_prompt == "System prompt"
      assert agent.model == "claude-3"
      assert agent.temperature == 0.8
      assert agent.input_token_cost == Decimal.new("0.01")
      assert agent.visibility == "SHARED"
      assert agent.enabled == false
      assert agent.user_id == "user-456"
      assert agent.inserted_at == ~U[2024-01-01 00:00:00Z]
      assert agent.updated_at == ~U[2024-01-02 00:00:00Z]
    end

    test "handles nil optional fields" do
      schema = %{
        __struct__: SomeSchema,
        id: "agent-123",
        name: "Minimal Agent",
        description: nil,
        system_prompt: nil,
        model: nil,
        temperature: 0.7,
        input_token_cost: nil,
        cached_input_token_cost: nil,
        output_token_cost: nil,
        cached_output_token_cost: nil,
        visibility: "PRIVATE",
        enabled: true,
        user_id: "user-789",
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 00:00:00Z]
      }

      agent = Agent.from_schema(schema)

      assert %Agent{} = agent
      assert agent.description == nil
      assert agent.system_prompt == nil
      assert agent.model == nil
    end
  end

  describe "Agent.valid_visibilities/0" do
    test "returns list of valid visibility values" do
      visibilities = Agent.valid_visibilities()

      assert is_list(visibilities)
      assert "PRIVATE" in visibilities
      assert "SHARED" in visibilities
    end
  end
end

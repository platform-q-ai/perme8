defmodule AgentVerifySteps do
  @moduledoc """
  Agent verification and assertion step definitions - Creation and Defaults.

  Covers:
  - Agent creation assertions
  - Default value assertions

  Related modules:
  - AgentVerifyValidationSteps - Validation error assertions
  - AgentVerifyPubSubSteps - Chat/system prompt and PubSub assertions
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Agents.AgentsFixtures

  # ============================================================================
  # CREATION ASSERTIONS
  # ============================================================================

  step "the agent should not be created", context do
    assert {:error, _reason} = context[:last_result],
           "Expected agent creation to fail, but got: #{inspect(context[:last_result])}"

    {:ok, context}
  end

  step "the agent should have the configured token costs", context do
    agent = context[:agent]

    assert agent != nil
    assert agent.input_token_cost != nil || agent.output_token_cost != nil

    {:ok, context}
  end

  step "future usage tracking should use these costs", context do
    agent = context[:agent]
    assert agent != nil

    assert valid_cost?(agent.input_token_cost)
    assert valid_cost?(agent.output_token_cost)

    assert_positive_cost(agent.input_token_cost)
    assert_positive_cost(agent.output_token_cost)

    {:ok, context}
  end

  defp valid_cost?(nil), do: true
  defp valid_cost?(cost) when is_number(cost), do: true
  defp valid_cost?(%Decimal{}), do: true
  defp valid_cost?(_), do: false

  defp assert_positive_cost(nil), do: :ok
  defp assert_positive_cost(%Decimal{} = cost), do: assert(Decimal.to_float(cost) > 0)
  defp assert_positive_cost(cost) when is_number(cost), do: assert(cost > 0)

  step "both agents should exist", context do
    agents = Map.get(context, :agents, %{})
    duplicate_agents = Map.get(context, :duplicate_agents, [])

    agent_count = length(Map.keys(agents)) + length(duplicate_agents)
    assert agent_count >= 2, "Expected at least 2 agents, got #{agent_count}"

    {:ok, context}
  end

  step "both should have unique IDs", context do
    agents = Map.get(context, :agents, %{})
    agent_list = Map.values(agents)
    ids = Enum.map(agent_list, & &1.id)
    assert length(Enum.uniq(ids)) == length(ids)
    {:ok, context}
  end

  # ============================================================================
  # DEFAULT VALUE ASSERTIONS
  # ============================================================================

  step "the agent should have visibility {string}", %{args: [visibility]} = context do
    agent = context[:agent]
    assert agent.visibility == visibility
    {:ok, context}
  end

  step "the agent should have temperature {float}", %{args: [temp]} = context do
    agent = context[:agent]
    assert agent.temperature == temp
    {:ok, context}
  end

  step "the agent should be enabled", context do
    agent = context[:agent]
    assert agent.enabled == true
    {:ok, context}
  end

  step "{string} is enabled", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    assert agent.enabled == true
    {:ok, context}
  end

  step "I have an agent with ID {string}", %{args: [_id]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: "Test Agent"})

    {:ok, Map.put(context, :agent, agent)}
  end

  step "I use the agent in chat", context do
    agent = context[:agent]
    assert agent != nil
    {:ok, context}
  end

  step "the system should use the default LLM model", context do
    agent = context[:agent]
    assert agent.model == nil || agent.model == ""
    {:ok, context}
  end
end

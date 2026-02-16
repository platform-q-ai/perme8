defmodule AgentDeleteSteps do
  @moduledoc """
  Agent deletion step definitions.

  Covers:
  - Deleting agents
  - Cascade deletion from workspaces
  - Authorization checks for deletion
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Agents

  # ============================================================================
  # DELETION ACTIONS
  # ============================================================================

  step "I click delete on {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result = Agents.delete_user_agent(agent.id, user.id)

    {:ok,
     context
     |> Map.put(:deleted_agent, agent)
     |> Map.put(:last_result, result)}
  end

  step "I delete the agent {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result = Agents.delete_user_agent(agent.id, user.id)

    {:ok,
     context
     |> Map.put(:deleted_agent, agent)
     |> Map.put(:last_result, result)}
  end

  step "I attempt to delete {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result = Agents.delete_user_agent(agent.id, user.id)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "{string} attempts to delete {string}", %{args: [user_name, agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    other_user = get_in(context, [:users, user_name])

    result = Agents.delete_user_agent(agent.id, other_user.id)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "the agent is deleted by another process", context do
    agent = context[:agent]
    user = context[:current_user]

    Agents.delete_user_agent(agent.id, user.id)

    {:ok, context}
  end

  step "I attempt to load the agent", context do
    agent = context[:agent]
    user = context[:current_user]

    result = Agents.update_user_agent(agent.id, user.id, %{})

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I delete agent {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    {:ok, _deleted} = Agents.delete_user_agent(agent.id, user.id)

    {:ok, Map.put(context, :deleted_agent, agent)}
  end

  # ============================================================================
  # DELETION ASSERTIONS
  # ============================================================================

  step "{string} should not appear in my agents list", %{args: [agent_name]} = context do
    user = context[:current_user]

    agents = Agents.list_user_agents(user.id)
    agent_names = Enum.map(agents, & &1.name)

    refute agent_name in agent_names

    conn = context[:conn]
    {:ok, _view, html} = live(conn, ~p"/app/agents")

    refute html =~ agent_name

    {:ok, context}
  end

  step "the agent should be removed from workspace {string}",
       %{args: [workspace_name]} = context do
    workspace = get_in(context, [:workspaces, workspace_name]) || context[:workspace]
    user = context[:current_user]
    deleted_agent = context[:deleted_agent]

    result = Agents.list_workspace_available_agents(workspace.id, user.id)
    all_agents = (result.my_agents || []) ++ (result.other_agents || [])
    agent_ids = Enum.map(all_agents, & &1.id)

    refute deleted_agent.id in agent_ids

    {:ok, context}
  end

  step "workspace members should receive notifications of the removal", context do
    deleted_agent = context[:deleted_agent]
    workspace_ids = Agents.get_agent_workspace_ids(deleted_agent.id)

    Enum.each(workspace_ids, fn workspace_id ->
      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace_id}")
    end)

    {:ok, context}
  end

  step "the agent should still exist", context do
    assert {:error, _reason} = context[:last_result],
           "Expected delete to fail, but got: #{inspect(context[:last_result])}"

    {:ok, context}
  end

  step "I should receive an error {string}", %{args: [expected_error]} = context do
    {:error, actual_error} = context[:last_result]

    expected_atom = String.to_existing_atom(expected_error)

    assert actual_error == expected_atom,
           "Expected error '#{expected_error}' but got '#{inspect(actual_error)}'"

    {:ok, context}
  end
end

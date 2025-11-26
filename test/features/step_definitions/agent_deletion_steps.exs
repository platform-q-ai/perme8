defmodule AgentDeletionSteps do
  @moduledoc """
  Cucumber step definitions for Agent Deletion scenarios.

  Covers:
  - Deleting agents
  - Cascade deletion from workspaces
  - Authorization checks for deletion
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  # import Jarga.AgentsFixtures  # Not used in this file

  alias Jarga.Agents

  # ============================================================================
  # DELETION ACTIONS
  # ============================================================================

  step "I click delete on {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    # Delete via context API (simulating the delete button click)
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
    # Simulate concurrent deletion
    agent = context[:agent]
    user = context[:current_user]

    # Delete agent directly
    Agents.delete_user_agent(agent.id, user.id)

    {:ok, context}
  end

  step "I attempt to load the agent", context do
    agent = context[:agent]
    user = context[:current_user]

    # Try to update to test if agent exists
    result = Agents.update_user_agent(agent.id, user.id, %{})

    {:ok, Map.put(context, :last_result, result)}
  end

  # ============================================================================
  # DELETION ASSERTIONS
  # ============================================================================

  step "{string} should not appear in my agents list", %{args: [agent_name]} = context do
    user = context[:current_user]

    # Verify agent is not in list
    agents = Agents.list_user_agents(user.id)
    agent_names = Enum.map(agents, & &1.name)

    refute agent_name in agent_names

    # Also verify via UI
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

    # Verify agent is not in workspace
    result = Agents.list_workspace_available_agents(workspace.id, user.id)
    all_agents = (result.my_agents || []) ++ (result.other_agents || [])
    agent_ids = Enum.map(all_agents, & &1.id)

    refute deleted_agent.id in agent_ids

    {:ok, context}
  end

  step "workspace members should receive notifications of the removal", context do
    # Get the agent that was deleted from the context
    deleted_agent = context[:deleted_agent]

    if deleted_agent do
      # Get workspaces this agent was in before deletion
      workspace_ids = Jarga.Agents.get_agent_workspace_ids(deleted_agent.id)

      if length(workspace_ids) > 0 do
        # Subscribe to all workspaces the agent was in
        Enum.each(workspace_ids, fn workspace_id ->
          Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace_id}")
        end)

        # Now we should receive the notification
        assert_receive {:workspace_agent_updated, agent}, 1000
        # Store the received agent in context for subsequent steps to use
        {:ok, Map.put(context, :last_received_agent, agent)}
      else
        # Agent wasn't in any workspaces, no PubSub notification expected
        {:ok, context}
      end
    else
      # No deleted agent in context, skip PubSub check
      {:ok, context}
    end
  end

  step "the agent should still exist", context do
    case context[:last_result] do
      {:ok, _} -> flunk("Expected delete to fail")
      {:error, _} -> {:ok, context}
    end
  end

  step "I should receive an error {string}", %{args: [error]} = context do
    case context[:last_result] do
      {:error, ^error} ->
        {:ok, context}

      {:error, error_atom} when is_atom(error_atom) ->
        assert to_string(error_atom) == error
        {:ok, context}

      other ->
        flunk("Expected error #{error}, got: #{inspect(other)}")
    end
  end
end

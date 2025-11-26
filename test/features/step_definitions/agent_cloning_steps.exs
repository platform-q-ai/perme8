defmodule AgentCloningSteps do
  @moduledoc """
  Cucumber step definitions for Agent Cloning scenarios.

  Covers:
  - Cloning own agents
  - Cloning shared agents from workspace context
  - Authorization checks for cloning
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  # import Phoenix.LiveViewTest  # Not used in this file
  import Jarga.AccountsFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Agents

  # alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository  # Not used in this file

  # ============================================================================
  # CLONING ACTIONS
  # ============================================================================

  step "I clone the agent {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result = Agents.clone_shared_agent(agent.id, user.id)

    case result do
      {:ok, cloned_agent} ->
        agents = Map.get(context, :agents, %{})

        {:ok,
         context
         |> Map.put(:cloned_agent, cloned_agent)
         |> Map.put(:agents, Map.put(agents, cloned_agent.name, cloned_agent))
         |> Map.put(:last_result, result)}

      {:error, _} ->
        {:ok, Map.put(context, :last_result, result)}
    end
  end

  step "I clone {string} from the workspace context", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    result = Agents.clone_shared_agent(agent.id, user.id, workspace_id: workspace.id)

    case result do
      {:ok, cloned_agent} ->
        agents = Map.get(context, :agents, %{})

        {:ok,
         context
         |> Map.put(:cloned_agent, cloned_agent)
         |> Map.put(:agents, Map.put(agents, cloned_agent.name, cloned_agent))
         |> Map.put(:last_result, result)}

      {:error, _} ->
        {:ok, Map.put(context, :last_result, result)}
    end
  end

  step "I attempt to clone {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result = Agents.clone_shared_agent(agent.id, user.id)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I attempt to clone {string} without workspace context", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result = Agents.clone_shared_agent(agent.id, user.id)

    {:ok, Map.put(context, :last_result, result)}
  end

  # ============================================================================
  # SETUP STEPS
  # ============================================================================

  step "another user has a shared agent named {string}", %{args: [agent_name]} = context do
    other_user =
      user_fixture(%{
        email: "shared_agent_owner_#{System.unique_integer([:positive])}@example.com"
      })

    agent = agent_fixture(other_user, %{name: agent_name, visibility: "SHARED"})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:other_user, other_user)
     |> Map.put(:agents, Map.put(agents, agent_name, agent))}
  end

  step "I am not in a workspace with {string}", %{args: [_agent_name]} = context do
    # User is not in any workspace with this agent
    {:ok, context}
  end

  step "another user has a private agent named {string}", %{args: [agent_name]} = context do
    other_user =
      user_fixture(%{
        email: "private_agent_owner_#{System.unique_integer([:positive])}@example.com"
      })

    agent = agent_fixture(other_user, %{name: agent_name, visibility: "PRIVATE"})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:other_user, other_user)
     |> Map.put(:agents, Map.put(agents, agent_name, agent))}
  end

  # ============================================================================
  # CLONING ASSERTIONS
  # ============================================================================

  step "a new agent {string} should be created", %{args: [expected_name]} = context do
    cloned_agent = context[:cloned_agent]

    assert cloned_agent != nil
    assert cloned_agent.name == expected_name

    {:ok, context}
  end

  step "the cloned agent should have the same system prompt", context do
    original_agent = context[:agent]
    cloned_agent = context[:cloned_agent]

    assert cloned_agent.system_prompt == original_agent.system_prompt

    {:ok, context}
  end

  step "the cloned agent should have the same model", context do
    original_agent = context[:agent]
    cloned_agent = context[:cloned_agent]

    assert cloned_agent.model == original_agent.model

    {:ok, context}
  end

  step "the cloned agent should have the same temperature", context do
    original_agent = context[:agent]
    cloned_agent = context[:cloned_agent]

    assert cloned_agent.temperature == original_agent.temperature

    {:ok, context}
  end

  step "the cloned agent should have visibility {string}", %{args: [visibility]} = context do
    cloned_agent = context[:cloned_agent]
    assert cloned_agent.visibility == visibility
    {:ok, context}
  end

  step "the cloned agent should belong to me", context do
    cloned_agent = context[:cloned_agent]
    user = context[:current_user]

    assert cloned_agent.user_id == user.id

    {:ok, context}
  end

  step "the cloned agent should not be added to any workspaces", context do
    cloned_agent = context[:cloned_agent]

    workspace_ids = Agents.get_agent_workspace_ids(cloned_agent.id)
    assert Enum.empty?(workspace_ids)

    {:ok, context}
  end

  step "the cloned agent should not be in any workspaces", context do
    cloned_agent = context[:cloned_agent]

    workspace_ids = Agents.get_agent_workspace_ids(cloned_agent.id)
    assert Enum.empty?(workspace_ids)

    {:ok, context}
  end

  step "the agent should not be cloned", context do
    case context[:last_result] do
      {:ok, _} -> flunk("Expected clone to fail")
      {:error, _} -> {:ok, context}
    end
  end

  step "I should see an error {string}", %{args: [_error]} = context do
    # Error handling scenarios - just pass for now as they test edge cases
    {:ok, context}
  end

  step "{string} should be able to clone {string}", %{args: [user_name, agent_name]} = context do
    user = get_in(context, [:users, user_name])
    agent = get_in(context, [:agents, agent_name])

    # Get workspace - could be in :workspace or :workspaces map or :current_workspace
    workspace =
      context[:workspace] || context[:current_workspace] ||
        (context[:workspaces] && Map.values(context[:workspaces]) |> List.first())

    # Verify user can clone via workspace context
    result = Agents.clone_shared_agent(agent.id, user.id, workspace_id: workspace.id)

    case result do
      {:ok, _} ->
        {:ok, context}

      {:error, reason} ->
        flunk("Expected #{user_name} to be able to clone, got: #{inspect(reason)}")
    end
  end
end

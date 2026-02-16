defmodule AgentCloneSteps do
  @moduledoc """
  Agent cloning step definitions.

  Covers:
  - Cloning agents (own and shared)
  - Setup for cloning
  - Cloning assertions
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Agents.AgentsFixtures

  alias Agents
  alias Agents.Infrastructure.Repositories.WorkspaceAgentRepository

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
  # SETUP STEPS FOR CLONING
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

  step "I am not in a workspace with {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    assert agent != nil, "Agent #{agent_name} should exist in context"

    agent_workspace_ids = Agents.get_agent_workspace_ids(agent.id)

    assert Enum.empty?(agent_workspace_ids),
           "Agent should not be in any workspace for this authorization test"

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

  step "{string} should be able to clone {string}", %{args: [user_name, agent_name]} = context do
    user = get_in(context, [:users, user_name])
    agent = get_in(context, [:agents, agent_name])

    workspace =
      context[:workspace] || context[:current_workspace] ||
        (context[:workspaces] && Map.values(context[:workspaces]) |> List.first())

    result = Agents.clone_shared_agent(agent.id, user.id, workspace_id: workspace.id)

    case result do
      {:ok, _} ->
        {:ok, context}

      {:error, reason} ->
        flunk("Expected #{user_name} to be able to clone, got: #{inspect(reason)}")
    end
  end

  step "another user has created an agent named {string}", %{args: [agent_name]} = context do
    other_user =
      user_fixture(%{email: "other_user_#{System.unique_integer([:positive])}@example.com"})

    agent = agent_fixture(other_user, %{name: agent_name})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:other_user, other_user)
     |> Map.put(:agents, Map.put(agents, agent_name, agent))}
  end

  step "another user has a shared agent named {string} in the workspace",
       %{args: [agent_name]} = context do
    workspace = context[:workspace] || context[:current_workspace]

    other_user =
      user_fixture(%{email: "shared_owner_#{System.unique_integer([:positive])}@example.com"})

    agent = agent_fixture(other_user, %{name: agent_name, visibility: "SHARED"})

    WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
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
    assert {:error, _reason} = context[:last_result],
           "Expected clone to fail but got: #{inspect(context[:last_result])}"

    {:ok, context}
  end

  step "the clone operation should fail with {string}", %{args: [expected_error]} = context do
    result = context[:last_result]

    assert {:error, actual_error} = result,
           "Expected clone to fail but got: #{inspect(result)}"

    expected_atom = String.to_existing_atom(expected_error)

    assert actual_error == expected_atom,
           "Expected error '#{expected_error}' but got '#{inspect(actual_error)}'"

    {:ok, context}
  end
end

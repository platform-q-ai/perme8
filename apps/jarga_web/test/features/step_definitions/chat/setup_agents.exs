defmodule ChatSetupAgentsSteps do
  @moduledoc """
  Step definitions for Chat Panel Basic Agent Setup.

  Covers:
  - Basic agent creation for chat contexts
  - Agent availability and selection basics

  Related modules:
  - ChatSetupAgentsWorkspaceSteps - Workspace agent configuration
  - ChatSetupAgentsConfigSteps - Agent configuration and selection
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Jarga.WorkspacesFixtures
  import Jarga.AgentsFixtures

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp setup_workspace_with_agents(context, agent_configs) do
    user = context[:current_user]

    workspace =
      get_workspace(context) ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    existing_agents = get_agents(context)

    {primary_agent, agents_map} =
      create_and_sync_agents(user, workspace, agent_configs, existing_agents)

    context
    |> Map.put(:workspace, workspace)
    |> Map.put(:current_workspace, workspace)
    |> Map.put(:agent, primary_agent)
    |> Map.put(:agents, agents_map)
  end

  defp create_and_sync_agents(user, workspace, agent_configs, existing_agents) do
    agents_with_names =
      Enum.map(agent_configs, fn {name, attrs} ->
        agent = agent_fixture(user, Map.merge(%{name: name, enabled: true}, attrs))
        :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])
        {name, agent}
      end)

    agents_map =
      Enum.reduce(agents_with_names, existing_agents, fn {name, agent}, acc ->
        Map.put(acc, name, agent)
      end)

    {_, primary_agent} = List.first(agents_with_names)
    {primary_agent, agents_map}
  end

  defp ensure_selected_agent(context) do
    case get_selected_agent(context) do
      nil -> create_selected_agent(context)
      existing_agent -> existing_agent
    end
  end

  defp create_selected_agent(context) do
    user = context[:current_user]
    workspace = get_workspace(context)
    agent = agent_fixture(user, %{name: "Selected Agent", enabled: true})
    sync_agent_to_workspace_if_exists(agent, user, workspace)
    agent
  end

  defp sync_agent_to_workspace_if_exists(_agent, _user, nil), do: :ok

  defp sync_agent_to_workspace_if_exists(agent, user, workspace) do
    :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])
  end

  defp create_default_workspace(user) do
    workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})
  end

  defp create_default_agent_pair(user, workspace) do
    agent1 = agent_fixture(user, %{name: "Code Helper", enabled: true})
    agent2 = agent_fixture(user, %{name: "Doc Writer", enabled: true})

    :ok = Agents.sync_agent_workspaces(agent1.id, user.id, [workspace.id])
    :ok = Agents.sync_agent_workspaces(agent2.id, user.id, [workspace.id])

    {agent1, agent2}
  end

  defp build_agents_map(context, agent1, agent2) do
    get_agents(context)
    |> Map.put("Code Helper", agent1)
    |> Map.put("Doc Writer", agent2)
    |> Map.put("Agent 1", agent1)
    |> Map.put("Agent 2", agent2)
  end

  # ============================================================================
  # BASIC AGENT SETUP STEPS
  # ============================================================================

  step "I have at least one enabled agent available", context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})

    agent = agent_fixture(user, %{name: "Test Agent", enabled: true})
    existing_agents = get_agents(context)

    {:ok,
     context
     |> Map.put(:agents, Map.put(existing_agents, "Test Agent", agent))
     |> Map.put(:default_agent, agent)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I have a workspace with an enabled agent", context do
    updated_context = setup_workspace_with_agents(context, [{"Test Agent", %{}}])
    {:ok, updated_context}
  end

  step "I have a workspace with enabled agents", context do
    updated_context =
      setup_workspace_with_agents(context, [
        {"Test Agent", %{}},
        {"Code Helper", %{}}
      ])

    {:ok, updated_context}
  end

  step "an agent is selected", context do
    agent = ensure_selected_agent(context)
    {:ok, Map.put(context, :selected_agent, agent)}
  end

  step "multiple agents are available", context do
    user = context[:current_user]
    workspace = get_workspace(context) || create_default_workspace(user)

    {agent1, agent2} = create_default_agent_pair(user, workspace)
    agents_map = build_agents_map(context, agent1, agent2)

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:agents, agents_map)}
  end

  step "I previously selected agent {string} in this workspace",
       %{args: [agent_name]} = context do
    user = context[:current_user]

    workspace =
      get_workspace(context) ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    existing_agents = get_agents(context)

    agent =
      Map.get(existing_agents, agent_name) ||
        agent_fixture(user, %{name: agent_name, enabled: true})

    :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:agents, Map.put(existing_agents, agent_name, agent))
     |> Map.put(:selected_agent, agent)}
  end
end

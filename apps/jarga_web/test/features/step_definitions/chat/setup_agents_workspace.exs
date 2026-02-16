defmodule ChatSetupAgentsWorkspaceSteps do
  @moduledoc """
  Step definitions for Chat Panel Workspace Agent Configuration.

  Covers:
  - Workspace agent ordering
  - Workspace agent assignment
  - Workspace agent availability

  Related modules:
  - ChatSetupAgentsSteps - Basic agent setup
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

  defp get_map_from_context(context, key) do
    case context[key] do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  # ============================================================================
  # WORKSPACE AGENT CONFIGURATION STEPS
  # ============================================================================

  step "workspace has agents {string} and {string} in that order",
       %{args: [agent1_name, agent2_name]} = context do
    user = context[:current_user]

    workspace =
      get_workspace(context) ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    agent1 = agent_fixture(user, %{name: agent1_name, enabled: true})
    agent2 = agent_fixture(user, %{name: agent2_name, enabled: true})

    :ok = Agents.sync_agent_workspaces(agent1.id, user.id, [workspace.id])
    :ok = Agents.sync_agent_workspaces(agent2.id, user.id, [workspace.id])

    existing_agents = get_agents(context)

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(
       :agents,
       existing_agents |> Map.put(agent1_name, agent1) |> Map.put(agent2_name, agent2)
     )}
  end

  step "workspace {string} has no enabled agents", %{args: [ws_name]} = context do
    user = context[:current_user]
    workspace = workspace_fixture(user, %{name: ws_name, slug: Slugy.slugify(ws_name)})

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "workspace {string} has the following enabled agents:", context do
    user = context[:current_user]
    ws_name = context[:args] |> List.first()

    workspace =
      get_workspace(context) ||
        workspace_fixture(user, %{name: ws_name, slug: Slugy.slugify(ws_name)})

    rows = context.datatable.maps
    existing_agents = get_agents(context)

    agents =
      Enum.reduce(rows, existing_agents, fn row, acc ->
        agent_name = Map.values(row) |> List.first()
        agent = agent_fixture(user, %{name: agent_name, enabled: true})
        :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])
        Map.put(acc, agent_name, agent)
      end)

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:agents, agents)}
  end

  step "workspace {string} has enabled agent {string}",
       %{args: [ws_name, agent_name]} = context do
    user = context[:current_user]
    existing_workspaces = get_map_from_context(context, :workspaces)

    workspace =
      Map.get(existing_workspaces, ws_name) ||
        workspace_fixture(user, %{name: ws_name, slug: Slugy.slugify(ws_name)})

    agent = agent_fixture(user, %{name: agent_name, enabled: true})
    :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    existing_agents = get_agents(context)

    {:ok,
     context
     |> Map.put(:workspaces, Map.put(existing_workspaces, ws_name, workspace))
     |> Map.put(:agents, Map.put(existing_agents, agent_name, agent))}
  end

  step "workspace {string} has disabled agent {string}",
       %{args: [ws_name, agent_name]} = context do
    user = context[:current_user]
    existing_workspaces = get_map_from_context(context, :workspaces)

    workspace =
      Map.get(existing_workspaces, ws_name) ||
        workspace_fixture(user, %{name: ws_name, slug: Slugy.slugify(ws_name)})

    agent = agent_fixture(user, %{name: agent_name, enabled: false})
    :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    existing_agents = get_agents(context)

    {:ok,
     context
     |> Map.put(:workspaces, Map.put(existing_workspaces, ws_name, workspace))
     |> Map.put(:agents, Map.put(existing_agents, agent_name, agent))}
  end

  step "workspace has an enabled agent named {string}", %{args: [agent_name]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    agent = agent_fixture(user, %{name: agent_name, enabled: true})
    :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    agents = context[:agents] || %{}

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:agents, Map.put(agents, agent_name, agent))
     |> Map.put(:agent, agent)}
  end

  step "workspace has an agent named {string}", %{args: [agent_name]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    agent = Jarga.AgentsFixtures.agent_fixture(user, %{name: agent_name, enabled: true})
    :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    agents = context[:agents] || %{}

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:agents, Map.put(agents, agent_name, agent))
     |> Map.put(:agent, agent)}
  end
end

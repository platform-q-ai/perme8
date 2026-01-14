defmodule AgentAssignFixturesSteps do
  @moduledoc """
  Agent workspace fixture step definitions.

  Covers:
  - Creating agents with workspace associations
  - Adding agents to workspaces via fixtures
  - Workspace agent setup for tests

  Related files:
  - assign.exs - Core assignment actions
  - assign_verify.exs - Verification steps
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_or_create_workspace(context, ws_name) do
    case get_in(context, [:workspaces, ws_name]) do
      nil ->
        slug = ws_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
        owner = user_fixture(%{email: "#{slug}-owner@example.com"})
        workspace = workspace_fixture(owner, %{name: ws_name, slug: slug})

        if context[:current_user] do
          add_workspace_member_fixture(workspace.id, context[:current_user], :member)
        end

        {workspace, owner}

      workspace ->
        {workspace, nil}
    end
  end

  defp update_context_with_workspaces(context, workspace_data) do
    Enum.reduce(workspace_data, context, fn {name, workspace, owner}, ctx ->
      ctx = Map.put(ctx, :workspaces, Map.put(Map.get(ctx, :workspaces, %{}), name, workspace))

      if owner do
        Map.put(
          ctx,
          :workspace_owners,
          Map.put(Map.get(ctx, :workspace_owners, %{}), name, owner)
        )
      else
        ctx
      end
    end)
  end

  defp get_or_create_workspace_in_context(ws_name, user, existing_workspaces) do
    workspace =
      Map.get(existing_workspaces, ws_name) ||
        workspace_fixture(user, %{name: ws_name, slug: Slugy.slugify(ws_name)})

    {workspace, Map.put(existing_workspaces, ws_name, workspace)}
  end

  defp get_workspaces_map(%{workspaces: ws}) when is_map(ws), do: ws
  defp get_workspaces_map(_context), do: %{}

  defp get_agents_map(%{agents: agents}) when is_map(agents), do: agents
  defp get_agents_map(_context), do: %{}

  # ============================================================================
  # FIXTURE STEPS
  # ============================================================================

  step "I have an agent named {string} added to workspaces:", %{args: [name]} = context do
    table_data = context.datatable.maps
    user = context[:current_user]

    agent = agent_fixture(user, %{name: name})

    workspaces =
      Enum.reduce(table_data, Map.get(context, :workspaces, %{}), fn row, acc ->
        ws_name = row["Workspace Name"]
        slug = ws_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
        workspace = workspace_fixture(user, %{name: ws_name, slug: slug})

        WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

        Map.put(acc, ws_name, workspace)
      end)

    agents = Map.get(context, :agents, %{})

    context
    |> Map.put(:agent, agent)
    |> Map.put(:agents, Map.put(agents, name, agent))
    |> Map.put(:workspaces, workspaces)
  end

  step "{string} is added to workspace {string}",
       %{args: [agent_name, workspace_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    {workspace, owner} = get_or_create_workspace(context, workspace_name)

    WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

    context = update_context_with_workspaces(context, [{workspace_name, workspace, owner}])

    {:ok, context}
  end

  step "{string} is in workspaces {string} and {string}",
       %{args: [agent_name, ws1, ws2]} = context do
    agent = get_in(context, [:agents, agent_name])

    {workspace1, owner1} = get_or_create_workspace(context, ws1)
    {workspace2, owner2} = get_or_create_workspace(context, ws2)

    WorkspaceAgentRepository.add_to_workspace(workspace1.id, agent.id)
    WorkspaceAgentRepository.add_to_workspace(workspace2.id, agent.id)

    context =
      context
      |> update_context_with_workspaces([{ws1, workspace1, owner1}, {ws2, workspace2, owner2}])

    {:ok, context}
  end

  step "{string} is in workspaces {string}, {string}, and {string}",
       %{args: [agent_name, ws1, ws2, ws3]} = context do
    agent = get_in(context, [:agents, agent_name])

    {workspace1, owner1} = get_or_create_workspace(context, ws1)
    {workspace2, owner2} = get_or_create_workspace(context, ws2)
    {workspace3, owner3} = get_or_create_workspace(context, ws3)

    WorkspaceAgentRepository.add_to_workspace(workspace1.id, agent.id)
    WorkspaceAgentRepository.add_to_workspace(workspace2.id, agent.id)
    WorkspaceAgentRepository.add_to_workspace(workspace3.id, agent.id)

    context =
      context
      |> update_context_with_workspaces([
        {ws1, workspace1, owner1},
        {ws2, workspace2, owner2},
        {ws3, workspace3, owner3}
      ])

    {:ok, context}
  end

  step "workspace has agents {string} and {string}",
       %{args: [agent1, agent2]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    a1 = agent_fixture(user, %{name: agent1})
    a2 = agent_fixture(user, %{name: agent2})

    WorkspaceAgentRepository.add_to_workspace(workspace.id, a1.id)
    WorkspaceAgentRepository.add_to_workspace(workspace.id, a2.id)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, agents |> Map.put(agent1, a1) |> Map.put(agent2, a2))}
  end

  step "workspace has agents {string}, {string}, {string}",
       %{args: [agent1, agent2, agent3]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    a1 = agent_fixture(user, %{name: agent1})
    a2 = agent_fixture(user, %{name: agent2})
    a3 = agent_fixture(user, %{name: agent3})

    WorkspaceAgentRepository.add_to_workspace(workspace.id, a1.id)
    WorkspaceAgentRepository.add_to_workspace(workspace.id, a2.id)
    WorkspaceAgentRepository.add_to_workspace(workspace.id, a3.id)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(
       :agents,
       agents |> Map.put(agent1, a1) |> Map.put(agent2, a2) |> Map.put(agent3, a3)
     )}
  end

  step "I have no saved agent preference for this workspace", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    assert user, "User must be logged in"
    assert workspace, "Workspace must be created in a prior step"

    saved_agent_id = Jarga.Accounts.get_selected_agent_id(user.id, workspace.id)

    assert saved_agent_id == nil,
           "Expected no saved agent preference, but found: #{inspect(saved_agent_id)}"

    {:ok, Map.put(context, :selected_agent_id, nil)}
  end

  step "workspace {string} has agent {string}", %{args: [ws_name, agent_name]} = context do
    user = context[:current_user]

    existing_workspaces = get_workspaces_map(context)
    existing_agents = get_agents_map(context)

    {workspace, workspaces} =
      get_or_create_workspace_in_context(ws_name, user, existing_workspaces)

    agent = agent_fixture(user, %{name: agent_name})
    WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

    %{
      workspaces: workspaces,
      agents: Map.put(existing_agents, agent_name, agent)
    }
  end

  step "I have an agent {string} in workspace {string}",
       %{args: [agent_name, ws_name]} = context do
    user = context[:current_user]

    {workspace, owner} = get_or_create_workspace(context, ws_name)

    agent =
      get_in(context, [:agents, agent_name]) ||
        agent_fixture(user, %{name: agent_name, visibility: "SHARED"})

    WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

    agents = Map.get(context, :agents, %{})

    context =
      context
      |> update_context_with_workspaces([{ws_name, workspace, owner}])
      |> Map.put(:agent, agent)
      |> Map.put(:agents, Map.put(agents, agent_name, agent))
      |> Map.put(:workspace, workspace)

    {:ok, context}
  end

  step "I have an agent {string} in workspaces {string} and {string}",
       %{args: [agent_name, ws1, ws2]} = context do
    user = context[:current_user]

    {workspace1, owner1} = get_or_create_workspace(context, ws1)
    {workspace2, owner2} = get_or_create_workspace(context, ws2)

    agent = agent_fixture(user, %{name: agent_name, visibility: "SHARED"})

    WorkspaceAgentRepository.add_to_workspace(workspace1.id, agent.id)
    WorkspaceAgentRepository.add_to_workspace(workspace2.id, agent.id)

    agents = Map.get(context, :agents, %{})

    context =
      context
      |> update_context_with_workspaces([{ws1, workspace1, owner1}, {ws2, workspace2, owner2}])
      |> Map.put(:agent, agent)
      |> Map.put(:agents, Map.put(agents, agent_name, agent))

    {:ok, context}
  end
end

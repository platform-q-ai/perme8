defmodule AgentAssignSteps do
  @moduledoc """
  Agent workspace assignment action step definitions.

  Covers:
  - Adding agents to workspaces
  - Removing agents from workspaces
  - Syncing workspace associations
  - Agent selection in chat panel

  Related files:
  - assign_fixtures.exs - Fixture steps
  - assign_verify.exs - Verification steps
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Agents.AgentsFixtures

  alias Agents

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

  # ============================================================================
  # ACTION STEPS
  # ============================================================================

  step "I add agent {string} to the workspace", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = context[:workspace] || context[:current_workspace]
    user = context[:current_user]

    current_workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    new_workspace_ids = [workspace.id | current_workspace_ids] |> Enum.uniq()

    result = Agents.sync_agent_workspaces(agent.id, user.id, new_workspace_ids)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I remove agent {string} from the workspace", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = context[:workspace] || context[:current_workspace]
    user = context[:current_user]

    current_workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    new_workspace_ids = Enum.reject(current_workspace_ids, &(&1 == workspace.id))

    result = Agents.sync_agent_workspaces(agent.id, user.id, new_workspace_ids)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I attempt to add {string} to workspace {string}",
       %{args: [agent_name, workspace_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = get_in(context, [:workspaces, workspace_name])
    user = context[:current_user]

    result = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I sync agent workspaces to include {string}, {string}, and {string}",
       %{args: [ws1, ws2, ws3]} = context do
    agent = context[:agent]
    user = context[:current_user]

    workspace_ids_before = Agents.get_agent_workspace_ids(agent.id)

    {workspace1, owner1} = get_or_create_workspace(context, ws1)
    {workspace2, owner2} = get_or_create_workspace(context, ws2)
    {workspace3, owner3} = get_or_create_workspace(context, ws3)

    workspace_ids = [workspace1.id, workspace2.id, workspace3.id]
    result = Agents.sync_agent_workspaces(agent.id, user.id, workspace_ids)

    context =
      context
      |> update_context_with_workspaces([
        {ws1, workspace1, owner1},
        {ws2, workspace2, owner2},
        {ws3, workspace3, owner3}
      ])
      |> Map.put(:workspace_ids_before, workspace_ids_before)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I sync agent workspaces to only {string} and {string}",
       %{args: [ws1, ws2]} = context do
    agent = context[:agent]
    user = context[:current_user]

    workspace_ids_before = Agents.get_agent_workspace_ids(agent.id)

    workspace1 = get_in(context, [:workspaces, ws1])
    workspace2 = get_in(context, [:workspaces, ws2])

    workspace_ids = [workspace1.id, workspace2.id]
    result = Agents.sync_agent_workspaces(agent.id, user.id, workspace_ids)

    {:ok,
     context
     |> Map.put(:last_result, result)
     |> Map.put(:workspace_ids_before, workspace_ids_before)}
  end

  step "I remove {string} from workspace {string}", %{args: [agent_name, ws_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = get_in(context, [:workspaces, ws_name])
    user = context[:current_user]

    current_workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    new_workspace_ids = Enum.reject(current_workspace_ids, &(&1 == workspace.id))

    result = Agents.sync_agent_workspaces(agent.id, user.id, new_workspace_ids)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I add {string} to workspace {string}", %{args: [agent_name, ws_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = get_in(context, [:workspaces, ws_name])
    user = context[:current_user]

    current_workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    new_workspace_ids = [workspace.id | current_workspace_ids] |> Enum.uniq()

    result = Agents.sync_agent_workspaces(agent.id, user.id, new_workspace_ids)

    {:ok, Map.put(context, :last_result, result)}
  end

  # ============================================================================
  # SELECTION STEPS
  # ============================================================================

  step "I select agent {string} in the chat panel", %{args: [agent_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]
    existing_agents = context[:agents] || %{}

    agent =
      Map.get(existing_agents, agent_name) ||
        agent_fixture(user, %{name: agent_name, enabled: true})

    {:ok, _updated_user} = Jarga.Accounts.set_selected_agent_id(user.id, workspace.id, agent.id)

    updated_agents = Map.put(existing_agents, agent_name, agent)

    {:ok,
     context
     |> Map.put(:selected_agent, agent)
     |> Map.put(:agents, updated_agents)
     |> Map.put(:workspace, workspace)}
  end

  step "I select agent {string} in workspace {string}",
       %{args: [agent_name, workspace_name]} = context do
    selections = Map.get(context, :workspace_selections, %{})

    {:ok,
     context
     |> Map.put(:workspace_selections, Map.put(selections, workspace_name, agent_name))}
  end
end

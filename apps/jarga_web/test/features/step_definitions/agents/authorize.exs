defmodule AgentAuthorizeSteps do
  @moduledoc """
  Agent authorization and policy step definitions.

  Covers:
  - Permission checks for editing
  - Permission checks for deleting
  - Visibility controls
  - Agent discoverability
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Accounts
  alias Jarga.Agents
  alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository

  # ============================================================================
  # SETUP STEPS
  # ============================================================================

  step "{string} is a member of workspace {string}", %{args: [user_name, ws_name]} = context do
    user =
      get_in(context, [:users, user_name]) ||
        get_or_create_user_by_name(user_name)

    workspace = get_in(context, [:workspaces, ws_name]) || context[:workspace]

    try do
      add_workspace_member_fixture(workspace.id, user, :member)
    rescue
      # Handle both Ecto.ConstraintError and Ecto.InvalidChangesetError
      # when user is already a member (e.g., as owner)
      Ecto.ConstraintError -> :ok
      Ecto.InvalidChangesetError -> :ok
    end

    users = Map.get(context, :users, %{})

    {:ok, Map.put(context, :users, Map.put(users, user_name, user))}
  end

  step "workspace member {string} can see {string}",
       %{args: [user_name, agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    assert agent, "Agent '#{agent_name}' must be created in a prior step"

    workspace = context[:workspace] || context[:current_workspace]
    assert workspace, "Workspace must be created in a prior step"

    {user, context} = get_or_create_workspace_member(context, user_name, workspace)

    viewable_agents = Jarga.Agents.list_viewable_agents(user.id)
    viewable_ids = Enum.map(viewable_agents, & &1.id)

    assert agent.id in viewable_ids,
           "Workspace member '#{user_name}' should be able to see agent '#{agent_name}'"

    {:ok, context}
  end

  defp get_or_create_workspace_member(context, user_name, workspace) do
    existing_user = get_in(context, [:users, user_name])
    get_or_create_workspace_member_impl(context, user_name, workspace, existing_user)
  end

  defp get_or_create_workspace_member_impl(context, _user_name, _workspace, existing_user)
       when not is_nil(existing_user) do
    {existing_user, context}
  end

  defp get_or_create_workspace_member_impl(context, user_name, workspace, nil) do
    new_user = get_or_create_user_by_name(user_name)

    add_workspace_member_fixture(workspace.id, new_user, :member)

    users = Map.get(context, :users, %{})
    {new_user, Map.put(context, :users, Map.put(users, user_name, new_user))}
  end

  # ============================================================================
  # DISCOVERY STEPS
  # ============================================================================

  step "{string} searches for available agents", %{args: [user_name]} = context do
    user = get_in(context, [:users, user_name])

    agents = Agents.list_viewable_agents(user.id)

    {:ok,
     context
     |> Map.put(:searched_agents, agents)
     |> Map.put(:search_user, user)}
  end

  step "{string} views agents in workspace {string}", %{args: [user_name, ws_name]} = context do
    user = get_in(context, [:users, user_name])
    workspace = get_in(context, [:workspaces, ws_name]) || context[:workspace]

    result = Agents.list_workspace_available_agents(workspace.id, user.id)
    all_agents = (result.my_agents || []) ++ (result.other_agents || [])

    {:ok,
     context
     |> Map.put(:viewed_agents, all_agents)
     |> Map.put(:viewing_user, user)}
  end

  step "I view agents in workspace {string} context", %{args: [ws_name]} = context do
    user = context[:current_user]
    workspace = get_in(context, [:workspaces, ws_name]) || context[:workspace]

    result = Agents.list_workspace_available_agents(workspace.id, user.id)
    all_agents = (result.my_agents || []) ++ (result.other_agents || [])

    {:ok,
     context
     |> Map.put(:viewed_agents, all_agents)
     |> Map.put(:last_html, "Agents: #{Enum.map_join(all_agents, ", ", & &1.name)}")}
  end

  # ============================================================================
  # SETUP WITH WORKSPACE AGENTS
  # ============================================================================

  step "workspace {string} has the following agents:", %{args: [ws_name]} = context do
    table_data = context.datatable.maps
    user = context[:current_user]
    workspace = get_in(context, [:workspaces, ws_name]) || context[:workspace]
    users = context[:users] || %{}

    agents =
      Enum.reduce(table_data, Map.get(context, :agents, %{}), fn row, acc ->
        owner_name = row["Owner"]

        owner = get_or_create_owner(owner_name, user, users, workspace)

        agent =
          agent_fixture(owner, %{
            name: row["Agent Name"],
            visibility: row["Visibility"]
          })

        WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

        Map.put(acc, row["Agent Name"], agent)
      end)

    Map.put(context, :agents, agents)
  end

  defp get_or_create_owner("Me", user, _users, _workspace), do: user

  defp get_or_create_owner(owner_name, _user, users, workspace) do
    Map.get(users, owner_name) ||
      create_workspace_member(owner_name, workspace)
  end

  defp create_workspace_member(name, workspace) do
    other = get_or_create_user_by_name(name)

    add_workspace_member_fixture(workspace.id, other, :member)
    other
  end

  defp get_or_create_user_by_name(name) do
    email = "#{name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")}@example.com"

    case Accounts.get_user_by_email(email) do
      nil -> user_fixture(%{email: email, first_name: name})
      existing_user -> existing_user
    end
  end

  # ============================================================================
  # ASSERTION STEPS
  # ============================================================================

  step "{string} should not see {string}", %{args: [_user_name, agent_name]} = context do
    agents = context[:searched_agents] || context[:viewed_agents]
    agent_names = Enum.map(agents, & &1.name)

    refute agent_name in agent_names

    {:ok, context}
  end

  step "{string} should see {string}", %{args: [_user_name, agent_name]} = context do
    agents = context[:searched_agents] || context[:viewed_agents]
    agent_names = Enum.map(agents, & &1.name)

    assert agent_name in agent_names

    {:ok, context}
  end

  step "{string} cannot select {string} in the chat panel",
       %{args: [_user_name, agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    assert agent.enabled == false
    {:ok, context}
  end

  step "{string} should no longer see {string} in the workspace agents list",
       %{args: [_user_name, agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    assert agent.enabled == false
    {:ok, context}
  end

  step "other workspace members should not see {string} because it's PRIVATE",
       %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    assert agent.visibility == "PRIVATE"

    workspace = context[:workspace] || context[:current_workspace]

    other_user = user_fixture(%{email: "other-member@example.com"})
    add_workspace_member_fixture(workspace.id, other_user, :member)

    result = Jarga.Agents.list_workspace_available_agents(workspace.id, other_user.id)
    all_agents = (result.my_agents || []) ++ (result.other_agents || [])
    agent_names = Enum.map(all_agents, & &1.name)

    refute agent_name in agent_names,
           "Private agent '#{agent_name}' should not be visible to other workspace members"

    {:ok, context}
  end

  step "{string} should appear in their agent selectors\"", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name]) || context[:agent]

    workspace =
      context[:current_workspace] ||
        context[:workspace] ||
        get_first_workspace_from_context(context)

    assert agent != nil, "Agent '#{agent_name}' not found in context"
    assert workspace != nil, "No workspace found in context"

    workspace_ids = Jarga.Agents.get_agent_workspace_ids(agent.id)

    assert workspace.id in workspace_ids,
           "Agent '#{agent_name}' should be in workspace '#{workspace.name}'"

    assert agent.visibility != "SHARED" or agent.enabled == true,
           "Shared agent '#{agent_name}' should be enabled to appear in selector"

    {:ok, context}
  end

  defp get_first_workspace_from_context(context) do
    case context[:workspaces] do
      workspaces when is_map(workspaces) and map_size(workspaces) > 0 ->
        workspaces |> Map.values() |> List.first()

      _ ->
        nil
    end
  end
end

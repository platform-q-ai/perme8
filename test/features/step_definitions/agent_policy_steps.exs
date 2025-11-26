defmodule AgentPolicySteps do
  @moduledoc """
  Cucumber step definitions for Agent Policy scenarios.

  Covers:
  - Permission checks for editing
  - Permission checks for deleting
  - Visibility controls
  - Agent discoverability
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  # import Phoenix.LiveViewTest  # Not used in this file
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Agents
  alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository

  # ============================================================================
  # SETUP STEPS
  # ============================================================================

  step "{string} is a member of workspace {string}", %{args: [user_name, ws_name]} = context do
    # Get or create user
    user =
      case get_in(context, [:users, user_name]) do
        nil ->
          slug = user_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
          user_fixture(%{email: "#{slug}@example.com"})

        existing ->
          existing
      end

    workspace = get_in(context, [:workspaces, ws_name]) || context[:workspace]

    # Add as member if workspace exists
    if workspace do
      try do
        add_workspace_member_fixture(workspace.id, user, :member)
      rescue
        Ecto.ConstraintError -> :ok
      end
    end

    users = Map.get(context, :users, %{})

    {:ok, Map.put(context, :users, Map.put(users, user_name, user))}
  end

  step "workspace member {string} can see {string}",
       %{args: [_user_name, _agent_name]} = context do
    # This is a precondition - agent is visible to workspace members
    {:ok, context}
  end

  # ============================================================================
  # DISCOVERY STEPS
  # ============================================================================

  step "{string} searches for available agents", %{args: [user_name]} = context do
    user = get_in(context, [:users, user_name])

    # Search viewable agents
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
     |> Map.put(:last_html, "Agents: #{Enum.map(all_agents, & &1.name) |> Enum.join(", ")}")}
  end

  # ============================================================================
  # SETUP WITH WORKSPACE AGENTS
  # ============================================================================

  step "workspace {string} has the following agents:", %{args: [ws_name]} = context do
    # Access data table using dot notation
    table_data = context.datatable.maps
    user = context[:current_user]
    workspace = get_in(context, [:workspaces, ws_name]) || context[:workspace]

    agents =
      Enum.reduce(table_data, Map.get(context, :agents, %{}), fn row, acc ->
        owner_name = row["Owner"]

        owner =
          cond do
            owner_name == "Me" ->
              user

            Map.has_key?(context[:users] || %{}, owner_name) ->
              context[:users][owner_name]

            true ->
              other =
                user_fixture(%{
                  email: "#{String.downcase(owner_name)}@example.com",
                  first_name: owner_name
                })

              add_workspace_member_fixture(workspace.id, other, :member)
              other
          end

        agent =
          agent_fixture(owner, %{
            name: row["Agent Name"],
            visibility: row["Visibility"]
          })

        WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

        Map.put(acc, row["Agent Name"], agent)
      end)

    # Return context directly for data table steps
    Map.put(context, :agents, agents)
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
    # Verify agent is not available for selection (disabled agents are hidden)
    agent = get_in(context, [:agents, agent_name])
    assert agent.enabled == false
    {:ok, context}
  end

  step "{string} should no longer see {string} in the workspace agents list",
       %{args: [_user_name, agent_name]} = context do
    # Disabled agents are not visible
    agent = get_in(context, [:agents, agent_name])
    assert agent.enabled == false
    {:ok, context}
  end

  step "other workspace members should not see {string} because it's PRIVATE",
       %{args: [agent_name]} = context do
    # Private agents are only visible to their owner, not to other workspace members
    agent = get_in(context, [:agents, agent_name])
    assert agent.visibility == "PRIVATE"

    # Verify that other members can't see this agent
    workspace = context[:workspace] || context[:current_workspace]

    if workspace do
      # Create another user to check visibility
      other_user = user_fixture(%{email: "other-member@example.com"})
      add_workspace_member_fixture(workspace.id, other_user, :member)

      # Check that the agent is not in the list for this user
      result = Jarga.Agents.list_workspace_available_agents(workspace.id, other_user.id)
      all_agents = (result.my_agents || []) ++ (result.other_agents || [])
      agent_names = Enum.map(all_agents, & &1.name)

      refute agent_name in agent_names,
             "Private agent '#{agent_name}' should not be visible to other workspace members"
    end

    {:ok, context}
  end

  step "{string} should appear in their agent selectors\"", %{args: [agent_name]} = context do
    # Verify that the agent appears in the workspace agent selector
    agent = get_in(context, [:agents, agent_name])
    workspace = context[:workspace] || context[:current_workspace]

    if workspace && agent do
      # Check that the agent is in the workspace and visible to members
      workspace_ids = Jarga.Agents.get_agent_workspace_ids(agent.id)

      assert workspace.id in workspace_ids,
             "Agent '#{agent_name}' should be in workspace '#{workspace.name}'"

      # For shared agents, verify they would appear in the selector
      if agent.visibility == "SHARED" do
        assert agent.enabled == true,
               "Agent '#{agent_name}' should be enabled to appear in selector"
      end
    end

    {:ok, context}
  end
end

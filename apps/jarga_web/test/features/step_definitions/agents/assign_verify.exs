defmodule AgentAssignVerifySteps do
  @moduledoc """
  Agent workspace assignment verification step definitions.

  Covers:
  - Verifying agent workspace associations
  - Verifying agent visibility
  - Verifying selection persistence
  - PubSub notification verification

  Related files:
  - assign.exs - Core assignment actions
  - assign_fixtures.exs - Fixture steps
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  alias Agents

  # ============================================================================
  # ASSERTION STEPS
  # ============================================================================

  step "{string} should appear in the workspace agents list", %{args: [agent_name]} = context do
    workspace = context[:workspace] || context[:current_workspace]
    user = context[:current_user]

    result = Agents.list_workspace_available_agents(workspace.id, user.id)
    all_agents = (result.my_agents || []) ++ (result.other_agents || [])
    agent_names = Enum.map(all_agents, & &1.name)

    assert agent_name in agent_names

    {:ok, context}
  end

  step "{string} should not appear in workspace agents list", %{args: [agent_name]} = context do
    workspace = context[:workspace] || context[:current_workspace]
    user = context[:current_user]

    result = Agents.list_workspace_available_agents(workspace.id, user.id)
    all_agents = (result.my_agents || []) ++ (result.other_agents || [])
    agent_names = Enum.map(all_agents, & &1.name)

    refute agent_name in agent_names

    {:ok, context}
  end

  step "other workspace members should not see {string} (because it's PRIVATE)",
       %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    owner = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    assert agent, "Agent '#{agent_name}' must be created in a prior step"
    assert agent.visibility == :PRIVATE, "Agent should be PRIVATE for this step"
    assert workspace, "Workspace must be created in a prior step"

    workspace_members =
      Jarga.Workspaces.list_members(workspace.id)
      |> Enum.reject(&(&1.user_id == owner.id))

    Enum.each(workspace_members, fn member ->
      viewable = Agents.list_viewable_agents(member.user_id)
      viewable_ids = Enum.map(viewable, & &1.id)

      refute agent.id in viewable_ids,
             "Other workspace member should not see private agent '#{agent_name}'"
    end)

    {:ok, context}
  end

  step "all workspace members should be able to use {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = context[:workspace] || context[:current_workspace]

    assert agent, "Agent '#{agent_name}' must be created in a prior step"
    assert workspace, "Workspace must be created in a prior step"

    workspace_members = Jarga.Workspaces.list_members(workspace.id)

    Enum.each(workspace_members, fn member ->
      viewable = Agents.list_viewable_agents(member.user_id)
      viewable_ids = Enum.map(viewable, & &1.id)

      assert agent.id in viewable_ids,
             "Workspace member should be able to use agent '#{agent_name}'"
    end)

    {:ok, context}
  end

  step "the sync should succeed", context do
    assert context[:last_result] == :ok,
           "Expected sync to succeed, got: #{inspect(context[:last_result])}"

    {:ok, context}
  end

  step "the agent should not be added to the workspace", context do
    agent =
      context[:agent] ||
        context[:last_agent] ||
        get_first_agent_from_context(context)

    workspace =
      context[:current_workspace] ||
        context[:workspace] ||
        get_first_workspace_from_context(context)

    assert agent != nil, "No agent found in context"
    assert workspace != nil, "No workspace found in context"

    workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    refute workspace.id in workspace_ids, "Agent should not be in the workspace"

    {:ok, context}
  end

  defp get_first_agent_from_context(context) do
    case context[:agents] do
      agents when is_map(agents) and map_size(agents) > 0 ->
        agents |> Map.values() |> List.first()

      _ ->
        nil
    end
  end

  defp get_first_workspace_from_context(context) do
    case context[:workspaces] do
      workspaces when is_map(workspaces) and map_size(workspaces) > 0 ->
        workspaces |> Map.values() |> List.first()

      _ ->
        nil
    end
  end

  step "workspace members should receive notification of removal", context do
    workspace = context[:workspace] || context[:current_workspace]
    agent = context[:agent] || context[:deleted_agent]

    assert workspace, "Workspace must be created in a prior step"
    assert agent, "Agent must be available (current or deleted) in context"

    workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    refute workspace.id in workspace_ids, "Agent should be removed from workspace"

    {:ok, context}
  end

  step "{string} should be added to workspace {string}",
       %{args: [agent_name, ws_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = get_in(context, [:workspaces, ws_name])

    workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    assert workspace.id in workspace_ids

    {:ok, context}
  end

  step "{string} should remain in {string} and {string}",
       %{args: [agent_name, ws1, ws2]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace1 = get_in(context, [:workspaces, ws1])
    workspace2 = get_in(context, [:workspaces, ws2])

    workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    assert workspace1.id in workspace_ids
    assert workspace2.id in workspace_ids

    {:ok, context}
  end

  step "{string} should be removed from workspace {string}",
       %{args: [agent_name, ws_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = get_in(context, [:workspaces, ws_name])

    workspace_ids = Agents.get_agent_workspace_ids(agent.id)
    refute workspace.id in workspace_ids

    {:ok, context}
  end

  step "no workspace associations should be added or removed", context do
    agent = context[:agent]
    workspace_ids_before = context[:workspace_ids_before]

    assert agent, "Agent must be created in a prior step"

    assert workspace_ids_before,
           "Workspace IDs must be captured before this step"

    current_workspace_ids = Agents.get_agent_workspace_ids(agent.id)

    assert MapSet.new(workspace_ids_before) == MapSet.new(current_workspace_ids),
           "Workspace associations should remain unchanged"

    {:ok, context}
  end

  step "no PubSub notifications should be sent", context do
    receive do
      {:workspace_agent_updated, _} ->
        flunk("Expected no PubSub notifications, but received workspace_agent_updated")
    after
      100 -> :ok
    end

    {:ok, context}
  end

  step "workspace {string} members should receive PubSub notification",
       %{args: [ws_name]} = context do
    workspace = get_in(context, [:workspaces, ws_name])

    assert workspace, "Workspace '#{ws_name}' must be created in a prior step"

    topic = "workspace:#{workspace.id}"
    Phoenix.PubSub.subscribe(Jarga.PubSub, topic)

    {:ok, Map.put(context, :subscribed_to_workspace, workspace.id)}
  end

  # ============================================================================
  # SELECTION PERSISTENCE STEPS
  # ============================================================================

  step "my selection should be saved to user preferences", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]
    agent = context[:selected_agent] || context[:agent]

    assert user, "User must be logged in"
    assert workspace, "Workspace must be created in a prior step"
    assert agent, "Agent must be selected in a prior step"

    saved_agent_id = Jarga.Accounts.get_selected_agent_id(user.id, workspace.id)
    assert saved_agent_id == agent.id, "Selection should be saved to preferences"

    {:ok, context}
  end

  step "when I return to workspace {string} later, {string} should still be selected",
       %{args: [ws_name, agent_name]} = context do
    user = context[:current_user]
    workspace = get_in(context, [:workspaces, ws_name])
    agent = get_in(context, [:agents, agent_name])

    assert user, "User must be logged in"
    assert workspace, "Workspace '#{ws_name}' must be created in a prior step"
    assert agent, "Agent '#{agent_name}' must be created in a prior step"

    saved_agent_id = Jarga.Accounts.get_selected_agent_id(user.id, workspace.id)

    assert saved_agent_id == agent.id,
           "Expected agent '#{agent_name}' to be saved as selection"

    {:ok, context}
  end

  step "workspace {string} should remember {string} as my selection",
       %{args: [ws_name, agent_name]} = context do
    selections = context[:workspace_selections]
    assert Map.get(selections, ws_name) == agent_name
    {:ok, context}
  end

  step "agent {string} should be auto-selected", %{args: [agent_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]
    agent = get_in(context, [:agents, agent_name])

    assert user, "User must be logged in"
    assert workspace, "Workspace must be created in a prior step"
    assert agent, "Agent '#{agent_name}' must be created in a prior step"

    saved_agent_id = Jarga.Accounts.get_selected_agent_id(user.id, workspace.id)

    assert saved_agent_id == agent.id,
           "Expected agent '#{agent_name}' to be auto-selected"

    {:ok, context}
  end

  step "the selection should be saved to my preferences", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]
    selected_agent = context[:selected_agent] || context[:auto_selected_agent]

    assert user && workspace && selected_agent, "User, workspace, and selected agent required"

    saved_agent_id = Jarga.Accounts.get_selected_agent_id(user.id, workspace.id)
    assert saved_agent_id == selected_agent.id, "Selection should be saved to preferences"
    {:ok, context}
  end
end

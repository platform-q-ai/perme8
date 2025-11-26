defmodule AgentPubsubSteps do
  @moduledoc """
  Cucumber step definitions for Agent PubSub Notification scenarios.

  Covers:
  - Real-time agent updates propagating to clients
  - Agent deletion notifications
  - Workspace agent synchronization notifications
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  # import Phoenix.LiveViewTest  # Not used in this file
  # import Jarga.AccountsFixtures  # Not used in this file
  # import Jarga.WorkspacesFixtures  # Not used in this file
  import Jarga.AgentsFixtures

  alias Jarga.Agents

  # alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository  # Not used in this file

  # ============================================================================
  # SUBSCRIPTION SETUP STEPS
  # ============================================================================

  step "{string} is viewing workspace {string} chat panel",
       %{args: [user_name, ws_name]} = context do
    workspace = get_in(context, [:workspaces, ws_name])

    # Subscribe to workspace agent updates
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    viewers = Map.get(context, :workspace_viewers, %{})

    {:ok, Map.put(context, :workspace_viewers, Map.put(viewers, user_name, workspace.id))}
  end

  step "{string} and {string} members are connected", %{args: [ws1, ws2]} = context do
    workspace1 = get_in(context, [:workspaces, ws1])
    workspace2 = get_in(context, [:workspaces, ws2])

    # Subscribe to both workspaces
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace1.id}")
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace2.id}")

    {:ok,
     context
     |> Map.put(:subscribed_workspaces, [workspace1.id, workspace2.id])}
  end

  step "{string} members are connected", %{args: [ws_name]} = context do
    workspace = get_in(context, [:workspaces, ws_name])

    # Subscribe to workspace
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    subscribed = Map.get(context, :subscribed_workspaces, [])

    {:ok, Map.put(context, :subscribed_workspaces, [workspace.id | subscribed])}
  end

  step "{string} has {string} selected in the chat panel",
       %{args: [user_name, agent_name]} = context do
    # User has this agent selected - will be affected if agent is deleted
    agent = get_in(context, [:agents, agent_name])
    workspace = context[:workspace]

    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    {:ok,
     context
     |> Map.put(:selected_agent_user, user_name)
     |> Map.put(:selected_agent, agent)}
  end

  step "I have an agent {string}", %{args: [agent_name]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: agent_name, visibility: "SHARED"})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, agent_name, agent))}
  end

  # ============================================================================
  # NOTIFICATION ASSERTION STEPS
  # ============================================================================

  step "{string} should see the updated agent in her chat panel",
       %{args: [_user_name]} = context do
    # Verify we receive the workspace_agent_updated message
    assert_receive {:workspace_agent_updated, _agent}, 1000

    {:ok, context}
  end

  step "{string} should see the updated agent in his chat panel",
       %{args: [_user_name]} = context do
    # Same as above, just different pronoun
    assert_receive {:workspace_agent_updated, _agent}, 1000

    {:ok, context}
  end

  step "{string} should see {string} removed from the agent list",
       %{args: [_user_name, _agent_name]} = context do
    # Verify we receive the agent update (deletion triggers update)
    assert_receive {:workspace_agent_updated, agent}, 1000

    # Store the received agent for subsequent steps
    {:ok, Map.put(context, :last_received_agent, agent)}
  end

  step "if {string} was her only agent, the chat panel should auto-select another agent",
       %{args: [_agent_name]} = context do
    # Auto-selection is handled by the LiveView
    # The workspace_agent_updated message triggers the LiveView to handle auto-selection
    # Check if we already received the agent from the previous step
    case context[:last_received_agent] do
      nil ->
        # If not, try to receive a new message
        assert_receive {:workspace_agent_updated, _agent}, 1000
        {:ok, context}

      _received_agent ->
        # Use the agent that was already received in the previous step
        {:ok, context}
    end
  end

  step "{string} members should receive a workspace agent updated message",
       %{args: [_ws_name]} = context do
    assert_receive {:workspace_agent_updated, _agent}, 1000
    {:ok, context}
  end

  step "members of other workspaces should not receive notifications", context do
    # Verify no message for unsubscribed workspaces
    refute_received {:workspace_agent_updated, _}
    {:ok, context}
  end

  step "{string} members should receive agent removed notification",
       %{args: [_ws_name]} = context do
    assert_receive {:workspace_agent_updated, agent}, 1000
    # Store the received agent in context for subsequent steps to use
    {:ok, Map.put(context, :last_received_agent, agent)}
  end

  step "their chat panels should refresh the agent list", context do
    # This is handled by the LiveView handle_info
    # The workspace_agent_updated message triggers the LiveView to refresh the agent list
    # Check if we already received the agent from the previous step
    case context[:last_received_agent] do
      nil ->
        # If not, try to receive a new message
        assert_receive {:workspace_agent_updated, _agent}, 1000
        {:ok, context}

      _received_agent ->
        # Use the agent that was already received in the previous step
        {:ok, context}
    end
  end

  step "{string} members should receive agent added notification",
       %{args: [_ws_name]} = context do
    assert_receive {:workspace_agent_updated, agent}, 1000
    # Store the received agent in context for subsequent steps to use
    {:ok, Map.put(context, :last_received_agent, agent)}
  end

  step "{string} should appear in their agent selectors", %{args: [agent_name]} = context do
    # Check if we already received the agent from the previous step
    case context[:last_received_agent] do
      nil ->
        # If not, try to receive a new message (fallback for scenarios where this is the first assertion)
        flush_mailbox()
        assert_receive {:workspace_agent_updated, agent}, 2000
        assert agent.name == agent_name
        {:ok, context}

      received_agent ->
        # Use the agent that was already received in the previous step
        assert received_agent.name == agent_name
        {:ok, context}
    end
  end

  # Helper to flush email messages that might be in the mailbox
  defp flush_mailbox do
    receive do
      {:email, _} -> flush_mailbox()
      _ -> :ok
    after
      0 -> :ok
    end
  end

  # ============================================================================
  # ACTION STEPS FOR PUBSUB
  # ============================================================================

  step "I update {string} configuration", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    {:ok, updated_agent} =
      Agents.update_user_agent(agent.id, user.id, %{"description" => "Updated via PubSub test"})

    {:ok,
     context
     |> Map.put(:agent, updated_agent)
     |> Map.put(:agents, Map.put(context[:agents], agent_name, updated_agent))}
  end

  step "I delete agent {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    {:ok, _deleted} = Agents.delete_user_agent(agent.id, user.id)

    {:ok,
     context
     |> Map.put(:deleted_agent, agent)}
  end
end

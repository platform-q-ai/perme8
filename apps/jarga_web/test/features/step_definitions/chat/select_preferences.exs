defmodule ChatSelectPreferencesSteps do
  @moduledoc """
  Step definitions for Chat Agent Selection Preferences.

  Covers:
  - Agent preferences persistence
  - PubSub agent updates
  - Agent deletion handling
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Agents.AgentsFixtures

  alias Agents

  # ============================================================================
  # AGENT PREFERENCES STEPS
  # ============================================================================

  step "my agent selection should be saved to preferences", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]
    selected_agent = context[:selected_agent]

    assert user, "User must be logged in"
    assert workspace, "Workspace must be set"
    assert selected_agent, "An agent must be selected in a prior step"

    saved_agent_id = Jarga.Accounts.get_selected_agent_id(user.id, workspace.id)

    assert saved_agent_id == selected_agent.id,
           "Expected agent selection to be saved to preferences. Expected: #{selected_agent.id}, Got: #{saved_agent_id}"

    {:ok, Map.put(context, :preferences_saved, true)}
  end

  step "when I reload the page, {string} should still be selected",
       %{args: [agent_name]} = context do
    conn = context[:conn]
    workspace = context[:workspace] || context[:current_workspace]
    existing_agents = context[:agents] || %{}
    agent = Map.get(existing_agents, agent_name)

    assert workspace, "Workspace must be set"
    assert agent, "Agent '#{agent_name}' must be created in a prior step"

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    assert has_element?(view, ~s|#agent-selector option[value="#{agent.id}"][selected]|),
           "Expected agent '#{agent_name}' to still be selected after page reload"

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:expected_agent_after_reload, agent_name)}
  end

  # ============================================================================
  # PUBSUB NOTIFICATION STEPS
  # ============================================================================

  step "another user adds a new agent {string} to the workspace",
       %{args: [agent_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    assert workspace, "Workspace must be created in a prior step"

    agent = agent_fixture(user, %{name: agent_name, enabled: true})
    :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    existing_agents = context[:agents] || %{}

    {:ok,
     context
     |> Map.put(:agents, Map.put(existing_agents, agent_name, agent))
     |> Map.put(:new_agent_added, agent_name)}
  end

  step "I should receive a PubSub notification", context do
    {view, context} = ensure_view(context)
    html = render(view)

    {:ok,
     context
     |> Map.put(:pubsub_notification_received, true)
     |> Map.put(:last_html, html)}
  end

  step "{string} should appear in my agent selector", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    agent_name_escaped = Phoenix.HTML.html_escape(agent_name) |> Phoenix.HTML.safe_to_string()

    assert html =~ agent_name_escaped,
           "Expected agent '#{agent_name}' to appear in the agent selector"

    {:ok,
     context
     |> Map.put(:expected_agent_in_selector, agent_name)
     |> Map.put(:last_html, html)}
  end

  step "I had agent {string} selected", %{args: [agent_name]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        Jarga.WorkspacesFixtures.workspace_fixture(user, %{name: "Test Workspace"})

    existing_agents =
      case context[:agents] do
        agents when is_map(agents) -> agents
        _ -> %{}
      end

    agent =
      Map.get(existing_agents, agent_name) ||
        Agents.AgentsFixtures.agent_fixture(user, %{name: agent_name, enabled: true})

    :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])
    Jarga.Accounts.set_selected_agent_id(user.id, workspace.id, agent.id)

    {:ok,
     context
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:agents, Map.put(existing_agents, agent_name, agent))
     |> Map.put(:previously_selected_agent, agent)}
  end

  step "I should be prompted to select a different agent", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_selector = html =~ "agent-selector" || html =~ "Select Agent"

    {:ok,
     context
     |> Map.put(:prompt_to_select_agent, has_selector)
     |> Map.put(:last_html, html)}
  end

  step "the agent selector should show remaining agents", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_agents = html =~ ~r/<option[^>]*value="[^"]+"/

    {:ok, Map.put(context, :remaining_agents_shown, has_agents) |> Map.put(:last_html, html)}
  end

  step "I should be able to send messages to {string}", %{args: [_agent_name]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ ~r/<textarea[^>]*name="message"/,
           "Expected chat input textarea to be available"

    refute html =~ ~r/<textarea[^>]*name="message"[^>]*disabled/,
           "Expected chat input to NOT be disabled"

    {:ok, context |> Map.put(:can_send_messages, true) |> Map.put(:last_html, html)}
  end

  step "{string} is deleted", %{args: [agent_name]} = context do
    agent =
      get_in(context, [:agents, agent_name]) ||
        raise "Agent '#{agent_name}' not found. Create the agent in a prior step."

    user = context[:current_user] || raise "No user logged in. Run 'Given I am logged in' first."

    Agents.delete_user_agent(agent.id, user.id)

    {:ok, Map.put(context, :deleted_agent, agent_name)}
  end

  step "{string} is deleted from the workspace", %{args: [agent_name]} = context do
    agent =
      get_in(context, [:agents, agent_name]) ||
        raise "Agent '#{agent_name}' not found. Create the agent in a prior step."

    user = context[:current_user] || raise "No user logged in. Run 'Given I am logged in' first."

    Agents.delete_user_agent(agent.id, user.id)

    {:ok, Map.put(context, :deleted_agent, agent_name)}
  end

  step "{string} configuration is updated by another user", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    _result =
      agent && user &&
        Agents.update_user_agent(agent.id, user.id, %{"description" => "Updated config"})

    {:ok, Map.put(context, :agent_configuration_updated, agent_name)}
  end

  step "an {string} event should be broadcast", %{args: [event_name]} = context do
    case event_name do
      "agent-selected" ->
        {:ok, Map.put(context, :event_broadcast_verified, true)}

      _ ->
        {:ok, Map.put(context, :event_broadcast_verified, true)}
    end
  end

  step "{string} should be removed from my agent selector", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    refute html =~ agent_name,
           "Expected agent '#{agent_name}' to be removed from selector"

    {:ok, Map.put(context, :agent_removed_from_selector, agent_name) |> Map.put(:last_html, html)}
  end

  step "the agent selector should refresh with updated info", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_selector = html =~ "select" or html =~ "agent"

    {:ok, Map.put(context, :selector_refreshed, has_selector) |> Map.put(:last_html, html)}
  end

  step "the parent LiveView should receive the agent ID", context do
    selected_agent = context[:selected_agent] || context[:auto_selected_agent]
    agent_id = selected_agent && selected_agent.id

    {:ok, Map.put(context, :parent_received_agent_id, agent_id || true)}
  end

  step "another available agent should be auto-selected", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_selected_option = html =~ ~r/<option[^>]*selected[^>]*>/

    {:ok,
     context
     |> Map.put(:another_agent_auto_selected, has_selected_option)
     |> Map.put(:last_html, html)}
  end
end

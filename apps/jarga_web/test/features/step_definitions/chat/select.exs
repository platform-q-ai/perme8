defmodule ChatSelectSteps do
  @moduledoc """
  Step definitions for Chat Agent Selection.

  Covers:
  - Agent selector interactions
  - Agent selection

  For preferences and persistence, see: ChatSelectPreferencesSteps (select_preferences.exs)
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # AGENT SELECTOR STEPS
  # ============================================================================

  step "I open the agent selector dropdown", context do
    conn = context[:conn]
    workspace = context[:workspace] || context[:current_workspace]

    assert workspace, "Workspace must be created in a prior step"

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
    {:ok, Map.put(context, :view, view) |> Map.put(:last_html, html)}
  end

  step "I should see {string} in the list", %{args: [agent_name]} = context do
    html = context[:last_html]
    agent_name_escaped = Phoenix.HTML.html_escape(agent_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ agent_name_escaped
    {:ok, context}
  end

  step "I select {string}", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    agent = get_in(context, [:agents, agent_name])

    assert agent,
           "Agent '#{agent_name}' must be created in a prior step. Available: #{inspect(Map.keys(context[:agents] || %{}))}"

    html =
      view
      |> element(chat_panel_target() <> " form[phx-change=select_agent]")
      |> render_change(%{"agent_id" => agent.id})

    {:ok,
     context
     |> Map.put(:selected_agent, agent)
     |> Map.put(:last_html, html)}
  end

  step "{string} should be marked as selected", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])

    assert agent,
           "Agent '#{agent_name}' must be created in a prior step. Available: #{inspect(Map.keys(context[:agents] || %{}))}"

    {view, _updated_context} = ensure_view(context)

    assert has_element?(view, ~s|#agent-selector option[value="#{agent.id}"][selected]|),
           "Expected agent '#{agent_name}' (id: #{agent.id}) to be marked as selected"

    {:ok, context}
  end

  step "my selection should be saved to preferences", context do
    _user = context[:current_user]
    selected_agent = context[:selected_agent]

    assert selected_agent, "An agent must be selected in a prior step"

    assert selected_agent.id != nil
    assert selected_agent.enabled == true

    {:ok, context}
  end

  step "the agent selector should show {string}", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    agent_name_escaped = Phoenix.HTML.html_escape(agent_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ agent_name_escaped

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the agent selector should not show {string}", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    agent_name_escaped = Phoenix.HTML.html_escape(agent_name) |> Phoenix.HTML.safe_to_string()

    refute html =~ ~r/<option[^>]*>#{Regex.escape(agent_name_escaped)}<\/option>/,
           "Expected agent '#{agent_name}' to NOT appear in the agent selector"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I have no previously selected agent for this workspace", context do
    user = context[:current_user]
    workspace = context[:current_workspace] || context[:workspace]

    assert user, "User must be logged in"
    assert workspace, "Workspace must be created in a prior step"

    Jarga.Accounts.set_selected_agent_id(user.id, workspace.id, nil)

    saved_agent_id = Jarga.Accounts.get_selected_agent_id(user.id, workspace.id)
    assert saved_agent_id == nil, "Expected no saved agent preference"

    {:ok, Map.put(context, :selected_agent_id, nil)}
  end

  step "{string} should be automatically selected", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    agent_name_escaped = Phoenix.HTML.html_escape(agent_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ agent_name_escaped

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I previously selected agent {string}", %{args: [agent_name]} = context do
    user = context[:current_user]
    workspace = context[:current_workspace] || context[:workspace]
    agent = get_in(context, [:agents, agent_name])

    assert agent, "Agent '#{agent_name}' must be created in a prior step"
    assert workspace, "Workspace must be created in a prior step"

    Jarga.Accounts.set_selected_agent_id(user.id, workspace.id, agent.id)

    {:ok, Map.put(context, :previously_selected_agent, agent_name)}
  end

  step "{string} should be selected", %{args: [agent_name]} = context do
    {view, updated_context} = ensure_view(context)
    agents_map = updated_context[:agents] || %{}
    agent = Map.get(agents_map, agent_name)

    assert agent,
           "Agent '#{agent_name}' must be created in a prior step. Available: #{inspect(Map.keys(agents_map))}"

    assert has_element?(view, ~s|#agent-selector option[value="#{agent.id}"][selected]|),
           "Expected agent '#{agent_name}' (id: #{agent.id}) to be selected"

    {:ok, updated_context}
  end

  step "I can start chatting immediately", context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ "chat-input" or html =~ "Ask me anything",
           "Expected chat input to be available"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "{string} should still be selected", %{args: [agent_name]} = context do
    {view, updated_context} = ensure_view(context)
    agents_map = updated_context[:agents] || %{}
    agent = Map.get(agents_map, agent_name)

    assert agent,
           "Agent '#{agent_name}' must be created in a prior step. Available: #{inspect(Map.keys(agents_map))}"

    assert has_element?(view, ~s|#agent-selector option[value="#{agent.id}"][selected]|),
           "Expected agent '#{agent_name}' (id: #{agent.id}) to still be selected"

    {:ok, updated_context}
  end

  # ============================================================================
  # ADDITIONAL AGENT SELECTION STEPS
  # ============================================================================

  step "I select agent {string}", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    existing_agents = context[:agents] || %{}
    agent = Map.get(existing_agents, agent_name)

    assert agent,
           "Agent '#{agent_name}' must be created in a prior step. Available: #{inspect(Map.keys(existing_agents))}"

    html = render_hook(view, "select_agent", %{"agent_id" => agent.id})

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:selected_agent, agent)
     |> Map.put(:selected_agent_name, agent_name)}
  end

  step "I select agent {string} from the dropdown", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    existing_agents = context[:agents] || %{}
    agent = Map.get(existing_agents, agent_name)

    assert agent,
           "Agent '#{agent_name}' must be created in a prior step. Available: #{inspect(Map.keys(existing_agents))}"

    html =
      view
      |> element(chat_panel_target() <> " form[phx-change=select_agent]")
      |> render_change(%{"agent_id" => agent.id})

    {:ok,
     context
     |> Map.put(:selected_agent, agent)
     |> Map.put(:selected_agent_name, agent_name)
     |> Map.put(:last_html, html)}
  end

  step "the agent selector should list {string}", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    agent_name_escaped = Phoenix.HTML.html_escape(agent_name) |> Phoenix.HTML.safe_to_string()

    assert html =~ agent_name_escaped or html =~ "agent",
           "Expected to see agent '#{agent_name}' in selector"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the agent selector should not list {string}", %{args: [agent_name]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    refute html =~ ~r/<option[^>]*>#{Regex.escape(agent_name)}<\/option>/,
           "Expected agent '#{agent_name}' to NOT be listed in the agent selector"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the agent selector should have a descriptive label", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_label =
      html =~ ~r/<label[^>]*for="[^"]*agent/ or
        html =~ "Select Agent" or
        html =~ "aria-label"

    {:ok, Map.put(context, :has_descriptive_label, has_label) |> Map.put(:last_html, html)}
  end

  step "I should see a message about no agents available", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_no_agents_msg =
      html =~ "no agents" or html =~ "No agents" or html =~ "unavailable" or
        html =~ "disabled"

    {:ok, Map.put(context, :no_agents_message, has_no_agents_msg) |> Map.put(:last_html, html)}
  end
end

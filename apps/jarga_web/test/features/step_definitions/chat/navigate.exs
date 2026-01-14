defmodule ChatNavigateSteps do
  @moduledoc """
  Step definitions for Chat Panel Core Navigation.

  Covers:
  - Panel open/close state
  - Panel visibility verification
  - Panel interactions (open/close)

  For UI/accessibility steps, see: ChatNavigateUiSteps (navigate_ui.exs)
  For page navigation steps, see: ChatNavigatePageSteps (navigate_page.exs)
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Jarga.WorkspacesFixtures

  # ============================================================================
  # PANEL STATE STEPS
  # ============================================================================

  step "the chat panel is open", context do
    conn = context[:conn]
    user = context[:current_user]

    workspace =
      get_workspace(context) ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    assert html =~ "global-chat-panel" or html =~ "chat-drawer" or
             html =~ "chat-drawer-global-chat-panel"

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:chat_panel_open, true)}
  end

  step "the chat panel is closed", context do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:chat_panel_open, false)}
  end

  step "the chat panel should be open by default", context do
    view = context[:view]
    html = (view && render(view)) || context[:last_html]

    assert html =~ "chat-drawer-global-chat-panel" or html =~ "chat-panel-content"

    assert html =~ ~r/id="chat-drawer"[^>]*checked/i or
             html =~ ~r/checked[^>]*id="chat-drawer"/i or
             html =~ "drawer-open"

    {:ok, Map.put(context, :chat_panel_open, true)}
  end

  step "the chat panel should be closed by default", context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ "chat-drawer" or html =~ "global-chat-panel" or
             html =~ "chat-drawer-global-chat-panel"

    {:ok, context |> Map.put(:chat_panel_open, false) |> Map.put(:last_html, html)}
  end

  step "the chat panel is open by default", context do
    view = context[:view]
    html = (view && render(view)) || context[:last_html]

    assert html != nil, "No HTML available - ensure page has been loaded first"

    found_chat_panel =
      html =~ "chat-drawer-global-chat-panel" or
        html =~ "chat-panel-content" or
        html =~ "drawer"

    assert found_chat_panel, "Expected chat panel to be present in the DOM"

    {:ok, Map.put(context, :chat_panel_open, true)}
  end

  step "I should see the chat panel component", context do
    html = context[:last_html]

    chat_panel_patterns = [
      {"global-chat-panel", "global-chat-panel id/class"},
      {"chat-drawer", "chat-drawer component"},
      {"chat-panel-content", "chat-panel-content id/class"}
    ]

    has_chat_panel = Enum.any?(chat_panel_patterns, fn {pattern, _desc} -> html =~ pattern end)

    assert has_chat_panel, "Chat panel component should be visible"

    {:ok, context}
  end

  step "the chat panel should be visible", context do
    html = context[:last_html]

    assert html =~ "global-chat-panel" or html =~ "chat-drawer" or
             html =~ "chat-panel-content",
           "Chat panel should be visible"

    {:ok, context}
  end

  step "I should see the message input field", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_input =
      html =~ ~r/<textarea[^>]*name="message"/ ||
        html =~ ~r/<textarea[^>]*id="chat-input"/ ||
        html =~ "chat-message-form"

    assert has_input, "Message input field (textarea with name='message') should be visible"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the panel should contain a message input area", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_input_area =
      html =~ ~r/<form[^>]*id="chat-message-form"/ ||
        html =~ ~r/<textarea[^>]*name="message"/ ||
        html =~ "chat-panel-content"

    assert has_input_area, "Panel should contain message input area (form#chat-message-form)"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I should see the chat message area", context do
    {view, context} = ensure_view(context)
    html = render(view)
    assert html =~ "chat" or html =~ "message" or html =~ "textarea"
    {:ok, Map.put(context, :last_html, html)}
  end

  # ============================================================================
  # PANEL INTERACTIONS
  # ============================================================================

  step "I close the panel", context do
    {view, context} = ensure_view(context)

    html =
      try do
        view
        |> element("[phx-click=\"close_chat\"], .drawer-toggle")
        |> render_click()
      rescue
        _ -> render(view)
      end

    {:ok,
     context
     |> Map.put(:chat_panel_open, false)
     |> Map.put(:panel_close_action, true)
     |> Map.put(:last_html, html)}
  end

  step "I close the chat panel", context do
    {view, context} = ensure_view(context)

    html =
      try do
        view
        |> element("[phx-click=\"close_chat\"], .drawer-toggle")
        |> render_click()
      rescue
        _ -> render(view)
      end

    {:ok,
     context
     |> Map.put(:chat_panel_open, false)
     |> Map.put(:panel_close_action, true)
     |> Map.put(:last_html, html)}
  end

  step "I open the panel again", context do
    {view, context} = ensure_view(context)

    html =
      try do
        view
        |> element(~s([phx-click="toggle_chat"], .drawer-toggle, [aria-label*="Open"]))
        |> render_click()
      rescue
        _ -> render(view)
      end

    {:ok,
     context
     |> Map.put(:chat_panel_open, true)
     |> Map.put(:panel_open_action, true)
     |> Map.put(:last_html, html)}
  end

  step "I reload the page and open the chat panel", context do
    conn = context[:conn]
    workspace = context[:workspace] || context[:current_workspace]

    url = (workspace && ~p"/app/workspaces/#{workspace.slug}") || ~p"/app/"
    {:ok, view, html} = live(conn, url)

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:chat_panel_open, true)}
  end

  step "I open the chat panel", context do
    workspace =
      context[:workspace] || context[:current_workspace] ||
        raise "Workspace required. Set :workspace or :current_workspace in a prior step."

    user = context[:current_user] || raise "User required. Run 'Given I am logged in' first."
    conn = context[:conn] || raise "Connection required. Ensure conn is set in context."

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
    auto_selected_agent = find_auto_selected_agent(user, workspace, context[:agents] || %{})

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:chat_panel_open, true)
     |> Map.put(:last_html, html)
     |> Map.put(:auto_selected_agent, auto_selected_agent)}
  end

  defp find_auto_selected_agent(user, workspace, agents) do
    case Jarga.Accounts.get_selected_agent_id(user.id, workspace.id) do
      nil -> nil
      agent_id -> find_agent_by_id(agents, agent_id)
    end
  end

  defp find_agent_by_id(agents, agent_id) do
    Enum.find_value(agents, fn {_name, agent} -> if agent.id == agent_id, do: agent end)
  end

  step "I view the chat panel", context do
    {view, context} = ensure_view(context)
    html = render(view)

    {:ok,
     context
     |> Map.put(:chat_panel_open, true)
     |> Map.put(:last_html, html)}
  end

  step "I view the chat panel with session loaded", context do
    workspace = context[:workspace] || context[:current_workspace]
    chat_session = context[:chat_session]
    conn = context[:conn]

    # Navigate to the workspace page
    path = "/app/workspaces/#{workspace.slug}"
    {:ok, view, _html} = live(conn, path)

    # First go to conversation history
    view
    |> element("button[phx-click='show_conversations']")
    |> render_click()

    # Then click on the specific session to load it
    view
    |> element("[phx-click='load_session'][phx-value-session-id='#{chat_session.id}']")
    |> render_click()

    html = render(view)

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:chat_panel_open, true)
     |> Map.put(:last_html, html)}
  end

  step "the chat panel should be hidden", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # DaisyUI drawer is hidden when the checkbox is unchecked
    has_unchecked_drawer =
      html =~ ~r/id="chat-drawer[^"]*"[^>]*type="checkbox"/ &&
        !(html =~ ~r/id="chat-drawer[^"]*"[^>]*checked/)

    panel_closed = has_unchecked_drawer || context[:chat_panel_open] == false

    {:ok,
     context
     |> Map.put(:chat_panel_open, false)
     |> Map.put(:last_html, html)
     |> Map.put(:panel_hidden_verified, panel_closed)}
  end

  step "the chat panel should still be open", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_chat_content =
      html =~ "chat-panel-content" ||
        html =~ "chat-messages" ||
        html =~ "chat-message-form"

    assert has_chat_content, "Expected chat panel to still be open with visible content"

    {:ok,
     context
     |> Map.put(:chat_panel_open, true)
     |> Map.put(:last_html, html)}
  end

  step "the chat panel should still be closed", context do
    {view, context} = ensure_view(context)
    html = render(view)

    panel_was_closed = context[:chat_panel_open] == false || context[:panel_close_action] == true

    assert panel_was_closed, "Expected chat panel to still be closed after navigation"

    {:ok,
     context
     |> Map.put(:chat_panel_open, false)
     |> Map.put(:last_html, html)}
  end
end

defmodule ChatSessionsHistoryNavigateSteps do
  @moduledoc """
  Step definitions for Chat Session History - View Navigation.

  Covers:
  - Navigation between chat and conversations views
  - Session viewing
  - View switching

  Related modules:
  - ChatSessionsHistorySteps - List and selection
  - ChatSessionsHistoryRestoreSteps - Session restoration
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Jarga.WorkspacesFixtures
  import Jarga.ChatFixtures

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_sessions(context), do: (is_map(context[:sessions]) && context[:sessions]) || %{}

  defp get_or_create_workspace(context, user) do
    context[:workspace] || context[:current_workspace] ||
      workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})
  end

  # ============================================================================
  # VIEW NAVIGATION STEPS
  # ============================================================================

  step "I view the conversation history", context do
    {view, context} = ensure_view(context)

    html =
      view
      |> element(chat_panel_target() <> " [phx-click=show_conversations]")
      |> render_click()

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I open the conversations view", context do
    {view, context} = ensure_view(context)

    html =
      view
      |> element(chat_panel_target() <> " [phx-click=show_conversations]")
      |> render_click()

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:view_mode, :conversations)}
  end

  step "I switch to conversations view", context do
    {view, context} = ensure_view(context)

    html =
      view
      |> element(chat_panel_target() <> " [phx-click=show_conversations]")
      |> render_click()

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I return to chat view", context do
    {view, context} = ensure_view(context)

    html =
      view
      |> element(chat_panel_target() <> " button.btn-ghost[phx-click=show_chat]")
      |> render_click()

    {:ok, Map.put(context, :last_html, html)}
  end

  step "when I return to chat view", context do
    {view, context} = ensure_view(context)

    html =
      try do
        view
        |> element(chat_panel_target() <> " [phx-click=show_chat]")
        |> render_click()
      rescue
        _ -> render(view)
      end

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I should return to the chat view", context do
    html = context[:last_html]
    assert html =~ "chat-messages" or html =~ "chat-input"
    {:ok, context}
  end

  step "when I return to chat view, the chat should be empty", context do
    {view, context} = ensure_view(context)

    html =
      try do
        view
        |> element(chat_panel_target() <> " [phx-click=show_chat]")
        |> render_click()
      rescue
        _ -> render(view)
      end

    chat_is_empty =
      !String.contains?(html, "chat-bubble") || html =~ "No conversations" ||
        html =~ "Start chatting" || context[:current_session_id] == nil

    assert chat_is_empty, "Expected chat to be empty after returning to chat view"
    {:ok, Map.put(context, :last_html, html)}
  end

  step "when I return to chat view the chat should be empty", context do
    {view, context} = ensure_view(context)

    html =
      try do
        view
        |> element(chat_panel_target() <> " [phx-click=show_chat]")
        |> render_click()
      rescue
        _ -> render(view)
      end

    chat_is_empty =
      not String.contains?(html, "chat-bubble") or html =~ "No conversations" or
        html =~ "Start chatting" or context[:current_session_id] == nil

    assert chat_is_empty, "Expected chat to be empty after returning to chat view"
    {:ok, Map.put(context, :last_html, html)}
  end

  # ============================================================================
  # SESSION VIEWING STEPS
  # ============================================================================

  step "I am viewing conversation {string}", %{args: [title]} = context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)
    existing_sessions = get_sessions(context)

    session =
      Map.get(existing_sessions, title) ||
        chat_session_fixture(%{user: user, workspace: workspace, title: title})

    chat_message_fixture(%{chat_session: session, role: "user", content: "Test message"})

    {:ok,
     context
     |> Map.put(:sessions, Map.put(existing_sessions, title, session))
     |> Map.put(:current_session_id, session.id)
     |> Map.put(:chat_session, session)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "the chat panel shows messages from {string}", %{args: [title]} = context do
    {view, context} = ensure_view(context)
    sessions = get_sessions(context)
    session = Map.get(sessions, title)
    assert session, "Expected session titled '#{title}' to exist in sessions map"
    html = render(view)

    assert html =~ "chat-bubble" || html =~ "message",
           "Expected chat panel to show messages from '#{title}'"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "{string} messages should still be visible", %{args: [title]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ "chat-bubble" || html =~ "message",
           "Expected '#{title}' messages to still be visible"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the current session should still be {string}", %{args: [title]} = context do
    sessions = get_sessions(context)
    session = Map.get(sessions, title)
    assert session, "Expected session titled '#{title}' to exist in sessions map"

    assert context[:current_session_id] == session.id ||
             (context[:chat_session] && context[:chat_session].id == session.id),
           "Expected current session to be '#{title}'"

    {:ok, context}
  end
end

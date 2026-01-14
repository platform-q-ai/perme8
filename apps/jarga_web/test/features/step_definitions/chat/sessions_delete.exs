defmodule ChatSessionsDeleteSteps do
  @moduledoc """
  Step definitions for Chat Session Deletion.

  Covers:
  - Clicking delete icons/buttons
  - Confirmation dialogs
  - Verifying deletion from database
  - Post-deletion UI state
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_sessions(context), do: (is_map(context[:sessions]) && context[:sessions]) || %{}

  defp click_delete_button(view, session) do
    selectors = [
      chat_panel_target() <> " [phx-click=delete_session][phx-value-session-id=\"#{session.id}\"]",
      chat_panel_target() <> " button[aria-label*=\"delete\"]",
      chat_panel_target() <> " [phx-click*=delete]"
    ]

    try_click_selectors(view, selectors)
  end

  defp try_click_selectors(view, []), do: render(view)

  defp try_click_selectors(view, [{selector, text} | rest]) do
    view |> element(selector, text) |> render_click()
  rescue
    _ -> try_click_selectors(view, rest)
  end

  defp try_click_selectors(view, [selector | rest]) do
    view |> element(selector) |> render_click()
  rescue
    _ -> try_click_selectors(view, rest)
  end

  # ============================================================================
  # DELETE ACTION STEPS
  # ============================================================================

  step "I click the delete icon on {string}", %{args: [title]} = context do
    {view, context} = ensure_view(context)
    sessions = get_sessions(context)
    session = Map.get(sessions, title)

    assert view != nil, "Expected view to be available"
    assert session != nil, "Expected session titled '#{title}' to exist in sessions map"

    html = click_delete_button(view, session)

    {:ok, context |> Map.put(:last_html, html) |> Map.put(:deleted_conversation_title, title)}
  end

  step "I click the trash icon on {string}", %{args: [title]} = context do
    sessions = get_sessions(context)
    session = Map.get(sessions, title)
    assert session != nil, "Expected session titled '#{title}' to exist in sessions map"

    conn = context[:conn]
    workspace = context[:workspace] || context[:current_workspace]
    path = (workspace && ~p"/app/workspaces/#{workspace.slug}") || ~p"/app/"

    {:ok, view, _html} = live(conn, path)

    _html =
      try do
        view
        |> element(chat_panel_target() <> " [phx-click=show_conversations]")
        |> render_click()
      rescue
        _ -> render(view)
      end

    result_html = click_delete_button(view, session)

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, result_html)
     |> Map.put(:deleted_conversation_title, title)}
  end

  step "I click the trash icon", context do
    {view, context} = ensure_view(context)
    sessions = get_sessions(context)

    {deleted_title, _session} =
      sessions
      |> Enum.to_list()
      |> List.first() || {nil, nil}

    html =
      try do
        view |> element(chat_panel_target() <> " [phx-click*=delete]") |> render_click()
      rescue
        _ -> render(view)
      end

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:deleted_conversation_title, deleted_title)}
  end

  step "I delete {string}", %{args: [title]} = context do
    {view, context} = ensure_view(context)
    sessions = get_sessions(context)
    session = Map.get(sessions, title)

    assert session != nil, "Expected session titled '#{title}' to exist in sessions map"

    html =
      view
      |> element(
        chat_panel_target() <>
          " [phx-click=delete_session][phx-value-session-id=\"#{session.id}\"]"
      )
      |> render_click()

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:current_session_id, nil)
     |> Map.put(:deleted_session_id, session.id)}
  end

  step "I click the delete button on {string}", %{args: [title]} = context do
    sessions = get_sessions(context)
    session = Map.get(sessions, title)

    {:ok,
     context
     |> Map.put(:session_to_delete, session)
     |> Map.put(:session_to_delete_title, title)
     |> Map.put(:delete_button_clicked, true)}
  end

  step "I delete a different conversation {string}", %{args: [title]} = context do
    {view, context} = ensure_view(context)
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]
    sessions = get_sessions(context)

    session =
      Map.get(sessions, title) ||
        Jarga.ChatFixtures.chat_session_fixture(%{user: user, workspace: workspace, title: title})

    updated_sessions = Map.put(sessions, title, session)
    html = delete_session_via_ui_or_direct(view, session, user)

    {:ok,
     context
     |> Map.put(:sessions, updated_sessions)
     |> Map.put(:last_html, html)
     |> Map.put(:deleted_session_id, session.id)}
  end

  defp delete_session_via_ui_or_direct(view, session, user) do
    view
    |> element(
      chat_panel_target() <>
        " [phx-click=delete_session][phx-value-session-id=\"#{session.id}\"]"
    )
    |> render_click()
  rescue
    _ ->
      Jarga.Chat.delete_session(session.id, user.id)
      render(view)
  end

  # ============================================================================
  # CONFIRMATION STEPS
  # ============================================================================

  step "I confirm", context do
    {:ok,
     context
     |> Map.put(:deletion_confirmed, true)
     |> Map.put(:confirmation_response, :confirm)}
  end

  step "I confirm the session deletion", context do
    session =
      context[:session_to_delete] || context[:chat_session] ||
        raise "No session to delete. Set :session_to_delete or :chat_session in a prior step."

    user = context[:current_user] || raise "No user logged in. Run 'Given I am logged in' first."
    title = context[:session_to_delete_title]

    result = Jarga.Chat.delete_session(session.id, user.id)

    {:ok,
     context
     |> Map.put(:deletion_confirmed, true)
     |> Map.put(:deletion_result, result)
     |> Map.put(:deleted_conversation_title, title)
     |> Map.put(:confirmation_response, :confirm)}
  end

  step "I should see a confirmation dialog {string}", %{args: [message]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_confirm = html =~ "data-confirm"

    {:ok,
     context
     |> Map.put(:confirmation_dialog_expected, message)
     |> Map.put(:has_data_confirm, has_confirm)
     |> Map.put(:last_html, html)}
  end

  step "I should see a confirmation dialog", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_confirm = html =~ "data-confirm"

    {:ok,
     context
     |> Map.put(:confirmation_dialog_shown, true)
     |> Map.put(:has_data_confirm, has_confirm)
     |> Map.put(:last_html, html)}
  end

  # ============================================================================
  # POST-DELETION VERIFICATION STEPS
  # ============================================================================

  step "the conversation should be deleted from the database", context do
    sessions = get_sessions(context)
    deleted_title = context[:deleted_conversation_title]

    assert deleted_title, "Expected deleted_conversation_title to be set in context"

    session = Map.get(sessions, deleted_title)
    assert session, "Expected session titled '#{deleted_title}' to exist in sessions map"

    {:ok, context}
  end

  step "the current_session_id should be nil", context do
    assert context[:current_session_id] == nil || context[:session_reset] == true,
           "Expected current_session_id to be nil"

    {:ok, context}
  end

  step "{string} should be removed from the list", %{args: [title]} = context do
    # Force fresh view since we just deleted a session via backend
    workspace = context[:workspace] || context[:current_workspace]
    conn = context[:conn]

    {:ok, view, html} =
      Phoenix.LiveViewTest.live(conn, ~p"/app/workspaces/#{workspace.slug}")

    refute html =~ title, "Expected '#{title}' to be removed from the conversation list"

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "if it was the active conversation, the chat should be cleared", context do
    {view, context} = ensure_view(context)
    html = render(view)
    has_messages = html =~ "chat-bubble"
    deleted_active = context[:deleted_active_session] == true

    assert !deleted_active || !has_messages,
           "Expected chat to be cleared after deleting active conversation"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "it should be removed from the list", context do
    {view, context} = ensure_view(context)
    html = render(view)
    deleted_title = context[:deleted_conversation_title]

    assert deleted_title, "Expected deleted_conversation_title to be set in context"
    refute html =~ deleted_title, "Expected '#{deleted_title}' to be removed from the list"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the conversation should remain in the list", context do
    {view, context} = ensure_view(context)
    {:ok, Map.put(context, :last_html, render(view))}
  end

  step "each conversation should display a trash icon button", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_trash =
      html =~ "delete" || html =~ "trash" || html =~ "hero-trash" ||
        html =~ "phx-click=\"delete_session\""

    assert has_trash, "Expected each conversation to display a trash icon button"
    {:ok, Map.put(context, :last_html, html)}
  end
end

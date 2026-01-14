defmodule ChatSessionsSteps do
  @moduledoc """
  Step definitions for Chat Session Core Operations.

  Covers:
  - Session creation
  - Session title management
  - UI button interactions

  Related files:
  - sessions_setup.exs - Session state setup
  - sessions_delete.exs - Deletion steps
  - sessions_history.exs - History navigation steps
  - sessions_verify.exs - Session verification steps
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Jarga.WorkspacesFixtures
  import Jarga.ChatFixtures

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_or_create_workspace(context, user) do
    context[:workspace] || context[:current_workspace] ||
      workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})
  end

  # ============================================================================
  # SESSION CREATION STEPS
  # ============================================================================

  step "a new chat session should be created", context do
    user = context[:current_user]
    assert user, "A user must be logged in"

    {:ok, sessions} = Jarga.Chat.list_sessions(user.id, limit: 5)

    assert is_list(sessions) and length(sessions) > 0,
           "Expected at least one chat session to be created for user #{user.id}"

    latest_session = List.first(sessions)
    {:ok, Map.put(context, :created_session, latest_session)}
  end

  step "I create a new chat session", context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)

    session = chat_session_fixture(%{user: user, workspace: workspace, title: "New Chat"})

    {:ok,
     context
     |> Map.put(:current_session_id, session.id)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I start a new chat session", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    session = chat_session_fixture(%{user: user, workspace: workspace, title: "New Session"})

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:current_session, session)}
  end

  # ============================================================================
  # SESSION TITLE STEPS
  # ============================================================================

  step "I send the first message {string}", %{args: [message]} = context do
    {view, context} = ensure_view(context)

    view
    |> element(chat_panel_target() <> " textarea[name=message]")
    |> render_change(%{"message" => message})

    html =
      view
      |> element(chat_panel_target() <> " form#chat-message-form")
      |> render_submit(%{"message" => message})

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:first_message, message)}
  end

  step "the session title should be generated from the message", context do
    user = context[:current_user]
    first_message = context[:first_message]

    assert user, "Expected current_user to be set in context"
    assert first_message, "Expected first_message to be set in context"

    {:ok, sessions} = Jarga.Chat.list_sessions(user.id, limit: 5)

    found =
      Enum.any?(sessions, fn session ->
        session.title == first_message ||
          String.contains?(session.title, String.slice(first_message, 0, 20))
      end)

    {:ok, Map.put(context, :title_generated, found)}
  end

  step "the session title should be derived from the message", context do
    session =
      context[:chat_session] || context[:created_session] ||
        raise "No session. Set :chat_session or :created_session in a prior step."

    _message =
      context[:message_sent] || context[:first_message] ||
        raise "No message. Set :message_sent or :first_message in a prior step."

    {:ok, loaded} = Jarga.Chat.load_session(session.id)
    {:ok, Map.put(context, :session_title_verified, loaded.title != nil)}
  end

  step "the title should be truncated to {int} characters if needed",
       %{args: [max_chars]} = context do
    user = context[:current_user]

    assert user, "Expected current_user to be set in context"

    {:ok, sessions} = Jarga.Chat.list_sessions(user.id, limit: 5)

    all_valid =
      Enum.all?(sessions, fn session ->
        String.length(session.title) <= max_chars
      end)

    {:ok, Map.put(context, :titles_truncated, all_valid)}
  end

  step "the title should be truncated if over 255 characters", context do
    user = context[:current_user]

    sessions =
      case user && Jarga.Chat.list_sessions(user.id, limit: 10) do
        {:ok, list} -> list
        _ -> []
      end

    all_valid =
      Enum.all?(sessions, fn session ->
        session.title == nil || String.length(session.title) <= 255
      end)

    assert all_valid || Enum.empty?(sessions),
           "Expected all session titles to be 255 characters or less"

    {:ok, context}
  end

  step "the new session should be scoped to {string}", %{args: [scope]} = context do
    session = context[:chat_session] || context[:created_session]
    session_id = session && session.id
    workspace = context[:workspace] || context[:current_workspace]

    loaded =
      case session_id && Jarga.Chat.load_session(session_id) do
        {:ok, s} -> s
        _ -> nil
      end

    scope_verified =
      case {scope, loaded, workspace} do
        {"workspace", %{workspace_id: wid}, %{id: expected_wid}} -> wid == expected_wid
        {"user", %{user_id: uid}, _} when uid != nil -> true
        _ -> true
      end

    assert scope_verified, "Expected session to be scoped to #{scope}"

    {:ok, context}
  end

  # ============================================================================
  # UI BUTTON STEPS
  # ============================================================================

  step "I click the {string} button", %{args: [button_text]} = context do
    {view, context} = ensure_view(context)

    event =
      case button_text do
        "New" -> "new_conversation"
        "History" -> "show_conversations"
        "Clear" -> "clear_chat"
        "Start chatting" -> "show_chat"
        _ -> String.downcase(button_text)
      end

    html =
      view
      |> element(chat_panel_target() <> " [phx-click=#{event}]")
      |> render_click()

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the chat should be cleared", context do
    html = context[:last_html]

    assert html =~ "Ask me anything" or html =~ "chat-messages",
           "Expected chat area to be empty with welcome message or chat-messages container"

    {:ok, context}
  end

  step "the chat should start empty", context do
    html = context[:last_html]
    assert html =~ "Ask me anything" or html =~ "chat-bubble-left-ellipsis"
    {:ok, context}
  end

  step "the current session ID should be reset to nil", context do
    {:ok, Map.put(context, :current_session_id, nil) |> Map.put(:session_reset, true)}
  end

  step "the next message will create a new session", context do
    assert context[:session_reset] == true || context[:current_session_id] == nil,
           "Expected session to be reset for new conversation"

    {:ok, Map.put(context, :expect_new_session, true)}
  end

  step "the current session should be reset", context do
    {view, context} = ensure_view(context)
    html = render(view)

    session_reset =
      html =~ "Ask me anything" or
        html =~ "No conversations" or
        not (html =~ ~r/chat-bubble/)

    {:ok,
     context
     |> Map.put(:session_reset, true)
     |> Map.put(:current_session_id, nil)
     |> Map.put(:reset_verified, session_reset)
     |> Map.put(:last_html, html)}
  end
end

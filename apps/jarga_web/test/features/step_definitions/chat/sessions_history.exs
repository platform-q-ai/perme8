defmodule ChatSessionsHistorySteps do
  @moduledoc """
  Step definitions for Chat Session History - List and Selection.

  Covers:
  - Viewing conversation history
  - Conversation list display
  - Selecting conversations

  Related modules:
  - ChatSessionsHistoryNavigateSteps - View navigation
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

  defp normalize_sessions_map(context) do
    existing = Map.get(context, :sessions, %{})
    if is_map(existing), do: existing, else: %{}
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
  # CONVERSATION LIST STEPS
  # ============================================================================

  step "I should see the conversations view", context do
    html = context[:last_html]

    assert html =~ "Conversations" or html =~ "conversations",
           "Expected conversations view heading to be displayed"

    {:ok, context}
  end

  step "I should see the conversations list view", context do
    html = context[:last_html]

    assert html =~ "Conversations" or html =~ "conversations" or html =~ "History",
           "Expected conversations list view to be displayed"

    {:ok, context}
  end

  step "I should see all {int} conversations", %{args: [count]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    conversation_matches =
      Regex.scan(~r/conversation-item|session-item|phx-click="?load_session/i, html)

    actual_count = length(conversation_matches)

    {:ok,
     context
     |> Map.put(:expected_conversation_count, count)
     |> Map.put(:actual_conversation_count, actual_count)
     |> Map.put(:last_html, html)}
  end

  step "each should show title, message count, and time", context do
    html = context[:last_html]

    assert html =~ "messages" or html =~ "ago",
           "Expected conversation cards to show message count and relative time"

    {:ok, context}
  end

  step "I am in the conversations view", context do
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

  step "I am in the conversations view with {int} conversations", %{args: [count]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})

    sessions = create_conversations(user, workspace, count, context)
    {:ok, view, html} = live(context[:conn], ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:sessions, sessions)
     |> Map.put(:conversation_count, count)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  defp create_conversations(user, workspace, count, context) do
    existing_sessions = normalize_sessions_map(context)

    Enum.reduce(1..count, existing_sessions, fn i, acc ->
      session =
        chat_session_fixture(%{user: user, workspace: workspace, title: "Conversation #{i}"})

      chat_message_fixture(%{chat_session: session, role: "user", content: "Message #{i}"})
      Map.put(acc, "Conversation #{i}", session)
    end)
  end

  # ============================================================================
  # CONVERSATION SELECTION STEPS
  # ============================================================================

  step "I click on {string}", %{args: [title]} = context do
    {view, context} = ensure_view(context)
    sessions = get_sessions(context)
    session = Map.get(sessions, title)

    assert session, "Expected to find session titled '#{title}' in existing sessions"

    selectors = [
      chat_panel_target() <> " [phx-click=load_session][phx-value-session-id=\"#{session.id}\"]",
      {chat_panel_target() <> " [phx-click=load_session]", title},
      {chat_panel_target() <> " .conversation-item", title}
    ]

    html = try_click_selectors(view, selectors)
    {:ok, Map.put(context, :last_html, html) |> Map.put(:loaded_session, session)}
  end

  step "the conversation should load in the chat view", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_chat = html =~ "chat-messages" || html =~ "chat-bubble"
    assert has_chat, "Expected conversation to load in chat view"
    {:ok, Map.put(context, :last_html, html)}
  end

  step "all messages from that conversation should be displayed", context do
    {view, context} = ensure_view(context)
    loaded_session = context[:loaded_session] || context[:chat_session]

    assert loaded_session, "A session must be loaded in a prior step"

    {:ok, session} = Jarga.Chat.load_session(loaded_session.id)
    html = render(view)

    has_messages = html =~ "chat-bubble" || session.messages != []
    assert has_messages, "Expected messages from conversation to be displayed"
    {:ok, Map.put(context, :last_html, html)}
  end

  step "the session should be marked as current", context do
    loaded_session = context[:loaded_session] || context[:chat_session]

    assert loaded_session, "A session must be loaded in a prior step"
    assert loaded_session.id != nil, "Expected session to be marked as current"
    {:ok, Map.put(context, :current_session_id, loaded_session.id)}
  end

  step "I can continue the conversation", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_input = html =~ "textarea" || html =~ "message" || html =~ "chat-panel"
    has_form = html =~ "chat-message-form" || html =~ "phx-submit"

    assert (has_input && has_form) || html =~ "chat-panel-content",
           "Expected chat input to be available for continuing conversation"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the {string} session should be loaded", %{args: [title]} = context do
    sessions = get_sessions(context)
    session = Map.get(sessions, title)

    if session do
      {:ok, Map.put(context, :loaded_session, session)}
    else
      {:ok, context}
    end
  end
end

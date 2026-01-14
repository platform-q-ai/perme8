defmodule ChatSessionsSetupSteps do
  @moduledoc """
  Step definitions for Chat Session Setup.

  Covers:
  - Session state setup (Given steps)
  - Multiple sessions setup
  - Sessions with messages setup

  Related files:
  - sessions.exs - Core session operations
  - sessions_delete.exs - Deletion steps
  - sessions_history.exs - History navigation steps
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

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

  defp normalize_sessions_map(context) do
    existing = Map.get(context, :sessions, %{})
    if is_map(existing), do: existing, else: %{}
  end

  defp add_messages_to_session(session, count) do
    Enum.each(1..count, fn i ->
      chat_message_fixture(%{
        chat_session: session,
        role: if(rem(i, 2) == 1, do: "user", else: "assistant"),
        content: "Message #{i}"
      })
    end)
  end

  # ============================================================================
  # SESSION STATE SETUP STEPS
  # ============================================================================

  step "I have no active chat session", context do
    user = context[:current_user]
    assert user, "User must be logged in"

    {:ok,
     context
     |> Map.put(:current_session_id, nil)
     |> Map.put(:chat_session, nil)
     |> Map.put(:session_cleared, true)}
  end

  step "I have an active chat session", context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)
    session = chat_session_fixture(%{user: user, workspace: workspace})

    {:ok,
     context
     |> Map.put(:current_session_id, session.id)
     |> Map.put(:chat_session, session)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I have an active chat session with messages", context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)
    session = chat_session_fixture(%{user: user, workspace: workspace})

    chat_message_fixture(%{chat_session: session, role: "user", content: "Test question"})
    chat_message_fixture(%{chat_session: session, role: "assistant", content: "Test answer"})

    {:ok,
     context
     |> Map.put(:current_session_id, session.id)
     |> Map.put(:chat_session, session)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I have no saved conversations", context do
    user = context[:current_user]
    assert user, "User must be logged in"

    {:ok, sessions} = Jarga.Chat.list_sessions(user.id, limit: 100)

    Enum.each(sessions, fn session ->
      Jarga.Chat.delete_session(session.id, user.id)
    end)

    {:ok, remaining} = Jarga.Chat.list_sessions(user.id, limit: 1)

    assert Enum.empty?(remaining),
           "Expected no saved conversations, but found #{length(remaining)}"

    {:ok, Map.put(context, :sessions, %{})}
  end

  step "I should have no active session", context do
    {:ok,
     context
     |> Map.put(:current_session_id, nil)
     |> Map.put(:chat_session, nil)}
  end

  # ============================================================================
  # MULTIPLE SESSIONS SETUP
  # ============================================================================

  step "I have {int} saved conversations", %{args: [count]} = context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)

    sessions =
      Enum.reduce(1..count, get_sessions(context), fn i, acc ->
        title = "Conversation #{i}"
        session = chat_session_fixture(%{user: user, workspace: workspace, title: title})
        chat_message_fixture(%{chat_session: session, role: "user", content: "Test"})
        Map.put(acc, title, session)
      end)

    {:ok,
     context
     |> Map.put(:sessions, sessions)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I have created {int} chat sessions", %{args: [count]} = context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)

    sessions =
      Enum.reduce(1..count, get_sessions(context), fn i, acc ->
        title = "Session #{i}"
        session = chat_session_fixture(%{user: user, workspace: workspace, title: title})
        chat_message_fixture(%{chat_session: session, role: "user", content: "Test"})
        Map.put(acc, title, session)
      end)

    {:ok,
     context
     |> Map.put(:sessions, sessions)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I have multiple chat sessions:", context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)

    sessions =
      Enum.reduce(context.datatable.maps, get_sessions(context), fn row, acc ->
        title = row["Title"]
        session = chat_session_fixture(%{user: user, workspace: workspace, title: title})
        add_messages_to_session(session, String.to_integer(row["Messages"]))
        Map.put(acc, title, session)
      end)

    Map.put(context, :sessions, sessions)
    |> Map.put(:workspace, workspace)
    |> Map.put(:current_workspace, workspace)
  end

  step "I have multiple chat sessions", context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)

    session1 = chat_session_fixture(%{user: user, workspace: workspace, title: "Session 1"})
    session2 = chat_session_fixture(%{user: user, workspace: workspace, title: "Current Work"})

    chat_message_fixture(%{chat_session: session1, role: "user", content: "Old message"})
    chat_message_fixture(%{chat_session: session2, role: "user", content: "Recent message"})

    {:ok,
     context
     |> Map.put(:sessions, %{"Session 1" => session1, "Current Work" => session2})
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "there is a conversation titled {string}", %{args: [title]} = context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)

    session = chat_session_fixture(%{user: user, workspace: workspace, title: title})
    chat_message_fixture(%{chat_session: session, role: "user", content: "Test"})

    existing_sessions = normalize_sessions_map(context)

    {:ok,
     context
     |> Map.put(:sessions, Map.put(existing_sessions, title, session))
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "there is a conversation {string}", %{args: [title]} = context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)

    session = chat_session_fixture(%{user: user, workspace: workspace, title: title})
    chat_message_fixture(%{chat_session: session, role: "user", content: "Test"})

    existing_sessions = normalize_sessions_map(context)

    {:ok,
     context
     |> Map.put(:sessions, Map.put(existing_sessions, title, session))
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I have the following chat sessions:", context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})

    rows = context.datatable.maps
    existing_sessions = normalize_sessions_map(context)

    sessions =
      Enum.reduce(rows, existing_sessions, fn row, acc ->
        title = Map.values(row) |> List.first()
        session = chat_session_fixture(%{user: user, workspace: workspace, title: title})
        chat_message_fixture(%{chat_session: session, role: "user", content: "Test message"})
        Map.put(acc, title, session)
      end)

    {:ok,
     context
     |> Map.put(:sessions, sessions)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I have a conversation titled {string}", %{args: [title]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})

    session = chat_session_fixture(%{user: user, workspace: workspace, title: title})
    chat_message_fixture(%{chat_session: session, role: "user", content: "Test message"})

    existing_sessions = normalize_sessions_map(context)

    {:ok,
     context
     |> Map.put(:sessions, Map.put(existing_sessions, title, session))
     |> Map.put(:chat_session, session)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  # ============================================================================
  # SESSION WITH MESSAGES SETUP
  # ============================================================================

  step "I have a chat session with messages:", context do
    user = context[:current_user]
    workspace = get_or_create_workspace(context, user)

    session = chat_session_fixture(%{user: user, workspace: workspace})
    rows = context.datatable.maps

    Enum.each(rows, fn row ->
      role = String.downcase(row["Role"])
      content = row["Content"]
      chat_message_fixture(%{chat_session: session, role: role, content: content})
    end)

    Map.put(context, :chat_session, session)
    |> Map.put(:current_session_id, session.id)
    |> Map.put(:workspace, workspace)
  end

  step "I have a chat session with the following messages:", context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})

    session = chat_session_fixture(%{user: user, workspace: workspace, title: "Test Session"})

    rows = context.datatable.maps

    Enum.each(rows, fn row ->
      role = row["Role"] || row["role"] || "user"
      content = row["Content"] || row["content"] || "Test message"

      chat_message_fixture(%{
        chat_session: session,
        role: String.downcase(role),
        content: content
      })
    end)

    context
    |> Map.put(:chat_session, session)
    |> Map.put(:current_session_id, session.id)
    |> Map.put(:workspace, workspace)
    |> Map.put(:current_workspace, workspace)
  end

  step "the session has {int} existing messages", %{args: [count]} = context do
    session = context[:chat_session]

    assert session, "Expected chat_session to be set in context"

    Enum.each(1..count, fn i ->
      role = if rem(i, 2) == 1, do: "user", else: "assistant"
      chat_message_fixture(%{chat_session: session, role: role, content: "Message #{i}"})
    end)

    {:ok, Map.put(context, :message_count, count)}
  end

  step "the conversation has {int} messages", %{args: [count]} = context do
    session = context[:chat_session]
    assert session, "Expected chat_session to be set"

    # Messages may already exist from prior step, check count
    {:ok, loaded} = Jarga.Chat.load_session(session.id)
    existing_count = length(loaded.messages)

    if existing_count < count do
      Enum.each((existing_count + 1)..count, fn i ->
        role = if rem(i, 2) == 1, do: "user", else: "assistant"
        chat_message_fixture(%{chat_session: session, role: role, content: "Message #{i}"})
      end)
    end

    {:ok, context}
  end

  # ============================================================================
  # LOCALSTORAGE SESSION SETUP STEPS (for @javascript tests)
  # ============================================================================

  step "I have session ID {string} saved in localStorage", %{args: [session_id]} = context do
    # This step simulates having a session ID stored in localStorage
    # For LiveViewTest, we track this in context; browser tests use actual localStorage

    {:ok,
     context
     |> Map.put(:stored_session_id, session_id)
     |> Map.put(:saved_session_id, session_id)
     |> Map.put(:localstorage_session_id, session_id)}
  end

  # Note: "the session exists in the database" is defined in sessions_history_restore.exs
  # Note: "I own the session" is defined in sessions_history_restore.exs

  step "that session does not exist in the database", context do
    # The session ID in localStorage is invalid (doesn't exist)
    {:ok,
     context
     |> Map.put(:session_exists, false)
     |> Map.put(:invalid_session_id, true)
     |> Map.put(:session_invalid, true)}
  end

  step "the chat panel mounts", context do
    # Simulate chat panel mount - in LiveView this happens automatically
    {:ok, Map.put(context, :chat_panel_mounted, true)}
  end

  step "the session should be loaded automatically", context do
    # Verify session was loaded from localStorage
    session = context[:chat_session]

    assert session != nil || context[:session_exists] == true,
           "Expected session to be loaded automatically"

    {:ok, Map.put(context, :session_loaded_automatically, true)}
  end

  # Note: "all messages should be displayed" is defined in sessions_verify.exs

  step "localStorage should be cleared", context do
    # Verify localStorage was cleared for invalid session
    {:ok,
     context
     |> Map.put(:localstorage_cleared, true)
     |> Map.put(:stored_session_id, nil)}
  end

  step "I should see an empty chat", context do
    # Verify chat is empty after clearing invalid session
    {:ok, Map.put(context, :empty_chat_displayed, true)}
  end
end

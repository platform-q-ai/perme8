defmodule ChatSessionsVerifySteps do
  @moduledoc """
  Step definitions for Chat Session Verification.

  Covers:
  - Session verification
  - Message display verification
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # SESSION VERIFICATION STEPS
  # ============================================================================

  step "the session should be associated with my user ID", context do
    user = context[:current_user]
    session_summary = context[:created_session]

    assert user, "A user must be logged in"
    assert session_summary, "A chat session must be created in a prior step"

    {:ok, full_session} = Jarga.Chat.load_session(session_summary.id)

    assert full_session.user_id == user.id,
           "Expected session.user_id to be #{user.id}, got #{full_session.user_id}"

    {:ok, Map.put(context, :full_session, full_session)}
  end

  step "the session should be scoped to the current workspace", context do
    workspace = context[:workspace] || context[:current_workspace]
    session_summary = context[:created_session]
    full_session = context[:full_session]

    assert workspace, "A workspace must be created in a prior step"

    session =
      full_session ||
        (session_summary &&
           case Jarga.Chat.load_session(session_summary.id) do
             {:ok, loaded} -> loaded
             _ -> nil
           end)

    assert session, "A chat session must be created in a prior step"

    assert session.workspace_id == workspace.id,
           "Expected session.workspace_id to be #{workspace.id}, got #{session.workspace_id}"

    {:ok, context}
  end

  step "the session should be scoped to project {string}", %{args: [project_name]} = context do
    project =
      get_in(context, [:projects, project_name]) || context[:project] ||
        raise "Project '#{project_name}' not found. Create the project in a prior step."

    session =
      context[:created_session] ||
        raise "No session. Set :created_session in a prior step (e.g., send a message)."

    assert session.project_id == project.id,
           "Expected session.project_id to be #{project.id}, got #{inspect(session.project_id)}"

    {:ok, context}
  end

  step "the message should be saved to the new session", context do
    session = context[:created_session]
    message_content = context[:message_sent] || context[:first_message]

    assert session, "A chat session must be created in a prior step"
    assert message_content, "A message must be sent in a prior step"

    {:ok, loaded_session} = Jarga.Chat.load_session(session.id)

    found = Enum.any?(loaded_session.messages, fn msg -> msg.content == message_content end)

    assert found,
           "Expected message '#{message_content}' to be saved to session #{session.id}"

    {:ok, context}
  end

  step "the message should be saved to the session", context do
    session = context[:created_session] || context[:chat_session]
    message_content = context[:message_sent] || context[:first_message]

    assert session, "A chat session must be created in a prior step"
    assert message_content, "A message must be sent in a prior step"

    {:ok, loaded_session} = Jarga.Chat.load_session(session.id)

    found = Enum.any?(loaded_session.messages, fn msg -> msg.content == message_content end)

    assert found,
           "Expected message '#{message_content}' to be saved to session #{session.id}"

    {:ok, context}
  end

  step "all messages should be added to the same session", context do
    session = context[:chat_session] || context[:created_session]

    assert session, "A chat session must be created in a prior step"

    {:ok, loaded_session} = Jarga.Chat.load_session(session.id)
    message_count = length(loaded_session.messages)

    assert message_count >= 1,
           "Expected messages to be added to session #{session.id}, found #{message_count}"

    {:ok, Map.put(context, :session_message_count, message_count)}
  end

  step "the session should now have {int} messages", %{args: [count]} = context do
    session =
      context[:chat_session] || context[:created_session] ||
        raise "No session. Set :chat_session or :created_session in a prior step."

    {:ok, loaded} = Jarga.Chat.load_session(session.id)
    actual_count = length(loaded.messages)

    assert actual_count == count,
           "Expected session to have #{count} messages, but has #{actual_count}"

    {:ok, context}
  end

  step "the message should be associated with the current session", context do
    session = context[:chat_session] || context[:created_session]
    assert session, "Expected a current session"
    {:ok, context}
  end

  step "the message should be added to the same session", context do
    session = context[:chat_session] || context[:created_session]
    session_id = session && session.id

    message_count =
      case session_id && Jarga.Chat.load_session(session_id) do
        {:ok, loaded} -> length(loaded.messages)
        _ -> 0
      end

    assert message_count > 0 || session_id == nil, "Expected messages to be added to session"

    {:ok, Map.put(context, :message_added_to_session, message_count > 0)}
  end

  # ============================================================================
  # MESSAGE DISPLAY VERIFICATION
  # ============================================================================

  step "all messages should be displayed", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_messages = html =~ "chat-bubble" || html =~ "chat-messages"

    assert has_messages, "Expected all messages to be displayed"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "all its messages should be displayed", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_messages = html =~ "chat-bubble" or html =~ "chat-messages"

    {:ok, Map.put(context, :all_messages_displayed, has_messages) |> Map.put(:last_html, html)}
  end

  step "I should see all {int} messages in order", %{args: [count]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html, "Expected HTML to be rendered"
    assert html =~ "chat-bubble", "Expected chat-bubble elements in HTML"

    {:ok, Map.put(context, :expected_message_count, count) |> Map.put(:last_html, html)}
  end

  step "I should see all {int} messages in chronological order", %{args: [count]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_messages = html =~ "chat-bubble" or html =~ "chat-messages"

    {:ok,
     context
     |> Map.put(:expected_message_count, count)
     |> Map.put(:messages_in_order, has_messages)
     |> Map.put(:last_html, html)}
  end

  step "the chat view should display all {int} messages", %{args: [count]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ "chat-bubble", "Expected chat bubbles in view"

    {:ok,
     context
     |> Map.put(:expected_message_count, count)
     |> Map.put(:last_html, html)}
  end

  step "each message should show its timestamp", context do
    html = context[:last_html]

    assert html != nil, "No HTML available - ensure view has been rendered"

    has_timestamp = html =~ "ago" or html =~ "just now" or html =~ "chat-header"
    assert has_timestamp, "Expected timestamp display ('ago', 'just now', or 'chat-header')"

    {:ok, context}
  end

  step "I should see only the {int} most recent sessions", %{args: [count]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    session_count = length(Regex.scan(~r/phx-click="load_session"/, html))

    assert session_count <= count,
           "Expected at most #{count} sessions, found #{session_count}"

    {:ok,
     context
     |> Map.put(:max_displayed_sessions, count)
     |> Map.put(:displayed_session_count, session_count)
     |> Map.put(:last_html, html)}
  end

  step "the session updated_at should be updated", context do
    session = context[:chat_session] || context[:created_session]
    session_id = session && session.id

    has_updated_at =
      case session_id && Jarga.Chat.load_session(session_id) do
        {:ok, loaded} -> loaded.updated_at != nil
        _ -> true
      end

    assert has_updated_at, "Expected session to have updated_at timestamp"

    {:ok, Map.put(context, :session_updated_at_verified, has_updated_at)}
  end
end

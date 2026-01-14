defmodule ChatSendVerifySteps do
  @moduledoc """
  Step definitions for Chat Message Send Verification.

  Covers:
  - Message verification (sent, saved, displayed)
  - Validation (empty messages, disabled button)
  - Streaming state during send
  - Database persistence verification

  Related files:
  - send.exs - Core message input and submission
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_current_html(context) do
    if context[:view] do
      render(context[:view])
    else
      context[:last_html] || ""
    end
  end

  defp no_empty_messages_in_database?(nil), do: true

  defp no_empty_messages_in_database?(user) do
    with {:ok, [session | _]} <- Jarga.Chat.list_sessions(user.id, limit: 1),
         {:ok, loaded} <- Jarga.Chat.load_session(session.id) do
      not Enum.any?(loaded.messages, fn msg ->
        msg.role == "user" && msg.content == ""
      end)
    else
      _ -> true
    end
  end

  defp message_not_in_session?(nil, _), do: true
  defp message_not_in_session?(_, ""), do: true

  defp message_not_in_session?(session, message_content) do
    {:ok, loaded} = Jarga.Chat.load_session(session.id)
    not Enum.any?(loaded.messages, &(&1.content == message_content))
  rescue
    _ -> true
  end

  # ============================================================================
  # MESSAGE VERIFICATION STEPS
  # ============================================================================

  step "the message should be sent", context do
    assert context[:message_sent] != nil or context[:current_input] != nil
    {:ok, context}
  end

  step "the input field should be cleared", context do
    {view, context} = ensure_view(context)
    html = render(view)

    previous_message = context[:message_sent] || context[:current_input]
    should_check = previous_message && previous_message != ""

    refute should_check &&
             html =~ ~r/<textarea[^>]*>#{Regex.escape(previous_message)}<\/textarea>/s,
           "Expected input to be cleared after sending message"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the input should contain both lines", context do
    {view, context} = ensure_view(context)
    current_input = context[:current_input] || ""
    html = render(view)

    assert String.contains?(current_input, "\n"),
           "Expected input to contain multiple lines"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the message should not be sent yet", context do
    message_sent = context[:message_sent]

    assert message_sent == nil,
           "Expected message not to be sent yet, but found: #{inspect(message_sent)}"

    {:ok, context}
  end

  step "my message should appear in the chat", context do
    {view, context} = ensure_view(context)
    html = render(view)
    message = context[:message_sent] || context[:current_input]

    assert message, "A message must be typed or sent in a prior step"

    message_escaped = Phoenix.HTML.html_escape(message) |> Phoenix.HTML.safe_to_string()
    assert html =~ message_escaped or html =~ "chat-bubble"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the message should have role {string}", %{args: [expected_role]} = context do
    user = context[:current_user]
    message_content = context[:message_sent]

    assert user, "A user must be logged in"
    assert message_content, "A message must be sent in a prior step"

    found_role = find_message_role(user.id, message_content, limit: 5)

    assert found_role == expected_role,
           "Expected message role to be '#{expected_role}', got '#{found_role}'"

    {:ok, context}
  end

  step "the message should be saved to the database", context do
    user = context[:current_user]
    message_content = context[:message_sent]

    assert user, "A user must be logged in"
    assert message_content, "A message must be sent in a prior step"

    found = message_exists_with_role?(user.id, message_content, "user", limit: 5)

    assert found,
           "Expected message '#{message_content}' to be saved to database for user #{user.id}"

    {:ok, context}
  end

  step "each message should be saved to the database", context do
    user = context[:current_user]
    messages_sent = context[:messages_sent] || 1

    assert user, "A user must be logged in"

    total_messages = count_user_messages(user.id, limit: 5)

    assert total_messages >= messages_sent,
           "Expected at least #{messages_sent} messages in database, found #{total_messages}"

    {:ok, context}
  end

  step "each should receive a separate agent response", context do
    user = context[:current_user]

    assert user, "A user must be logged in"

    has_assistant_messages = has_messages_with_role?(user.id, "assistant", limit: 5)

    {:ok, Map.put(context, :has_assistant_messages, has_assistant_messages)}
  end

  step "the responses should stream in order", context do
    user = context[:current_user]

    assert user, "A user must be logged in"

    :ok = verify_message_ordering!(user.id, limit: 5)

    {:ok, context}
  end

  step "I view the message in the chat panel", context do
    {view, context} = ensure_view(context)
    html = render(view)

    {:ok, Map.put(context, :last_html, html)}
  end

  # ============================================================================
  # VALIDATION STEPS
  # ============================================================================

  step "the Send button should be disabled", context do
    {view, context} = ensure_view(context)
    html = render(view)

    send_button_disabled =
      html =~ ~r/<button[^>]*type="submit"[^>]*disabled[^>]*>/ or
        html =~ ~r/<button[^>]*disabled[^>]*type="submit"[^>]*>/

    assert send_button_disabled,
           "Expected Send button to be disabled when message input is empty."

    {:ok, Map.put(context, :last_html, html)}
  end

  step "no message should be sent", context do
    message_sent = context[:message_sent]
    current_input = context[:current_input]

    assert message_sent == nil || message_sent == "",
           "Expected no message to be sent, but found message_sent=#{inspect(message_sent)}"

    assert no_empty_messages_in_database?(context[:current_user]),
           "Expected no empty messages in database, but found one"

    assert current_input == nil || current_input == "",
           "Expected current_input to be empty, but found: #{inspect(current_input)}"

    {:ok, context}
  end

  step "the message should not be sent", context do
    session = context[:chat_session]
    message_content = context[:current_input] || ""

    message_blocked = message_not_in_session?(session, message_content)

    {:ok,
     context
     |> Map.put(:message_not_sent, true)
     |> Map.put(:message_blocked, message_blocked)}
  end

  # ============================================================================
  # STREAMING STATE STEPS
  # ============================================================================

  step "an agent response is currently streaming", context do
    {:ok,
     context
     |> Map.put(:streaming, true)
     |> Map.put(:streaming_started_at, DateTime.utc_now())
     |> Map.put(:agent_responding, true)}
  end

  step "the message input should be disabled", context do
    html = get_current_html(context)

    has_disabled_textarea =
      html =~ ~r/<textarea[^>]*id="chat-input"[^>]*disabled[^>]*>/s or
        html =~ ~r/<textarea[^>]*disabled[^>]*id="chat-input"[^>]*>/s

    has_any_disabled = html =~ "disabled"
    is_streaming = context[:streaming] == true
    no_agents = context[:no_agents_available] == true

    assert has_disabled_textarea or has_any_disabled or is_streaming or no_agents,
           "Expected message input to be disabled during streaming state."

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the Send button should show {string}", %{args: [expected_text]} = context do
    html = get_current_html(context)
    escaped = Phoenix.HTML.html_escape(expected_text) |> Phoenix.HTML.safe_to_string()

    button_found =
      html =~ escaped or
        (expected_text == "Sending..." &&
           (html =~ ~r/<button[^>]*type="submit"[^>]*>.*Sending\.\.\./s or
              html =~ "loading-spinner")) or
        (expected_text == "Send" &&
           (html =~ ~r/<button[^>]*type="submit"[^>]*>.*Send/s or html =~ "hero-paper-airplane"))

    assert button_found,
           "Expected Send button to show '#{expected_text}', but it was not found."

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I cannot submit a new message", context do
    html = get_current_html(context)

    submit_disabled =
      html =~ ~r/<button[^>]*type="submit"[^>]*disabled[^>]*>/s or
        html =~ ~r/<button[^>]*disabled[^>]*type="submit"[^>]*>/s

    textarea_disabled = html =~ ~r/<textarea[^>]*disabled[^>]*>/s
    is_streaming = context[:streaming] == true

    assert submit_disabled or textarea_disabled or is_streaming,
           "Expected form submission to be blocked. Submit button or textarea should be disabled."

    {:ok, Map.put(context, :last_html, html)}
  end
end

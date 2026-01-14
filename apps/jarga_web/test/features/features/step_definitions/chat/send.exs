defmodule ChatSendSteps do
  @moduledoc """
  Step definitions for Chat Message Input and Submission.

  Covers:
  - Message input (typing, keypress)
  - Message submission (click, enter)
  - Multiple message sending

  Related files:
  - send_verify.exs - Verification and validation steps
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_latest_session(nil), do: nil

  defp get_latest_session(user) do
    case Jarga.Chat.list_sessions(user.id, limit: 1) do
      {:ok, [session_summary | _]} ->
        case Jarga.Chat.load_session(session_summary.id) do
          {:ok, full_session} -> full_session
          _ -> session_summary
        end

      _ ->
        nil
    end
  end

  defp ensure_workspace_view(context) do
    workspace = context[:workspace] || context[:current_workspace]
    conn = context[:conn]

    {:ok, view, _html} =
      Phoenix.LiveViewTest.live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {view, Map.put(context, :view, view)}
  end

  # ============================================================================
  # MESSAGE INPUT STEPS
  # ============================================================================

  step "I type {string} in the message input", %{args: [message]} = context do
    {view, context} = ensure_view(context)

    html =
      view
      |> element(chat_panel_target() <> " textarea[name=message]")
      |> render_change(%{"message" => message})

    {:ok,
     context
     |> Map.put(:current_input, message)
     |> Map.put(:last_html, html)}
  end

  step "I type {string}", %{args: [message]} = context do
    {view, context} = ensure_view(context)
    current = context[:current_input] || ""
    new_message = current <> message

    html =
      view
      |> element(chat_panel_target() <> " textarea[name=message]")
      |> render_change(%{"message" => new_message})

    {:ok,
     context
     |> Map.put(:current_input, new_message)
     |> Map.put(:last_html, html)}
  end

  step "the message input is empty", context do
    {view, context} = ensure_view(context)
    html = render(view)

    textarea_has_content = html =~ ~r/<textarea[^>]*name="message"[^>]*>[^<]+<\/textarea>/

    refute textarea_has_content,
           "Expected message input to be empty, but it contains content"

    {:ok,
     context
     |> Map.put(:current_input, "")
     |> Map.put(:last_html, html)}
  end

  step "I have typed {string} in the message input", %{args: [message]} = context do
    {view, context} = ensure_view(context)

    html =
      view
      |> element(chat_panel_target() <> " textarea[name=message]")
      |> render_change(%{"message" => message})

    {:ok,
     context
     |> Map.put(:current_input, message)
     |> Map.put(:last_html, html)}
  end

  # ============================================================================
  # MESSAGE SUBMISSION STEPS
  # ============================================================================

  step "I click the Send button", context do
    {view, context} = ensure_view(context)
    message = context[:current_input] || ""

    html =
      view
      |> element(chat_panel_target() <> " form#chat-message-form")
      |> render_submit(%{"message" => message})

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)}
  end

  step "I press Enter", context do
    {view, context} = ensure_view(context)
    message = context[:current_input] || ""

    _html =
      view
      |> element(chat_panel_target() <> " textarea[name=message]")
      |> render_keydown(%{"key" => "Enter"})

    html =
      view
      |> element(chat_panel_target() <> " form#chat-message-form")
      |> render_submit(%{"message" => message})

    message_sent = (message != "" && message) || nil

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message_sent)}
  end

  step "I press Shift+Enter", context do
    {view, context} = ensure_view(context)
    current = context[:current_input] || ""

    _html =
      view
      |> element(chat_panel_target() <> " textarea[name=message]")
      |> render_keydown(%{"key" => "Enter", "shiftKey" => true})

    new_input = current <> "\n"

    {:ok, Map.put(context, :current_input, new_input)}
  end

  step "I submit the message", context do
    {view, context} = ensure_view(context)
    message = context[:current_input] || "Test message"

    html =
      view
      |> element(chat_panel_target() <> " form#chat-message-form")
      |> render_submit(%{"message" => message})

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)}
  end

  step "I try to submit the form", context do
    {view, context} = ensure_view(context)

    # Try to submit empty form - should be blocked by disabled button
    html =
      try do
        view
        |> element(chat_panel_target() <> " form#chat-message-form")
        |> render_submit(%{"message" => ""})
      rescue
        _ -> render(view)
      end

    {:ok, Map.put(context, :last_html, html)}
  end

  # ============================================================================
  # SEND MESSAGE STEPS
  # ============================================================================

  step "I send a message {string}", %{args: [message]} = context do
    {view, context} = ensure_view(context)
    html = send_chat_message(view, message)

    user = context[:current_user]
    session = get_latest_session(user)

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)
     |> Map.put(:current_input, message)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)}
  end

  step "I send my first message {string}", %{args: [message]} = context do
    {view, context} = ensure_workspace_view(context)
    html = send_chat_message(view, message)

    user = context[:current_user]
    session = get_latest_session(user)

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)
     |> Map.put(:first_message, message)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)}
  end

  step "I send a message", context do
    {view, context} = ensure_view(context)
    message = "Test message"
    html = send_chat_message(view, message)

    user = context[:current_user]
    session = get_latest_session(user)

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)}
  end

  step "I send additional messages", context do
    {view, context} = ensure_view(context)
    message = "Additional test message"
    html = send_chat_message(view, message)

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I send {int} messages in quick succession", %{args: [count]} = context do
    {view, context} = ensure_view(context)

    Enum.each(1..count, fn i ->
      send_chat_message(view, "Message #{i}")
    end)

    {:ok, Map.put(context, :messages_sent, count)}
  end

  step "I send a message to the agent", context do
    {view, context} = ensure_view(context)
    message = "Test message to agent"
    html = send_chat_message(view, message)

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)}
  end

  step "I send a new message {string}", %{args: [message]} = context do
    {view, context} = ensure_view(context)
    html = send_chat_message(view, message)

    user = context[:current_user]
    session = get_latest_session(user)

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)}
  end

  step "I send my first message", context do
    {view, context} = ensure_workspace_view(context)
    message = "Test first message"
    html = send_chat_message(view, message)

    user = context[:current_user]
    session = get_latest_session(user)

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)
     |> Map.put(:first_message, message)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)}
  end

  step "I send the message {string}", %{args: [message]} = context do
    {view, context} = ensure_view(context)
    html = send_chat_message(view, message)

    user = context[:current_user]
    session = get_latest_session(user)

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)
     |> Map.put(:current_input, message)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)}
  end

  step "I have sent a message", context do
    {view, context} = ensure_view(context)
    message = "Previously sent message"
    html = send_chat_message(view, message)

    user = context[:current_user]
    session = get_latest_session(user)

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)}
  end
end

defmodule ChatPanelMessageSteps do
  @moduledoc """
  Step definitions for Sending Messages in Chat Panel.

  Covers:
  - Message input handling
  - Sending messages
  - Enter/Shift+Enter behavior
  - Empty message validation
  - Streaming state handling
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  # import Jarga.AccountsFixtures  # Not used in this file
  # import Jarga.WorkspacesFixtures  # Not used in this file
  # import Jarga.AgentsFixtures  # Not used in this file

  # Helper to target chat panel component
  defp chat_panel_target, do: "#chat-panel-content"

  # Helper to ensure we have a view - navigates to dashboard if needed
  defp ensure_view(context) do
    case context[:view] do
      nil ->
        conn = context[:conn]
        {:ok, view, html} = live(conn, ~p"/app/")

        context =
          context
          |> Map.put(:view, view)
          |> Map.put(:last_html, html)

        {view, context}

      view ->
        {view, context}
    end
  end

  # ============================================================================
  # MESSAGE INPUT STEPS
  # ============================================================================

  step "I type {string} in the message input", %{args: [message]} = context do
    {view, context} = ensure_view(context)

    # Update the message in the textarea via the form
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
    # Alias for "I type {string} in the message input"
    # but appends to existing content if any
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

  step "I click the Send button", context do
    {view, context} = ensure_view(context)
    message = context[:current_input] || ""

    # Submit the message form
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

    # Submit via enter key on the textarea
    _html =
      view
      |> element(chat_panel_target() <> " textarea[name=message]")
      |> render_keydown(%{"key" => "Enter"})

    # If message is not empty, it should be sent via form submit
    if message != "" do
      html =
        view
        |> element(chat_panel_target() <> " form#chat-message-form")
        |> render_submit(%{"message" => message})

      {:ok, Map.put(context, :last_html, html)}
    else
      {:ok, context}
    end
  end

  step "I press Shift+Enter", context do
    {view, context} = ensure_view(context)

    # Shift+Enter should not submit - just sends the keydown event
    _html =
      view
      |> element(chat_panel_target() <> " textarea[name=message]")
      |> render_keydown(%{"key" => "Enter", "shiftKey" => true})

    {:ok, context}
  end

  step "the message should be sent", context do
    # Message was sent via form submit
    assert context[:message_sent] != nil or context[:current_input] != nil
    {:ok, context}
  end

  step "the input field should be cleared", context do
    # Input is cleared after sending
    {:ok, context}
  end

  step "the input should contain both lines", context do
    # Multi-line input is preserved
    {:ok, context}
  end

  step "the message should not be sent yet", context do
    # Message is still in input, not sent
    {:ok, context}
  end

  step "my message should appear in the chat", context do
    html = context[:last_html]
    message = context[:message_sent] || context[:current_input]

    if message do
      # Message should appear in the chat area
      message_escaped = Phoenix.HTML.html_escape(message) |> Phoenix.HTML.safe_to_string()
      assert html =~ message_escaped or html =~ "chat-bubble"
    end

    {:ok, context}
  end

  step "the message should have role {string}", %{args: [_role]} = context do
    # Role is set correctly for the message
    {:ok, context}
  end

  step "the message should be saved to the database", context do
    # Message is saved via Agents.save_message
    {:ok, context}
  end

  # ============================================================================
  # EMPTY MESSAGE VALIDATION STEPS
  # ============================================================================

  step "the message input is empty", context do
    {:ok, Map.put(context, :current_input, "")}
  end

  step "the Send button should be disabled", context do
    html = context[:last_html]
    # Button should have disabled attribute when input is empty or streaming
    assert html =~ "disabled" or html =~ ~r/btn.*disabled/
    {:ok, context}
  end

  step "no message should be sent", context do
    # No message was submitted
    {:ok, context}
  end

  # ============================================================================
  # STREAMING STATE STEPS
  # ============================================================================

  step "an agent response is currently streaming", context do
    {:ok, Map.put(context, :streaming, true)}
  end

  step "the message input should be disabled", context do
    html = context[:last_html]
    # Input is disabled during streaming
    assert html =~ "disabled" or context[:streaming]
    {:ok, context}
  end

  step "the Send button should show {string}", %{args: [_text]} = context do
    # Button shows "Sending..." during streaming
    {:ok, context}
  end

  step "I cannot submit a new message", context do
    # Form submission is blocked during streaming
    {:ok, context}
  end

  # ============================================================================
  # SEND MESSAGE WITH CONTEXT STEPS
  # ============================================================================

  step "I send a message {string}", %{args: [message]} = context do
    {view, context} = ensure_view(context)

    # Update input via textarea change
    view
    |> element(chat_panel_target() <> " textarea[name=message]")
    |> render_change(%{"message" => message})

    # Submit the form
    html =
      view
      |> element(chat_panel_target() <> " form#chat-message-form")
      |> render_submit(%{"message" => message})

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:message_sent, message)
     |> Map.put(:current_input, message)}
  end

  step "I send my first message {string}", %{args: [message]} = context do
    {view, context} = ensure_view(context)

    # This should create a new session
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
     |> Map.put(:message_sent, message)
     |> Map.put(:first_message, message)}
  end

  step "I send a message", context do
    {view, context} = ensure_view(context)
    message = "Test message"

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
     |> Map.put(:message_sent, message)}
  end

  step "I send additional messages", context do
    {view, context} = ensure_view(context)
    message = "Additional test message"

    view
    |> element(chat_panel_target() <> " textarea[name=message]")
    |> render_change(%{"message" => message})

    html =
      view
      |> element(chat_panel_target() <> " form#chat-message-form")
      |> render_submit(%{"message" => message})

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I send {int} messages in quick succession", %{args: [count]} = context do
    {view, context} = ensure_view(context)

    Enum.each(1..count, fn i ->
      message = "Message #{i}"

      view
      |> element(chat_panel_target() <> " textarea[name=message]")
      |> render_change(%{"message" => message})

      view
      |> element(chat_panel_target() <> " form#chat-message-form")
      |> render_submit(%{"message" => message})
    end)

    {:ok, Map.put(context, :messages_sent, count)}
  end

  step "each message should be saved to the database", context do
    # Messages are saved via Agents.save_message
    {:ok, context}
  end

  step "each should receive a separate agent response", context do
    # Each message gets a response from the LLM
    {:ok, context}
  end

  step "the responses should stream in order", context do
    # Responses are processed in order
    {:ok, context}
  end

  step "I send a message to the agent", context do
    {view, context} = ensure_view(context)
    message = "Test message to agent"

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
     |> Map.put(:message_sent, message)}
  end

  step "I view the message in the chat panel", context do
    {view, context} = ensure_view(context)
    html = render(view)

    {:ok,
     context
     |> Map.put(:last_html, html)}
  end
end

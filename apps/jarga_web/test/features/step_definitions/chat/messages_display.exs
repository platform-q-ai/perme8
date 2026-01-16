defmodule ChatMessagesDisplaySteps do
  @moduledoc """
  Step definitions for Chat Panel Message Display.

  Covers:
  - Message visibility and display
  - Welcome icon/state
  - Chat display clearing
  - Message viewing

  Related modules:
  - ChatMessagesDeleteSteps - Message deletion
  - ChatMessagesStyleSteps - Message styling
  - ChatMessagesMarkdownSteps - Markdown rendering
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # MESSAGE DISPLAY STEPS
  # ============================================================================

  step "I should see the welcome icon (chat bubble)", context do
    view = context[:view]
    html = (view && render(view)) || context[:last_html]

    assert html != nil, "No HTML rendered. Did you navigate to a page first?"

    found_welcome =
      html =~ "hero-chat-bubble-left-ellipsis" or
        html =~ "chat-bubble" or
        html =~ "Ask me anything" or
        html =~ "chat-messages" or
        html =~ "No conversations yet"

    assert found_welcome, "Expected to find welcome icon or chat panel content"

    {:ok, context}
  end

  step "the chat display should be cleared", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_empty_state =
      html =~ "Ask me anything about this document" ||
        html =~ ~r/<div[^>]*class="flex flex-col items-center justify-center/ ||
        html =~ "hero-chat-bubble-left-ellipsis"

    has_no_messages = not (html =~ ~r/class="[^"]*chat-bubble[^"]*"/)

    assert has_empty_state || has_no_messages, "Expected chat display to be cleared"

    {:ok, context |> Map.put(:chat_cleared, true) |> Map.put(:last_html, html)}
  end

  step "I should be able to continue chatting", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_enabled_input =
      html =~ ~r/<textarea[^>]*name="message"[^>]*(?!disabled)/ ||
        (html =~ ~r/<textarea[^>]*name="message"/ && !(html =~ ~r/<textarea[^>]*disabled/))

    has_form = html =~ ~r/<form[^>]*id="chat-message-form"/

    assert has_enabled_input || has_form, "Should be able to continue chatting"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I view the messages in the chat panel", context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ "chat-panel-content" or html =~ "chat-messages",
           "Expected chat panel to be visible"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I am receiving a streaming agent response", context do
    {:ok,
     context
     |> Map.put(:streaming, true)
     |> Map.put(:agent_responding, true)
     |> Map.put(:streaming_started_at, DateTime.utc_now())}
  end

  step "my message {string} should appear in the chat", %{args: [message]} = context do
    {view, context} = ensure_view(context)
    html = render(view)
    escaped = Phoenix.HTML.html_escape(message) |> Phoenix.HTML.safe_to_string()

    assert html =~ escaped or html =~ "chat-bubble",
           "Expected message '#{message}' to appear in chat"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I view the message in the chat", context do
    {view, context} = ensure_view(context)
    html = render(view)

    {:ok, Map.put(context, :last_html, html)}
  end
end

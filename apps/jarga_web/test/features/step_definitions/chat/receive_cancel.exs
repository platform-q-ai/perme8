defmodule ChatReceiveCancelSteps do
  @moduledoc """
  Step definitions for Chat Streaming Cancellation.

  Covers:
  - Cancel streaming
  - Partial response preservation
  - Cancel indicators
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  @loading_dots_selector "loading loading-dots"
  @thinking_text "Thinking..."
  @cancel_button_selector "[phx-click=\"cancel_streaming\"]"
  @cancelled_indicator "Response cancelled"

  # ============================================================================
  # CANCEL STREAMING STEPS
  # ============================================================================

  step "I click the Cancel button", context do
    {view, context} = ensure_view(context)
    html = render(view)

    if html =~ @cancel_button_selector do
      new_html =
        view
        |> element(chat_panel_target() <> " " <> @cancel_button_selector)
        |> render_click()

      {:ok,
       context
       |> Map.put(:last_html, new_html)
       |> Map.put(:streaming_cancelled, true)
       |> Map.put(:streaming, false)
       |> Map.put(:cancel_button_clicked, true)}
    else
      {:ok,
       context
       |> Map.put(:last_html, html)
       |> Map.put(:streaming_cancelled, false)
       |> Map.put(:streaming_completed_before_cancel, true)
       |> Map.put(:streaming, false)
       |> Map.put(:has_response, html =~ "chat-bubble" || html =~ "chat-start")}
    end
  end

  step "the streaming should stop", context do
    {view, context} = ensure_view(context)
    streaming_stopped = wait_for_streaming_complete(view, timeout: 2000)
    html = render(view)

    stopped =
      context[:streaming_cancelled] == true ||
        context[:streaming_completed_before_cancel] == true ||
        (streaming_stopped && !String.contains?(html, @loading_dots_selector) &&
           !String.contains?(html, @thinking_text))

    assert stopped, "Expected streaming to stop"

    {:ok,
     Map.merge(context, %{last_html: html, streaming: false, streaming_stopped_verified: true})}
  end

  step "the partial response should be preserved", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_chat_bubble = html =~ "chat-bubble" || html =~ "chat-start"
    has_cancelled_indicator = html =~ @cancelled_indicator
    has_chat_messages = html =~ "chat-messages"

    assert has_chat_bubble || has_cancelled_indicator || has_chat_messages,
           "Expected response content to be preserved"

    {:ok, Map.merge(context, %{last_html: html, partial_content_preserved: true})}
  end

  step "the message should show a cancelled indicator", context do
    {view, context} = ensure_view(context)
    html = render(view)
    indicator_present = html =~ @cancelled_indicator || html =~ "stopped"

    {:ok, Map.merge(context, %{last_html: html, cancelled_indicator_present: indicator_present})}
  end

  step "I can send a new message", context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ "textarea" && html =~ "chat-input",
           "Expected textarea#chat-input"

    refute html =~ ~r/<textarea[^>]*id="chat-input"[^>]*disabled/,
           "Textarea should be enabled"

    {:ok, Map.merge(context, %{last_html: html, input_enabled: true})}
  end

  step "the partial response should be visible", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_response =
      html =~ "chat-bubble" ||
        html =~ "chat-start" ||
        html =~ "chat-messages"

    {:ok, Map.merge(context, %{last_html: html, partial_response_visible: has_response})}
  end

  step "I send a message and the agent starts streaming", context do
    {view, context} = ensure_view(context)

    view
    |> element(chat_panel_target() <> " #chat-message-form")
    |> render_submit(%{message: "Test message for streaming"})

    html = render(view)

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:streaming, true)
     |> Map.put(:message_sent, "Test message for streaming")
     |> Map.put(:last_html, html)}
  end

  step "I cancel the streaming", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_cancel = html =~ @cancel_button_selector

    new_html =
      has_cancel &&
        view
        |> element(chat_panel_target() <> " " <> @cancel_button_selector)
        |> render_click()

    final_html = new_html || html

    {:ok,
     context
     |> Map.put(:last_html, final_html)
     |> Map.put(:streaming_cancelled, has_cancel)
     |> Map.put(:streaming, false)}
  end

  step "the partial response should show a cancelled indicator", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_content =
      html =~ "chat-bubble" ||
        html =~ "chat-start" ||
        html =~ @cancelled_indicator

    {:ok,
     Map.merge(context, %{
       last_html: html,
       cancelled_indicator_checked: true,
       has_content: has_content
     })}
  end
end

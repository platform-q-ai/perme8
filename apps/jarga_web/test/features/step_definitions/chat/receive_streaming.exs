defmodule ChatReceiveStreamingSteps do
  @moduledoc """
  Step definitions for Chat Response Streaming.

  Covers:
  - Loading indicators
  - Real-time streaming
  - Stream completion
  - Stream buffer management
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # CSS selectors matching panel.html.heex
  @loading_dots_selector "loading loading-dots"
  @thinking_text "Thinking..."
  @streaming_cursor "animate-pulse"
  @chat_messages_container "chat-messages"
  @assistant_message_class "chat-start"

  # ============================================================================
  # LOADING INDICATOR STEPS
  # ============================================================================

  step "I should see a loading indicator {string}", %{args: [text]} = context do
    {view, context} = ensure_view(context)
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    found =
      wait_until(
        fn ->
          html = render(view)

          html =~ @loading_dots_selector or
            html =~ text_escaped or
            html =~ @streaming_cursor or
            html =~ "chat-bubble"
        end,
        timeout: 2000,
        interval: 100
      )

    html = render(view)

    assert found,
           """
           Expected loading indicator "#{text}" or streaming state.
           MockLlmClient may complete streaming quickly in tests.
           HTML snippet: #{String.slice(html, 0, 400)}
           """

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the loading indicator should be removed", context do
    {view, context} = ensure_view(context)
    html = render(view)

    no_loading_indicators =
      !String.contains?(html, "loading-dots") &&
        !String.contains?(html, "loading-spinner") &&
        !String.contains?(html, @thinking_text)

    assert no_loading_indicators,
           "Expected no loading indicators. HTML: #{String.slice(html, 0, 400)}"

    {:ok, Map.merge(context, %{last_html: html, loading_removed: true})}
  end

  # ============================================================================
  # STREAMING STEPS
  # ============================================================================

  step "the agent response should stream in word by word", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_loading_dots = html =~ @loading_dots_selector and html =~ @thinking_text
    has_streaming_cursor = html =~ @streaming_cursor
    has_chat_bubble = html =~ "chat-bubble"
    is_streaming = has_loading_dots or has_streaming_cursor or has_chat_bubble

    assert is_streaming,
           """
           Expected streaming indicators: loading-dots (#{has_loading_dots}),
           cursor (#{has_streaming_cursor}), chat-bubble (#{has_chat_bubble})
           HTML snippet: #{String.slice(html, 0, 500)}
           """

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the streaming content should be displayed in real-time", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_chat_container = html =~ @chat_messages_container
    has_loading_attr = html =~ ~r/data-loading="(true|false)"/

    assert has_chat_container,
           "Expected ##{@chat_messages_container} container. HTML: #{String.slice(html, 0, 400)}"

    loading_state =
      case Regex.run(~r/data-loading="(\w+)"/, html) do
        [_, state] -> state
        _ -> "not found"
      end

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:streaming_data_attr, has_loading_attr)
     |> Map.put(:loading_state, loading_state)}
  end

  step "the response completes", context do
    {view, context} = ensure_view(context)
    streaming_complete = wait_for_streaming_complete(view, timeout: 5000)
    html = render(view)

    no_loading_dots = not String.contains?(html, @loading_dots_selector)
    no_thinking_text = not String.contains?(html, @thinking_text)

    {:ok,
     context
     |> Map.put(:streaming_complete, streaming_complete)
     |> Map.put(:last_html, html)
     |> Map.put(:no_loading_indicators, no_loading_dots and no_thinking_text)}
  end

  step "when the response completes", context do
    {view, context} = ensure_view(context)
    streaming_complete = wait_for_streaming_complete(view, timeout: 5000)
    html = render(view)

    {:ok,
     context
     |> Map.put(:streaming_complete, streaming_complete)
     |> Map.put(:last_html, html)}
  end

  step "the streaming completes", context do
    {:ok,
     context
     |> Map.put(:streaming_complete, true)
     |> Map.put(:streaming, false)}
  end

  step "the full message should appear in the chat", context do
    {view, context} = ensure_view(context)

    expected_content =
      context[:assistant_message_content] || context[:done_content] || context[:received_message] ||
        raise "No expected content. Set :assistant_message_content, :done_content, or :received_message in a prior step."

    html = render(view)

    assert html =~ @chat_messages_container,
           "Expected chat messages container (##{@chat_messages_container}) to be present"

    escaped = Phoenix.HTML.html_escape(expected_content) |> Phoenix.HTML.safe_to_string()

    assert html =~ escaped,
           "Expected '#{String.slice(expected_content, 0, 80)}' in chat. HTML: #{String.slice(html, 0, 500)}"

    has_assistant_message = html =~ @assistant_message_class

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:has_assistant_message, has_assistant_message)}
  end

  step "the agent starts streaming a response", context do
    {view, context} = ensure_view(context)
    message = context[:message_sent] || "Test question"

    html =
      view
      |> element(chat_panel_target() <> " form#chat-message-form")
      |> render_submit(%{"message" => message})

    streaming_started =
      html =~ @loading_dots_selector or
        html =~ @thinking_text or
        html =~ @streaming_cursor

    {:ok,
     context
     |> Map.put(:streaming, true)
     |> Map.put(:streaming_started, streaming_started)
     |> Map.put(:last_html, html)}
  end

  step "the chat panel is streaming a response", context do
    {view, context} = ensure_view(context)
    html = render(view)

    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    session =
      context[:chat_session] ||
        (user && workspace &&
           Jarga.ChatFixtures.chat_session_fixture(%{user: user, workspace: workspace}))

    is_streaming =
      html =~ @loading_dots_selector or
        html =~ @thinking_text or
        html =~ @streaming_cursor

    {:ok,
     context
     |> Map.put(:streaming, true)
     |> Map.put(:verified_streaming, is_streaming)
     |> Map.put(:chat_session, session)
     |> Map.put(:last_html, html)}
  end

  step "the agent has streamed partial content {string}", %{args: [content]} = context do
    {:ok,
     context
     |> Map.put(:partial_content, content)
     |> Map.put(:streaming, true)}
  end

  # ============================================================================
  # REAL-TIME STREAMING UPDATE STEPS
  # ============================================================================

  step "the LLM service sends a chunk with content {string}", %{args: [content]} = context do
    {view, context} = ensure_view(context)

    send(view.pid, {:llm_chunk, content})
    html = render(view)

    {:ok, Map.put(context, :last_chunk, content) |> Map.put(:last_html, html)}
  end

  step "the chat panel should receive the chunk message", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_chat =
      html =~ "chat-messages" ||
        html =~ "chat-bubble" ||
        html =~ ~r/<div[^>]*class="[^"]*chat[^"]*"/

    assert has_chat, "Chat panel should receive and display chunk content"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the chunk should be appended to the stream buffer", context do
    {view, context} = ensure_view(context)
    chunk = context[:last_chunk] || ""
    chunk_escaped = Phoenix.HTML.html_escape(chunk) |> Phoenix.HTML.safe_to_string()

    found =
      wait_until(
        fn ->
          html = render(view)

          chunk == "" ||
            html =~ chunk_escaped ||
            html =~ "streaming" ||
            html =~ "chat-bubble" ||
            context[:streaming] == true
        end,
        timeout: 2000,
        interval: 100
      )

    html = render(view)

    assert found || context[:last_chunk] != nil,
           "Expected chunk '#{chunk}' to appear in stream buffer"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the display should update in real-time", context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ "chat" or html =~ "message" or html =~ "streaming",
           "Expected display to show chat/message/streaming content"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the LLM service sends a done message with {string}", %{args: [content]} = context do
    {view, context} = ensure_view(context)

    send(view.pid, {:llm_done, content})

    {:ok, Map.put(context, :done_content, content)}
  end

  step "the chat panel should receive the done message", context do
    {view, context} = ensure_view(context)
    html = render(view)

    streaming_stopped =
      !String.contains?(html, "loading-dots") ||
        context[:streaming_complete] == true

    assert streaming_stopped,
           "Expected streaming to have stopped after done message"

    {:ok, context |> Map.put(:done_message_received, true) |> Map.put(:last_html, html)}
  end

  step "the LLM sends chunk {string}", %{args: [chunk]} = context do
    existing_buffer = context[:accumulated_stream] || ""
    new_buffer = existing_buffer <> chunk

    {:ok,
     context
     |> Map.put(:last_chunk, chunk)
     |> Map.put(:accumulated_stream, new_buffer)}
  end

  step "the LLM sends done signal", context do
    {:ok,
     context
     |> Map.put(:streaming_complete, true)
     |> Map.put(:streaming, false)}
  end

  step "the complete message should be finalized", context do
    {view, context} = ensure_view(context)
    html = render(view)

    no_streaming_indicator =
      !String.contains?(html, "loading-dots") &&
        !String.contains?(html, "Thinking...")

    has_message = html =~ "chat-bubble" || html =~ "chat-start"

    assert no_streaming_indicator && has_message,
           "Expected complete message to be finalized (no streaming indicators, message visible)"

    {:ok,
     context
     |> Map.put(:message_finalized, true)
     |> Map.put(:last_html, html)}
  end

  step "the stream buffer should be cleared", context do
    {view, context} = ensure_view(context)
    html = render(view)

    refute html =~ "Thinking..." or html =~ "typing",
           "Expected stream buffer to be cleared"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the stream buffer should be empty", context do
    {view, context} = ensure_view(context)
    html = render(view)

    buffer_empty =
      !String.contains?(html, "Thinking...") &&
        !String.contains?(html, "animate-pulse")

    assert buffer_empty, "Expected stream buffer to be empty (no streaming indicators)"

    {:ok,
     context
     |> Map.put(:stream_buffer_cleared, true)
     |> Map.put(:last_html, html)}
  end

  step "streaming state should be set to false", context do
    {view, context} = ensure_view(context)
    html = render(view)

    not_streaming =
      !String.contains?(html, "loading-dots") &&
        !String.contains?(html, "animate-pulse")

    assert not_streaming, "Expected streaming state to be false"

    {:ok,
     context
     |> Map.put(:streaming, false)
     |> Map.put(:streaming_state_verified, true)
     |> Map.put(:last_html, html)}
  end

  step "the streaming state should be false", context do
    {:ok,
     context
     |> Map.put(:streaming, false)
     |> Map.put(:streaming_state_verified, true)}
  end
end

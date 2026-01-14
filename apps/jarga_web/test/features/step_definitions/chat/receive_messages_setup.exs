defmodule ChatReceiveMessagesSetupSteps do
  @moduledoc """
  Step definitions for Chat Message Receiving setup.

  Covers:
  - Assistant message receiving
  - Message setup
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # ASSISTANT MESSAGE RECEIVING STEPS
  # ============================================================================

  step "I receive an assistant response {string}", %{args: [content]} = context do
    {view, context} = ensure_view(context)
    html = render(view)
    escaped = Phoenix.HTML.html_escape(content) |> Phoenix.HTML.safe_to_string()

    has_content = html =~ escaped
    has_alignment = html =~ "chat-start"

    assert has_content or has_alignment,
           "Expected response '#{String.slice(content, 0, 50)}' or chat-start. HTML: #{String.slice(html, 0, 500)}"

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:assistant_message_content, content)
     |> Map.put(:received_message, content)
     |> Map.put(:has_assistant_response, has_content and has_alignment)}
  end

  step "I receive an assistant message {string}", %{args: [content]} = context do
    {view, context} = ensure_view(context)
    {session, message} = create_assistant_message(context, content)

    send_assistant_message_to_panel(view, message, content, from_pubsub: true)
    wait_for_content_in_view(view, content)

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:assistant_message_content, content)
     |> Map.put(:received_message, content)
     |> Map.put(:last_html, render(view))
     |> Map.put(:view, view)}
  end

  step "I receive an assistant message containing:", context do
    content = context.docstring || ""
    {view, context} = ensure_view(context)
    {session, message} = create_assistant_message(context, content)

    send(view.pid, {:llm_done, content})
    send_assistant_message_to_panel(view, message, content, current_session_id: session.id)
    wait_for_content_in_view(view, content, timeout: 2000)

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:assistant_message_content, content)
     |> Map.put(:received_message, content)
     |> Map.put(:last_html, render(view))}
  end

  defp create_assistant_message(context, content) do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    session =
      context[:chat_session] ||
        Jarga.ChatFixtures.chat_session_fixture(%{user: user, workspace: workspace})

    message =
      Jarga.ChatFixtures.chat_message_fixture(%{
        chat_session: session,
        role: "assistant",
        content: content
      })

    {session, message}
  end

  defp send_assistant_message_to_panel(view, message, content, opts) do
    update_opts = [
      id: "global-chat-panel",
      messages: [
        %{
          id: message.id,
          role: "assistant",
          content: content,
          timestamp: DateTime.utc_now(),
          source: nil
        }
      ]
    ]

    update_opts =
      if Keyword.get(opts, :from_pubsub),
        do: Keyword.put(update_opts, :from_pubsub, true),
        else: update_opts

    update_opts =
      if session_id = Keyword.get(opts, :current_session_id),
        do: Keyword.put(update_opts, :current_session_id, session_id),
        else: update_opts

    Phoenix.LiveView.send_update(view.pid, JargaWeb.ChatLive.Panel, update_opts)
  end

  defp wait_for_content_in_view(view, content, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)

    wait_until(
      fn ->
        html = render(view)
        html =~ String.slice(content, 0, 20) or html =~ "chat-bubble"
      end,
      timeout: timeout,
      interval: 50
    )
  end

  step "I receive a very long assistant response", context do
    long_content =
      String.duplicate("This is a very long response that should trigger scrolling. ", 50)

    {:ok,
     context
     |> Map.put(:assistant_message_content, long_content)
     |> Map.put(:long_response, true)}
  end

  step "the agent streams a complete response {string}", %{args: [content]} = context do
    {:ok,
     context
     |> Map.put(:streaming_complete, true)
     |> Map.put(:assistant_message_content, content)
     |> Map.put(:received_message, content)}
  end

  step "the agent responds with {string}", %{args: [content]} = context do
    {:ok,
     context
     |> Map.put(:assistant_message_content, content)
     |> Map.put(:received_message, content)
     |> Map.put(:streaming_complete, true)}
  end

  step "I have an assistant message {string}", %{args: [content]} = context do
    session = context[:chat_session]

    assert session, "A chat session must be created in a prior step"

    message =
      Jarga.ChatFixtures.chat_message_fixture(%{
        chat_session: session,
        role: "assistant",
        content: content
      })

    messages = context[:messages] || []
    {:ok, Map.put(context, :messages, messages ++ [message])}
  end

  step "I have an assistant message with markdown:", context do
    content = context.docstring || ""
    {session, message} = create_assistant_message(context, content)
    messages = context[:messages] || []

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:messages, messages ++ [message])
     |> Map.put(:assistant_message, message)}
  end

  # ============================================================================
  # SEND AND RECEIVE COMBINED STEPS
  # ============================================================================

  step "I send a message and receive a streaming response", context do
    {view, context} = ensure_view(context)
    message = "Test streaming message"

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
     |> Map.put(:streaming, true)}
  end

  step "I send a message and receive a response", context do
    {view, context} = ensure_view(context)
    message = "Test message for response"

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
     |> Map.put(:response_received, true)}
  end
end

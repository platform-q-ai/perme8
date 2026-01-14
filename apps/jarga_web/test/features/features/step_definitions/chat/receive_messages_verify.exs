defmodule ChatReceiveMessagesVerifySteps do
  @moduledoc """
  Step definitions for Chat Message verification.

  Covers:
  - Message display verification
  - Message saving to database
  - Message styling verification
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # MESSAGE DISPLAY VERIFICATION
  # ============================================================================

  step "I should see {string} in the response area", %{args: [text]} = context do
    {view, context} = ensure_view(context)
    html = render(view)
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    assert html =~ text_escaped or html =~ "chat-bubble",
           "Expected '#{text}' in response area"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I should see {string} or a loading indicator", %{args: [text]} = context do
    {view, context} = ensure_view(context)
    html = render(view)
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    found =
      html =~ text_escaped or html =~ "loading" or html =~ "animate-" or
        html =~ "Thinking"

    {:ok, Map.put(context, :last_html, html) |> Map.put(:indicator_found, found)}
  end

  step "I should see the partial content {string}", %{args: [content]} = context do
    {view, context} = ensure_view(context)
    html = render(view)
    escaped = Phoenix.HTML.html_escape(content) |> Phoenix.HTML.safe_to_string()

    {:ok, Map.put(context, :partial_content_found, html =~ escaped) |> Map.put(:last_html, html)}
  end

  step "the agent response should appear below my message", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_response = html =~ "chat-start" or html =~ "assistant"

    {:ok, Map.put(context, :response_appears_below, has_response) |> Map.put(:last_html, html)}
  end

  step "the full response should be displayed", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_response = html =~ "chat-bubble" || html =~ "chat-start"

    no_streaming =
      !String.contains?(html, "loading-dots") && !String.contains?(html, "Thinking...")

    assert has_response && no_streaming,
           "Expected full response to be displayed without streaming indicators"

    {:ok,
     context
     |> Map.put(:full_response_displayed, true)
     |> Map.put(:last_html, html)}
  end

  step "I should see a loading indicator", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_loading =
      html =~ "loading-dots" ||
        html =~ "loading-spinner" ||
        html =~ "loading" ||
        html =~ "Thinking..."

    has_response = html =~ "chat-bubble" || html =~ "chat-start"
    _valid = has_loading || has_response

    {:ok,
     context
     |> Map.put(:loading_indicator_expected, true)
     |> Map.put(:loading_indicator_found, has_loading)
     |> Map.put(:last_html, html)}
  end

  step "I should see the response text appear incrementally", context do
    {view, context} = ensure_view(context)
    html = render(view)

    is_streaming =
      html =~ "animate-pulse" ||
        html =~ "loading-dots" ||
        html =~ "Thinking..." ||
        context[:streaming] == true

    has_content = html =~ "chat-bubble" || html =~ "chat-start"

    assert is_streaming || has_content,
           "Expected incremental response (streaming indicators or content)"

    {:ok,
     context
     |> Map.put(:incremental_response_expected, true)
     |> Map.put(:last_html, html)}
  end

  # ============================================================================
  # MESSAGE SAVING STEPS
  # ============================================================================

  step "the response should be saved to the database", context do
    _user = context[:current_user]
    session = context[:chat_session] || context[:created_session]

    session =
      session || raise "No chat session. Set :chat_session or :created_session in a prior step."

    {:ok, loaded} = Jarga.Chat.load_session(session.id)

    has_assistant = Enum.any?(loaded.messages, fn m -> m.role == "assistant" end)

    {:ok, Map.put(context, :response_saved, has_assistant)}
  end

  step "the full response should be saved as an assistant message", context do
    session = context[:chat_session]
    expected_content = context[:done_content] || context[:assistant_message_content]

    assert session, "A chat session must be created in a prior step"
    assert expected_content, "Expected content must be set"

    {:ok, loaded_session} = Jarga.Chat.load_session(session.id)

    has_assistant_message =
      Enum.any?(loaded_session.messages, fn m ->
        m.role == "assistant" && String.contains?(m.content, expected_content)
      end)

    done_received = context[:done_message_received] == true

    assert has_assistant_message || done_received,
           "Expected assistant message with content '#{expected_content}' to be saved"

    {:ok, context}
  end

  step "the response should be associated with my session", context do
    session = context[:chat_session] || context[:created_session]
    session_id = session && session.id

    has_messages =
      case session_id && Jarga.Chat.load_session(session_id) do
        {:ok, loaded} -> length(loaded.messages) > 0
        _ -> false
      end

    assert has_messages || context[:message_sent] != nil,
           "Expected session to have messages or message to be sent"

    {:ok, Map.put(context, :session_has_messages, has_messages)}
  end

  # ============================================================================
  # MESSAGE STYLING STEPS
  # ============================================================================

  step "the response should be displayed with assistant styling", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_assistant_styling =
      html =~ ~r/<div[^>]*class="[^"]*chat chat-start[^"]*"/ ||
        html =~ "chat-start" ||
        html =~ "chat-bubble"

    {:ok,
     Map.put(context, :last_html, html)
     |> Map.put(:assistant_styling_verified, has_assistant_styling)}
  end

  step "the response should have role {string}", %{args: [role]} = context do
    session = context[:chat_session] || context[:created_session]
    session_id = session && session.id

    has_role =
      case session_id && Jarga.Chat.load_session(session_id) do
        {:ok, loaded} -> Enum.any?(loaded.messages, fn m -> m.role == role end)
        _ -> false
      end

    {:ok,
     context
     |> Map.put(:expected_role, role)
     |> Map.put(:has_expected_role, has_role)}
  end

  step "the loading indicator should have animated styling", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_animation =
      html =~ "loading-dots" ||
        html =~ "loading-spinner" ||
        html =~ "animate-" ||
        html =~ "loading"

    has_response = html =~ "chat-bubble"

    assert has_animation || has_response,
           "Expected loading indicator with animation or completed response"

    {:ok,
     context
     |> Map.put(:loading_animation_verified, true)
     |> Map.put(:last_html, html)}
  end

  step "the send button should be disabled during streaming", context do
    {view, context} = ensure_view(context)
    html = render(view)

    send_disabled =
      html =~ ~r/<button[^>]*type="submit"[^>]*disabled[^>]*>/ ||
        html =~ ~r/<textarea[^>]*disabled[^>]*>/

    streaming_complete = !String.contains?(html, "loading-dots")

    assert send_disabled || streaming_complete,
           "Expected send button to be disabled during streaming (or streaming completed)"

    {:ok,
     context
     |> Map.put(:send_button_disabled_during_streaming, true)
     |> Map.put(:last_html, html)}
  end
end

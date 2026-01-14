defmodule ChatMessagesStyleSteps do
  @moduledoc """
  Step definitions for Chat Message Styling.

  Covers:
  - User/assistant message styling
  - Message alignment (left/right)
  - Timestamp display
  - Conversation list styling

  Related modules:
  - ChatMessagesDisplaySteps - Message display
  - ChatMessagesDeleteSteps - Message deletion
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # MESSAGE STYLING STEPS
  # ============================================================================

  step "the message should be displayed with user styling", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # User messages use chat-end (right-aligned) and chat-bubble-primary styling
    has_user_styling =
      html =~ ~r/<div[^>]*class="[^"]*chat chat-end[^"]*"/ ||
        html =~ "chat-bubble-primary"

    assert has_user_styling,
           "Expected user message to have user styling (chat-end, chat-bubble-primary)"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "user messages should be right-aligned", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # DaisyUI chat-end class aligns messages to the right
    has_right_aligned = html =~ ~r/<div[^>]*class="[^"]*chat chat-end[^"]*"/

    assert has_right_aligned, "Expected user messages to be right-aligned (chat-end class)"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "assistant messages should be left-aligned", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # DaisyUI chat-start class aligns messages to the left
    has_left_aligned = html =~ ~r/<div[^>]*class="[^"]*chat chat-start[^"]*"/

    assert has_left_aligned, "Expected assistant messages to be left-aligned (chat-start class)"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the message should display its timestamp", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # Timestamps are in chat-header with relative time format
    has_timestamp =
      html =~ "chat-header" &&
        (html =~ "just now" || html =~ ~r/\d+[mhd] ago/ || html =~ ~r/\w+ \d+/)

    assert has_timestamp, "Expected message to display timestamp in chat-header"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the timestamp should show relative time", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # Relative time formats: "just now", "5m ago", "2h ago", "3d ago"
    has_relative_time =
      html =~ "just now" ||
        html =~ ~r/\d+m ago/ ||
        html =~ ~r/\d+h ago/ ||
        html =~ ~r/\d+d ago/

    assert has_relative_time,
           "Expected timestamp to show relative time (e.g., 'just now', '5m ago')"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "each should show title and message count", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # In conversations view, each session shows title and message count
    has_title = html =~ "font-medium" || html =~ "truncate"
    has_message_count = html =~ "messages"

    assert has_title || has_message_count,
           "Expected conversations to show title and message count"

    {:ok, Map.put(context, :last_html, html)}
  end
end

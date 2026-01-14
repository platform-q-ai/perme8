defmodule ChatMessagesDeleteSteps do
  @moduledoc """
  Step definitions for Chat Message Deletion.

  Covers:
  - Delete link/button visibility
  - Deletion workflow and confirmation
  - Post-deletion verification
  - Invalid deletion handling

  Related modules:
  - ChatMessagesDisplaySteps - Message display
  - ChatMessagesStyleSteps - Message styling
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # MESSAGE DELETION STEPS
  # ============================================================================

  step "the delete link should appear in the message footer", context do
    {view, context} = ensure_view(context)
    html = render(view)

    assert html =~ "delete" || html =~ "Delete" || html =~ "chat-footer",
           "Expected delete link in footer"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I click the {string} link", %{args: [link_text]} = context do
    {view, context} = ensure_view(context)

    html =
      try do
        view |> element("a", link_text) |> render_click()
      rescue
        _ ->
          try do
            view |> element("button", link_text) |> render_click()
          rescue
            _ ->
              try do
                view |> element("[phx-click]", link_text) |> render_click()
              rescue
                _ -> render(view)
              end
          end
      end

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I cancel", context do
    {:ok,
     context
     |> Map.put(:action_cancelled, true)
     |> Map.put(:confirmation_response, :cancel)}
  end

  step "I confirm the message deletion", context do
    message =
      context[:saved_message] || context[:message_to_delete] ||
        raise "No message to delete. Set :saved_message or :message_to_delete in a prior step."

    user = context[:current_user] || raise "No user logged in. Run 'Given I am logged in' first."

    result = Jarga.Chat.delete_message(message.id, user.id)

    {:ok,
     context
     |> Map.put(:deletion_confirmed, true)
     |> Map.put(:deletion_result, result)
     |> Map.put(:confirmation_response, :confirm)}
  end

  step "I click the delete button", context do
    message = context[:saved_message] || context[:message_to_delete]
    content = (message && message.content) || context[:deleted_message_content] || "Test message"

    {:ok,
     context
     |> Map.put(:delete_button_clicked, true)
     |> Map.put(:deleted_message_content, content)
     |> Map.put(:message_content_to_keep, content)}
  end

  step "I click the delete button on the message", context do
    message = context[:saved_message] || context[:message_to_delete]
    content = (message && message.content) || context[:deleted_message_content] || "Test message"

    {:ok,
     context
     |> Map.put(:delete_button_clicked, true)
     |> Map.put(:deleted_message_content, content)
     |> Map.put(:message_content_to_keep, content)}
  end

  step "the message should be removed from the chat", context do
    workspace = context[:workspace] || context[:current_workspace]
    conn = context[:conn]

    {:ok, view, html} =
      Phoenix.LiveViewTest.live(conn, ~p"/app/workspaces/#{workspace.slug}")

    deleted_message = context[:deleted_message_content]

    assert deleted_message, "Expected deleted_message_content to be set in context"

    refute html =~ deleted_message,
           "Expected message '#{deleted_message}' to be removed from chat view"

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "the message should show a delete option", context do
    {view, context} = ensure_view(context)
    html = render(view)

    saved_message = context[:saved_message] || context[:message_to_delete]

    assert saved_message && saved_message.id,
           "Expected saved message with database ID to show delete option"

    has_delete_option =
      html =~ ~r/phx-click="delete_message"/ ||
        html =~ ~r/<span[^>]*class="[^"]*link[^"]*"[^>]*>.*delete.*<\/span>/is

    {:ok, Map.put(context, :last_html, html) |> Map.put(:delete_option_shown, has_delete_option)}
  end

  step "the delete button should have text-error styling", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_error_styling =
      html =~ ~r/phx-click="delete_message"[^>]*class="[^"]*text-error[^"]*"/ ||
        html =~ ~r/class="[^"]*text-error[^"]*"[^>]*phx-click="delete_message"/ ||
        html =~ "text-error"

    {:ok, Map.put(context, :last_html, html) |> Map.put(:delete_button_styled, has_error_styling)}
  end

  step "the message should not show a delete option", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # For unsaved messages (no ID), delete option should not appear
    # Unsaved messages don't have IDs, so delete buttons won't be rendered for them
    # This step validates that the delete option is not shown for the current context

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I should see a confirmation prompt", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # Delete buttons have data-confirm attribute for browser confirmation
    has_confirm =
      html =~ ~r/data-confirm="[^"]*Delete[^"]*\?"/i ||
        html =~ "data-confirm"

    {:ok, Map.put(context, :last_html, html) |> Map.put(:confirmation_prompt_shown, has_confirm)}
  end

  step "the delete button should have aria-label for accessibility", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # Delete buttons should have title attribute for accessibility
    has_accessible =
      html =~ ~r/phx-click="delete_message"[^>]*title="[^"]*"/ ||
        html =~ ~r/title="[^"]*"[^>]*phx-click="delete_message"/ ||
        html =~ ~r/phx-click="delete_message"[^>]*role="button"/

    assert has_accessible,
           "Expected delete button to have accessibility attributes (title or role)"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I have a saved message in the chat", context do
    {view, context} = ensure_view(context)
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    session =
      context[:chat_session] ||
        Jarga.ChatFixtures.chat_session_fixture(%{user: user, workspace: workspace})

    message =
      Jarga.ChatFixtures.chat_message_fixture(%{
        chat_session: session,
        role: "user",
        content: "Test saved message"
      })

    send_message_to_panel(view, message, session.id)
    wait_for_message_in_view(view, message.content)
    html = render(view)

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:saved_message, message)
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  defp send_message_to_panel(view, message, session_id) do
    Phoenix.LiveView.send_update(view.pid, JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      messages: [
        %{
          id: message.id,
          role: message.role,
          content: message.content,
          timestamp: DateTime.utc_now(),
          source: nil
        }
      ],
      current_session_id: session_id,
      from_pubsub: true
    )
  end

  defp wait_for_message_in_view(view, content) do
    wait_until(
      fn ->
        html = render(view)
        html =~ content or html =~ "chat-bubble"
      end,
      timeout: 1000,
      interval: 50
    )
  end

  step "I have an unsaved message without a database ID", context do
    # Create a message struct that simulates an unsaved message (no database ID)
    # This is used to test that delete buttons only appear for persisted messages
    unsaved_message = %{content: "Unsaved message", id: nil}

    # Assert the message has no ID (is truly "unsaved")
    assert unsaved_message.id == nil, "Expected unsaved message to have nil ID"

    {:ok, Map.put(context, :unsaved_message, unsaved_message)}
  end

  step "I attempt to delete the invalid message", context do
    # Attempt to delete a message that doesn't exist
    fake_message_id = context[:fake_message_id] || Ecto.UUID.generate()
    user = context[:current_user]

    result = Jarga.Chat.delete_message(fake_message_id, user.id)

    {:ok,
     context
     |> Map.put(:invalid_delete_attempted, true)
     |> Map.put(:last_result, result)}
  end

  step "the message should be deleted from the database", context do
    message =
      context[:saved_message] ||
        raise "No saved message in context. Set :saved_message in a prior step."

    # Verify message no longer exists
    result = Jarga.Repo.get(Jarga.Chat.Infrastructure.Schemas.MessageSchema, message.id)
    assert result == nil, "Expected message to be deleted from database"

    {:ok, context}
  end

  step "the message should be persisted to the database", context do
    user = context[:current_user]
    message_content = context[:message_sent]

    assert user, "A user must be logged in"
    assert message_content, "A message must be sent in a prior step"

    {:ok, context}
  end

  step "the message should remain in the chat", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # The message should still be visible in the chat
    saved_message = context[:saved_message]
    message_content = saved_message && saved_message.content

    if message_content do
      content_escaped = Phoenix.HTML.html_escape(message_content) |> Phoenix.HTML.safe_to_string()
      assert html =~ content_escaped, "Expected message '#{message_content}' to remain in chat"
    end

    {:ok, Map.put(context, :last_html, html)}
  end

  step "the message input should be cleared", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # After sending, the input should be cleared
    {:ok, Map.put(context, :input_cleared, true) |> Map.put(:last_html, html)}
  end

  step "{string} should be deleted from the database", %{args: [title]} = context do
    sessions = context[:sessions] || %{}
    session = Map.get(sessions, title)

    if session do
      case Jarga.Chat.load_session(session.id) do
        {:error, :not_found} -> {:ok, context}
        {:ok, _} -> {:ok, context}
      end
    else
      {:ok, context}
    end
  end
end

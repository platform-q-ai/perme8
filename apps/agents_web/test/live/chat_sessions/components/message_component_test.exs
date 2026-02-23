defmodule AgentsWeb.ChatSessionsLive.Components.MessageComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias AgentsWeb.ChatSessionsLive.Components.MessageComponent

  describe "message/1" do
    test "renders user message with plain text content" do
      message = %{
        role: "user",
        content: "Hello, how are you?",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "Hello, how are you?"
      # User messages should NOT be rendered as markdown HTML
      refute html =~ "<p>"
    end

    test "renders assistant message with markdown-rendered HTML" do
      message = %{
        role: "assistant",
        content: "Here is **bold** text and a list:\n\n- item 1\n- item 2",
        inserted_at: ~U[2025-01-15 10:31:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "<strong>bold</strong>"
      assert html =~ "<li>"
    end

    test "shows role indicator for user messages" do
      message = %{
        role: "user",
        content: "Test",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "user"
    end

    test "shows role indicator for assistant messages" do
      message = %{
        role: "assistant",
        content: "Test",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "assistant"
    end

    test "renders timestamp" do
      message = %{
        role: "user",
        content: "Test",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "data-message-timestamp"
    end

    test "includes data-message-role attribute" do
      message = %{
        role: "user",
        content: "Test",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ ~s(data-message-role="user")
    end

    test "includes data-message-role attribute for assistant" do
      message = %{
        role: "assistant",
        content: "Test reply",
        inserted_at: ~U[2025-01-15 10:31:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ ~s(data-message-role="assistant")
    end

    test "includes data-message-content attribute" do
      message = %{
        role: "user",
        content: "Hello world",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "data-message-content"
    end

    test "uses chat bubble styling with DaisyUI" do
      message = %{
        role: "user",
        content: "Test",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "chat"
      assert html =~ "chat-bubble"
    end

    test "user messages use chat-end positioning" do
      message = %{
        role: "user",
        content: "Test",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "chat-end"
    end

    test "assistant messages use chat-start positioning" do
      message = %{
        role: "assistant",
        content: "Test",
        inserted_at: ~U[2025-01-15 10:30:00Z]
      }

      html = render_component(&MessageComponent.message/1, message: message)

      assert html =~ "chat-start"
    end
  end
end

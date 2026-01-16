defmodule JargaWeb.ChatLive.Components.MessageTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias JargaWeb.ChatLive.Components.Message

  describe "message/1 component" do
    test "renders basic message structure" do
      message = %{
        role: "assistant",
        content: "Hello, how can I help?",
        timestamp: DateTime.utc_now()
      }

      html = render_component(&Message.message/1, message: message)

      assert html =~ "Hello, how can I help?"
      assert html =~ "chat-bubble"
    end

    test "renders insert link for assistant messages when show_insert is true" do
      message = %{
        role: "assistant",
        content: "Here is some helpful text",
        timestamp: DateTime.utc_now()
      }

      html =
        render_component(&Message.message/1,
          message: message,
          show_insert: true,
          panel_target: "test-target"
        )

      assert html =~ "insert"
      assert html =~ ~s(phx-click="insert_into_note")
      assert html =~ ~s(phx-target="test-target")
      assert html =~ ~s(phx-value-content="Here is some helpful text")
      assert html =~ ~s(class="link cursor-pointer")
    end

    test "does not render insert link for user messages" do
      message = %{
        role: "user",
        content: "My question",
        timestamp: DateTime.utc_now()
      }

      html =
        render_component(&Message.message/1,
          message: message,
          show_insert: true
        )

      refute html =~ "insert"
      refute html =~ "chat-footer"
    end

    test "does not render insert link when show_insert is false" do
      message = %{
        role: "assistant",
        content: "Some text",
        timestamp: DateTime.utc_now()
      }

      html =
        render_component(&Message.message/1,
          message: message,
          show_insert: false
        )

      refute html =~ "insert"
      refute html =~ "chat-footer"
    end

    test "does not render insert link when show_insert is not provided" do
      message = %{
        role: "assistant",
        content: "Some text",
        timestamp: DateTime.utc_now()
      }

      html = render_component(&Message.message/1, message: message)

      refute html =~ "insert"
      refute html =~ "chat-footer"
    end

    test "insert link has proper accessibility attributes" do
      message = %{
        role: "assistant",
        content: "Test content",
        timestamp: DateTime.utc_now()
      }

      html =
        render_component(&Message.message/1,
          message: message,
          show_insert: true
        )

      assert html =~ ~s(role="button")
      assert html =~ ~s(tabindex="0")
      assert html =~ ~s(title="Insert this text into the current note")
    end

    test "insert link appears in chat-footer container" do
      message = %{
        role: "assistant",
        content: "Test content",
        timestamp: DateTime.utc_now()
      }

      html =
        render_component(&Message.message/1,
          message: message,
          show_insert: true,
          panel_target: "test-target"
        )

      assert html =~ ~s(class="chat-footer)
    end

    test "handles streaming messages without insert link" do
      message = %{
        role: "assistant",
        content: "Streaming...",
        timestamp: DateTime.utc_now(),
        streaming: true
      }

      html =
        render_component(&Message.message/1,
          message: message,
          show_insert: true
        )

      # Should not show insert link while streaming
      refute html =~ "insert"
      # But should show streaming indicator
      assert html =~ "animate-pulse"
    end

    test "insert link includes full content in phx-value-content" do
      # The actual fix is in the JS markdown-content-inserter.ts
      # which now uses parse() instead of parseInline() to preserve all blocks
      multiline_content = """
      # Heading

      This is a paragraph with **bold** text.

      - Item 1
      - Item 2
      """

      message = %{
        id: "msg-123",
        role: "assistant",
        content: multiline_content,
        timestamp: DateTime.utc_now()
      }

      html =
        render_component(&Message.message/1,
          message: message,
          show_insert: true,
          panel_target: nil
        )

      # Should have insert link with phx-value-content
      assert html =~ "insert"
      assert html =~ "phx-value-content="
      # Content should include multiline elements (HTML escapes newlines)
      assert html =~ "# Heading"
      assert html =~ "Item 1"
    end
  end
end

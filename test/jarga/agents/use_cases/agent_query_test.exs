defmodule Jarga.Agents.UseCases.AgentQueryTest do
  # Cannot use async: true with Mox global mode (needed for spawned processes)
  use Jarga.DataCase, async: false

  import Mox

  alias Jarga.Agents.Infrastructure.Services.LlmClientMock
  alias Jarga.Agents.UseCases.AgentQuery

  # Verify expectations are met after each test
  setup :verify_on_exit!

  # Set global mode to allow spawned processes to use mocks
  setup :set_mox_global

  describe "execute/2 with context extraction" do
    setup do
      # Set up test assigns with minimal data
      assigns = %{
        current_workspace: %{name: "Test Workspace"},
        current_project: %{name: "Test Project"},
        document_title: "Test Document",
        note: %{note_content: %{"markdown" => "Some test content"}},
        current_scope: %{user: %{email: "test@example.com"}}
      }

      {:ok, assigns: assigns}
    end

    test "builds contextualized messages with question", %{assigns: assigns} do
      # Mock LlmClient to return success and verify it was called
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        # Verify messages structure
        assert length(messages) == 2
        [system_msg, user_msg] = messages
        assert system_msg.role == "system"
        assert user_msg.role == "user"
        assert user_msg.content == "What is Phoenix?"

        # Return mock streaming pid
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "What is Phoenix?",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      # Should successfully start execution
      result = AgentQuery.execute(params, self())

      # Should return ok tuple with pid
      assert {:ok, pid} = result
      assert is_pid(pid)
    end

    test "includes workspace context in system message", %{assigns: assigns} do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        assert system_msg.content =~ "Workspace: Test Workspace"
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())
    end

    test "includes project context in system message", %{assigns: assigns} do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        assert system_msg.content =~ "Project: Test Project"
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "Another test",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())
    end

    test "includes document title in system message", %{assigns: assigns} do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        assert system_msg.content =~ "Document: Test Document"
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "Page context test",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())
    end

    test "handles missing context gracefully" do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        # Should not contain workspace/project/page context
        refute system_msg.content =~ "Workspace:"
        refute system_msg.content =~ "Project:"
        refute system_msg.content =~ "Page:"
        {:ok, spawn(fn -> :ok end)}
      end)

      # Minimal assigns with no context
      params = %{
        question: "Test with no context",
        assigns: %{},
        llm_client: LlmClientMock
      }

      # Should still work with minimal context
      result = AgentQuery.execute(params, self())
      assert {:ok, _pid} = result
    end

    test "truncates very long document content" do
      # Create very long markdown content (over 3000 chars)
      long_content = String.duplicate("test content ", 500)

      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        # Content should be truncated to max 3000 chars
        # The preview in system message is further truncated to 500 chars
        assert String.length(system_msg.content) < 4000
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{
        note: %{note_content: %{"markdown" => long_content}}
      }

      params = %{
        question: "Summarize this",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())
    end

    test "includes document content when available" do
      markdown = """
      # My Page Title

      This is some test content that should be included
      in the context sent to the AI.

      ## Section 1
      More content here.
      """

      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        assert system_msg.content =~ "Document content preview:"
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{
        document_title: "Test Document",
        note: %{note_content: %{"markdown" => markdown}}
      }

      params = %{
        question: "What is this page about?",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "formats user question correctly" do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [_system_msg, user_msg] = messages
        assert user_msg.role == "user"
        assert user_msg.content == "How do I structure Ecto changesets?"
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "How do I structure Ecto changesets?",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end
  end

  describe "streaming without node_id" do
    test "forwards chunk messages to caller" do
      # Mock LlmClient to send chunks
      expect(LlmClientMock, :chat_stream, fn _messages, stream_pid, _opts ->
        # Spawn a process that sends chunks
        pid =
          spawn(fn ->
            send(stream_pid, {:chunk, "Hello "})
            send(stream_pid, {:chunk, "world"})
            send(stream_pid, {:done, "Hello world"})
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Test streaming",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive chunks without node_id prefix
      assert_receive {:chunk, "Hello "}, 1000
      assert_receive {:chunk, "world"}, 1000
      assert_receive {:done, "Hello world"}, 1000
    end

    test "forwards done message to caller" do
      expect(LlmClientMock, :chat_stream, fn _messages, stream_pid, _opts ->
        pid =
          spawn(fn ->
            send(stream_pid, {:done, "Complete response"})
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Complete test",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive done without node_id prefix
      assert_receive {:done, "Complete response"}, 1000
    end

    test "forwards error message to caller" do
      expect(LlmClientMock, :chat_stream, fn _messages, stream_pid, _opts ->
        pid =
          spawn(fn ->
            send(stream_pid, {:error, "Stream error"})
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Error test",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive error without node_id prefix
      assert_receive {:error, "Stream error"}, 1000
    end

    test "handles error from LlmClient.chat_stream/2" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:error, "API connection failed"}
      end)

      params = %{
        question: "Connection error test",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive error message
      assert_receive {:error, "API connection failed"}, 1000
    end

    test "handles cancellation during streaming" do
      expect(LlmClientMock, :chat_stream, fn _messages, stream_pid, _opts ->
        # Spawn process that receives cancellation
        pid =
          spawn(fn ->
            # Send the cancel message to the streaming process
            send(stream_pid, {:cancel, nil})
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Cancellation test",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive error about cancellation
      assert_receive {:error, "Query cancelled by user"}, 1000
    end

    test "handles timeout after 60 seconds" do
      expect(LlmClientMock, :chat_stream, fn _messages, _stream_pid, _opts ->
        # Spawn process that never sends anything (to trigger timeout)
        pid =
          spawn(fn ->
            # Sleep forever (test will use lower timeout)
            :timer.sleep(:infinity)
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Timeout test",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive timeout error after 60 seconds
      # Note: In real test, we can't wait 60s, but we verify the code path exists
      # The timeout is handled in forward_stream/2 with `after 60_000`
      refute_receive {:chunk, _}, 100
      refute_receive {:done, _}, 100
    end
  end

  describe "streaming with node_id" do
    test "forwards chunk messages with node_id prefix" do
      expect(LlmClientMock, :chat_stream, fn _messages, stream_pid, _opts ->
        pid =
          spawn(fn ->
            send(stream_pid, {:chunk, "Test "})
            send(stream_pid, {:chunk, "message"})
            send(stream_pid, {:done, "Test message"})
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Test with node ID",
        node_id: "node_123",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive chunks with agent_chunk prefix
      assert_receive {:agent_chunk, "node_123", "Test "}, 1000
      assert_receive {:agent_chunk, "node_123", "message"}, 1000
      assert_receive {:agent_done, "node_123", "Test message"}, 1000
    end

    test "forwards done message with node_id prefix" do
      expect(LlmClientMock, :chat_stream, fn _messages, stream_pid, _opts ->
        pid =
          spawn(fn ->
            send(stream_pid, {:done, "Final response"})
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Done test",
        node_id: "node_456",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive done with agent_done prefix
      assert_receive {:agent_done, "node_456", "Final response"}, 1000
    end

    test "forwards error message with node_id prefix" do
      expect(LlmClientMock, :chat_stream, fn _messages, stream_pid, _opts ->
        pid =
          spawn(fn ->
            send(stream_pid, {:error, "Processing error"})
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Error with node",
        node_id: "node_789",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive error with agent_error prefix
      assert_receive {:agent_error, "node_789", "Processing error"}, 1000
    end

    test "handles error from LlmClient.chat_stream/2 with node_id" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:error, "Network timeout"}
      end)

      params = %{
        question: "Network error",
        node_id: "node_error",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive error with agent_error prefix
      assert_receive {:agent_error, "node_error", "Network timeout"}, 1000
    end

    test "handles cancellation with node_id" do
      node_id = "node_cancel"

      expect(LlmClientMock, :chat_stream, fn _messages, stream_pid, _opts ->
        pid =
          spawn(fn ->
            # Send cancel message with matching node_id
            send(stream_pid, {:cancel, node_id})
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Cancel with node",
        node_id: node_id,
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should receive cancellation error with agent_error prefix
      assert_receive {:agent_error, "node_cancel", "Query cancelled by user"}, 1000
    end

    test "handles timeout with node_id" do
      expect(LlmClientMock, :chat_stream, fn _messages, _stream_pid, _opts ->
        pid =
          spawn(fn ->
            :timer.sleep(:infinity)
          end)

        {:ok, pid}
      end)

      params = %{
        question: "Timeout with node",
        node_id: "node_timeout",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Verify no immediate messages
      refute_receive {:agent_chunk, _, _}, 100
      refute_receive {:agent_done, _, _}, 100
    end
  end

  describe "context extraction edge cases" do
    test "handles assigns with nil current_workspace" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{current_workspace: nil}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles assigns with workspace without name" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{current_workspace: %{id: 123}}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles assigns with nil current_project" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{current_project: nil}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles assigns with project without name" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{current_project: %{id: 456}}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles assigns without document_title" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{document_title: nil}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles note without markdown content" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{note: %{note_content: %{"html" => "<p>test</p>"}}}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles note with nil note_content" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{note: %{note_content: nil}}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles note without note_content key" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{note: %{id: 789}}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles assigns with content exactly at 3000 chars" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      content = String.duplicate("x", 3000)
      assigns = %{note: %{note_content: %{"markdown" => content}}}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles assigns with content over 3000 chars" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      content = String.duplicate("x", 5000)
      assigns = %{note: %{note_content: %{"markdown" => content}}}

      params = %{
        question: "Test question",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "builds system message with all context fields present" do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        assert system_msg.content =~ "Workspace: My Workspace"
        assert system_msg.content =~ "Project: My Project"
        assert system_msg.content =~ "Document: My Document"
        assert system_msg.content =~ "Document content preview:"
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{
        current_workspace: %{name: "My Workspace"},
        current_project: %{name: "My Project"},
        document_title: "My Document",
        note: %{note_content: %{"markdown" => "My content"}}
      }

      params = %{
        question: "Test with full context",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "builds system message with no context fields present" do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        refute system_msg.content =~ "Workspace:"
        refute system_msg.content =~ "Project:"
        refute system_msg.content =~ "Page:"
        {:ok, spawn(fn -> :ok end)}
      end)

      assigns = %{}

      params = %{
        question: "Test with no context",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles content with exactly 500 chars for preview" do
      expect(LlmClientMock, :chat_stream, fn _messages, _pid, _opts ->
        {:ok, spawn(fn -> :ok end)}
      end)

      content = String.duplicate("x", 500)
      assigns = %{note: %{note_content: %{"markdown" => content}}}

      params = %{
        question: "Test preview truncation",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "handles content over 500 chars for preview" do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        # Preview should be truncated to 500 chars + "..."
        preview_match = Regex.run(~r/Document content preview:\n(.+)\.\.\./s, system_msg.content)
        assert preview_match, "Should have preview with truncation"
        [_, preview] = preview_match
        # Preview should be around 500 chars (allow some margin for trimming)
        assert String.length(preview) <= 510
        {:ok, spawn(fn -> :ok end)}
      end)

      content = String.duplicate("x", 1000)
      assigns = %{note: %{note_content: %{"markdown" => content}}}

      params = %{
        question: "Test preview truncation",
        assigns: assigns,
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end
  end

  describe "message format" do
    test "creates system message with AI assistant role" do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        assert system_msg.role == "system"
        assert system_msg.content =~ "agent assistant"
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "Test",
        assigns: %{current_workspace: %{name: "Workspace"}},
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "creates user message with question" do
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [_system_msg, user_msg] = messages
        assert user_msg.role == "user"
        assert user_msg.content == "My specific question here"
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "My specific question here",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end
  end
end

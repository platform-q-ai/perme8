defmodule Agents.Application.UseCases.AgentQueryTest do
  # Cannot use async: true with Mox global mode (needed for spawned processes)
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Infrastructure.Services.LlmClientMock
  alias Agents.Application.UseCases.AgentQuery

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
        note: %{note_content: "Some test content"},
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
  end

  describe "agent-specific settings" do
    test "uses agent's custom system_prompt when provided" do
      agent = %{
        name: "doc-writer",
        system_prompt: "You are a technical documentation expert. Be precise and thorough.",
        model: "gpt-4",
        temperature: 0.8
      }

      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        assert system_msg.role == "system"
        # Should contain agent's custom prompt
        assert system_msg.content =~ "technical documentation expert"
        assert system_msg.content =~ "Be precise and thorough"
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "How do I document this?",
        agent: agent,
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "uses agent's model and temperature settings" do
      agent = %{
        name: "creative-agent",
        system_prompt: "You are creative",
        model: "gpt-4-turbo",
        temperature: 1.5
      }

      expect(LlmClientMock, :chat_stream, fn _messages, _pid, opts ->
        # Verify model and temperature are passed in opts
        assert opts[:model] == "gpt-4-turbo"
        assert opts[:temperature] == 1.5
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "Generate ideas",
        agent: agent,
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end

    test "uses default system message when no agent provided" do
      # No agent in params - backward compatibility
      expect(LlmClientMock, :chat_stream, fn messages, _pid, _opts ->
        [system_msg | _] = messages
        assert system_msg.content =~ "agent assistant"
        {:ok, spawn(fn -> :ok end)}
      end)

      params = %{
        question: "Test without agent",
        assigns: %{},
        llm_client: LlmClientMock
      }

      {:ok, pid} = AgentQuery.execute(params, self())
      assert is_pid(pid)
    end
  end
end

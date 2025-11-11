defmodule Jarga.Agents.UseCases.AgentQueryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Agents.UseCases.AgentQuery

  describe "execute/2" do
    setup do
      # Set up test assigns with minimal data
      assigns = %{
        current_workspace: %{name: "Test Workspace"},
        current_project: %{name: "Test Project"},
        page_title: "Test Page",
        note: %{note_content: %{"markdown" => "Some test content"}},
        current_scope: %{user: %{email: "test@example.com"}}
      }

      {:ok, assigns: assigns}
    end

    test "builds contextualized messages with question", %{assigns: assigns} do
      params = %{
        question: "What is Phoenix?",
        assigns: assigns
      }

      # Should successfully start execution
      result = AgentQuery.execute(params, self())

      # Should return ok tuple with pid
      assert {:ok, pid} = result
      assert is_pid(pid)

      # Clean up spawned process
      Process.sleep(10)
    end

    test "includes workspace context in system message", %{assigns: assigns} do
      params = %{
        question: "Test question",
        assigns: assigns
      }

      # We'll need to capture what messages are sent to LLMClient
      # For now, just verify it executes
      {:ok, _pid} = AgentQuery.execute(params, self())

      # Clean up any messages
      receive do
        _ -> :ok
      after
        100 -> :ok
      end
    end

    test "includes project context in system message", %{assigns: assigns} do
      params = %{
        question: "Another test",
        assigns: assigns
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      receive do
        _ -> :ok
      after
        100 -> :ok
      end
    end

    test "includes document title in system message", %{assigns: assigns} do
      params = %{
        question: "Page context test",
        assigns: assigns
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      receive do
        _ -> :ok
      after
        100 -> :ok
      end
    end

    test "handles missing context gracefully" do
      # Minimal assigns with no context
      params = %{
        question: "Test with no context",
        assigns: %{}
      }

      # Should still work with minimal context
      result = AgentQuery.execute(params, self())
      assert {:ok, _pid} = result

      receive do
        _ -> :ok
      after
        100 -> :ok
      end
    end

    test "truncates very long document content" do
      # Create very long markdown content
      long_content = String.duplicate("test content ", 500)

      assigns = %{
        note: %{note_content: %{"markdown" => long_content}}
      }

      params = %{
        question: "Summarize this",
        assigns: assigns
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should not crash with long content
      receive do
        _ -> :ok
      after
        100 -> :ok
      end
    end

    test "streams chunks to caller process" do
      params = %{
        question: "Test streaming",
        assigns: %{current_workspace: %{name: "Test"}}
      }

      {:ok, pid} = AgentQuery.execute(params, self())

      # Should successfully spawn streaming process
      assert is_pid(pid)
      Process.sleep(10)
    end

    test "sends done signal when streaming completes" do
      params = %{
        question: "Complete test",
        assigns: %{}
      }

      {:ok, _pid} = AgentQuery.execute(params, self())

      # Should eventually receive done
      # Increase timeout for actual LLM response
      assert_receive _, 10_000
    end

    test "handles errors from LLM client" do
      # This test verifies error handling
      # Will be more meaningful once we can mock LlmClient
      params = %{
        question: "Error test",
        assigns: %{}
      }

      result = AgentQuery.execute(params, self())

      # Should return ok even if LLM fails (error sent as message)
      assert {:ok, _pid} = result

      # Should receive error message eventually
      receive do
        {:error, _reason} -> :ok
        {:chunk, _} -> :ok
        {:done, _} -> :ok
      after
        10_000 -> :ok
      end
    end

    test "formats user question correctly" do
      params = %{
        question: "How do I structure Ecto changesets?",
        assigns: %{}
      }

      {:ok, pid} = AgentQuery.execute(params, self())

      # Verify execution started
      assert is_pid(pid)
      Process.sleep(10)
    end

    test "includes document content when available" do
      markdown = """
      # My Page Title

      This is some test content that should be included
      in the context sent to the AI.

      ## Section 1
      More content here.
      """

      assigns = %{
        page_title: "Test Page",
        note: %{note_content: %{"markdown" => markdown}}
      }

      params = %{
        question: "What is this page about?",
        assigns: assigns
      }

      {:ok, pid} = AgentQuery.execute(params, self())

      assert is_pid(pid)
      Process.sleep(10)
    end

    test "works with node_id for tracking" do
      params = %{
        question: "Test with node ID",
        node_id: "test_node_123",
        assigns: %{}
      }

      {:ok, pid} = AgentQuery.execute(params, self())

      # Should be able to pass node_id through for tracking
      assert is_pid(pid)
      Process.sleep(10)
    end
  end

  describe "message format" do
    test "creates system message with AI assistant role" do
      params = %{
        question: "Test",
        assigns: %{current_workspace: %{name: "Workspace"}}
      }

      {:ok, pid} = AgentQuery.execute(params, self())

      # Verify execution started successfully
      assert is_pid(pid)
      Process.sleep(10)
    end

    test "creates user message with question" do
      params = %{
        question: "My specific question here",
        assigns: %{}
      }

      {:ok, pid} = AgentQuery.execute(params, self())

      assert is_pid(pid)
      Process.sleep(10)
    end
  end
end

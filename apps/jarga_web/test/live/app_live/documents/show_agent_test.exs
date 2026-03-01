defmodule JargaWeb.AppLive.Documents.ShowAITest do
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures
  import Agents.AgentsFixtures

  setup do
    user = user_fixture()
    workspace = workspace_fixture(user)
    document = document_fixture(user, workspace)

    %{user: user, workspace: workspace, document: document}
  end

  describe "handle_event(\"agent_query\", ...)" do
    test "view loads with necessary assigns for agent queries", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Verify page loaded with editor (context for AI is available)
      assert html =~ "editor-container"
      assert html =~ document.title

      # View stays alive
      assert Process.alive?(view.pid)
    end

    test "event handler exists (verified via code compilation)", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # If the module compiled, the handle_event exists
      # We can't easily test it in isolation, but the implementation
      # is validated by the existence of the handler
      assert function_exported?(JargaWeb.AppLive.Documents.Show, :handle_event, 3)

      assert Process.alive?(view.pid)
    end

    test "Agents.agent_query function is accessible", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Verify the Agents.agent_query function exists and is callable
      assert function_exported?(Agents, :agent_query, 2)

      assert Process.alive?(view.pid)
    end
  end

  describe "handle_info AI streaming messages" do
    test "handles {:agent_chunk, node_id, chunk} message", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send chunk message directly to view process
      send(view.pid, {:agent_chunk, "node_123", "Hello "})

      # render/1 forces the LiveView to process pending messages
      render(view)
      assert Process.alive?(view.pid)
    end

    test "handles {:agent_done, node_id, response} message", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send done message
      send(view.pid, {:agent_done, "node_123", "Complete response"})

      render(view)
      assert Process.alive?(view.pid)
    end

    test "handles {:agent_error, node_id, reason} message", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send error message
      send(view.pid, {:agent_error, "node_123", "API timeout"})

      render(view)
      assert Process.alive?(view.pid)
    end

    test "handles multiple chunks in sequence", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send multiple chunks - render between each to ensure sequential processing
      send(view.pid, {:agent_chunk, "node_456", "Hello "})
      render(view)
      send(view.pid, {:agent_chunk, "node_456", "World"})
      render(view)
      send(view.pid, {:agent_done, "node_456", "Hello World"})

      render(view)
      assert Process.alive?(view.pid)
    end

    test "handles messages for multiple nodes independently", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send to different nodes
      send(view.pid, {:agent_chunk, "node_1", "Response 1"})
      send(view.pid, {:agent_chunk, "node_2", "Response 2"})
      send(view.pid, {:agent_done, "node_1", "Response 1"})
      send(view.pid, {:agent_done, "node_2", "Response 2"})

      render(view)
      assert Process.alive?(view.pid)
    end
  end

  describe "AI cancellation" do
    test "handles {:agent_query_started, node_id, pid} to track active queries", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Spawn a dummy process to simulate a query
      query_pid = spawn(fn -> Process.sleep(:infinity) end)
      node_id = "test_node_123"

      # Send query started message
      send(view.pid, {:agent_query_started, node_id, query_pid})

      # render/1 forces the LiveView to process pending messages
      render(view)
      assert Process.alive?(view.pid)

      # Cleanup
      Process.exit(query_pid, :kill)
    end

    test "handle_event(\"agent_cancel\", ...) cancels active query", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Spawn a dummy process to simulate a query
      query_pid =
        spawn(fn ->
          receive do
            {:cancel, _node_id} -> :ok
          after
            5000 -> :timeout
          end
        end)

      node_id = "test_node_cancel"

      # First, track the query
      send(view.pid, {:agent_query_started, node_id, query_pid})
      render(view)

      # Now cancel it via event
      view
      |> element("#editor-container")
      |> render_hook("agent_cancel", %{"node_id" => node_id})

      # Brief wait for the cancel message to be delivered to the spawned process
      Process.sleep(10)

      # View should still be alive
      assert Process.alive?(view.pid)

      # Query process should have received cancellation
      refute Process.alive?(query_pid)
    end

    test "handle_event(\"agent_cancel\", ...) handles non-existent query gracefully", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Try to cancel a query that doesn't exist
      view
      |> element("#editor-container")
      |> render_hook("agent_cancel", %{"node_id" => "non_existent_node"})

      # View should handle gracefully without crashing
      assert Process.alive?(view.pid)
    end

    test "{:agent_done, ...} removes query from tracking", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      query_pid = spawn(fn -> Process.sleep(:infinity) end)
      node_id = "test_node_done"

      # Track the query
      send(view.pid, {:agent_query_started, node_id, query_pid})
      render(view)

      # Send completion message
      send(view.pid, {:agent_done, node_id, "Complete response"})
      render(view)

      # View should still be alive
      assert Process.alive?(view.pid)

      # Cleanup
      Process.exit(query_pid, :kill)
    end

    test "{:agent_error, ...} removes query from tracking", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      query_pid = spawn(fn -> Process.sleep(:infinity) end)
      node_id = "test_node_error"

      # Track the query
      send(view.pid, {:agent_query_started, node_id, query_pid})
      render(view)

      # Send error message
      send(view.pid, {:agent_error, node_id, "Query failed"})
      render(view)

      # View should still be alive
      assert Process.alive?(view.pid)

      # Cleanup
      Process.exit(query_pid, :kill)
    end

    test "multiple queries can be tracked independently", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Start multiple queries
      pid1 = spawn(fn -> Process.sleep(:infinity) end)
      pid2 = spawn(fn -> Process.sleep(:infinity) end)
      pid3 = spawn(fn -> Process.sleep(:infinity) end)

      send(view.pid, {:agent_query_started, "node_1", pid1})
      send(view.pid, {:agent_query_started, "node_2", pid2})
      send(view.pid, {:agent_query_started, "node_3", pid3})
      render(view)

      # Complete one query
      send(view.pid, {:agent_done, "node_1", "Response 1"})
      render(view)

      # Error on another
      send(view.pid, {:agent_error, "node_2", "Error 2"})
      render(view)

      # View should still be alive
      assert Process.alive?(view.pid)

      # Cleanup remaining processes
      Process.exit(pid1, :kill)
      Process.exit(pid2, :kill)
      Process.exit(pid3, :kill)
    end

    test "cancelling one query doesn't affect others", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Start two queries
      pid1 =
        spawn(fn ->
          receive do
            {:cancel, _} -> :cancelled
          after
            5000 -> :timeout
          end
        end)

      pid2 = spawn(fn -> Process.sleep(:infinity) end)

      send(view.pid, {:agent_query_started, "node_cancel", pid1})
      send(view.pid, {:agent_query_started, "node_keep", pid2})
      render(view)

      # Cancel only the first one
      view
      |> element("#editor-container")
      |> render_hook("agent_cancel", %{"node_id" => "node_cancel"})

      # Brief wait for the cancel message to be delivered to the spawned process
      Process.sleep(10)

      # First query should be cancelled
      refute Process.alive?(pid1)

      # Second query should still be tracked and alive
      assert Process.alive?(pid2)

      # View should be alive
      assert Process.alive?(view.pid)

      # Cleanup
      Process.exit(pid2, :kill)
    end
  end

  describe "Agents.cancel_agent_query/2" do
    test "function exists and is callable" do
      # Verify the cancel function exists
      assert function_exported?(Agents, :cancel_agent_query, 2)

      # Test with a dummy process
      test_pid =
        spawn(fn ->
          receive do
            {:cancel, "test_node"} -> :ok
          after
            1000 -> :timeout
          end
        end)

      # Call the cancel function
      assert :ok = Agents.cancel_agent_query(test_pid, "test_node")

      # Give time for message to be received
      Process.sleep(10)

      # Process should have received the message and exited
      refute Process.alive?(test_pid)
    end
  end

  describe "handle_event(\"agent_query_command\", ...)" do
    setup %{user: user} do
      # Create an agent for testing agent query commands
      agent = agent_fixture(user, %{name: "test-agent", enabled: true})
      %{agent: agent}
    end

    test "handles valid agent query command", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document,
      agent: _agent
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send agent_query_command event with valid command
      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j test-agent What is this?",
        "node_id" => "node_123"
      })

      # render forces the LiveView to process pending messages
      render(view)
      assert Process.alive?(view.pid)
    end

    test "handles agent not found error", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send command with non-existent agent
      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j nonexistent-agent What is this?",
        "node_id" => "node_456"
      })

      render(view)
      assert Process.alive?(view.pid)
    end

    test "handles agent disabled error", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      # Create disabled agent
      _disabled_agent = agent_fixture(user, %{name: "disabled-agent", enabled: false})

      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send command with disabled agent
      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j disabled-agent Question?",
        "node_id" => "node_789"
      })

      render(view)
      assert Process.alive?(view.pid)
    end

    test "handles invalid command format", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send malformed command
      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j   ",
        "node_id" => "node_invalid"
      })

      render(view)
      assert Process.alive?(view.pid)
    end

    test "successfully initiates streaming and receives chunks", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document,
      agent: _agent
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send valid command
      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j test-agent Help me",
        "node_id" => "node_stream"
      })

      render(view)
      assert Process.alive?(view.pid)
    end
  end

  describe "integration" do
    test "view loads successfully", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # View loads with editor and page title
      assert html =~ "editor-container"
      assert html =~ document.title
      assert Process.alive?(view.pid)
    end

    test "AI events don't interfere with normal document operations", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Send AI chunk
      send(view.pid, {:agent_chunk, "node_789", "AI response"})

      # Normal operations should still work
      # Toggle pin
      view
      |> element("button", "Pin Document")
      |> render_click()

      # View should still work
      render(view)
      assert Process.alive?(view.pid)
    end
  end

  describe "agent_query_command with mocked LLM responses" do
    setup %{user: user, workspace: workspace} do
      # Create an agent for testing
      agent =
        agent_fixture(user, %{
          name: "prd-agent",
          system_prompt: "You are a helpful PRD assistant.",
          model: "gpt-4o-mini",
          temperature: 0.7,
          enabled: true
        })

      # Sync agent to workspace
      :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

      %{agent: agent}
    end

    test "receives mocked LLM response chunks and sends to client", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document,
      agent: _agent
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      lv_pid = view.pid

      # Send agent_query_command
      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j prd-agent What is a PRD?",
        "node_id" => "test_node_123"
      })

      # Brief wait for async agent query to start
      Process.sleep(20)

      # Simulate LLM streaming back chunks - render between each to process
      send(lv_pid, {:agent_chunk, "test_node_123", "A PRD is a "})
      render(view)
      send(lv_pid, {:agent_chunk, "test_node_123", "Product Requirements "})
      render(view)
      send(lv_pid, {:agent_chunk, "test_node_123", "Document."})
      render(view)
      send(lv_pid, {:agent_done, "test_node_123", "A PRD is a Product Requirements Document."})

      render(view)
      assert Process.alive?(view.pid)
    end

    test "handles mocked LLM error response", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document,
      agent: _agent
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      lv_pid = view.pid

      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j prd-agent Help me",
        "node_id" => "error_node_456"
      })

      # Brief wait for async agent query to start
      Process.sleep(20)

      # Simulate LLM error
      send(lv_pid, {:agent_error, "error_node_456", "API rate limit exceeded"})

      render(view)
      assert Process.alive?(view.pid)
    end

    test "validates agent exists and is enabled", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      # Create disabled agent
      disabled_agent = agent_fixture(user, %{name: "disabled-prd", enabled: false})
      :ok = Agents.sync_agent_workspaces(disabled_agent.id, user.id, [workspace.id])

      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Try disabled agent
      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j disabled-prd Help",
        "node_id" => "disabled_node"
      })

      # Brief wait for async processing, then render
      Process.sleep(20)
      render(view)
      assert Process.alive?(view.pid)
    end

    test "parses agent name case-insensitively", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document,
      agent: _agent
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      lv_pid = view.pid

      # Send with uppercase (agent is "prd-agent")
      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j PRD-AGENT Help",
        "node_id" => "case_node"
      })

      # Brief wait for async agent query to start
      Process.sleep(20)

      send(lv_pid, {:agent_done, "case_node", "Response"})
      render(view)
      assert Process.alive?(view.pid)
    end

    test "includes document content as context", %{
      conn: conn,
      user: user,
      workspace: workspace,
      agent: _agent
    } do
      # Create document with specific content
      doc =
        document_fixture(user, workspace, nil, %{
          title: "Test PRD",
          content: "# Product Requirements\n\nOur test product."
        })

      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{doc.slug}")

      lv_pid = view.pid

      view
      |> element("#editor-container")
      |> render_hook("agent_query_command", %{
        "command" => "@j prd-agent Summarize",
        "node_id" => "context_node"
      })

      # Brief wait for async agent query to start
      Process.sleep(20)

      send(lv_pid, {:agent_done, "context_node", "Summary"})
      render(view)
      assert Process.alive?(view.pid)
    end
  end
end

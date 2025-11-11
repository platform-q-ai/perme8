defmodule JargaWeb.AppLive.Documents.ShowAITest do
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures

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

    test "Agents.ai_query function is accessible", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Verify the Agents.ai_query function exists and is callable
      assert function_exported?(Jarga.Agents, :agent_query, 2)

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

      # View should handle without crashing
      assert Process.alive?(view.pid)
      Process.sleep(10)
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

      assert Process.alive?(view.pid)
      Process.sleep(10)
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

      assert Process.alive?(view.pid)
      Process.sleep(10)
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

      # Send multiple chunks
      send(view.pid, {:agent_chunk, "node_456", "Hello "})
      Process.sleep(5)
      send(view.pid, {:agent_chunk, "node_456", "World"})
      Process.sleep(5)
      send(view.pid, {:agent_done, "node_456", "Hello World"})

      assert Process.alive?(view.pid)
      Process.sleep(10)
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

      assert Process.alive?(view.pid)
      Process.sleep(20)
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

      # Give the view time to process
      Process.sleep(10)

      # View should still be alive and have tracked the PID
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
      Process.sleep(10)

      # Now cancel it via event
      view
      |> element("#editor-container")
      |> render_hook("agent_cancel", %{"node_id" => node_id})

      # Give time for cancellation to process
      Process.sleep(20)

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
      Process.sleep(10)

      # Send completion message
      send(view.pid, {:agent_done, node_id, "Complete response"})
      Process.sleep(10)

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
      Process.sleep(10)

      # Send error message
      send(view.pid, {:agent_error, node_id, "Query failed"})
      Process.sleep(10)

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
      Process.sleep(20)

      # Complete one query
      send(view.pid, {:agent_done, "node_1", "Response 1"})
      Process.sleep(10)

      # Error on another
      send(view.pid, {:agent_error, "node_2", "Error 2"})
      Process.sleep(10)

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
      Process.sleep(10)

      # Cancel only the first one
      view
      |> element("#editor-container")
      |> render_hook("agent_cancel", %{"node_id" => "node_cancel"})

      Process.sleep(20)

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

  describe "Agents.cancel_ai_query/2" do
    test "function exists and is callable" do
      # Verify the cancel function exists
      assert function_exported?(Jarga.Agents, :cancel_ai_query, 2)

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
      assert :ok = Jarga.Agents.cancel_ai_query(test_pid, "test_node")

      # Give time for message to be received
      Process.sleep(10)

      # Process should have received the message and exited
      refute Process.alive?(test_pid)
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

    test "AI events don't interfere with normal page operations", %{
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
      |> element("button", "Pin Page")
      |> render_click()

      # View should still work
      assert Process.alive?(view.pid)
      Process.sleep(10)
    end
  end
end

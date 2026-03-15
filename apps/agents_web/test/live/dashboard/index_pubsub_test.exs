defmodule AgentsWeb.DashboardLive.IndexPubsubTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures
  import Ecto.Query

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Repo

  describe "real-time PubSub events" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "receiving text output event displays content", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"id" => "part-1", "type" => "text", "text" => "Working on it..."}
        }
      }

      send(lv.pid, {:task_event, task.id, event})

      html = render(lv)
      assert html =~ "Working on it..."
    end

    test "receiving session.updated shows session title", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      event = %{
        "type" => "session.updated",
        "properties" => %{
          "info" => %{"title" => "Fix login bug", "slug" => "fix-login"}
        }
      }

      send(lv.pid, {:task_event, task.id, event})

      html = render(lv)
      assert html =~ "Fix login bug"
    end

    test "session.status idle refreshes task status from DB", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      Repo.update_all(
        from(t in TaskSchema, where: t.id == ^task.id),
        set: [status: "completed"]
      )

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "session.status",
          "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "idle"}}
        }
      })

      html =
        Enum.reduce_while(1..12, render(lv), fn _, _acc ->
          html = render(lv)

          if html =~ "completed" do
            {:halt, html}
          else
            Process.sleep(25)
            {:cont, html}
          end
        end)

      assert html =~ "completed"
    end

    test "receiving assistant message.updated shows model and tokens", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      event = %{
        "type" => "message.updated",
        "properties" => %{
          "info" => %{
            "role" => "assistant",
            "modelID" => "gpt-5.3-codex",
            "providerID" => "openai",
            "tokens" => %{
              "input" => 5200,
              "output" => 150,
              "cache" => %{"read" => 13_000, "write" => 0}
            },
            "cost" => 0
          }
        }
      }

      send(lv.pid, {:task_event, task.id, event})

      html = render(lv)
      assert html =~ "gpt-5.3-codex"
      assert html =~ "5.2k in"
      assert html =~ "150 out"
      assert html =~ "13.0k cached"
    end

    test "text segments are preserved across tool calls", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # 1. First text part — thinking (unique part ID)
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "part-1", "type" => "text", "text" => "Let me check the file..."}
           }
         }}
      )

      # 2. Tool call
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "tool-1", "type" => "tool-start", "name" => "read"}
           }
         }}
      )

      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "tool-1", "type" => "tool-result", "name" => "read"}
           }
         }}
      )

      # 3. Second text part — different part ID (new message or continuation)
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "part-2", "type" => "text", "text" => "Now I see the issue."}
           }
         }}
      )

      html = render(lv)
      # Both text segments should be visible
      assert html =~ "Let me check the file..."
      assert html =~ "Now I see the issue."
      # Tool should be rendered
      assert html =~ "read"
    end

    test "streaming text shows cursor, frozen text after tool call renders as markdown", %{
      conn: conn,
      user: user
    } do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Send streaming text — should show raw with cursor
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{
               "id" => "part-1",
               "type" => "text",
               "text" => "**bold text** streaming"
             }
           }
         }}
      )

      html = render(lv)
      # Streaming: raw text visible, cursor present, NOT rendered as markdown <strong>
      assert html =~ "**bold text** streaming"
      assert html =~ "animate-pulse"

      # Tool call freezes the text segment
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "tool-1", "type" => "tool-start", "name" => "bash"}
           }
         }}
      )

      html = render(lv)
      # First segment now frozen — rendered as markdown (<strong>)
      assert html =~ "<strong>bold text</strong>"
    end

    test "text is frozen and rendered as markdown when task completes", %{
      conn: conn,
      user: user
    } do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Stream some markdown text
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "part-1", "type" => "text", "text" => "# Heading\n\nDone."}
           }
         }}
      )

      html = render(lv)
      # While streaming: raw text
      assert html =~ "# Heading"
      refute html =~ "<h1>"

      # Task completes — freezes all text
      Repo.get!(TaskSchema, task.id)
      |> Ecto.Changeset.change(status: "completed")
      |> Repo.update!()

      send(lv.pid, {:task_status_changed, task.id, "completed"})

      html = render(lv)
      # Now rendered as markdown
      assert html =~ "<h1>"
      assert html =~ "Heading"
    end

    test "reasoning events render as thinking blocks", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{
               "id" => "reasoning-1",
               "type" => "reasoning",
               "text" => "I need to analyze the function signature..."
             }
           }
         }}
      )

      html = render(lv)
      assert html =~ "Thinking"
      assert html =~ "I need to analyze the function signature..."
    end

    test "multiple messages accumulate rather than replacing each other", %{
      conn: conn,
      user: user
    } do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # First assistant message (part-1)
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "part-1", "type" => "text", "text" => "First message content"}
           }
         }}
      )

      # Second assistant message (part-2, different ID)
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "part-2", "type" => "text", "text" => "Second message content"}
           }
         }}
      )

      html = render(lv)
      # BOTH messages should be visible, not just the last one
      assert html =~ "First message content"
      assert html =~ "Second message content"
    end

    test "tool events from other tasks are ignored", %{conn: conn, user: user} do
      _task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})
      _other = task_fixture(%{user_id: user.id, status: "running", container_id: "c2"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Send event for the OTHER task (not the one we're viewing)
      send(
        lv.pid,
        {:task_event, "nonexistent-id",
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "text", "text" => "SHOULD NOT APPEAR"}}
         }}
      )

      html = render(lv)
      refute html =~ "SHOULD NOT APPEAR"
    end

    test "receiving task_status_changed to completed updates UI", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Simulate what TaskRunner does: update DB first, then broadcast
      Repo.get!(TaskSchema, task.id)
      |> Ecto.Changeset.change(status: "completed")
      |> Repo.update!()

      send(lv.pid, {:task_status_changed, task.id, "completed"})

      html = render(lv)
      assert html =~ "completed"
    end

    test "renders lifecycle state and predicates on session task card", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          status: "queued",
          lifecycle_state: "queued_cold",
          container_id: "c-lifecycle"
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-lifecycle")

      assert has_element?(lv, ~s([data-testid="session-task-card"][data-task-id="#{task.id}"]))
      assert has_element?(lv, ~s([data-testid="lifecycle-state"]), "Queued (cold)")
      assert has_element?(lv, ~s([data-testid="state-predicate-active"]))
      refute has_element?(lv, ~s([data-testid="state-predicate-terminal"]))
    end

    test "lifecycle_state_changed updates rendered lifecycle state", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          status: "queued",
          lifecycle_state: "queued_cold",
          container_id: "c-lifecycle-rt"
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-lifecycle-rt")

      assert has_element?(lv, ~s([data-testid="lifecycle-state"]), "Queued (cold)")

      send(lv.pid, {:lifecycle_state_changed, task.id, :queued_cold, :warming})
      assert has_element?(lv, ~s([data-testid="lifecycle-state"]), "Warming up")

      send(lv.pid, {:lifecycle_state_changed, task.id, :warming, :starting})
      assert has_element?(lv, ~s([data-testid="lifecycle-state"]), "Starting")

      send(lv.pid, {:lifecycle_state_changed, task.id, :starting, :running})
      assert has_element?(lv, ~s([data-testid="lifecycle-state"]), "Running")
    end

    test "receiving task_status_changed to failed shows failed badge", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Simulate what TaskRunner does: update DB first, then broadcast
      Repo.get!(TaskSchema, task.id) |> Ecto.Changeset.change(status: "failed") |> Repo.update!()
      send(lv.pid, {:task_status_changed, task.id, "failed"})

      html = render(lv)
      assert html =~ "failed"
    end

    test "shows error message when viewing failed task", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        status: "failed",
        container_id: "c1",
        error: "Model not found: anthropic/claude-sonnet-4-5"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ "Task failed"
      assert html =~ "Model not found"
    end

    test "shows error alert for failed task with error in DB", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        status: "failed",
        container_id: "c1",
        error: "Container start failed: timeout"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ "Task failed"
      assert html =~ "Container start failed: timeout"
    end

    test "shows cancelled alert when viewing cancelled task", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        status: "cancelled",
        container_id: "c1",
        error: nil
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ "Session cancelled"
      assert html =~ "This session was cancelled and is no longer running."
    end

    test "todo_updated events update the session card progress bar", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Send todo update via PubSub (as TaskRunner does)
      todo_items = [
        %{"id" => "t1", "title" => "Plan", "status" => "completed", "position" => 0},
        %{"id" => "t2", "title" => "Code", "status" => "in_progress", "position" => 1}
      ]

      send(lv.pid, {:todo_updated, task.id, todo_items})

      html = render(lv)
      # Both items should appear in the main detail area
      assert html =~ "Plan"
      assert html =~ "Code"
    end

    test "live todo state survives reload_all after status change", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Send live todo update
      todo_items = [
        %{"id" => "t1", "title" => "Research", "status" => "completed", "position" => 0},
        %{"id" => "t2", "title" => "Implement", "status" => "in_progress", "position" => 1}
      ]

      send(lv.pid, {:todo_updated, task.id, todo_items})
      render(lv)

      # Now trigger a status change which calls reload_all
      # (reload_all re-fetches sessions from DB, which may have stale todos)
      Repo.get!(TaskSchema, task.id)
      |> Ecto.Changeset.change(status: "completed")
      |> Repo.update!()

      send(lv.pid, {:task_status_changed, task.id, "completed"})

      html = render(lv)
      # The live todo items should still be visible after reload
      assert html =~ "Research"
      assert html =~ "Implement"
    end

    test "waiting for response indicator shows while output is empty", %{
      conn: conn,
      user: user
    } do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})

      {:ok, lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Waiting for response"

      # Once output arrives, the waiting indicator should disappear
      send(
        lv.pid,
        {:task_event, task.id,
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"id" => "part-1", "type" => "text", "text" => "Working on it..."}
           }
         }}
      )

      html = render(lv)
      assert html =~ "Working on it..."
      refute html =~ "Waiting for response"
    end
  end
end

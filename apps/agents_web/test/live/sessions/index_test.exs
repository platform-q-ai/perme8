defmodule AgentsWeb.SessionsLive.IndexTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures
  import Ecto.Query

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Repo

  defmodule FakeTaskRunner do
    use GenServer

    def start_link(task_id) do
      GenServer.start_link(__MODULE__, task_id)
    end

    @impl true
    def init(task_id) do
      Registry.register(Agents.Sessions.TaskRegistry, task_id, %{})
      {:ok, %{task_id: task_id}}
    end

    @impl true
    def handle_call({:send_message, _message}, _from, state) do
      {:reply, :ok, state}
    end
  end

  describe "mount and rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the sessions page with heading", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Sessions"
    end

    test "renders New Session button", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "New Session"
    end

    test "renders empty state when no sessions exist", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "No sessions yet"
    end

    test "loads and displays sessions in left panel on mount", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Write tests for login",
        container_id: "c1",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Refactor auth module",
        container_id: "c2",
        status: "completed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Write tests for login"
      assert html =~ "Refactor auth module"
    end

    test "shows active task without container in session list", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Fresh session starting",
        status: "running"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ "session-item-fresh-session-starting"
    end

    test "selects most recent session by default", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "First task",
        container_id: "c1",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Second task",
        container_id: "c2",
        status: "completed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Second task"
    end
  end

  describe "form submission" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "submitting empty instruction does not create a task", %{conn: conn, user: user} do
      # Create a session so the input form is visible
      task_fixture(%{
        user_id: user.id,
        instruction: "Some task",
        container_id: "c1",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> form("#session-form", %{"instruction" => ""})
      |> render_submit()

      html = render(lv)
      # Should still show the existing session, not a "Waiting for response..." indicator
      assert html =~ "Some task"
      refute html =~ "Waiting for response"
    end

    test "sending a follow-up message to a running task appends it immediately", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c1",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> form("#session-form", %{"instruction" => "Follow-up message"})
      |> render_submit()

      html = render(lv)
      assert html =~ "Follow-up message"
      assert html =~ "Awaiting response..."
    end

    test "follow-up message renders at the bottom of the chat log", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c1",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{"id" => "part-1", "type" => "text", "text" => "Earlier assistant output"}
          }
        }
      })

      lv
      |> form("#session-form", %{"instruction" => "Follow-up message"})
      |> render_submit()

      html = render(lv)
      assert html =~ "Earlier assistant output"
      assert html =~ "Follow-up message"

      assistant_pos =
        html |> :binary.matches("Earlier assistant output") |> List.last() |> elem(0)

      followup_pos = html |> :binary.matches("Follow-up message") |> List.last() |> elem(0)

      assert followup_pos > assistant_pos
    end

    test "follow-up message persists after assistant response updates", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c1",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> form("#session-form", %{"instruction" => "Persist this follow-up"})
      |> render_submit()

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.updated",
          "properties" => %{"info" => %{"role" => "user", "id" => "user-msg-1"}}
        }
      })

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{
              "id" => "user-part-1",
              "type" => "text",
              "messageID" => "user-msg-1",
              "text" => "Persist this follow-up"
            }
          }
        }
      })

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{"id" => "asst-part-1", "type" => "text", "text" => "Assistant reply"}
          }
        }
      })

      html = render(lv)
      assert html =~ "Persist this follow-up"
      assert html =~ "Assistant reply"
      refute html =~ "Awaiting response..."
    end

    test "follow-up stays between prior and subsequent assistant outputs", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c1",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{"id" => "asst-1", "type" => "text", "text" => "Assistant before"}
          }
        }
      })

      lv
      |> form("#session-form", %{"instruction" => "User follow-up"})
      |> render_submit()

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.updated",
          "properties" => %{"info" => %{"role" => "user", "id" => "user-msg-3"}}
        }
      })

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{
              "id" => "user-part-3",
              "type" => "text",
              "messageID" => "user-msg-3",
              "text" => "User follow-up"
            }
          }
        }
      })

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{"id" => "asst-2", "type" => "text", "text" => "Assistant after"}
          }
        }
      })

      html = render(lv)

      before_pos = html |> :binary.matches("Assistant before") |> List.last() |> elem(0)
      followup_pos = html |> :binary.matches("User follow-up") |> List.last() |> elem(0)
      after_pos = html |> :binary.matches("Assistant after") |> List.last() |> elem(0)

      assert before_pos < followup_pos
      assert followup_pos < after_pos
    end

    test "follow-up message is restored after reload from cached output", %{
      conn: conn,
      user: user
    } do
      output =
        Jason.encode!([
          %{"type" => "text", "id" => "asst-1", "text" => "Assistant reply"},
          %{"type" => "user", "id" => "user-msg-1", "text" => "Applied follow-up"}
        ])

      task_fixture(%{
        user_id: user.id,
        instruction: "Initial instruction",
        container_id: "c1",
        status: "completed",
        output: output
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ "Applied follow-up"
      assert html =~ "Assistant reply"
      refute html =~ "Awaiting response..."
    end

    test "multiple applied follow-up messages remain visible after assistant continues", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c1",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> form("#session-form", %{"instruction" => "First queued follow-up"})
      |> render_submit()

      lv
      |> form("#session-form", %{"instruction" => "Second queued follow-up"})
      |> render_submit()

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.updated",
          "properties" => %{"info" => %{"role" => "user", "id" => "user-msg-1"}}
        }
      })

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{
              "id" => "user-part-shared",
              "type" => "text",
              "messageID" => "user-msg-1",
              "text" => "First queued follow-up"
            }
          }
        }
      })

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.updated",
          "properties" => %{"info" => %{"role" => "user", "id" => "user-msg-2"}}
        }
      })

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{
              "id" => "user-part-shared",
              "type" => "text",
              "messageID" => "user-msg-2",
              "text" => "Second queued follow-up"
            }
          }
        }
      })

      send(lv.pid, {
        :task_event,
        task.id,
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{"id" => "asst-part-1", "type" => "text", "text" => "Assistant continues"}
          }
        }
      })

      html = render(lv)

      assert html =~ "First queued follow-up"
      assert html =~ "Second queued follow-up"
      assert html =~ "Assistant continues"
      refute html =~ "Awaiting response..."
    end

    test "submitting on a cancelled non-resumable session does not create a new session", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Cancelled run",
        container_id: "c1",
        status: "cancelled"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> form("#session-form", %{"instruction" => "Try again"})
      |> render_submit()

      assert Repo.aggregate(from(t in TaskSchema, where: t.user_id == ^user.id), :count, :id) == 1
    end

    test "optimistic follow-up message is not duplicated across rerenders", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c1",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> form("#session-form", %{"instruction" => "One follow-up"})
      |> render_submit()

      # Trigger a rerender path that reloads sessions
      send(lv.pid, {:task_status_changed, task.id, "running"})

      html = render(lv)
      assert length(Regex.scan(~r/One follow-up/, html)) == 1
    end
  end

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

      html = render(lv)
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

  describe "session management" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "clicking a session in the left panel selects it", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Session A task",
        container_id: "c-a",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Session B task",
        container_id: "c-b",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      html =
        lv
        |> element(~s([phx-click="select_session"][phx-value-container-id="c-a"]))
        |> render_click()

      assert html =~ "Session A task"
    end

    test "container URL param selects the correct session on mount", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Session A task",
        container_id: "c-a",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Session B task",
        container_id: "c-b",
        status: "completed"
      })

      # Navigate directly to session A via URL param (not the most recent)
      {:ok, _lv, html} = live(conn, ~p"/sessions?container=c-a")
      assert html =~ "Session A task"
    end

    test "selecting a session updates the URL with container param", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Session A task",
        container_id: "c-a",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Session B task",
        container_id: "c-b",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> element(~s([phx-click="select_session"][phx-value-container-id="c-a"]))
      |> render_click()

      assert_patch(lv, ~p"/sessions?container=c-a")
    end

    test "invalid container param falls back to most recent session", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Only session",
        container_id: "c-1",
        status: "completed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions?container=nonexistent")
      assert html =~ "Only session"
    end

    test "clicking New Session clears active session detail pane", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Long running task",
        container_id: "c-running",
        status: "running"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      html =
        lv
        |> element(~s([phx-click="new_session"]))
        |> render_click()

      assert_patch(lv, ~p"/sessions?#{%{new: true}}")
      assert html =~ "Enter an instruction below to start"
      assert html =~ "Image:"
      refute html =~ "Waiting for response"
    end

    test "new session remains blank after clicking New Session even with existing sessions", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-existing",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> element(~s([phx-click="new_session"]))
      |> render_click()

      html = render(lv)
      assert html =~ "Enter an instruction below to start"
      assert html =~ "Image:"
    end

    test "renders status dots in session list", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Completed session",
        container_id: "c1",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Failed session",
        container_id: "c2",
        status: "failed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "bg-success"
      assert html =~ "bg-error"
    end

    test "delete session button is hidden for running sessions", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Running session",
        container_id: "c-running",
        status: "running"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      refute html =~ "title=\"Delete session\""
    end

    test "delete session button is shown for completed sessions", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Completed session",
        container_id: "c-completed",
        status: "completed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "title=\"Delete session\""
    end
  end
end

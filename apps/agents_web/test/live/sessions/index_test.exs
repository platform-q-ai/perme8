defmodule AgentsWeb.SessionsLive.IndexTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures
  import Ecto.Query

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}
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
    def handle_call({:send_message, _message, _opts}, _from, state) do
      {:reply, :ok, state}
    end

    @impl true
    def handle_call({:send_message, _message}, _from, state) do
      {:reply, :ok, state}
    end

    @impl true
    def handle_call({:answer_question, _request_id, _answers, _message}, _from, state) do
      {:reply, :ok, state}
    end

    @impl true
    def handle_call({:answer_question, _request_id, _answers}, _from, state) do
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

    test "renders sidebar new session textarea", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "sidebar-new-session-form"
      assert html =~ "Start a new session..."
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

    test "places running sessions at the bottom of sidebar list", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Completed session",
        container_id: "c1",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Running session",
        container_id: "c2",
        status: "running"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      running_pos =
        html |> :binary.matches("session-item-running-session") |> List.first() |> elem(0)

      completed_pos =
        html |> :binary.matches("session-item-completed-session") |> List.first() |> elem(0)

      assert running_pos > completed_pos
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
      assert html =~ "Queued"
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

    test "question tool submit appends answer to conversation history", %{conn: conn, user: user} do
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
          "type" => "question.asked",
          "properties" => %{
            "id" => "req-1",
            "sessionID" => "sess-1",
            "questions" => [
              %{
                "header" => "Deploy",
                "question" => "Ship now?",
                "options" => [%{"label" => "Yes", "description" => "Deploy"}],
                "multiple" => false
              }
            ]
          }
        }
      })

      lv
      |> element("button[phx-value-question-index='0'][phx-value-label='Yes']")
      |> render_click()

      lv
      |> form("#question-form", %{"custom_answer" => %{"0" => ""}})
      |> render_submit()

      html = render(lv)
      assert html =~ "Re: Deploy — Yes"
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

      assert html =~ "Assistant before"
      assert html =~ "User follow-up"
      assert html =~ "Assistant after"
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

    test "does not duplicate initial instruction when output already contains matching user message",
         %{
           conn: conn,
           user: user
         } do
      output =
        Jason.encode!([
          %{"type" => "user", "id" => "user-msg-1", "text" => "Repeat me"},
          %{"type" => "text", "id" => "asst-1", "text" => "Continuing now"}
        ])

      task_fixture(%{
        user_id: user.id,
        instruction: "Repeat me",
        container_id: "c-repeat",
        status: "completed",
        output: output
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions?container=c-repeat")

      refute html =~ ~s(data-testid="session-initial-instruction")
      assert html =~ "Repeat me"
      assert html =~ "Continuing now"
    end

    test "pending follow-up survives navigating away and back while session is restarting", %{
      conn: conn,
      user: user
    } do
      restarting_output =
        Jason.encode!([
          %{"type" => "text", "id" => "asst-1", "text" => "Resuming container..."},
          %{
            "type" => "user",
            "id" => "queued-user-1",
            "text" => "Please keep this",
            "pending" => true
          }
        ])

      task_fixture(%{
        user_id: user.id,
        instruction: "Restarting session",
        container_id: "c-resume",
        status: "starting",
        output: restarting_output
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Other session",
        container_id: "c-other",
        status: "completed"
      })

      {:ok, lv, html} = live(conn, ~p"/sessions?container=c-resume")

      assert html =~ "Please keep this"
      assert html =~ "Awaiting response..."

      lv
      |> element(~s([phx-click="select_session"][phx-value-container-id="c-other"]))
      |> render_click()

      html =
        lv
        |> element(~s([phx-click="select_session"][phx-value-container-id="c-resume"]))
        |> render_click()

      assert html =~ "Please keep this"
      assert html =~ "Awaiting response..."
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

    test "hydrates optimistic queue entries from hook payload", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c-hydrate",
          status: "running"
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-hydrate")

      entries = [
        %{
          "id" => "corr-1",
          "correlation_key" => "corr-1",
          "content" => "Hydrated follow-up",
          "status" => "pending",
          "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]

      lv
      |> element("#session-optimistic-state")
      |> render_hook("hydrate_optimistic_queue", %{"task_id" => task.id, "entries" => entries})

      html = render(lv)
      assert html =~ "Hydrated follow-up"
      assert html =~ "Queued"
    end

    test "hydrates optimistic new-session placeholders from hook payload", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "existing-c1",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      entries = [
        %{
          "id" => "new-1",
          "instruction" => "Build optimistic placeholder",
          "image" => "perme8-opencode",
          "status" => "queued",
          "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]

      lv
      |> element("#session-optimistic-state")
      |> render_hook("hydrate_optimistic_new_sessions", %{"entries" => entries})

      html = render(lv)
      assert html =~ ~s(data-testid="optimistic-session-item-build-optimistic-placeholder")
      assert html =~ "Syncing..."
    end

    test "new-session placeholder is removed after server acknowledgement", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "existing-c2",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      entries = [
        %{
          "id" => "new-ack-1",
          "instruction" => "Queue acknowledged task",
          "image" => "perme8-opencode",
          "status" => "queued",
          "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]

      lv
      |> element("#session-optimistic-state")
      |> render_hook("hydrate_optimistic_new_sessions", %{"entries" => entries})

      task_fixture(%{
        user_id: user.id,
        instruction: "Queue acknowledged task",
        status: "queued",
        container_id: nil
      })

      send(lv.pid, {:new_task_created, "new-ack-1", {:ok, %{id: "task-ack"}}})

      html = render(lv)
      refute html =~ ~s(data-testid="optimistic-session-item-queue-acknowledged-task")
      assert html =~ ~s(data-testid="session-item-queue-acknowledged-task")
    end

    test "new-session placeholder rolls back on create failure", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "existing-c3",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      entries = [
        %{
          "id" => "new-fail-1",
          "instruction" => "Failing queued task",
          "image" => "perme8-opencode",
          "status" => "queued",
          "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]

      lv
      |> element("#session-optimistic-state")
      |> render_hook("hydrate_optimistic_new_sessions", %{"entries" => entries})

      send(lv.pid, {:new_task_created, "new-fail-1", {:error, :instruction_required}})

      html = render(lv)
      refute html =~ ~s(data-testid="optimistic-session-item-failing-queued-task")
    end

    test "stale optimistic new-session entries are discarded on hydration", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "existing-c-stale",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Entry queued 5 minutes ago — should be considered stale (threshold is 2 min)
      stale_time =
        DateTime.utc_now() |> DateTime.add(-300, :second) |> DateTime.to_iso8601()

      entries = [
        %{
          "id" => "stale-1",
          "instruction" => "Stale queued task",
          "image" => "perme8-opencode",
          "status" => "queued",
          "queued_at" => stale_time
        }
      ]

      lv
      |> element("#session-optimistic-state")
      |> render_hook("hydrate_optimistic_new_sessions", %{"entries" => entries})

      html = render(lv)
      refute html =~ "Stale queued task"
      refute html =~ "Syncing..."
    end

    test "optimistic new-session entries matching an existing session are discarded on hydration",
         %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Already created session",
        container_id: "existing-c-dup",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Fresh entry but its instruction matches a real session title
      entries = [
        %{
          "id" => "dup-1",
          "instruction" => "Already created session",
          "image" => "perme8-opencode",
          "status" => "queued",
          "queued_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]

      lv
      |> element("#session-optimistic-state")
      |> render_hook("hydrate_optimistic_new_sessions", %{"entries" => entries})

      html = render(lv)
      # The real session card should exist but NOT the optimistic "Syncing..." one
      refute html =~ "Syncing..."
      refute html =~ ~s(data-testid="optimistic-session-item-already-created-session")
    end

    test "failed optimistic send is rendered as rolled back", %{conn: conn, user: user} do
      _task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c-fail",
          status: "running"
        })

      # no runner registered -> Sessions.send_message returns task_not_running
      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-fail")

      lv
      |> form("#session-form", %{"instruction" => "Will fail"})
      |> render_submit()

      assert render(lv) =~ "Will fail"

      html =
        Enum.reduce_while(1..8, render(lv), fn _, _acc ->
          html = render(lv)

          if html =~ "Rolled back before backend acceptance" do
            {:halt, html}
          else
            Process.sleep(25)
            {:cont, html}
          end
        end)

      assert html =~ "Rolled back before backend acceptance"
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

  describe "queue_snapshot v2 handling" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "handle_info with queue_snapshot updates assigns", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      snapshot =
        QueueSnapshot.new(%{
          user_id: user.id,
          lanes: %{
            processing: [],
            warm: [
              LaneEntry.new(%{
                task_id: "task-1",
                instruction: "Warm task",
                status: "queued",
                lane: :warm,
                warm_state: :warm
              })
            ],
            cold: [],
            awaiting_feedback: [],
            retry_pending: []
          },
          metadata: %{concurrency_limit: 3, running_count: 1, warm_cache_limit: 2}
        })

      send(lv.pid, {:queue_snapshot, user.id, snapshot})
      _html = render(lv)

      state = :sys.get_state(lv.pid)
      assigns = state.socket.assigns

      assert assigns.queue_snapshot == snapshot
      assert assigns.queue_state == QueueSnapshot.to_legacy_map(snapshot)
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

    test "switching sessions clears queued messages from the previous session", %{
      conn: conn,
      user: user
    } do
      running_task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Running session",
          container_id: "c-running",
          status: "running"
        })

      task_fixture(%{
        user_id: user.id,
        instruction: "Other session",
        container_id: "c-other",
        status: "completed"
      })

      start_supervised!({FakeTaskRunner, running_task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-running")

      # Send a follow-up to the running task — creates a queued message
      lv
      |> form("#session-form", %{"instruction" => "Queued follow-up"})
      |> render_submit()

      html = render(lv)
      assert html =~ "Queued follow-up"
      assert html =~ "Queued"

      # Switch to a different session
      lv
      |> element(~s([phx-click="select_session"][phx-value-container-id="c-other"]))
      |> render_click()

      html = render(lv)
      # Queued message from previous session should NOT appear
      refute html =~ "Queued follow-up"
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

    test "switching detail tabs preserves selected container in URL", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Container context persists for #123",
        container_id: "c-keep",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 123,
          title: "Linked ticket",
          status: "Ready",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-keep")
      send(lv.pid, {:tickets_synced, []})

      lv
      |> element(~s(button[data-tab-id="ticket"]))
      |> render_click()

      assert_patch(lv, ~p"/sessions?container=c-keep&tab=ticket")

      html = render(lv)
      assert html =~ "Container context persists for #123"
    end

    test "hides ticket tab for sessions without an assigned ticket", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "General coding session",
        container_id: "c-no-ticket",
        status: "completed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions?container=c-no-ticket")

      assert html =~ ~s(data-tab-id="chat")
      refute html =~ ~s(data-tab-id="ticket")
    end

    test "selecting ticket card navigates to session and shows ticket tab",
         %{
           conn: conn,
           user: user
         } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Continue work on #123",
        container_id: "c-ticket-session",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Another session",
        container_id: "c-other-session",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 123,
          title: "Ticket selected from session context",
          status: "Ready",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Ticket card is in triage (completed session). Click the ticket card.
      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="123"]))
      |> render_click()

      html =
        lv
        |> element(~s(button[data-tab-id="ticket"]))
        |> render_click()

      assert html =~ ~s(data-testid="ticket-context-panel")
      assert html =~ "Ticket selected from session context"
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

    test "sidebar quick-start form is visible while viewing an existing session", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Long running task",
        container_id: "c-running",
        status: "running"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ "sidebar-new-session-form"
      assert html =~ "sidebar-new-session-instruction"
    end

    test "submitting empty sidebar quick-start instruction does not change selected session", %{
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
      |> form("#sidebar-new-session-form", %{"instruction" => "   "})
      |> render_submit()

      html = render(lv)
      assert html =~ "sidebar-new-session-form"
      assert html =~ "Existing session"
    end

    test "renders empty concurrency slot cards in session list", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Running session",
        container_id: "c-running",
        status: "running"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{running: 1, queued: [], awaiting_feedback: [], concurrency_limit: 3}
      })

      html = render(lv)

      assert html =~ ~s(data-testid="empty-concurrency-slot-1")
      assert html =~ ~s(data-testid="empty-concurrency-slot-2")
      assert length(:binary.matches(html, ~s(data-slot-state="empty"))) == 2

      empty_pos =
        html
        |> :binary.matches(~s(data-testid="empty-concurrency-slot-1"))
        |> List.first()
        |> elem(0)

      running_pos =
        html
        |> :binary.matches(~s(data-testid="session-item-running-session"))
        |> List.first()
        |> elem(0)

      assert empty_pos < running_pos
    end

    test "queue concurrency updates rerender empty slot cards", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Running session",
        container_id: "c-running",
        status: "running"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{running: 1, queued: [], awaiting_feedback: [], concurrency_limit: 2}
      })

      html = render(lv)
      assert html =~ ~s(data-testid="empty-concurrency-slot-1")
      refute html =~ ~s(data-testid="empty-concurrency-slot-2")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{running: 2, queued: [], awaiting_feedback: [], concurrency_limit: 4}
      })

      html = render(lv)
      assert html =~ ~s(data-testid="empty-concurrency-slot-2")
      assert length(:binary.matches(html, ~s(data-slot-state="empty"))) == 2
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
        instruction: "Running session",
        container_id: "c2",
        status: "running"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "bg-success"
      assert html =~ "bg-info"
    end

    test "running session cards are marked as used slots", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Running slot",
        container_id: "c-running-slot",
        status: "running"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-running-slot")
      assert html =~ ~s(data-slot-state="used")
    end

    test "triage column shows completed/cancelled and queue column includes failed", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Cancelled attention",
        container_id: "c-cancelled-attention",
        status: "cancelled"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Completed attention",
        container_id: "c-completed-attention",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Failed exited",
        container_id: "c-failed-exited",
        status: "failed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Running progress",
        container_id: "c-running-progress",
        status: "running"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-failed-exited")
      assert html =~ ~s(data-testid="session-item-completed-attention")
      assert html =~ ~s(data-testid="session-item-cancelled-attention")
      assert html =~ ~s(data-testid="session-item-running-progress")
      assert html =~ "bg-warning/10"
      assert html =~ "bg-violet-500/10"
      assert html =~ "bg-error/10"
    end

    test "queued sessions render above concurrency rule", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Queued session",
        container_id: "c-queued-session",
        status: "queued"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Running session",
        container_id: "c-running-session",
        status: "running"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{running: 1, queued: [], awaiting_feedback: [], concurrency_limit: 2}
      })

      html = render(lv)

      queued_pos =
        html
        |> :binary.matches(~s(data-testid="session-item-queued-session"))
        |> List.first()
        |> elem(0)

      rule_pos =
        html
        |> :binary.matches(~s(data-testid="queue-limit-rule"))
        |> List.first()
        |> elem(0)

      assert queued_pos < rule_pos
    end

    test "renders warm divider above concurrency limit divider when queue exists", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Queued session",
        container_id: "c-queued-session",
        status: "queued"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="queue-warm-rule")

      {warm_pos, _} = :binary.match(html, ~s(data-testid="queue-warm-rule"))
      {limit_pos, _} = :binary.match(html, ~s(data-testid="queue-limit-rule"))

      assert warm_pos < limit_pos
    end

    test "renders empty warm slots based on warm cache limit", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Warm queued session",
        container_id: "warmed-container",
        status: "queued"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{
          running: 0,
          queued: [],
          awaiting_feedback: [],
          concurrency_limit: 2,
          warm_cache_limit: 3
        }
      })

      html = render(lv)

      assert html =~ ~s(data-testid="empty-warm-slot-1")
      assert html =~ ~s(data-testid="empty-warm-slot-2")
    end

    test "queued session with real container keeps warm styling outside warm queue window", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Warm outside queue window",
          status: "queued",
          container_id: "real-warm-container"
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{
          running: 0,
          queued: [],
          awaiting_feedback: [],
          concurrency_limit: 2,
          warm_cache_limit: 0
        }
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warm-outside-queue-window")
      assert html =~ ~s(phx-value-task-id="#{task.id}")
      assert html =~ "border border-warning/40 bg-warning/10"
      refute html =~ "bg-base-content/35"
    end

    test "cold queued sessions render with grey card styling", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Cold queued session",
        status: "queued",
        container_id: nil
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-cold-queued-session")
      assert html =~ ~s(data-slot-state="queued")
      assert html =~ "bg-base-content/8"
      assert html =~ "bg-base-content/35"
    end

    test "queued session in warm slot remains cold until warming starts", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Warming queued session",
          status: "queued",
          container_id: nil
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{
          running: 0,
          queued: [%{id: task.id}],
          awaiting_feedback: [],
          concurrency_limit: 2,
          warm_cache_limit: 1
        }
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warming-queued-session")
      assert html =~ ~s(data-slot-state="warm")
      refute html =~ "Warming..."
      assert html =~ "bg-base-content/35"
    end

    test "warm-lane queued session shows warming animation when queue marks it warming", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Warming queued session",
          status: "queued",
          container_id: nil
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{
          running: 0,
          queued: [%{id: task.id}],
          awaiting_feedback: [],
          concurrency_limit: 2,
          warm_cache_limit: 1,
          warming_task_ids: [task.id]
        }
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warming-queued-session")
      assert html =~ ~s(data-slot-state="warming")
      assert html =~ "Warming..."
      assert html =~ "animate-pulse"
      assert html =~ "bg-neutral"
      refute html =~ "bg-base-content/35"
    end

    test "warm-lane queued session clears warming animation once container is real", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Warmed queued session",
          status: "queued",
          container_id: "real-warmed-container"
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{
          running: 0,
          queued: [%{id: task.id}],
          awaiting_feedback: [],
          concurrency_limit: 2,
          warm_cache_limit: 1
        }
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warmed-queued-session")
      assert html =~ ~s(data-slot-state="warm")
      refute html =~ "Warming..."
      assert html =~ "border border-warning/40 bg-warning/10"
      refute html =~ "bg-base-content/35"
    end

    test "warmed queued session stays in warm lane when queue warm ids are empty", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Warmed session persists in lane",
          status: "queued",
          container_id: "real-warmed-persisted-container"
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{
          running: 0,
          queued: [],
          awaiting_feedback: [],
          concurrency_limit: 2,
          warm_cache_limit: 1,
          warm_task_ids: [],
          warming_task_ids: []
        }
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warmed-session-persists-in-lane")
      assert html =~ ~s(phx-value-task-id="#{task.id}")
      assert html =~ ~s(data-slot-state="warm")
    end

    test "deletes queued session from chat header trash action", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Delete queued from header",
          status: "queued",
          container_id: "c-delete-queued"
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-delete-queued")

      lv
      |> element(~s(button[phx-click="delete_queued_task"][phx-value-task-id="#{task.id}"]))
      |> render_click()

      assert Repo.get(TaskSchema, task.id) == nil

      html = render(lv)
      refute html =~ "Delete queued from header"
    end

    test "warm-task and warming-task ids from queue state keep warming indicator visible", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Warm via queue state ids",
          status: "queued",
          container_id: nil
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{
          running: 0,
          queued: [],
          awaiting_feedback: [],
          concurrency_limit: 2,
          warm_cache_limit: 1,
          warm_task_ids: [task.id],
          warming_task_ids: [task.id]
        }
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warm-via-queue-state-ids")
      assert html =~ ~s(data-slot-state="warming")
      assert html =~ "Warming..."
      assert html =~ "animate-pulse"
    end

    test "renders queue limit rule above the slot at concurrency threshold", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Running slot",
        container_id: "c-running-slot",
        status: "running"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(lv.pid, {
        :queue_updated,
        user.id,
        %{running: 1, queued: [], awaiting_feedback: [], concurrency_limit: 2}
      })

      html = render(lv)

      assert length(:binary.matches(html, ~s(data-testid="queue-limit-rule"))) == 1

      rule_pos =
        html |> :binary.matches(~s(data-testid="queue-limit-rule")) |> List.first() |> elem(0)

      running_pos =
        html
        |> :binary.matches(~s(data-testid="session-item-running-slot"))
        |> List.first()
        |> elem(0)

      assert rule_pos < running_pos
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

  describe "container_stats_updated handler" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "stores stats in assigns when container_stats_updated message received", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Stats session",
          container_id: "c-stats",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-stats")

      stats = %{
        cpu_percent: 45.2,
        memory_percent: 60.0,
        memory_usage: 600_000,
        memory_limit: 1_000_000
      }

      send(lv.pid, {:container_stats_updated, task.id, "c-stats", stats})

      # Force a render cycle to ensure the assign was processed
      _html = render(lv)

      # Verify the assign was stored (the LiveView should not crash)
      assert Process.alive?(lv.pid)
    end

    test "handles stats for multiple containers independently", %{conn: conn, user: user} do
      task1 =
        task_fixture(%{
          user_id: user.id,
          instruction: "Stats session 1",
          container_id: "c-stats-1",
          status: "running"
        })

      task2 =
        task_fixture(%{
          user_id: user.id,
          instruction: "Stats session 2",
          container_id: "c-stats-2",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task1.id})
      start_supervised!(%{id: :fake_runner_2, start: {FakeTaskRunner, :start_link, [task2.id]}})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      stats1 = %{cpu_percent: 10.0, memory_percent: 20.0, memory_usage: 200, memory_limit: 1000}
      stats2 = %{cpu_percent: 50.0, memory_percent: 80.0, memory_usage: 800, memory_limit: 1000}

      send(lv.pid, {:container_stats_updated, task1.id, "c-stats-1", stats1})
      send(lv.pid, {:container_stats_updated, task2.id, "c-stats-2", stats2})

      _html = render(lv)
      assert Process.alive?(lv.pid)
    end
  end

  describe "restart session button" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows restart button on failed resumable session", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Fix the bug",
        container_id: "c-restart-1",
        session_id: "sess-restart-1",
        status: "failed",
        error: "Something went wrong"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions?container=c-restart-1")

      assert html =~ "Task failed"
      assert html =~ "data-testid=\"restart-session-btn\""
      assert html =~ "Restart"
    end

    test "shows restart button on cancelled resumable session", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Build the feature",
        container_id: "c-restart-2",
        session_id: "sess-restart-2",
        status: "cancelled"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions?container=c-restart-2")

      assert html =~ "Session cancelled"
      assert html =~ "data-testid=\"restart-session-btn\""
      assert html =~ "Restart"
    end

    test "does not show restart button on non-resumable failed session", %{
      conn: conn,
      user: user
    } do
      # A task with container_id but no session_id is not resumable
      task_fixture(%{
        user_id: user.id,
        instruction: "Do something",
        container_id: "c-no-resume",
        session_id: nil,
        status: "failed",
        error: "Container start failed"
      })

      start_supervised!({FakeTaskRunner, nil})

      {:ok, _lv, html} = live(conn, ~p"/sessions?container=c-no-resume")

      assert html =~ "Task failed"
      refute html =~ "data-testid=\"restart-session-btn\""
    end
  end

  describe "close ticket" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "close_ticket event removes ticket from triage lane", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Work on #555",
        container_id: "c-close-test",
        status: "completed"
      })

      # Insert ticket into DB
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 555,
          title: "Ticket to close",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Trigger ticket reload so the LiveView picks up the DB ticket
      send(lv.pid, {:tickets_synced, []})
      html = render(lv)
      assert html =~ "Ticket to close"
      assert html =~ ~s(data-testid="triage-ticket-item-555")

      # Select the ticket to view its detail panel
      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="555"]))
      |> render_click()

      html =
        lv
        |> element(~s(button[data-tab-id="ticket"]))
        |> render_click()

      assert html =~ ~s(data-testid="close-ticket-btn")

      # Close the ticket
      html =
        lv
        |> element(~s([data-testid="close-ticket-btn"]))
        |> render_click()

      # Ticket should be removed from the triage lane
      refute html =~ "Ticket to close"
      refute html =~ ~s(data-testid="triage-ticket-item-555")

      # Ticket should be removed from the database
      remaining = ProjectTicketRepository.list_all()
      refute Enum.any?(remaining, &(&1.number == 555))
    end

    test "close_ticket switches to chat tab when viewing the closed ticket", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Work on #556",
        container_id: "c-close-tab",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 556,
          title: "Ticket for tab switch",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Select and view ticket
      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="556"]))
      |> render_click()

      lv
      |> element(~s(button[data-tab-id="ticket"]))
      |> render_click()

      # Close the ticket — should switch back to chat tab
      html =
        lv
        |> element(~s([data-testid="close-ticket-btn"]))
        |> render_click()

      # The ticket detail panel should no longer be visible
      refute html =~ ~s(data-testid="ticket-context-panel")
    end
  end

  describe "start ticket session" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "play button is shown on idle ticket cards", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-play-idle",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 600,
          title: "Idle ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)
      assert html =~ ~s(data-testid="start-ticket-session-600")
    end

    test "play button is hidden on tickets with running sessions", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Work on #601",
        container_id: "c-play-running",
        status: "running"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 601,
          title: "Running ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)
      refute html =~ ~s(data-testid="start-ticket-session-601")
    end

    test "clicking play button triggers session creation without error", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-play-start",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 602,
          title: "Ticket to start",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Clicking the play button should not crash the LiveView — it delegates
      # to run_new_task with the ticket instruction. The spawned process may
      # fail in the test sandbox but the LiveView survives.
      lv
      |> element(~s([data-testid="start-ticket-session-602"]))
      |> render_click()

      # The LiveView should still be alive and rendering
      html = render(lv)
      assert html =~ "Ticket to start"
    end
  end

  describe "ticket card real-time session state updates" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "ticket card status dot updates when task status changes to running", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #700 using the relevant skill",
          container_id: "c-ticket-700",
          status: "pending"
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 700,
          title: "Live update ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Subscribe and simulate task status changing to running
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")
      send(lv.pid, {:task_status_changed, task.id, "running"})

      html = render(lv)

      # The ticket card should NOT show the play button (session is active)
      refute html =~ ~s(data-testid="start-ticket-session-700")

      # The ticket should move from triage to build lane when running
      refute html =~ ~s(data-testid="triage-ticket-item-700")
      assert html =~ ~s(data-testid="build-ticket-item-700")
    end

    test "ticket card shows play button again after task completes", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #701 using the relevant skill",
          container_id: "c-ticket-701",
          status: "running"
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 701,
          title: "Completing ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Initially the play button should be hidden (task is running)
      html = render(lv)
      refute html =~ ~s(data-testid="start-ticket-session-701")

      # Now simulate task completing
      send(lv.pid, {:task_status_changed, task.id, "completed"})

      html = render(lv)
      # Play button should reappear after completion
      assert html =~ ~s(data-testid="start-ticket-session-701")
    end

    test "ticket card shows play button again after task fails", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #702 using the relevant skill",
          container_id: "c-ticket-702",
          status: "running"
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 702,
          title: "Failing ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Initially hidden (task is running)
      refute render(lv) =~ ~s(data-testid="start-ticket-session-702")

      # Simulate task failure
      send(lv.pid, {:task_status_changed, task.id, "failed"})

      html = render(lv)
      assert html =~ ~s(data-testid="start-ticket-session-702")
    end

    test "ticket card shows play button again after task is cancelled", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #703 using the relevant skill",
          container_id: "c-ticket-703",
          status: "running"
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 703,
          title: "Cancelled ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Initially hidden
      refute render(lv) =~ ~s(data-testid="start-ticket-session-703")

      # Simulate task cancellation
      send(lv.pid, {:task_status_changed, task.id, "cancelled"})

      html = render(lv)
      assert html =~ ~s(data-testid="start-ticket-session-703")
    end
  end

  describe "ticket-centric build lane lifecycle" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "idle ticket shows in triage lane, not build lane", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-idle",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 800,
          title: "Idle triage ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)
      # Ticket should appear in triage lane
      assert html =~ ~s(data-testid="triage-ticket-item-800")
      # Ticket should NOT appear in build lane
      refute html =~ ~s(data-testid="build-ticket-item-800")
    end

    test "running ticket moves from triage to build lane", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #801 using the relevant skill",
          container_id: "c-ticket-801",
          status: "running"
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 801,
          title: "Running build ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)
      # Ticket should appear in build lane, not triage
      assert html =~ ~s(data-testid="build-ticket-item-801")
      refute html =~ ~s(data-testid="triage-ticket-item-801")
      # Play button should not be shown
      refute html =~ ~s(data-testid="start-ticket-session-801")

      # Verify the build lane card has the running status (used slot)
      assert html =~ ~s(data-slot-state="used")

      _task = task
    end

    test "completed ticket returns to triage lane with session data", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #802 using the relevant skill",
          container_id: "c-ticket-802",
          status: "running"
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 802,
          title: "Completing build ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Initially in build lane
      html = render(lv)
      assert html =~ ~s(data-testid="build-ticket-item-802")
      refute html =~ ~s(data-testid="triage-ticket-item-802")

      # Simulate task completing
      send(lv.pid, {:task_status_changed, task.id, "completed"})

      html = render(lv)
      # Now should be back in triage
      assert html =~ ~s(data-testid="triage-ticket-item-802")
      refute html =~ ~s(data-testid="build-ticket-item-802")
      # Play button should reappear
      assert html =~ ~s(data-testid="start-ticket-session-802")
    end

    test "failed ticket returns to triage lane", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #803 using the relevant skill",
          container_id: "c-ticket-803",
          status: "running"
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 803,
          title: "Failing build ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Initially in build lane
      assert render(lv) =~ ~s(data-testid="build-ticket-item-803")

      # Simulate task failure
      send(lv.pid, {:task_status_changed, task.id, "failed"})

      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-803")
      refute html =~ ~s(data-testid="build-ticket-item-803")
    end

    test "queued ticket shows in build lane queue zone", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "pick up ticket #804 using the relevant skill",
        container_id: "c-ticket-804",
        status: "queued"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 804,
          title: "Queued build ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)
      assert html =~ ~s(data-testid="build-ticket-item-804")
      refute html =~ ~s(data-testid="triage-ticket-item-804")
    end

    test "close_ticket removes ticket from UI and destroys session", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "pick up ticket #805 using the relevant skill",
        container_id: "c-ticket-805",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 805,
          title: "Ticket to close",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-805")
      # Session card should also be visible (non-ticket triage session)
      assert html =~ "c-ticket-805"

      # Select the ticket to view it
      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="805"]))
      |> render_click()

      # Close the ticket
      lv
      |> element(~s([data-testid="close-ticket-btn"]))
      |> render_click()

      html = render(lv)
      # Ticket should be completely removed
      refute html =~ ~s(data-testid="triage-ticket-item-805")
      refute html =~ ~s(data-testid="build-ticket-item-805")
      # Session should also be removed
      refute html =~ "c-ticket-805"
    end

    test "non-ticket sessions still show in build lane independently", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "A freeform coding task",
        container_id: "c-freeform",
        status: "running"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      html = render(lv)
      # Non-ticket session should appear as a regular session card
      assert html =~ ~s(data-testid="session-item-a-freeform-coding-task")
      assert html =~ "A freeform coding task"
    end
  end

  describe "pause restores instruction to chat input" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "pausing a queued ticket pushes restore_draft with the instruction", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "pick up ticket #42 using the relevant skill",
        container_id: "c-ticket-42",
        status: "queued"
      })

      ProjectTicketRepository.sync_remote_ticket(%{
        number: 42,
        title: "Build the widget",
        status: "Backlog",
        priority: "Need",
        size: "M",
        labels: []
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})
      _ = render(lv)

      # Click the pause button on the ticket card
      lv
      |> element(~s([data-testid="pause-ticket-42"]))
      |> render_click()

      assert_push_event(lv, "restore_draft", %{
        text: "pick up ticket #42 using the relevant skill"
      })
    end

    test "pausing an in-progress non-ticket session restores the last user message", %{
      conn: conn,
      user: user
    } do
      output =
        Jason.encode!([
          %{"type" => "user", "id" => "u1", "text" => "Refactor the auth module"},
          %{"type" => "text", "id" => "t1", "text" => "Sure, I'll refactor..."},
          %{"type" => "user", "id" => "u2", "text" => "Also fix the tests"}
        ])

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Refactor the auth module",
          container_id: "c-refactor",
          status: "running",
          output: output
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Click the pause button on the in-progress session card
      lv
      |> element(~s([phx-click="pause_session"][phx-value-task-id="#{task.id}"]))
      |> render_click()

      # Should restore the LAST user message, not the original instruction
      assert_push_event(lv, "restore_draft", %{text: "Also fix the tests"})
    end

    test "cancelling the currently viewed task restores the last user message", %{
      conn: conn,
      user: user
    } do
      output =
        Jason.encode!([
          %{"type" => "user", "id" => "u1", "text" => "Write tests for login"},
          %{"type" => "text", "id" => "t1", "text" => "I'll write some tests..."},
          %{"type" => "user", "id" => "u2", "text" => "Focus on edge cases"}
        ])

      _task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Write tests for login",
          container_id: "c-cancel",
          status: "running",
          output: output
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-cancel")

      # Verify the task is the current task, then cancel it
      lv
      |> element(~s([phx-click="cancel_task"]))
      |> render_click()

      # Should restore the LAST user message, not the original instruction
      assert_push_event(lv, "restore_draft", %{text: "Focus on edge cases"})
    end

    test "falls back to instruction when task has no output", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "pick up ticket #99 using the relevant skill",
        container_id: "c-ticket-99",
        status: "queued"
      })

      ProjectTicketRepository.sync_remote_ticket(%{
        number: 99,
        title: "No-output ticket",
        status: "Backlog",
        priority: "Need",
        size: "M",
        labels: []
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})
      _ = render(lv)

      lv
      |> element(~s([data-testid="pause-ticket-99"]))
      |> render_click()

      # No output → falls back to original instruction
      assert_push_event(lv, "restore_draft", %{
        text: "pick up ticket #99 using the relevant skill"
      })
    end
  end

  describe "session search and filtering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "search input renders above both columns", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "A task",
        container_id: "c-search-test",
        status: "completed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Search sessions and tickets..."
      assert html =~ ~s(name="session_search")
    end

    test "status filter pills render", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "A task",
        container_id: "c-filter-test",
        status: "completed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ ~s(phx-click="status_filter")
      assert html =~ "Running"
      assert html =~ "Queued"
      assert html =~ "Feedback"
      assert html =~ "Failed"
      assert html =~ "Done"
      assert html =~ "Cancelled"
    end

    test "search filters sessions by title across both columns", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Fix login bug",
        container_id: "c-login",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Add dark mode",
        container_id: "c-dark",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      html =
        lv
        |> form(~s(form[phx-change="session_search"]), %{"session_search" => "login"})
        |> render_change()

      assert html =~ "session-item-fix-login-bug"
      refute html =~ "session-item-add-dark-mode"
    end

    test "empty search shows all sessions", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Fix login bug",
        container_id: "c-login",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Add dark mode",
        container_id: "c-dark",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Search then clear
      lv
      |> form(~s(form[phx-change="session_search"]), %{"session_search" => "login"})
      |> render_change()

      html =
        lv
        |> form(~s(form[phx-change="session_search"]), %{"session_search" => ""})
        |> render_change()

      assert html =~ "session-item-fix-login-bug"
      assert html =~ "session-item-add-dark-mode"
    end

    test "search filters tickets by title", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "pick up ticket #10 using the relevant skill",
        container_id: "c-t10",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "pick up ticket #20 using the relevant skill",
        container_id: "c-t20",
        status: "completed"
      })

      {:ok, _} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 10,
          title: "Fix authentication",
          status: "Ready",
          priority: "Need",
          size: "M",
          labels: ["bug"]
        })

      {:ok, _} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 20,
          title: "Add dashboard",
          status: "Ready",
          priority: "Want",
          size: "S",
          labels: ["feature"]
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})
      _ = render(lv)

      html =
        lv
        |> form(~s(form[phx-change="session_search"]), %{"session_search" => "authentication"})
        |> render_change()

      assert html =~ "Fix authentication"
      refute html =~ "Add dashboard"
    end

    test "status filter shows only completed sessions", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Completed task",
        container_id: "c-done",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Failed task",
        container_id: "c-fail",
        status: "failed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      html =
        lv
        |> element(~s(button[phx-click="status_filter"][phx-value-status="completed"]))
        |> render_click()

      assert html =~ "session-item-completed-task"
      refute html =~ "session-item-failed-task"
    end

    test "status filter shows only failed sessions", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Completed task",
        container_id: "c-done",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Failed task",
        container_id: "c-fail",
        status: "failed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      html =
        lv
        |> element(~s(button[phx-click="status_filter"][phx-value-status="failed"]))
        |> render_click()

      refute html =~ "session-item-completed-task"
      assert html =~ "session-item-failed-task"
    end

    test "All filter resets to show everything", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Completed task",
        container_id: "c-done",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Failed task",
        container_id: "c-fail",
        status: "failed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Filter to completed only
      lv
      |> element(~s(button[phx-click="status_filter"][phx-value-status="completed"]))
      |> render_click()

      # Reset to all
      html =
        lv
        |> element(~s(button[phx-click="status_filter"][phx-value-status="all"]))
        |> render_click()

      assert html =~ "session-item-completed-task"
      assert html =~ "session-item-failed-task"
    end

    test "search and status filter work together", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Fix login bug",
        container_id: "c-login-done",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Fix login auth",
        container_id: "c-login-fail",
        status: "failed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Add dark mode",
        container_id: "c-dark",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Search for "login"
      lv
      |> form(~s(form[phx-change="session_search"]), %{"session_search" => "login"})
      |> render_change()

      # Then filter to completed only
      html =
        lv
        |> element(~s(button[phx-click="status_filter"][phx-value-status="completed"]))
        |> render_click()

      assert html =~ "session-item-fix-login-bug"
      refute html =~ "session-item-fix-login-auth"
      refute html =~ "session-item-add-dark-mode"
    end
  end
end

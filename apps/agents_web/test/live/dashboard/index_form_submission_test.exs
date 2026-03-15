defmodule AgentsWeb.DashboardLive.IndexFormSubmissionTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures
  import Ecto.Query
  import AgentsWeb.DashboardTestHelpers, only: [send_queue_state: 3]

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Repo
  alias AgentsWeb.DashboardTestHelpers.FakeTaskRunner

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

    test "question tool submit shows answer submitted indicator", %{conn: conn, user: user} do
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
      assert html =~ "Answer submitted"
    end

    test "answer submitted indicator is removed on async error", %{conn: conn, user: user} do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Initial instruction",
          container_id: "c1",
          status: "running"
        })

      start_supervised!({FakeTaskRunner, task.id})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Submit a question answer to get the :answer_submitted indicator
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

      # Flush the first {:answer_question_async, ...} sent by submit_active_question
      _ = render(lv)
      assert render(lv) =~ "Answer submitted"

      # Send a second async message with a non-existent task ID to trigger
      # {:error, :task_not_running} — the FakeTaskRunner is only registered
      # for task.id, so "no-such-task" will fail lookup immediately.
      send(
        lv.pid,
        {:answer_question_async, "no-such-task", "req-1", [["Yes"]], "Re: Deploy — Yes"}
      )

      html = render(lv)
      refute html =~ "Answer submitted"
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

  describe "ticket context propagation in run_task" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "run_task with ticket_number prefixes instruction and appends ticket context", %{
      conn: conn,
      user: user
    } do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 910,
          title: "Ticket context for run_task",
          body: "Include this body in session instruction.",
          status: "Ready",
          priority: "Need",
          size: "M",
          labels: ["triage"]
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      _ =
        render_submit(lv, "run_task", %{
          "instruction" => "implement now",
          "ticket_number" => "910"
        })

      created_task =
        TaskSchema
        |> where([t], t.user_id == ^user.id)
        |> order_by([t], desc: t.inserted_at)
        |> limit(1)
        |> Repo.one!()

      assert created_task.instruction =~ "#910 implement now"
      assert created_task.instruction =~ "## Ticket #910: Ticket context for run_task"
      assert created_task.instruction =~ "Labels: #triage"
      assert created_task.instruction =~ "Body:\nInclude this body in session instruction."
    end
  end

  describe "ensure_ticket_reference edge cases in run_task" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "instruction already containing #N with ticket struct appends context without duplicating prefix",
         %{conn: conn, user: user} do
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 920,
          title: "Already referenced ticket",
          body: "Edge case body.",
          status: "Ready",
          priority: "Need",
          size: "S",
          labels: ["edge"]
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      _ =
        render_submit(lv, "run_task", %{
          "instruction" => "#920 do the thing",
          "ticket_number" => "920"
        })

      created_task =
        TaskSchema
        |> where([t], t.user_id == ^user.id)
        |> order_by([t], desc: t.inserted_at)
        |> limit(1)
        |> Repo.one!()

      # Should NOT double the prefix — keeps original #920
      assert created_task.instruction =~ "#920 do the thing"
      refute created_task.instruction =~ "#920 #920"
      # But context block is still appended
      assert created_task.instruction =~ "## Ticket #920: Already referenced ticket"
      assert created_task.instruction =~ "Body:\nEdge case body."
    end

    test "ticket_number present but ticket not found falls back to prefix-only", %{
      conn: conn,
      user: user
    } do
      # Do NOT sync ticket 999 — it doesn't exist in the DB
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      _ =
        render_submit(lv, "run_task", %{
          "instruction" => "work on this",
          "ticket_number" => "999"
        })

      created_task =
        TaskSchema
        |> where([t], t.user_id == ^user.id)
        |> order_by([t], desc: t.inserted_at)
        |> limit(1)
        |> Repo.one!()

      # Falls back to the prefix-only clause (ticket struct is nil)
      assert created_task.instruction =~ "#999 work on this"
      # No context block since ticket couldn't be found
      refute created_task.instruction =~ "<ticket-context>"
    end
  end

  describe "run_task with ticket_number for unrelated active session" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "creates a new task instead of following up on unrelated active session", %{
      conn: conn,
      user: user
    } do
      # 1. Create a running task on session A (unrelated to any ticket)
      running_task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Some unrelated coding task",
          container_id: "c-unrelated-active",
          status: "running"
        })

      # 2. Create ticket #422 with no associated session
      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 422,
          title: "Ticket that needs a session",
          body: "Please work on this.",
          status: "Ready",
          priority: "Need",
          size: "M",
          labels: []
        })

      # 3. Mount the dashboard viewing session A — current_task = running task
      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-unrelated-active")

      # Verify current_task is the running task
      state = :sys.get_state(lv.pid)

      assert state.socket.assigns.current_task.id == running_task.id
      assert state.socket.assigns.current_task.status == "running"

      # 4. Count tasks before submission
      task_count_before =
        TaskSchema
        |> where([t], t.user_id == ^user.id)
        |> select([t], count(t.id))
        |> Repo.one!()

      # 5. Submit run_task with ticket_number for the unrelated ticket
      #    This simulates the user being on the ticket tab with ticket #422
      #    but current_task is the running task from session A.
      _ =
        render_submit(lv, "run_task", %{
          "instruction" => "fix the bug in this ticket",
          "ticket_number" => "422"
        })

      # 6. A NEW task should have been created for the ticket
      task_count_after =
        TaskSchema
        |> where([t], t.user_id == ^user.id)
        |> select([t], count(t.id))
        |> Repo.one!()

      assert task_count_after == task_count_before + 1,
             "Expected a new task to be created for ticket #422, " <>
               "but task count didn't increase (was #{task_count_before}, now #{task_count_after}). " <>
               "The message was likely routed as a follow-up to the unrelated running task."

      # The new task's instruction should reference ticket #422
      new_task =
        TaskSchema
        |> where([t], t.user_id == ^user.id and t.id != ^running_task.id)
        |> Repo.one!()

      assert new_task.instruction =~ "#422"
      assert new_task.instruction =~ "fix the bug in this ticket"
    end
  end
end

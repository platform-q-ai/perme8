defmodule AgentsWeb.DashboardLive.IndexSessionManagementTest do
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

      assert html =~ "sidebar-new-ticket-form"
      assert html =~ "sidebar-new-ticket-instruction"
    end

    test "submitting empty sidebar quick-start body does not change selected session", %{
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
      |> form("#sidebar-new-ticket-form", %{"body" => "   "})
      |> render_submit()

      html = render(lv)
      assert html =~ "sidebar-new-ticket-form"
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

      send_queue_state(lv, user.id, %{
        running: 1,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 3
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

      send_queue_state(lv, user.id, %{
        running: 1,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 2
      })

      html = render(lv)
      assert html =~ ~s(data-testid="empty-concurrency-slot-1")
      refute html =~ ~s(data-testid="empty-concurrency-slot-2")

      send_queue_state(lv, user.id, %{
        running: 2,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 4
      })

      html = render(lv)
      assert html =~ ~s(data-testid="empty-concurrency-slot-2")
      assert length(:binary.matches(html, ~s(data-slot-state="empty"))) == 2
    end

    test "concurrency limit 0 shows no empty slots and no concurrency slots", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Running session",
        container_id: "c-running",
        status: "running"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send_queue_state(lv, user.id, %{
        running: 1,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 0
      })

      html = render(lv)
      refute html =~ ~s(data-testid="empty-concurrency-slot-1")
      refute html =~ ~s(data-slot-state="empty")
    end

    test "concurrency limit 0 with no running tasks shows no empty slots", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Completed session",
        container_id: "c-done",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 0
      })

      html = render(lv)
      refute html =~ ~s(data-testid="empty-concurrency-slot-1")
      refute html =~ ~s(data-slot-state="empty")
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

      send_queue_state(lv, user.id, %{
        running: 1,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 2
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

      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 2,
        warm_cache_limit: 3
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

      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 2,
        warm_cache_limit: 0
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warm-outside-queue-window")
      assert html =~ ~s(phx-value-task-id="#{task.id}")
      assert html =~ "border-warning/40 bg-warning/10"
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

      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [%{id: task.id}],
        awaiting_feedback: [],
        concurrency_limit: 2,
        warm_cache_limit: 1
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

      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [%{id: task.id}],
        awaiting_feedback: [],
        concurrency_limit: 2,
        warm_cache_limit: 1,
        warming_task_ids: [task.id]
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

      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [%{id: task.id}],
        awaiting_feedback: [],
        concurrency_limit: 2,
        warm_cache_limit: 1
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warmed-queued-session")
      assert html =~ ~s(data-slot-state="warm")
      refute html =~ "Warming..."
      assert html =~ "border-warning/40 bg-warning/10"
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

      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 2,
        warm_cache_limit: 1,
        warm_task_ids: [],
        warming_task_ids: []
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

      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [%{id: task.id}],
        awaiting_feedback: [],
        concurrency_limit: 2,
        warm_cache_limit: 1,
        warming_task_ids: [task.id]
      })

      html = render(lv)

      assert html =~ ~s(data-testid="session-item-warm-via-queue-state-ids")
      assert html =~ ~s(data-slot-state="warming")
      assert html =~ "Warming..."
      assert html =~ "animate-pulse"
    end

    test "queued ticket in warm slot renders as ticket card not session card", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #850 using the relevant skill",
          status: "queued",
          container_id: nil
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 850,
          title: "Warm ticket test",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: ["warm-test"]
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Place the task in the warm zone
      send_queue_state(lv, user.id, %{
        running: 0,
        queued: [%{id: task.id}],
        awaiting_feedback: [],
        concurrency_limit: 2,
        warm_cache_limit: 1
      })

      html = render(lv)

      # Should render as a ticket card (build-ticket-item-*), NOT as a session card
      assert html =~ ~s(data-testid="build-ticket-item-850")
      refute html =~ ~s(data-testid="session-item-pick-up-ticket-850-using-the-relevant-skill")

      # Should have ticket identity: number badge and labels
      assert html =~ "850"
      assert html =~ "Warm ticket test"
      assert html =~ "warm-test"

      # Should be in a warm slot
      assert html =~ ~s(data-slot-state="warm")
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

      send_queue_state(lv, user.id, %{
        running: 1,
        queued: [],
        awaiting_feedback: [],
        concurrency_limit: 2
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

  describe "session card duration and file stats rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    defp task_with_timestamps(attrs, timestamp_attrs) do
      task = task_fixture(attrs)

      task
      |> TaskSchema.status_changeset(timestamp_attrs)
      |> Repo.update!()
    end

    test "completed session card shows duration element", %{conn: conn, user: user} do
      five_min_ago = DateTime.add(DateTime.utc_now(), -300, :second)
      now = DateTime.utc_now()

      task_with_timestamps(
        %{
          user_id: user.id,
          instruction: "Completed with duration",
          container_id: "c-dur-#{System.unique_integer([:positive])}",
          status: "completed"
        },
        %{started_at: five_min_ago, completed_at: now}
      )

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-completed-with-duration")
      assert html =~ ~s(data-testid="session-duration")
    end

    test "failed session card shows duration element", %{conn: conn, user: user} do
      two_min_ago = DateTime.add(DateTime.utc_now(), -120, :second)

      task_with_timestamps(
        %{
          user_id: user.id,
          instruction: "Failed with duration",
          container_id: "c-fail-dur-#{System.unique_integer([:positive])}",
          status: "failed"
        },
        %{started_at: two_min_ago}
      )

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-failed-with-duration")
      assert html =~ ~s(data-testid="session-duration")
    end

    test "session card without started_at does not show duration element", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Pending no duration",
        container_id: "c-no-dur-#{System.unique_integer([:positive])}",
        status: "pending"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-pending-no-duration")
      refute html =~ ~s(data-testid="session-duration")
    end

    test "completed session card shows file change stats", %{conn: conn, user: user} do
      five_min_ago = DateTime.add(DateTime.utc_now(), -300, :second)
      now = DateTime.utc_now()

      task_with_timestamps(
        %{
          user_id: user.id,
          instruction: "Completed with file stats",
          container_id: "c-fstats-#{System.unique_integer([:positive])}",
          status: "completed"
        },
        %{
          started_at: five_min_ago,
          completed_at: now,
          session_summary: %{"files" => 3, "additions" => 42, "deletions" => 18}
        }
      )

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-completed-with-file-stats")
      assert html =~ ~s(data-testid="session-file-stats")
      assert html =~ "3 files"
      assert html =~ "+42"
      assert html =~ "-18"
    end

    test "session card without session_summary does not show file stats", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "No file stats",
        container_id: "c-no-fstats-#{System.unique_integer([:positive])}",
        status: "completed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-no-file-stats")
      refute html =~ ~s(data-testid="session-file-stats")
    end

    test "session card shows both duration and file stats together", %{conn: conn, user: user} do
      five_min_ago = DateTime.add(DateTime.utc_now(), -300, :second)
      now = DateTime.utc_now()

      task_with_timestamps(
        %{
          user_id: user.id,
          instruction: "Both stats session",
          container_id: "c-both-#{System.unique_integer([:positive])}",
          status: "completed"
        },
        %{
          started_at: five_min_ago,
          completed_at: now,
          session_summary: %{"files" => 5, "additions" => 100, "deletions" => 50}
        }
      )

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      card_testid = ~s(data-testid="session-item-both-stats-session")
      assert html =~ card_testid
      assert html =~ ~s(data-testid="session-duration")
      assert html =~ ~s(data-testid="session-file-stats")
      assert html =~ "5 files"
      assert html =~ "+100"
      assert html =~ "-50"
    end

    test "file stats with zero files does not render", %{conn: conn, user: user} do
      task_with_timestamps(
        %{
          user_id: user.id,
          instruction: "Zero files session",
          container_id: "c-zero-#{System.unique_integer([:positive])}",
          status: "completed"
        },
        %{
          started_at: DateTime.add(DateTime.utc_now(), -60, :second),
          completed_at: DateTime.utc_now(),
          session_summary: %{"files" => 0, "additions" => 0, "deletions" => 0}
        }
      )

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-item-zero-files-session")
      refute html =~ ~s(data-testid="session-file-stats")
    end

    test "file stats with single file uses singular label", %{conn: conn, user: user} do
      task_with_timestamps(
        %{
          user_id: user.id,
          instruction: "Single file session",
          container_id: "c-single-#{System.unique_integer([:positive])}",
          status: "completed"
        },
        %{
          started_at: DateTime.add(DateTime.utc_now(), -60, :second),
          completed_at: DateTime.utc_now(),
          session_summary: %{"files" => 1, "additions" => 10, "deletions" => 5}
        }
      )

      {:ok, _lv, html} = live(conn, ~p"/sessions")

      assert html =~ ~s(data-testid="session-file-stats")
      assert html =~ "1 file"
      refute html =~ "1 files"
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
end

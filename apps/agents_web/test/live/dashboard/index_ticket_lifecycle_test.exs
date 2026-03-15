defmodule AgentsWeb.DashboardLive.IndexTicketLifecycleTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures
  import Ecto.Query

  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Repo

  defmodule LabelTestGithubClient do
    @behaviour Agents.Application.Behaviours.GithubTicketClientBehaviour

    @impl true
    def update_issue(number, _attrs, _opts), do: {:ok, %{number: number}}
    @impl true
    def get_issue(_, _), do: {:error, :not_implemented}
    @impl true
    def list_issues(_), do: {:error, :not_implemented}
    @impl true
    def create_issue(_, _), do: {:error, :not_implemented}
    @impl true
    def close_issue_with_comment(_, _), do: {:error, :not_implemented}
    @impl true
    def add_comment(_, _, _), do: {:error, :not_implemented}
    @impl true
    def add_sub_issue(_, _, _), do: {:error, :not_implemented}
    @impl true
    def remove_sub_issue(_, _, _), do: {:error, :not_implemented}
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

      # Ticket should be removed from the triage lane (default filter is :open)
      refute html =~ "Ticket to close"
      refute html =~ ~s(data-testid="triage-ticket-item-555")

      # Ticket should be marked as closed in the database (not deleted)
      remaining = ProjectTicketRepository.list_all()
      closed_ticket = Enum.find(remaining, &(&1.number == 555))
      assert closed_ticket
      assert closed_ticket.state == "closed"
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

    test "clicking play button optimistically moves ticket to build queue", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-play-context",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 603,
          title: "Context-rich ticket",
          body: "Reproduce, verify, and ship.",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: ["bug", "backend"]
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Verify ticket starts in triage
      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-603")
      refute html =~ ~s(data-testid="build-ticket-item-603")

      # render_click returns the HTML immediately after the event handler
      # (before async messages like :DOWN can revert the optimistic update)
      html =
        lv
        |> element(~s([data-testid="start-ticket-session-603"]))
        |> render_click()

      # After clicking play, the ticket should immediately appear in build
      # as a proper ticket card (not a bare "Syncing..." session)
      assert html =~ ~s(data-testid="build-ticket-item-603")
      assert html =~ "Context-rich ticket"
      refute html =~ ~s(data-testid="triage-ticket-item-603")
    end

    test "optimistic ticket reverts to triage on task creation failure", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-play-fail",
        status: "completed"
      })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 604,
          title: "Ticket that fails to start",
          status: "Backlog",
          priority: "Need",
          size: "S",
          labels: ["chore"]
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Verify ticket starts in triage
      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-604")

      # render_click returns HTML immediately after the event handler
      # (optimistic update applied, before async DOWN arrives)
      html =
        lv
        |> element(~s([data-testid="start-ticket-session-604"]))
        |> render_click()

      # Optimistically moved to build
      assert html =~ ~s(data-testid="build-ticket-item-604")

      # The spawned process fails because create_task uses a DB connection
      # not available in the test sandbox. The :DOWN monitor fires and
      # reverts the optimistic ticket update.
      Process.sleep(200)

      # Ticket should revert back to triage after the error
      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-604")
      refute html =~ ~s(data-testid="build-ticket-item-604")
    end

    test "sub-ticket moves to build queue when started", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-sub-start",
        status: "completed"
      })

      {:ok, parent} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 610,
          title: "Parent with sub-tickets",
          status: "Backlog",
          priority: "Need",
          size: "L",
          labels: []
        })

      {:ok, _child} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 611,
          title: "Child sub-ticket",
          status: "Backlog",
          priority: "Need",
          size: "S",
          labels: [],
          parent_ticket_id: parent.id
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Sub-ticket should be visible in triage (parents expand by default)
      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-610")
      assert html =~ ~s(data-testid="triage-ticket-item-611")
      refute html =~ ~s(data-testid="build-ticket-item-611")

      # Click play on the sub-ticket
      html =
        lv
        |> element(~s([data-testid="start-ticket-session-611"]))
        |> render_click()

      # Sub-ticket should move to build queue
      assert html =~ ~s(data-testid="build-ticket-item-611")
      assert html =~ "Child sub-ticket"
      # Sub-ticket should no longer appear in triage
      refute html =~ ~s(data-testid="triage-ticket-item-611")
      # Parent should still be in triage
      assert html =~ ~s(data-testid="triage-ticket-item-610")
    end

    test "sub-ticket reverts to triage on task creation failure", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Existing session",
        container_id: "c-sub-fail",
        status: "completed"
      })

      {:ok, parent} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 620,
          title: "Parent for failure test",
          status: "Backlog",
          priority: "Need",
          size: "L",
          labels: []
        })

      {:ok, _child} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 621,
          title: "Child that fails to start",
          status: "Backlog",
          priority: "Need",
          size: "S",
          labels: [],
          parent_ticket_id: parent.id
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-621")

      # Click play on the sub-ticket
      html =
        lv
        |> element(~s([data-testid="start-ticket-session-621"]))
        |> render_click()

      # Optimistically moved to build
      assert html =~ ~s(data-testid="build-ticket-item-621")

      # The spawned process fails in test sandbox; DOWN reverts the update
      Process.sleep(200)

      html = render(lv)
      assert html =~ ~s(data-testid="triage-ticket-item-621")
      refute html =~ ~s(data-testid="build-ticket-item-621")
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

    test "session linked by associated_task_id renders only as build ticket", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Implement feature work",
          status: "queued",
          container_id: nil
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 806,
          title: "Task-linked build ticket",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      assert {:ok, _} = ProjectTicketRepository.link_task(806, task.id)

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)

      assert html =~ ~s(data-testid="build-ticket-item-806")
      refute html =~ ~s(data-testid="triage-ticket-item-806")
      refute html =~ ~s(data-testid="session-item-implement-feature-work")
    end

    test "close_ticket removes ticket from UI and destroys session", %{conn: conn, user: user} do
      task =
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

      # Persist the FK so apply_ticket_closed can resolve the container_id
      # even when the task is terminal and enrichment regex doesn't match.
      ProjectTicketRepository.link_task(805, task.id)

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

    test "close_ticket cleans stale task from snapshot so re-opened ticket is idle", %{
      conn: conn,
      user: user
    } do
      # 1. Create a failed task linked to ticket #900 via persisted FK
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #900 using the relevant skill",
          container_id: "c-ticket-900",
          status: "failed",
          error: "something went wrong"
        })

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 900,
          title: "Ticket that re-links after delete",
          status: "Backlog",
          priority: "Need",
          size: "M",
          labels: []
        })

      # Persist the FK so apply_ticket_closed can resolve the container_id
      ProjectTicketRepository.link_task(900, task.id)

      # 2. Mount — ticket should show as failed in triage
      {:ok, lv, _html} = live(conn, ~p"/sessions?container=c-ticket-900")
      send(lv.pid, {:tickets_synced, []})
      html = render(lv)

      assert html =~ ~s(data-testid="triage-ticket-item-900")
      # The card uses error border colors when task_status is "failed"
      assert html =~ "border-error"

      # 3. Close the ticket (destroys the session)
      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="900"]))
      |> render_click()

      lv |> element(~s(button[data-tab-id="ticket"])) |> render_click()

      lv
      |> element(~s([data-testid="close-ticket-btn"]))
      |> render_click()

      # 4. Re-open the ticket in the DB and reload.
      #    Enrichment runs against tasks_snapshot. Without the fix, the stale
      #    failed task still lurks in the snapshot, so enrichment's regex
      #    fallback re-links the ticket to the old failed task — the ticket
      #    card shows error styling instead of idle. With the fix, the
      #    snapshot was cleaned on close_ticket, so the ticket renders idle.
      Repo.update_all(
        from(t in "sessions_project_tickets", where: t.number == 900),
        set: [state: "open"]
      )

      send(lv.pid, {:tickets_synced, []})
      html = render(lv)

      assert html =~ ~s(data-testid="triage-ticket-item-900")
      # After closing and re-opening, the ticket should be idle — no error
      # border from the old failed session should bleed through.
      # Locate only the ticket-900 card to avoid false matches elsewhere.
      [_, card_html] = String.split(html, ~s(data-testid="triage-ticket-item-900"), parts: 2)
      card_html = String.split(card_html, ~s(data-testid="), parts: 2) |> hd()
      refute card_html =~ "border-error"
    end
  end

  describe "ticket hierarchy rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders parent and subticket depth attributes and supports collapse toggle", %{
      conn: conn
    } do
      {:ok, parent} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 900,
          title: "Parent ticket",
          status: "Backlog",
          labels: []
        })

      {:ok, _child} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 901,
          title: "Child ticket",
          status: "Backlog",
          labels: [],
          parent_ticket_id: parent.id
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      html = render(lv)
      assert html =~ ~s(data-ticket-depth="0")
      assert html =~ ~s(data-ticket-depth="1")
      assert html =~ ~s(data-testid="triage-parent-toggle")
      assert html =~ ~s(data-testid="triage-subticket-list")

      html =
        lv
        |> element(~s([data-testid="triage-parent-toggle"]))
        |> render_click()

      refute html =~ ~s(data-testid="triage-subticket-list")
    end

    test "ticket detail panel renders body, labels, sub-issues, and breadcrumb for subticket", %{
      conn: conn
    } do
      {:ok, parent} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 910,
          title: "Parent detail",
          body: "Parent body",
          status: "Backlog",
          labels: ["agents"]
        })

      {:ok, _child} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 911,
          title: "Child detail",
          body: "Child body",
          status: "Backlog",
          labels: [],
          parent_ticket_id: parent.id
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="910"]))
      |> render_click()

      html = lv |> element(~s(button[data-tab-id="ticket"])) |> render_click()

      assert html =~ ~s(data-testid="ticket-detail-panel")
      assert html =~ ~s(data-testid="ticket-detail-body")
      assert html =~ ~s(data-testid="ticket-detail-labels")
      assert html =~ ~s(data-testid="ticket-detail-subissues")
      assert html =~ ~s(data-testid="ticket-subissue-item-911")

      html =
        lv
        |> element(~s([data-testid="ticket-subissue-item-911"]))
        |> render_click()

      assert html =~ ~s(data-ticket-type="subticket")
      assert html =~ ~s(data-testid="ticket-detail-parent-breadcrumb")
    end
  end

  describe "ticket label picker" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, _ticket} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 950,
          title: "Label picker test ticket",
          body: "Test body",
          labels: ["bug"]
        })

      original = Application.get_env(:agents, :github_ticket_client)
      Application.put_env(:agents, :github_ticket_client, LabelTestGithubClient)

      on_exit(fn ->
        if original,
          do: Application.put_env(:agents, :github_ticket_client, original),
          else: Application.delete_env(:agents, :github_ticket_client)
      end)

      %{conn: log_in_user(conn, user), user: user}
    end

    test "label picker is visible on ticket detail panel", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Select the ticket
      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="950"]))
      |> render_click()

      html = lv |> element(~s(button[data-tab-id="ticket"])) |> render_click()

      # Label picker should be visible
      assert html =~ ~s(data-testid="label-picker")
      assert html =~ ~s(data-testid="label-toggle-bug")
      assert html =~ ~s(data-testid="label-toggle-enhancement")
    end

    test "clicking a label triggers update and reflects in UI", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sessions")
      send(lv.pid, {:tickets_synced, []})

      # Select the ticket and view detail panel
      lv
      |> element(~s([phx-click="select_ticket"][phx-value-number="950"]))
      |> render_click()

      lv |> element(~s(button[data-tab-id="ticket"])) |> render_click()

      # Click the "enhancement" label toggle to add it
      html =
        lv
        |> element(~s([data-testid="label-toggle-enhancement"]))
        |> render_click()

      # The ticket should now have "enhancement" label (added to existing "bug")
      assert html =~ "enhancement"
    end
  end
end

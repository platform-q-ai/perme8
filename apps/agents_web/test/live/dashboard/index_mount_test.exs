defmodule AgentsWeb.DashboardLive.IndexMountTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures

  describe "mount and rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the sessions page with heading", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Sessions"
    end

    test "renders sidebar new ticket textarea", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "sidebar-new-ticket-form"
      assert html =~ "Add a ticket..."
    end

    test "create_ticket via sidebar form creates ticket and shows in UI", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Submit the form with a ticket body
      lv
      |> form("#sidebar-new-ticket-form", %{body: "Fix the login page"})
      |> render_submit()

      # The CreateTicket use case broadcasts {:tickets_synced, []} which
      # the LiveView handles to reload tickets from DB.
      html = render(lv)

      # The ticket should appear in the triage lane
      assert html =~ "Fix the login page"
    end

    test "create_ticket with empty body does not create a ticket", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Submit with whitespace-only body — should not crash or create a ticket
      lv
      |> form("#sidebar-new-ticket-form", %{body: "   "})
      |> render_submit()

      html = render(lv)
      # No ticket should appear in the triage lane
      refute html =~ ~s(data-testid="triage-ticket-item-)
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
end

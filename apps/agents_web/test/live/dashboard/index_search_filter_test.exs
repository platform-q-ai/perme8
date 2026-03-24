defmodule AgentsWeb.DashboardLive.IndexSearchFilterTest do
  use AgentsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures

  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository

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

    test "status filter updates the active pill classes", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Completed task",
        container_id: "c-filter-class-done",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      html =
        lv
        |> element(~s(button[phx-click="status_filter"][phx-value-status="running"]))
        |> render_click()

      assert html =~ ~s(phx-value-status="running" class="btn btn-xs rounded-full btn-success")
      assert html =~ ~s(phx-value-status="open" class="btn btn-xs rounded-full btn-ghost")
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

    test "Open filter resets to show everything", %{conn: conn, user: user} do
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

      # Reset to open
      html =
        lv
        |> element(~s(button[phx-click="status_filter"][phx-value-status="open"]))
        |> render_click()

      assert html =~ "session-item-completed-task"
      assert html =~ "session-item-failed-task"
    end

    test "invalid status filter is handled gracefully", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "A task",
        container_id: "c-inv",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Sending an unknown status string should not crash the handler
      html = render_click(lv, "status_filter", %{"status" => "nonexistent"})
      assert html =~ "session-item-a-task"
    end

    test "clear search button resets filter", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Fix login bug",
        container_id: "c-login-clear",
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Add dark mode",
        container_id: "c-dark-clear",
        status: "completed"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Search to filter
      lv
      |> form(~s(form[phx-change="session_search"]), %{"session_search" => "login"})
      |> render_change()

      # Clear via dedicated event
      html = render_click(lv, "clear_session_search", %{})
      assert html =~ "session-item-fix-login-bug"
      assert html =~ "session-item-add-dark-mode"
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

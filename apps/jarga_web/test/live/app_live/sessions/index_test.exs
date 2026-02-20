defmodule JargaWeb.AppLive.Sessions.IndexTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures

  describe "mount and rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the sessions page with heading", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/sessions")
      assert html =~ "Sessions"
    end

    test "renders instruction textarea", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/sessions")
      assert html =~ "session-instruction"
    end

    test "renders Run button", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/sessions")
      assert html =~ "Run"
    end

    test "renders empty state when no tasks exist", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app/sessions")
      assert html =~ "No sessions yet"
    end

    test "loads and displays task history on mount", %{conn: conn, user: user} do
      task_fixture(%{user_id: user.id, instruction: "Write tests for login"})
      task_fixture(%{user_id: user.id, instruction: "Refactor auth module"})

      {:ok, _lv, html} = live(conn, ~p"/app/sessions")
      assert html =~ "Write tests for login"
      assert html =~ "Refactor auth module"
    end
  end

  describe "form submission" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "submitting empty instruction shows validation error", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app/sessions")

      html =
        lv
        |> form("#session-form", %{"instruction" => ""})
        |> render_submit()

      assert html =~ "Instruction is required"
    end
  end

  describe "real-time PubSub events" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "receiving task_event appends event to the log", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running"})
      {:ok, lv, _html} = live(conn, ~p"/app/sessions")

      event = %{type: "message.delta", data: %{content: "Working on it..."}}
      send(lv.pid, {:task_event, task.id, event})

      html = render(lv)
      assert html =~ "Working on it..."
    end

    test "receiving task_status_changed to completed updates UI", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running"})
      {:ok, lv, _html} = live(conn, ~p"/app/sessions")

      send(lv.pid, {:task_status_changed, task.id, "completed"})

      html = render(lv)
      assert html =~ "completed"
    end

    test "receiving task_status_changed to failed shows error", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running"})
      {:ok, lv, _html} = live(conn, ~p"/app/sessions")

      send(lv.pid, {:task_status_changed, task.id, "failed"})

      html = render(lv)
      assert html =~ "failed"
    end
  end

  describe "task history and status indicators" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders colour-coded status badges", %{conn: conn, user: user} do
      task_fixture(%{user_id: user.id, instruction: "Completed task", status: "completed"})
      task_fixture(%{user_id: user.id, instruction: "Failed task", status: "failed"})
      task_fixture(%{user_id: user.id, instruction: "Pending task", status: "pending"})

      {:ok, _lv, html} = live(conn, ~p"/app/sessions")

      assert html =~ "badge-success"
      assert html =~ "badge-error"
      assert html =~ "badge-warning"
    end

    test "truncates long instructions in history", %{conn: conn, user: user} do
      long_instruction = String.duplicate("a", 120)
      task_fixture(%{user_id: user.id, instruction: long_instruction})

      {:ok, _lv, html} = live(conn, ~p"/app/sessions")

      # Should be truncated with ellipsis
      refute html =~ long_instruction
      assert html =~ String.slice(long_instruction, 0..79)
    end
  end
end

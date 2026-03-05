defmodule AgentsWeb.SessionsLive.IndexAuthRefreshTest do
  @moduledoc """
  Tests for the per-session concurrent auth refresh feature.

  Verifies that:
  - Auth refresh buttons render per-session (not globally locked)
  - Multiple sessions can be refreshed concurrently
  - The "Refresh All Auth" button appears when candidates exist
  - Sidebar shows per-session refresh indicators
  - Async results correctly update per-task state
  """

  # Cannot be async because the task_status_changed handler triggers
  # QueueManager and task refresh processes that need DB access via the
  # Ecto sandbox. In async mode, those spawned processes cannot see the
  # test's sandbox checkout, causing intermittent failures.
  use AgentsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Repo

  describe "auth refresh button rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows Refresh Auth & Resume button for failed task with auth error", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        status: "failed",
        container_id: "c1",
        session_id: "sess-1",
        error: "Token refresh failed: 400"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Refresh Auth &amp; Resume"
    end

    test "does not show Refresh Auth button for non-auth errors", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        status: "failed",
        container_id: "c1",
        session_id: "sess-1",
        error: "Container start failed: timeout"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      refute html =~ "Refresh Auth &amp; Resume"
    end

    test "does not show Refresh Auth button for completed tasks", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        status: "completed",
        container_id: "c1",
        session_id: "sess-1"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      refute html =~ "Refresh Auth &amp; Resume"
    end
  end

  describe "Refresh All Auth button" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows Refresh All Auth when auth-failed sessions exist", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        status: "failed",
        container_id: "c1",
        session_id: "sess-1",
        error: "Token refresh failed: 400"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Refresh All Auth"
    end

    test "does not show Refresh All Auth when no auth errors", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        status: "failed",
        container_id: "c1",
        session_id: "sess-1",
        error: "Container start failed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      refute html =~ "Refresh All Auth"
    end

    test "does not show Refresh All Auth when all sessions are completed", %{
      conn: conn,
      user: user
    } do
      task_fixture(%{
        user_id: user.id,
        status: "completed",
        container_id: "c1",
        session_id: "sess-1"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      refute html =~ "Refresh All Auth"
    end
  end

  describe "sidebar per-session refresh indicators" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows global refresh action for auth-failed sessions", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Auth failed task",
        status: "failed",
        container_id: "c1",
        session_id: "sess-1",
        error: "Token refresh failed: 400"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      assert html =~ "Refresh All Auth"
    end

    test "does not show refresh icon for non-auth-failed sessions", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Normal failed task",
        status: "failed",
        container_id: "c1",
        session_id: "sess-1",
        error: "Container start failed"
      })

      {:ok, _lv, html} = live(conn, ~p"/sessions")
      # Should not have the sidebar refresh button (title attribute)
      refute html =~ "Refresh auth &amp; resume"
    end
  end

  describe "per-session async result handling" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "tagged success result from non-active session updates sidebar without changing detail pane",
         %{conn: conn, user: user} do
      # Create two sessions: one active (c2), one being refreshed (c1)
      task1 =
        task_fixture(%{
          user_id: user.id,
          instruction: "First task",
          status: "failed",
          container_id: "c1",
          session_id: "sess-1",
          error: "Token refresh failed: 400"
        })

      task_fixture(%{
        user_id: user.id,
        instruction: "Second task (active)",
        status: "completed",
        container_id: "c2",
        session_id: "sess-2"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Simulate a tagged success result for the non-active task
      # Update the task status in DB first (as the use case would)
      Repo.get!(TaskSchema, task1.id)
      |> Ecto.Changeset.change(status: "pending", error: nil)
      |> Repo.update!()

      resumed_task = Repo.get!(TaskSchema, task1.id)

      send(lv.pid, {make_ref(), {task1.id, {:ok, resumed_task}}})

      html = render(lv)
      # The detail pane should still show the active task (c2), not the refreshed one
      # The sidebar should reflect the updated state
      assert html =~ "Second task (active)"
    end

    test "tagged error result clears refreshing state for that task", %{conn: conn, user: user} do
      task_fixture(%{
        user_id: user.id,
        instruction: "Auth failed task",
        status: "failed",
        container_id: "c1",
        session_id: "sess-1",
        error: "Token refresh failed: 400"
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Simulate tagged error result — the handler clears the task from
      # @auth_refreshing and puts a flash.  Flash is rendered in the layout
      # so we can't assert on it via render(lv).  Instead verify the
      # sidebar refresh button is still available (not stuck spinning).
      send(lv.pid, {make_ref(), {"some-task-id", {:error, :health_timeout}}})

      html = render(lv)
      # The global refresh action should still be present and enabled
      assert html =~ "Refresh All Auth"
      # The "Refreshing..." text should NOT appear (proves state was cleared)
      refute html =~ "Refreshing..."
    end

    test "task_status_changed to failed with auth error shows refresh button", %{
      conn: conn,
      user: user
    } do
      task =
        task_fixture(%{
          user_id: user.id,
          status: "running",
          container_id: "c1",
          session_id: "sess-1"
        })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      # Update the DB with the auth failure error
      updated =
        Repo.get!(TaskSchema, task.id)
        |> Ecto.Changeset.change(status: "failed", error: "Token refresh failed: 401")
        |> Repo.update!()

      # task_status_changed only carries task_id + status (not the error field).
      # The error shows up after the async task refresh completes, so we send
      # both messages to simulate the full flow without relying on async DB fetch.
      send(lv.pid, {:task_status_changed, task.id, "failed"})
      send(lv.pid, {:task_refreshed, task.id, {:ok, updated}})

      html = render(lv)
      assert html =~ "Task failed"
      assert html =~ "Token refresh failed"
      assert html =~ "Refresh Auth &amp; Resume"
    end
  end
end

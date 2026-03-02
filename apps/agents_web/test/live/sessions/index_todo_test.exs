defmodule AgentsWeb.SessionsLive.IndexTodoTest do
  use AgentsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Agents.SessionsFixtures

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  describe "todo_items assign and PubSub updates" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "initializes :todo_items as []", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      assert socket_assign(lv, :todo_items) == []
    end

    test "updates :todo_items when {:todo_updated, task_id, items} matches current task", %{
      conn: conn,
      user: user
    } do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(
        lv.pid,
        {:todo_updated, task.id,
         [
           %{
             "id" => "todo-1",
             "title" => "Write tests",
             "status" => "in_progress",
             "position" => 0
           }
         ]}
      )

      assert socket_assign(lv, :todo_items) == [
               %{id: "todo-1", title: "Write tests", status: "in_progress", position: 0}
             ]
    end

    test "ignores {:todo_updated, other_id, items} for non-current tasks", %{
      conn: conn,
      user: user
    } do
      _task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(
        lv.pid,
        {:todo_updated, "other-task-id",
         [
           %{"id" => "todo-1", "title" => "Ignore me", "status" => "pending", "position" => 0}
         ]}
      )

      assert socket_assign(lv, :todo_items) == []
    end

    test "restores persisted todo_items on mount", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "completed", container_id: "c1"})

      put_todo_items!(task, %{
        "items" => [
          %{"id" => "todo-1", "title" => "Persisted", "status" => "completed", "position" => 0}
        ]
      })

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      assert socket_assign(lv, :todo_items) == [
               %{id: "todo-1", title: "Persisted", status: "completed", position: 0}
             ]
    end

    test "restores todo_items when selecting a different session", %{conn: conn, user: user} do
      task_with_todos = task_fixture(%{user_id: user.id, status: "completed", container_id: "c1"})

      put_todo_items!(task_with_todos, %{
        "items" => [
          %{"id" => "todo-1", "title" => "From c1", "status" => "pending", "position" => 0}
        ]
      })

      _latest = task_fixture(%{user_id: user.id, status: "completed", container_id: "c2"})

      {:ok, lv, _html} = live(conn, ~p"/sessions")

      lv
      |> element(~s([phx-click="select_session"][phx-value-container-id="c2"]))
      |> render_click()

      assert socket_assign(lv, :todo_items) == []

      lv
      |> element(~s([phx-click="select_session"][phx-value-container-id="c1"]))
      |> render_click()

      assert socket_assign(lv, :todo_items) == [
               %{id: "todo-1", title: "From c1", status: "pending", position: 0}
             ]
    end

    test "preserves :todo_items when task transitions to completed", %{conn: conn, user: user} do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(
        lv.pid,
        {:todo_updated, task.id,
         [
           %{
             "id" => "todo-1",
             "title" => "Still visible",
             "status" => "in_progress",
             "position" => 0
           }
         ]}
      )

      Repo.get!(TaskSchema, task.id)
      |> TaskSchema.status_changeset(%{status: "completed"})
      |> Repo.update!()

      send(lv.pid, {:task_status_changed, task.id, "completed"})

      assert socket_assign(lv, :todo_items) == [
               %{id: "todo-1", title: "Still visible", status: "in_progress", position: 0}
             ]
    end
  end

  describe "progress bar integration" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "shows progress bar when todo updates arrive and places it above input", %{
      conn: conn,
      user: user
    } do
      task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      send(
        lv.pid,
        {:todo_updated, task.id,
         [
           %{"id" => "todo-1", "title" => "Step one", "status" => "completed", "position" => 0},
           %{"id" => "todo-2", "title" => "Step two", "status" => "pending", "position" => 1}
         ]}
      )

      html = render(lv)
      assert html =~ ~s(data-testid="todo-progress")
      assert html =~ ~s(data-testid="todo-progress-summary")

      {progress_index, _} = :binary.match(html, ~s(data-testid="todo-progress"))
      {log_index, _} = :binary.match(html, ~s(id="session-log"))
      {input_index, _} = :binary.match(html, ~s(id="session-instruction"))
      assert progress_index > log_index
      assert progress_index < input_index
    end

    test "does not render progress bar when todo_items is empty", %{conn: conn, user: user} do
      _task = task_fixture(%{user_id: user.id, status: "running", container_id: "c1"})
      {:ok, lv, _html} = live(conn, ~p"/sessions")

      html = render(lv)
      refute html =~ ~s(data-testid="todo-progress")
    end
  end

  defp socket_assign(view, key) do
    view.pid
    |> :sys.get_state()
    |> Map.fetch!(:socket)
    |> Map.fetch!(:assigns)
    |> Map.fetch!(key)
  end

  defp put_todo_items!(task, todo_items) do
    task
    |> Repo.preload([])
    |> TaskSchema.status_changeset(%{todo_items: todo_items})
    |> Repo.update!()
  end
end

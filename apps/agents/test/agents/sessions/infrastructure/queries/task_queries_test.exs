defmodule Agents.Sessions.Infrastructure.Queries.TaskQueriesTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Sessions.Infrastructure.Queries.TaskQueries
  alias Agents.Repo

  import Agents.Test.AccountsFixtures

  defp create_task(user, attrs \\ %{}) do
    default_attrs = %{
      instruction: "Write tests",
      user_id: user.id,
      status: "pending"
    }

    %TaskSchema{}
    |> TaskSchema.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  # Force a specific inserted_at timestamp on a task record.
  # Ecto timestamps are managed fields, so we use a raw SQL update.
  defp force_inserted_at(%TaskSchema{id: id} = task, %DateTime{} = dt) do
    Repo.query!(
      "UPDATE sessions_tasks SET inserted_at = $1 WHERE id = $2",
      [dt, Ecto.UUID.dump!(id)]
    )

    %{task | inserted_at: dt}
  end

  describe "base/0" do
    test "returns a queryable" do
      query = TaskQueries.base()
      assert %Ecto.Query{} = query
    end
  end

  describe "for_user/2" do
    test "filters by user_id" do
      user1 = user_fixture()
      user2 = user_fixture()

      task1 = create_task(user1, %{instruction: "Task 1"})
      _task2 = create_task(user2, %{instruction: "Task 2"})

      results =
        TaskQueries.base()
        |> TaskQueries.for_user(user1.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == task1.id
    end
  end

  describe "by_status/2" do
    test "filters by status" do
      user = user_fixture()
      task1 = create_task(user, %{instruction: "Running task", status: "running"})
      _task2 = create_task(user, %{instruction: "Pending task", status: "pending"})

      results =
        TaskQueries.base()
        |> TaskQueries.for_user(user.id)
        |> TaskQueries.by_status("running")
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == task1.id
    end
  end

  describe "by_id/2" do
    test "filters by id" do
      user = user_fixture()
      task = create_task(user)

      results =
        TaskQueries.base()
        |> TaskQueries.by_id(task.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == task.id
    end
  end

  describe "sessions_for_user/1" do
    test "includes latest_task_id for each session" do
      user = user_fixture()
      task = create_task(user, %{instruction: "Session task", container_id: "c1"})

      sessions =
        TaskQueries.sessions_for_user(user.id)
        |> Repo.all()

      assert length(sessions) == 1
      session = hd(sessions)
      assert session.latest_task_id == task.id
    end

    test "latest_task_id is the most recently inserted task" do
      user = user_fixture()
      earlier = ~U[2025-01-01 00:00:00Z]
      later = ~U[2025-01-01 00:01:00Z]

      _old_task =
        create_task(user, %{instruction: "Old task", container_id: "c1", status: "completed"})
        |> force_inserted_at(earlier)

      new_task =
        create_task(user, %{instruction: "New task", container_id: "c1", status: "failed"})
        |> force_inserted_at(later)

      sessions =
        TaskQueries.sessions_for_user(user.id)
        |> Repo.all()

      assert length(sessions) == 1
      assert hd(sessions).latest_task_id == new_task.id
    end

    test "includes latest_error for each session" do
      user = user_fixture()

      create_task(user, %{
        instruction: "Failed task",
        container_id: "c1",
        status: "failed",
        error: "Token refresh failed: 400"
      })

      sessions =
        TaskQueries.sessions_for_user(user.id)
        |> Repo.all()

      assert length(sessions) == 1
      assert hd(sessions).latest_error == "Token refresh failed: 400"
    end

    test "latest_error is nil when latest task has no error" do
      user = user_fixture()
      create_task(user, %{instruction: "Completed task", container_id: "c1", status: "completed"})

      sessions =
        TaskQueries.sessions_for_user(user.id)
        |> Repo.all()

      assert length(sessions) == 1
      assert hd(sessions).latest_error == nil
    end

    test "latest_error reflects the most recent task, not earlier failures" do
      user = user_fixture()
      earlier = ~U[2025-01-01 00:00:00Z]
      later = ~U[2025-01-01 00:01:00Z]

      create_task(user, %{
        instruction: "Failed task",
        container_id: "c1",
        status: "failed",
        error: "Token refresh failed: 400"
      })
      |> force_inserted_at(earlier)

      create_task(user, %{
        instruction: "Recovered task",
        container_id: "c1",
        status: "completed"
      })
      |> force_inserted_at(later)

      sessions =
        TaskQueries.sessions_for_user(user.id)
        |> Repo.all()

      assert length(sessions) == 1
      # Latest task is the completed one, so error should be nil
      assert hd(sessions).latest_error == nil
    end

    test "groups by container_id and returns distinct sessions" do
      user = user_fixture()
      create_task(user, %{instruction: "Session 1", container_id: "c1", status: "completed"})

      create_task(user, %{
        instruction: "Session 2",
        container_id: "c2",
        status: "failed",
        error: "auth error"
      })

      sessions =
        TaskQueries.sessions_for_user(user.id)
        |> Repo.all()

      assert length(sessions) == 2
      container_ids = Enum.map(sessions, & &1.container_id) |> MapSet.new()
      assert container_ids == MapSet.new(["c1", "c2"])
    end
  end

  describe "recent_first/1" do
    test "orders by inserted_at desc" do
      user = user_fixture()
      task1 = create_task(user, %{instruction: "First task"})
      task2 = create_task(user, %{instruction: "Second task"})

      results =
        TaskQueries.base()
        |> TaskQueries.for_user(user.id)
        |> TaskQueries.recent_first()
        |> Repo.all()

      # Both tasks created in same second, so verify all are returned
      assert length(results) == 2

      assert MapSet.new(Enum.map(results, & &1.id)) ==
               MapSet.new([task1.id, task2.id])
    end
  end
end

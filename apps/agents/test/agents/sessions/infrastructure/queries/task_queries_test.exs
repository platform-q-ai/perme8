defmodule Agents.Sessions.Infrastructure.Queries.TaskQueriesTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Sessions.Infrastructure.Queries.TaskQueries
  alias Identity.Repo, as: Repo

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

  describe "recent_first/1" do
    test "orders by inserted_at desc" do
      user = user_fixture()
      task1 = create_task(user, %{instruction: "First task"})

      # Small delay to ensure different timestamps
      Process.sleep(10)
      task2 = create_task(user, %{instruction: "Second task"})

      results =
        TaskQueries.base()
        |> TaskQueries.for_user(user.id)
        |> TaskQueries.recent_first()
        |> Repo.all()

      assert [first, second] = results
      assert first.id == task2.id
      assert second.id == task1.id
    end
  end

  describe "running_count_for_user/1" do
    test "counts tasks with active statuses" do
      user = user_fixture()
      create_task(user, %{instruction: "Pending", status: "pending"})
      create_task(user, %{instruction: "Starting", status: "starting"})
      create_task(user, %{instruction: "Running", status: "running"})
      create_task(user, %{instruction: "Completed", status: "completed"})
      create_task(user, %{instruction: "Failed", status: "failed"})

      count =
        TaskQueries.running_count_for_user(user.id)
        |> Repo.one()

      assert count == 3
    end

    test "returns 0 when no active tasks" do
      user = user_fixture()
      create_task(user, %{instruction: "Done", status: "completed"})

      count =
        TaskQueries.running_count_for_user(user.id)
        |> Repo.one()

      assert count == 0
    end
  end
end

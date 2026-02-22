defmodule Agents.Sessions.Application.UseCases.DeleteTaskTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Sessions.Application.UseCases.DeleteTask
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  setup :verify_on_exit!

  @default_opts [
    task_repo: Agents.Mocks.TaskRepositoryMock,
    container_provider: Agents.Mocks.ContainerProviderMock
  ]

  describe "execute/3" do
    test "removes container and deletes a completed task" do
      task =
        struct(TaskSchema, %{
          id: "task-1",
          user_id: "user-1",
          status: "completed",
          container_id: "container-abc"
        })

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)
      |> expect(:delete_task, fn ^task -> {:ok, task} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "container-abc" -> :ok end)

      assert :ok = DeleteTask.execute("task-1", "user-1", @default_opts)
    end

    test "deletes a failed task and removes container" do
      task =
        struct(TaskSchema, %{
          id: "task-1",
          user_id: "user-1",
          status: "failed",
          container_id: "container-def"
        })

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)
      |> expect(:delete_task, fn ^task -> {:ok, task} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "container-def" -> :ok end)

      assert :ok = DeleteTask.execute("task-1", "user-1", @default_opts)
    end

    test "deletes a cancelled task and removes container" do
      task =
        struct(TaskSchema, %{
          id: "task-1",
          user_id: "user-1",
          status: "cancelled",
          container_id: "container-ghi"
        })

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)
      |> expect(:delete_task, fn ^task -> {:ok, task} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "container-ghi" -> :ok end)

      assert :ok = DeleteTask.execute("task-1", "user-1", @default_opts)
    end

    test "succeeds even when container is already gone" do
      task =
        struct(TaskSchema, %{
          id: "task-1",
          user_id: "user-1",
          status: "completed",
          container_id: "container-gone"
        })

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)
      |> expect(:delete_task, fn ^task -> {:ok, task} end)

      Agents.Mocks.ContainerProviderMock
      |> expect(:remove, fn "container-gone" -> {:error, :not_found} end)

      assert :ok = DeleteTask.execute("task-1", "user-1", @default_opts)
    end

    test "handles task with no container_id" do
      task =
        struct(TaskSchema, %{
          id: "task-1",
          user_id: "user-1",
          status: "failed",
          container_id: nil
        })

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)
      |> expect(:delete_task, fn ^task -> {:ok, task} end)

      # No container_provider call expected when container_id is nil

      assert :ok = DeleteTask.execute("task-1", "user-1", @default_opts)
    end

    test "returns error when task not found" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> nil end)

      assert {:error, :not_found} = DeleteTask.execute("task-1", "user-1", @default_opts)
    end

    test "returns error when task is still running" do
      task = struct(TaskSchema, %{id: "task-1", user_id: "user-1", status: "running"})

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)

      assert {:error, :not_deletable} = DeleteTask.execute("task-1", "user-1", @default_opts)
    end

    test "returns error when task is pending" do
      task = struct(TaskSchema, %{id: "task-1", user_id: "user-1", status: "pending"})

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> task end)

      assert {:error, :not_deletable} = DeleteTask.execute("task-1", "user-1", @default_opts)
    end
  end
end

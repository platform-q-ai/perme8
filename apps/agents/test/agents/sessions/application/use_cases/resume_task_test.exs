defmodule Agents.Sessions.Application.UseCases.ResumeTaskTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Sessions.Application.UseCases.ResumeTask
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  setup :verify_on_exit!

  @parent_task struct(TaskSchema, %{
                 id: "parent-1",
                 user_id: "user-1",
                 status: "completed",
                 container_id: "container-abc",
                 session_id: "session-xyz",
                 instruction: "original instruction"
               })

  @default_opts [
    task_repo: Agents.Mocks.TaskRepositoryMock,
    task_runner_starter: nil
  ]

  describe "execute/3" do
    test "creates a follow-up task linked to the parent" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "parent-1", "user-1" -> @parent_task end)
      |> expect(:running_task_count_for_user, fn "user-1" -> 0 end)
      |> expect(:create_task, fn attrs ->
        assert attrs.parent_task_id == "parent-1"
        assert attrs.container_id == "container-abc"
        assert attrs.session_id == "session-xyz"
        assert attrs.instruction == "Fix the tests"
        assert attrs.user_id == "user-1"

        {:ok,
         struct(TaskSchema, %{
           id: "new-task-1",
           instruction: attrs.instruction,
           user_id: attrs.user_id,
           parent_task_id: attrs.parent_task_id,
           container_id: attrs.container_id,
           session_id: attrs.session_id,
           status: "pending"
         })}
      end)

      assert {:ok, task} =
               ResumeTask.execute(
                 "parent-1",
                 %{instruction: "Fix the tests", user_id: "user-1"},
                 @default_opts
               )

      assert task.parent_task_id == "parent-1"
      assert task.container_id == "container-abc"
      assert task.session_id == "session-xyz"
    end

    test "starts a TaskRunner with resume context" do
      test_pid = self()

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "parent-1", "user-1" -> @parent_task end)
      |> expect(:running_task_count_for_user, fn "user-1" -> 0 end)
      |> expect(:create_task, fn attrs ->
        {:ok, struct(TaskSchema, Map.merge(%{id: "new-task-2", status: "pending"}, attrs))}
      end)

      starter = fn task_id, opts ->
        send(test_pid, {:runner_started, task_id, opts})
        {:ok, :fake_pid}
      end

      opts = Keyword.put(@default_opts, :task_runner_starter, starter)

      assert {:ok, _task} =
               ResumeTask.execute(
                 "parent-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 opts
               )

      assert_receive {:runner_started, "new-task-2", runner_opts}
      assert runner_opts[:resume] == true
      assert runner_opts[:container_id] == "container-abc"
      assert runner_opts[:session_id] == "session-xyz"
    end

    test "returns error when instruction is blank" do
      assert {:error, :instruction_required} =
               ResumeTask.execute(
                 "parent-1",
                 %{instruction: "", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when parent task not found" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "parent-1", "user-1" -> nil end)

      assert {:error, :not_found} =
               ResumeTask.execute(
                 "parent-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when parent task is still running" do
      running_parent = struct(@parent_task, status: "running")

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "parent-1", "user-1" -> running_parent end)

      assert {:error, :not_resumable} =
               ResumeTask.execute(
                 "parent-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when parent has no container" do
      no_container = struct(@parent_task, container_id: nil)

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "parent-1", "user-1" -> no_container end)

      assert {:error, :no_container} =
               ResumeTask.execute(
                 "parent-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when parent has no session" do
      no_session = struct(@parent_task, session_id: nil)

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "parent-1", "user-1" -> no_session end)

      assert {:error, :no_session} =
               ResumeTask.execute(
                 "parent-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when concurrent limit reached" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "parent-1", "user-1" -> @parent_task end)
      |> expect(:running_task_count_for_user, fn "user-1" -> 1 end)

      assert {:error, :concurrent_limit_reached} =
               ResumeTask.execute(
                 "parent-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end
  end
end

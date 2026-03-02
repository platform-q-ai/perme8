defmodule Agents.Sessions.Application.UseCases.ResumeTaskTest do
  use Agents.DataCase, async: true

  import Mox

  alias Agents.Sessions.Application.UseCases.ResumeTask
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  setup :verify_on_exit!

  @existing_task struct(TaskSchema, %{
                   id: "task-1",
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
    test "preserves original instruction and resets status for resume" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> @existing_task end)
      |> expect(:update_task_status, fn task, attrs ->
        assert task.id == "task-1"
        refute Map.has_key?(attrs, :instruction)
        assert attrs.status == "pending"
        assert attrs.error == nil
        assert attrs.pending_question == nil
        assert attrs.started_at == nil
        assert attrs.completed_at == nil

        {:ok, struct(task, attrs)}
      end)

      assert {:ok, task} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "Fix the tests", user_id: "user-1"},
                 @default_opts
               )

      assert task.id == "task-1"
      assert task.instruction == "original instruction"
      assert task.status == "pending"
      assert task.container_id == "container-abc"
      assert task.session_id == "session-xyz"
    end

    test "starts a TaskRunner with resume context" do
      test_pid = self()

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> @existing_task end)
      |> expect(:update_task_status, fn task, attrs ->
        {:ok, struct(task, attrs)}
      end)

      starter = fn task_id, opts ->
        send(test_pid, {:runner_started, task_id, opts})
        {:ok, :fake_pid}
      end

      opts = Keyword.put(@default_opts, :task_runner_starter, starter)

      assert {:ok, _task} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 opts
               )

      assert_receive {:runner_started, "task-1", runner_opts}
      assert runner_opts[:resume] == true
      assert runner_opts[:instruction] == "original instruction"
      assert runner_opts[:prompt_instruction] == "Follow up"
      assert runner_opts[:container_id] == "container-abc"
      assert runner_opts[:session_id] == "session-xyz"
    end

    test "returns error when instruction is blank" do
      assert {:error, :instruction_required} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when task not found" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> nil end)

      assert {:error, :not_found} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when task is still running" do
      running_task = struct(@existing_task, status: "running")

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> running_task end)

      assert {:error, :already_active} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when task is pending (double-click guard)" do
      pending_task = struct(@existing_task, status: "pending")

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> pending_task end)

      assert {:error, :already_active} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when task has no container" do
      no_container = struct(@existing_task, container_id: nil)

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> no_container end)

      assert {:error, :no_container} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end

    test "returns error when task has no session" do
      no_session = struct(@existing_task, session_id: nil)

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> no_session end)

      assert {:error, :no_session} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )
    end
  end
end

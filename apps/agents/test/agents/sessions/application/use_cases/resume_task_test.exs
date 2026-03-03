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
    task_repo: Agents.Mocks.TaskRepositoryMock
  ]

  describe "execute/3" do
    test "preserves original instruction and requeues for resume" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> @existing_task end)
      |> expect(:get_max_queue_position, fn "user-1" -> 2 end)
      |> expect(:update_task_status, fn task, attrs ->
        assert task.id == "task-1"
        refute Map.has_key?(attrs, :instruction)
        assert attrs.status == "queued"
        assert attrs.queue_position == 3
        assert %{"resume_prompt" => "Fix the tests"} = attrs.pending_question
        assert attrs.error == nil
        assert attrs.started_at == nil
        assert attrs.completed_at == nil
        assert attrs.session_summary == nil

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
      assert task.status == "queued"
      assert task.container_id == "container-abc"
      assert task.session_id == "session-xyz"
    end

    test "queues resume with next queue position" do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "task-1", "user-1" -> @existing_task end)
      |> expect(:get_max_queue_position, fn "user-1" -> 2 end)
      |> expect(:update_task_status, fn task, attrs ->
        assert task.id == "task-1"
        assert attrs.status == "queued"
        assert attrs.queue_position == 3
        assert %{"resume_prompt" => "Follow up"} = attrs.pending_question
        assert attrs.error == nil
        {:ok, struct(task, attrs)}
      end)

      assert {:ok, task} =
               ResumeTask.execute(
                 "task-1",
                 %{instruction: "Follow up", user_id: "user-1"},
                 @default_opts
               )

      assert task.status == "queued"
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

defmodule Agents.Sessions.Application.UseCases.ResumeTask do
  @moduledoc """
  Use case for resuming a session with a follow-up instruction.

  Reuses the existing task record and moves it back to "queued".
  The original instruction is preserved as the session title/context.
  Queue orchestration owns promotion and TaskRunner startup.

  This preserves todos, output history, and the task identity across
  the entire session lifetime.
  """

  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Sessions.Domain.Policies.QueuePolicy

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @doc """
  Resumes a session by updating the existing task with a new instruction.

  ## Parameters
  - `task_id` - ID of the completed/failed/cancelled task to resume
  - `attrs` - Map with:
    - `:instruction` - (required) The follow-up instruction
    - `:user_id` - (required) The user resuming the task
  - `opts` - Keyword list with:
    - `:task_repo` - Repository module

  ## Returns
  - `{:ok, task}` - Domain entity on success
  - `{:error, :instruction_required}` - When instruction is blank
  - `{:error, :not_found}` - Task not found or not owned by user
   - `{:error, :already_active}` - Task is already pending/starting/running/queued
  - `{:error, :not_resumable}` - Task is not in a terminal state
  - `{:error, :no_container}` - Task has no container to resume
  - `{:error, :no_session}` - Task has no opencode session to resume
  """
  @spec execute(String.t(), map(), keyword()) ::
          {:ok, Agents.Sessions.Domain.Entities.Task.t()} | {:error, term()}
  def execute(task_id, attrs, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    concurrency_lock = Keyword.get(opts, :concurrency_lock, &no_concurrency_lock/2)

    with :ok <- validate_instruction(attrs),
         {:ok, task} <- find_task(task_id, attrs.user_id, task_repo),
         :ok <- validate_resumable(task) do
      concurrency_lock.(attrs.user_id, fn ->
        queue_task_for_resume(task, attrs, task_repo)
      end)
    end
  end

  defp queue_task_for_resume(task, attrs, task_repo) do
    queue_position =
      QueuePolicy.next_queue_position(task_repo.get_max_queue_position(task.user_id))

    case task_repo.update_task_status(task, %{
           status: "queued",
           error: nil,
           pending_question: %{"resume_prompt" => attrs.instruction},
           queue_position: queue_position,
           queued_at: DateTime.utc_now(),
           started_at: nil,
           completed_at: nil,
           session_summary: nil
         }) do
      {:ok, schema} -> {:ok, Task.from_schema(schema)}
      error -> error
    end
  end

  defp validate_instruction(%{instruction: instruction})
       when is_binary(instruction) and instruction != "" do
    :ok
  end

  defp validate_instruction(_), do: {:error, :instruction_required}

  defp find_task(task_id, user_id, task_repo) do
    case task_repo.get_task_for_user(task_id, user_id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  defp validate_resumable(task) do
    cond do
      task.status in ["pending", "starting", "running"] ->
        {:error, :already_active}

      task.status not in ["completed", "failed", "cancelled"] ->
        {:error, :not_resumable}

      is_nil(task.container_id) ->
        {:error, :no_container}

      is_nil(task.session_id) ->
        {:error, :no_session}

      true ->
        :ok
    end
  end

  defp no_concurrency_lock(_user_id, fun), do: fun.()
end

defmodule Agents.Sessions.Application.UseCases.ResumeTask do
  @moduledoc """
  Use case for resuming a session with a follow-up instruction.

  Reuses the existing task record — updates its instruction and resets
  its status to "pending". The TaskRunner restarts the stopped container
  and sends the new prompt to the existing opencode session.

  This preserves todos, output history, and the task identity across
  the entire session lifetime.
  """

  alias Agents.Sessions.Domain.Entities.Task

  require Logger

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
    - `:task_runner_starter` - Function to start a TaskRunner

  ## Returns
  - `{:ok, task}` - Domain entity on success
  - `{:error, :instruction_required}` - When instruction is blank
  - `{:error, :not_found}` - Task not found or not owned by user
  - `{:error, :already_active}` - Task is already pending/starting/running (e.g. double-click)
  - `{:error, :not_resumable}` - Task is not in a terminal state
  - `{:error, :no_container}` - Task has no container to resume
  - `{:error, :no_session}` - Task has no opencode session to resume
  """
  @spec execute(String.t(), map(), keyword()) ::
          {:ok, Agents.Sessions.Domain.Entities.Task.t()} | {:error, term()}
  def execute(task_id, attrs, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)

    with :ok <- validate_instruction(attrs),
         {:ok, task} <- find_task(task_id, attrs.user_id, task_repo),
         :ok <- validate_resumable(task),
         {:ok, updated_schema} <- reset_task_for_resume(task, attrs, task_repo),
         :ok <- start_runner(updated_schema.id, task, task_repo, opts) do
      {:ok, Task.from_schema(updated_schema)}
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

  defp reset_task_for_resume(task, attrs, task_repo) do
    task_repo.update_task_status(task, %{
      instruction: attrs.instruction,
      status: "pending",
      error: nil,
      pending_question: nil,
      started_at: nil,
      completed_at: nil,
      session_summary: nil
    })
  end

  defp start_runner(task_id, task, task_repo, opts) do
    case Keyword.get(opts, :task_runner_starter) do
      nil ->
        :ok

      starter ->
        # Stop any lingering TaskRunner from a previous run. This can happen
        # when a completed/failed runner hasn't fully terminated before the
        # user triggers a resume (race window on process shutdown).
        stop_existing_runner(task_id)

        # Pass resume context so the TaskRunner knows to restart instead of create
        runner_opts =
          Keyword.merge(opts,
            resume: true,
            container_id: task.container_id,
            session_id: task.session_id
          )

        case starter.(task_id, runner_opts) do
          {:ok, _pid} ->
            :ok

          {:error, reason} ->
            Logger.error(
              "ResumeTask: failed to start runner for task #{task_id}: #{inspect(reason)}"
            )

            mark_task_failed(task_id, task_repo, "Runner failed to start: #{inspect(reason)}")
            {:error, :runner_start_failed}
        end
    end
  end

  defp stop_existing_runner(task_id) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] ->
        Logger.info("ResumeTask: stopping lingering runner #{inspect(pid)} for task #{task_id}")
        GenServer.stop(pid, :normal, 5_000)

      [] ->
        :ok
    end
  rescue
    # Process may have already exited between lookup and stop
    _ -> :ok
  end

  defp mark_task_failed(task_id, task_repo, error) do
    case task_repo.get_task(task_id) do
      nil -> :ok
      task -> task_repo.update_task_status(task, %{status: "failed", error: error})
    end
  end
end

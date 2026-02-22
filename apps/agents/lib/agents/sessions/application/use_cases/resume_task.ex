defmodule Agents.Sessions.Application.UseCases.ResumeTask do
  @moduledoc """
  Use case for resuming a session with a follow-up instruction.

  Creates a new task linked to the parent task via `parent_task_id`,
  inheriting the container and opencode session. The TaskRunner restarts
  the stopped container and sends the new prompt to the existing session.
  """

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Domain.Entities.Task

  require Logger

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @doc """
  Resumes a session by creating a follow-up task.

  ## Parameters
  - `parent_task_id` - ID of the completed task to resume from
  - `attrs` - Map with:
    - `:instruction` - (required) The follow-up instruction
    - `:user_id` - (required) The user creating the task
  - `opts` - Keyword list with:
    - `:task_repo` - Repository module
    - `:task_runner_starter` - Function to start a TaskRunner

  ## Returns
  - `{:ok, task}` - Domain entity on success
  - `{:error, :instruction_required}` - When instruction is blank
  - `{:error, :not_found}` - Parent task not found or not owned by user
  - `{:error, :not_resumable}` - Parent task is not in a terminal state
  - `{:error, :no_container}` - Parent task has no container to resume
  - `{:error, :concurrent_limit_reached}` - User already has an active task
  """
  def execute(parent_task_id, attrs, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)

    with :ok <- validate_instruction(attrs),
         {:ok, parent} <- find_parent(parent_task_id, attrs.user_id, task_repo),
         :ok <- validate_resumable(parent),
         :ok <- check_concurrent_limit(attrs.user_id, task_repo),
         {:ok, schema} <- create_resume_task(parent, attrs, task_repo),
         :ok <- start_runner(schema.id, parent, task_repo, opts) do
      {:ok, Task.from_schema(schema)}
    end
  end

  defp validate_instruction(%{instruction: instruction})
       when is_binary(instruction) and instruction != "" do
    :ok
  end

  defp validate_instruction(_), do: {:error, :instruction_required}

  defp find_parent(parent_task_id, user_id, task_repo) do
    case task_repo.get_task_for_user(parent_task_id, user_id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  defp validate_resumable(parent) do
    cond do
      parent.status not in ["completed", "failed", "cancelled"] ->
        {:error, :not_resumable}

      is_nil(parent.container_id) ->
        {:error, :no_container}

      is_nil(parent.session_id) ->
        {:error, :no_container}

      true ->
        :ok
    end
  end

  defp check_concurrent_limit(user_id, task_repo) do
    count = task_repo.running_task_count_for_user(user_id)
    max = SessionsConfig.max_concurrent_tasks()

    if count < max, do: :ok, else: {:error, :concurrent_limit_reached}
  end

  defp create_resume_task(parent, attrs, task_repo) do
    task_repo.create_task(%{
      instruction: attrs.instruction,
      user_id: attrs.user_id,
      parent_task_id: parent.id,
      container_id: parent.container_id,
      session_id: parent.session_id
    })
  end

  defp start_runner(task_id, parent, task_repo, opts) do
    case Keyword.get(opts, :task_runner_starter) do
      nil ->
        :ok

      starter ->
        # Pass resume context so the TaskRunner knows to restart instead of create
        runner_opts =
          Keyword.merge(opts,
            resume: true,
            container_id: parent.container_id,
            session_id: parent.session_id
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

  defp mark_task_failed(task_id, task_repo, error) do
    case task_repo.get_task(task_id) do
      nil -> :ok
      task -> task_repo.update_task_status(task, %{status: "failed", error: error})
    end
  end
end

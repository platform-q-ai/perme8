defmodule Agents.Sessions.Application.UseCases.CancelTask do
  @moduledoc """
  Use case for cancelling a running coding task.

  Validates ownership and cancellability, then sends a cancel
  message to the TaskRunner GenServer.
  """

  alias Agents.Sessions.Domain.Policies.TaskPolicy

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @doc """
  Cancels a running task.

  ## Parameters
  - `task_id` - ID of the task to cancel
  - `user_id` - ID of the user requesting cancellation
  - `opts` - Keyword list with `:task_repo`

  ## Returns
  - `:ok` - Cancel message sent
  - `{:error, :not_found}` - Task not found or not owned by user
  - `{:error, :not_cancellable}` - Task in a terminal state
  """
  def execute(task_id, user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    cancel_fn = Keyword.get(opts, :task_runner_cancel, &default_cancel/1)

    with {:ok, task} <- find_task(task_id, user_id, task_repo),
         :ok <- validate_cancellable(task) do
      cancel_fn.(task_id)
    end
  end

  defp find_task(task_id, user_id, task_repo) do
    case task_repo.get_task_for_user(task_id, user_id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  defp validate_cancellable(task) do
    if TaskPolicy.can_cancel?(task.status) do
      :ok
    else
      {:error, :not_cancellable}
    end
  end

  defp default_cancel(task_id) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] ->
        send(pid, :cancel)
        :ok

      [] ->
        # Runner already stopped — still return :ok since the intent was cancel
        :ok
    end
  end
end

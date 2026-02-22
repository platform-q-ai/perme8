defmodule Agents.Sessions.Application.UseCases.DeleteTask do
  @moduledoc """
  Use case for deleting a completed, failed, or cancelled task.

  Validates ownership and deletability, removes the Docker container
  (permanent destruction), then deletes the database record.
  """

  alias Agents.Sessions.Domain.Policies.TaskPolicy

  require Logger

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_container_provider Agents.Sessions.Infrastructure.Adapters.DockerAdapter

  @doc """
  Deletes a task and its associated container.

  ## Parameters
  - `task_id` - ID of the task to delete
  - `user_id` - ID of the user requesting deletion
  - `opts` - Keyword list with `:task_repo`, `:container_provider`

  ## Returns
  - `:ok` - Container removed and task deleted
  - `{:error, :not_found}` - Task not found or not owned by user
  - `{:error, :not_deletable}` - Task is still active
  """
  def execute(task_id, user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    container_provider = Keyword.get(opts, :container_provider, @default_container_provider)

    with {:ok, task} <- find_task(task_id, user_id, task_repo),
         :ok <- validate_deletable(task) do
      # Remove the Docker container (permanent destruction)
      remove_container(task.container_id, container_provider)

      case task_repo.delete_task(task) do
        {:ok, _task} -> :ok
        {:error, _changeset} -> {:error, :delete_failed}
      end
    end
  end

  defp find_task(task_id, user_id, task_repo) do
    case task_repo.get_task_for_user(task_id, user_id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  defp validate_deletable(task) do
    if TaskPolicy.can_delete?(task.status) do
      :ok
    else
      {:error, :not_deletable}
    end
  end

  defp remove_container(nil, _container_provider), do: :ok

  defp remove_container(container_id, container_provider) do
    case container_provider.remove(container_id) do
      :ok ->
        :ok

      {:error, reason} ->
        # Container may already be gone — log but don't fail the delete
        Logger.warning(
          "DeleteTask: failed to remove container #{container_id}: #{inspect(reason)}"
        )

        :ok
    end
  end
end

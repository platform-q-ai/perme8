defmodule Agents.Sessions.Application.UseCases.DeleteTask do
  @moduledoc """
  Use case for deleting a completed, failed, or cancelled task.

  Validates ownership and deletability, then deletes the database record.
  Does NOT remove the Docker container — use `DeleteSession` for that.
  """

  alias Agents.Sessions.Domain.Policies.TaskPolicy

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

  def execute(task_id, user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)

    with {:ok, task} <- find_task(task_id, user_id, task_repo),
         :ok <- validate_deletable(task) do
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
end

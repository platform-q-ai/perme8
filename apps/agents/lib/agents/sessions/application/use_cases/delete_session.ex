defmodule Agents.Sessions.Application.UseCases.DeleteSession do
  @moduledoc """
  Use case for deleting an entire session (container + all tasks).

  Sessions are identified by container_id. Deleting a session:
  1. Validates the user owns at least one task with this container_id
  2. Cancels any running TaskRunner for tasks in this session
  3. Removes the Docker container (permanent destruction)
  4. Deletes all task records sharing this container_id
  """

  require Logger

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_container_provider Agents.Sessions.Infrastructure.Adapters.DockerAdapter

  def execute(container_id, user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    container_provider = Keyword.get(opts, :container_provider, @default_container_provider)
    cancel_fn = Keyword.get(opts, :task_runner_cancel, &default_cancel/1)

    tasks = task_repo.list_tasks_for_container(container_id, user_id)

    if tasks == [] do
      {:error, :not_found}
    else
      # Cancel any running task runners
      Enum.each(tasks, fn task ->
        if task.status in ["pending", "starting", "running"] do
          cancel_fn.(task.id)
        end
      end)

      # Remove the Docker container
      remove_container(container_id, container_provider)

      # Delete all tasks in this session
      task_repo.delete_tasks_for_container(container_id, user_id)

      :ok
    end
  end

  defp remove_container(container_id, container_provider) do
    case container_provider.remove(container_id) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "DeleteSession: failed to remove container #{container_id}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp default_cancel(task_id) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] ->
        send(pid, :cancel)
        :ok

      [] ->
        :ok
    end
  end
end

defmodule Agents.Sessions.Application.UseCases.DeleteSession do
  @moduledoc """
  Use case for deleting an entire session (container + all tasks).

  Sessions are identified by container_id. Deleting a session:
  1. Validates the user owns at least one task with this container_id
  2. Cancels any active TaskRunner processes and waits for them to exit
  3. Removes the Docker container (permanent destruction)
  4. Deletes all task records sharing this container_id

  If container removal fails, the database records are preserved so the
  session remains visible and the user can retry deletion.
  """

  require Logger

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @active_statuses ["pending", "starting", "running", "awaiting_feedback"]

  @cancel_timeout_ms 5_000

  @spec execute(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def execute(container_id, user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)

    default_provider =
      Application.get_env(
        :agents,
        :container_provider,
        Agents.Sessions.Infrastructure.Adapters.DockerAdapter
      )

    container_provider = Keyword.get(opts, :container_provider, default_provider)
    cancel_fn = Keyword.get(opts, :task_runner_cancel, &default_cancel/1)

    tasks = task_repo.list_tasks_for_container(container_id, user_id)

    if tasks == [] do
      {:error, :not_found}
    else
      # Cancel any active task runners and wait for them to exit before
      # removing the container. This prevents a race where the TaskRunner's
      # cleanup_container (docker stop) collides with our docker rm -f.
      cancel_active_task_runners(tasks, cancel_fn)

      # Remove the Docker container. If this fails, keep the DB records so
      # the session stays visible and the user can retry.
      case remove_container(container_id, container_provider) do
        :ok ->
          task_repo.delete_tasks_for_container(container_id, user_id)
          :ok

        {:error, reason} ->
          {:error, {:container_remove_failed, reason}}
      end
    end
  end

  defp cancel_active_task_runners(tasks, cancel_fn) do
    tasks
    |> Enum.filter(&(&1.status in @active_statuses))
    |> Enum.each(fn task -> cancel_fn.(task.id) end)
  end

  defp remove_container(container_id, container_provider) do
    case container_provider.remove(container_id) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "DeleteSession: failed to remove container #{container_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp default_cancel(task_id) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] ->
        ref = Process.monitor(pid)
        send(pid, :cancel)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          @cancel_timeout_ms ->
            Process.demonitor(ref, [:flush])

            Logger.warning(
              "DeleteSession: TaskRunner for task #{task_id} did not exit within #{@cancel_timeout_ms}ms"
            )

            :ok
        end

      [] ->
        :ok
    end
  end
end

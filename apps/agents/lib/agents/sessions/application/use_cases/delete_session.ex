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
  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository
  @default_container_provider Agents.Sessions.Infrastructure.Adapters.DockerAdapter

  @active_statuses ["pending", "starting", "running", "awaiting_feedback"]

  @cancel_timeout_ms 5_000

  @doc """
  Deletes a session by container_id (legacy) or session_id (new).

  Accepts either:
  - `execute(container_id, user_id, opts)` -- legacy path via container_id
  - `execute(container_id, user_id, opts)` with `:session_id` in opts -- new path

  When `:session_id` is provided in opts, the session record is also deleted
  after tasks and container are cleaned up.
  """
  @spec execute(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def execute(container_id, user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    container_provider = Keyword.get(opts, :container_provider, @default_container_provider)
    cancel_fn = Keyword.get(opts, :task_runner_cancel, &default_cancel/1)
    session_id = Keyword.get(opts, :session_id)

    tasks = task_repo.list_tasks_for_container(container_id, user_id)

    if tasks == [] and is_nil(session_id) do
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
          maybe_delete_session(session_id, session_repo)
          :ok

        {:error, reason} ->
          {:error, {:container_remove_failed, reason}}
      end
    end
  end

  defp maybe_delete_session(nil, _session_repo), do: :ok

  defp maybe_delete_session(session_id, session_repo) do
    case session_repo.get_session(session_id) do
      nil ->
        :ok

      session ->
        case session_repo.delete_session(session) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "DeleteSession: failed to delete session record #{session_id}: #{inspect(reason)}"
            )

            :ok
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

defmodule Agents.Sessions.Infrastructure.OrphanRecovery do
  @moduledoc """
  Recovers tasks orphaned by a server restart.

  When the BEAM VM restarts, TaskRunner GenServer processes are lost but their
  associated Docker containers and database records remain in active states
  (`pending`, `starting`, `running`). This module detects those orphaned tasks
  on startup, marks them as failed, and stops their containers.

  Designed to run once during application boot as a `Task` child in the
  supervision tree, after the Repo is started but before other session
  infrastructure (TaskRunnerSupervisor, QueueManagerSupervisor).
  """

  require Logger

  import Ecto.Query, warn: false

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Adapters.DockerAdapter
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  @active_statuses ["pending", "starting", "running"]

  @doc """
  Finds and recovers all tasks stuck in active states.

  Options:
    - `:container_provider` — module implementing `stop/2` (default: `DockerAdapter`)

  Returns `{:ok, count}` where count is the number of recovered tasks.
  """
  @spec recover_orphaned_tasks(keyword()) :: {:ok, non_neg_integer()}
  def recover_orphaned_tasks(opts \\ []) do
    container_provider = Keyword.get(opts, :container_provider, DockerAdapter)

    orphans =
      from(t in TaskSchema, where: t.status in ^@active_statuses)
      |> Repo.all()

    if orphans != [] do
      Logger.warning(
        "OrphanRecovery: found #{length(orphans)} orphaned task(s) from previous server instance"
      )
    end

    Enum.each(orphans, fn task ->
      recover_task(task, container_provider)
    end)

    {:ok, length(orphans)}
  end

  defp recover_task(task, container_provider) do
    # Stop the container if one was assigned
    if task.container_id do
      case container_provider.stop(task.container_id) do
        :ok ->
          Logger.info(
            "OrphanRecovery: stopped container #{task.container_id} for task #{task.id}"
          )

        {:error, reason} ->
          Logger.warning(
            "OrphanRecovery: failed to stop container #{task.container_id} for task #{task.id}: #{inspect(reason)}"
          )
      end
    end

    # Mark the task as failed
    task
    |> TaskSchema.status_changeset(%{
      status: "failed",
      error: "Orphaned by server restart — no TaskRunner process was active for this task",
      completed_at: DateTime.utc_now()
    })
    |> Repo.update!()

    Logger.info("OrphanRecovery: marked task #{task.id} as failed (was #{task.status})")
  end
end

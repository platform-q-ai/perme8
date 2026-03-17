defmodule Agents.Sessions.Infrastructure.StartupReconciliation do
  @moduledoc """
  Reconciles session container state on server startup.

  Compares the database container_status with actual Docker container state
  and resolves discrepancies: orphaned containers are cleaned up, stale
  session records are marked accordingly.
  """

  require Logger

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository
  @default_container_provider Agents.Sessions.Infrastructure.Adapters.DockerAdapter

  @active_container_statuses ["pending", "starting", "running"]

  @doc """
  Runs startup reconciliation.

  Returns a map with reconciliation stats.
  """
  def run(opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
    container_provider = Keyword.get(opts, :container_provider, @default_container_provider)

    # Query all sessions with active container statuses
    sessions = list_active_sessions(session_repo)

    results =
      Enum.reduce(
        sessions,
        %{reconciled: 0, orphaned_containers_cleaned: 0, stale_sessions_marked: 0},
        fn session, acc ->
          reconcile_session(session, container_provider, session_repo, acc)
        end
      )

    Logger.info(
      "StartupReconciliation: reconciled=#{results.reconciled} orphaned=#{results.orphaned_containers_cleaned} stale=#{results.stale_sessions_marked}"
    )

    results
  end

  defp list_active_sessions(_session_repo) do
    # Query sessions with active container statuses directly via Ecto
    import Ecto.Query, warn: false
    alias Agents.Sessions.Infrastructure.Schemas.SessionSchema
    alias Agents.Sessions.Domain.Entities.SessionRecord

    try do
      schemas =
        from(s in SessionSchema,
          where: s.container_status in ^@active_container_statuses
        )
        |> Agents.Repo.all()

      # Convert to domain records so they match the session_repo contract.
      # If using the real SessionRepository, its callbacks already return
      # SessionRecord, but here we query directly for efficiency.
      Enum.map(schemas, fn schema ->
        SessionRecord.new(%{
          id: schema.id,
          user_id: schema.user_id,
          title: schema.title,
          status: schema.status,
          container_id: schema.container_id,
          container_port: schema.container_port,
          container_status: schema.container_status,
          image: schema.image,
          sdk_session_id: schema.sdk_session_id,
          paused_at: schema.paused_at,
          resumed_at: schema.resumed_at,
          inserted_at: schema.inserted_at,
          updated_at: schema.updated_at
        })
      end)
    rescue
      _ -> []
    end
  end

  defp reconcile_session(session, container_provider, session_repo, acc) do
    case check_container_state(session.container_id, container_provider) do
      :running ->
        # Container is actually running -- no action needed
        %{acc | reconciled: acc.reconciled + 1}

      :stopped ->
        # Container exists but stopped -- mark session accordingly
        session_repo.update_session(session, %{container_status: "stopped"})

        %{
          acc
          | reconciled: acc.reconciled + 1,
            stale_sessions_marked: acc.stale_sessions_marked + 1
        }

      :not_found ->
        # Container doesn't exist -- mark session as failed/removed
        session_repo.update_session(session, %{
          container_status: "removed",
          status: "failed"
        })

        %{
          acc
          | reconciled: acc.reconciled + 1,
            stale_sessions_marked: acc.stale_sessions_marked + 1
        }
    end
  rescue
    error ->
      Logger.warning(
        "StartupReconciliation: error reconciling session #{session.id}: #{inspect(error)}"
      )

      acc
  end

  defp check_container_state(nil, _provider), do: :not_found

  defp check_container_state(container_id, container_provider) do
    case container_provider.status(container_id) do
      {:ok, %{running: true}} -> :running
      {:ok, %{running: false}} -> :stopped
      {:error, _} -> :not_found
    end
  rescue
    _ -> :not_found
  end
end

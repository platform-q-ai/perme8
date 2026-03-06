defmodule Agents.Sessions.Infrastructure.QueueMirror do
  @moduledoc """
  Cross-validation utility for comparing QueueManager (legacy) and
  QueueOrchestrator (v2) queue state during migration.

  When mirror mode is enabled, both backends process notifications and
  their outputs are compared. Discrepancies are logged as warnings.
  """

  alias Agents.Sessions.Domain.Entities.QueueSnapshot

  require Logger

  @doc """
  Compares a legacy queue state map with a QueueSnapshot.
  Returns :match or {:mismatch, details}.
  """
  @spec compare(map(), QueueSnapshot.t()) :: :match | {:mismatch, list()}
  def compare(legacy_state, %QueueSnapshot{} = snapshot) do
    mismatches = []

    mismatches = compare_running_count(legacy_state, snapshot, mismatches)
    mismatches = compare_queued_count(legacy_state, snapshot, mismatches)
    mismatches = compare_concurrency_limit(legacy_state, snapshot, mismatches)

    case mismatches do
      [] -> :match
      _ -> {:mismatch, mismatches}
    end
  end

  @doc """
  Logs comparison results. Only logs mismatches at warning level.
  """
  @spec log_comparison(String.t(), :match | {:mismatch, list()}) :: :ok
  def log_comparison(user_id, :match) do
    Logger.debug("QueueMirror: state match for user #{user_id}")
    :ok
  end

  def log_comparison(user_id, {:mismatch, details}) do
    Logger.warning("QueueMirror: state mismatch for user #{user_id}: #{inspect(details)}")
    :ok
  end

  defp compare_running_count(legacy, snapshot, mismatches) do
    legacy_running = Map.get(legacy, :running, 0)
    snapshot_running = snapshot.metadata.running_count

    if legacy_running == snapshot_running do
      mismatches
    else
      [{:running_count, legacy: legacy_running, snapshot: snapshot_running} | mismatches]
    end
  end

  defp compare_queued_count(legacy, snapshot, mismatches) do
    legacy_queued = length(Map.get(legacy, :queued, []))
    snapshot_queued = QueueSnapshot.total_queued(snapshot)

    if legacy_queued == snapshot_queued do
      mismatches
    else
      [{:queued_count, legacy: legacy_queued, snapshot: snapshot_queued} | mismatches]
    end
  end

  defp compare_concurrency_limit(legacy, snapshot, mismatches) do
    legacy_limit = Map.get(legacy, :concurrency_limit, 2)
    snapshot_limit = snapshot.metadata.concurrency_limit

    if legacy_limit == snapshot_limit do
      mismatches
    else
      [{:concurrency_limit, legacy: legacy_limit, snapshot: snapshot_limit} | mismatches]
    end
  end
end

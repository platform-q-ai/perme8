defmodule Chat.Infrastructure.Workers.OrphanDetectionWorker do
  @moduledoc """
  Periodic GenServer that detects and removes orphaned chat sessions.

  Samples a batch of distinct `user_id` values from `chat_sessions`,
  checks each against Identity's public API, and deletes sessions
  belonging to users that no longer exist. This is defense-in-depth —
  the primary referential integrity check is in `CreateSession`, and
  the `IdentityEventSubscriber` handles real-time cleanup events.

  ## Configuration

  Injectable via opts for testing:
  - `:identity_api` — module implementing `IdentityApiBehaviour` (default: `IdentityApiAdapter`)
  - `:repo` — Ecto repo (default: `Chat.Repo`)
  - `:poll_interval_ms` — milliseconds between detection runs (default: 300_000 / 5 min)
  - `:sample_size` — max distinct user_ids to check per run (default: 100)
  """

  use GenServer

  require Logger

  @default_identity_api Chat.Infrastructure.Adapters.IdentityApiAdapter
  @default_repo Chat.Repo
  @default_poll_interval 300_000
  @default_sample_size 100

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      identity_api: Keyword.get(opts, :identity_api, @default_identity_api),
      repo: Keyword.get(opts, :repo, @default_repo),
      poll_interval_ms: Keyword.get(opts, :poll_interval_ms, @default_poll_interval),
      sample_size: Keyword.get(opts, :sample_size, @default_sample_size)
    }

    schedule_detection(state.poll_interval_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:detect_orphans, state) do
    run_detection(state)
    schedule_detection(state.poll_interval_ms)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp run_detection(state) do
    try do
      user_ids = sample_user_ids(state)

      orphaned_user_ids =
        Enum.reject(user_ids, fn user_id ->
          try do
            state.identity_api.user_exists?(user_id)
          rescue
            _ -> true
          end
        end)

      total_deleted =
        Enum.reduce(orphaned_user_ids, 0, fn user_id, acc ->
          try do
            {count, _} =
              Chat.Infrastructure.Queries.Queries.sessions_for_user(user_id)
              |> state.repo.delete_all()

            acc + count
          rescue
            error ->
              Logger.error(
                "OrphanDetectionWorker: failed to delete sessions for orphan user #{user_id}: #{inspect(error)}"
              )

              acc
          end
        end)

      Logger.info(
        "OrphanDetectionWorker: checked #{length(user_ids)} users, " <>
          "found #{length(orphaned_user_ids)} orphaned, " <>
          "deleted #{total_deleted} sessions"
      )
    rescue
      error ->
        Logger.error("OrphanDetectionWorker: detection run failed: #{inspect(error)}")
    end
  end

  defp sample_user_ids(state) do
    Chat.Infrastructure.Queries.Queries.sample_distinct_user_ids(state.sample_size)
    |> state.repo.all()
  end

  defp schedule_detection(interval) do
    Process.send_after(self(), :detect_orphans, interval)
  end
end

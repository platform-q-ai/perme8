defmodule Agents.Sessions.Infrastructure.TicketSyncServer do
  @moduledoc """
  Polls GitHub ProjectV2 tickets and broadcasts updates.

  Keeps the latest ticket snapshot in memory so LiveViews can render quickly
  without calling GitHub directly.
  """

  use GenServer

  require Logger

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Infrastructure.Clients.GithubProjectClient

  @topic "sessions:tickets"

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec list_tickets() :: [map()]
  def list_tickets do
    GenServer.call(__MODULE__, :list_tickets)
  catch
    :exit, _ -> []
  end

  @impl true
  def init(opts) do
    state = %{
      tickets: [],
      client: Keyword.get(opts, :client, GithubProjectClient),
      poll_interval_ms: SessionsConfig.github_poll_interval_ms(),
      pubsub: SessionsConfig.pubsub()
    }

    if SessionsConfig.github_sync_enabled?() do
      Process.send_after(self(), :poll, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:list_tickets, _from, state), do: {:reply, state.tickets, state}

  @impl true
  def handle_info(:poll, state) do
    next_state = poll_tickets(state)
    Process.send_after(self(), :poll, state.poll_interval_ms)
    {:noreply, next_state}
  end

  defp poll_tickets(state) do
    opts = [
      token: SessionsConfig.github_token(),
      org: SessionsConfig.github_project_org(),
      project_number: SessionsConfig.github_project_number(),
      statuses: SessionsConfig.github_ticket_statuses()
    ]

    case state.client.fetch_tickets(opts) do
      {:ok, tickets} ->
        Phoenix.PubSub.broadcast(state.pubsub, @topic, {:tickets_synced, tickets})
        %{state | tickets: tickets}

      {:error, :missing_token} ->
        Logger.debug("Skipping GitHub ticket sync: missing GH token")
        state

      {:error, reason} ->
        Logger.warning("GitHub ticket sync failed: #{inspect(reason)}")
        state
    end
  end
end

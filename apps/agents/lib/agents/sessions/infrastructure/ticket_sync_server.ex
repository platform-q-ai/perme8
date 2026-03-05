defmodule Agents.Sessions.Infrastructure.TicketSyncServer do
  @moduledoc """
  Polls open GitHub issues from the configured repository and broadcasts updates.

  Keeps the local `sessions_project_tickets` table in sync with the repo's
  open issues so LiveViews can render quickly without calling GitHub directly.
  Closed issues are automatically pruned from the local table on each sync.
  """

  use GenServer

  require Logger

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Infrastructure.Clients.GithubProjectClient
  alias Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository

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

  @doc """
  Closes a ticket on GitHub asynchronously (closes the issue).
  This is fire-and-forget — the local DB record should already be
  deleted before calling this.
  """
  @spec close_ticket(integer()) :: :ok
  def close_ticket(issue_number) when is_integer(issue_number) do
    GenServer.cast(__MODULE__, {:close_ticket, issue_number})
  end

  @impl true
  def init(opts) do
    state = %{
      client: Keyword.get(opts, :client, GithubProjectClient),
      ticket_repo: Keyword.get(opts, :ticket_repo, ProjectTicketRepository),
      poll_interval_ms: SessionsConfig.github_poll_interval_ms(),
      pubsub: SessionsConfig.pubsub()
    }

    if SessionsConfig.github_sync_enabled?() do
      Process.send_after(self(), :poll, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:list_tickets, _from, state) do
    tickets = state.ticket_repo.list_all()
    {:reply, tickets, state}
  rescue
    _ -> {:reply, [], state}
  end

  @impl true
  def handle_cast({:close_ticket, issue_number}, state) do
    opts = [
      token: SessionsConfig.github_token(),
      org: SessionsConfig.github_org(),
      repo: SessionsConfig.github_repo()
    ]

    case state.client.close_issue(issue_number, opts) do
      :ok ->
        Logger.info("Closed issue ##{issue_number} on GitHub")

      {:error, reason} ->
        Logger.warning("Failed to close issue ##{issue_number} on GitHub: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, state) do
    next_state = poll_tickets(state)
    Process.send_after(self(), :poll, state.poll_interval_ms)
    {:noreply, next_state}
  end

  defp poll_tickets(state) do
    opts = [
      token: SessionsConfig.github_token(),
      org: SessionsConfig.github_org(),
      repo: SessionsConfig.github_repo()
    ]

    case state.client.fetch_tickets(opts) do
      {:ok, tickets} ->
        Enum.each(tickets, &sync_remote_ticket(state, &1))

        # Remove local tickets that are no longer in the open issues list
        remote_numbers = MapSet.new(tickets, & &1.number)
        state.ticket_repo.delete_not_in(remote_numbers)

        persisted_tickets = state.ticket_repo.list_all()
        Phoenix.PubSub.broadcast(state.pubsub, @topic, {:tickets_synced, persisted_tickets})
        state

      {:error, :missing_token} ->
        Logger.debug("Skipping GitHub issue sync: missing GH token")
        state

      {:error, reason} ->
        Logger.warning("GitHub issue sync failed: #{inspect(reason)}")
        state
    end
  end

  defp sync_remote_ticket(state, ticket) do
    case state.ticket_repo.sync_remote_ticket(ticket) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("Ticket upsert failed: #{inspect(reason)}")
    end
  end
end

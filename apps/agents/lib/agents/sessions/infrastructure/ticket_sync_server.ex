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

  @spec reorder_ticket(integer(), String.t() | nil, [integer()]) :: :ok | {:error, term()}
  def reorder_ticket(ticket_number, target_status, ordered_ticket_numbers)
      when is_integer(ticket_number) and is_list(ordered_ticket_numbers) do
    GenServer.call(
      __MODULE__,
      {:reorder_ticket, ticket_number, target_status, ordered_ticket_numbers}
    )
  catch
    :exit, _ -> {:error, :sync_server_unavailable}
  end

  @doc """
  Closes a ticket on GitHub asynchronously (sets board status to "Done" and
  closes the issue). This is fire-and-forget — the local DB record should
  already be deleted before calling this.
  """
  @spec close_ticket(integer()) :: :ok
  def close_ticket(issue_number) when is_integer(issue_number) do
    GenServer.cast(__MODULE__, {:close_ticket, issue_number})
  end

  @impl true
  def init(opts) do
    state = %{
      tickets: [],
      ticket_index: %{},
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
    tickets = state.ticket_repo.list_by_statuses(SessionsConfig.github_ticket_statuses())
    {:reply, tickets, state}
  rescue
    _ -> {:reply, [], state}
  end

  @impl true
  def handle_call({:reorder_ticket, ticket_number, target_status, ordered_numbers}, _from, state) do
    result = do_reorder_ticket(state, ticket_number, target_status, ordered_numbers)

    next_state =
      case result do
        :ok -> poll_tickets(state)
        _ -> state
      end

    {:reply, result, next_state}
  end

  @impl true
  def handle_cast({:close_ticket, issue_number}, state) do
    opts = [
      token: SessionsConfig.github_token(),
      org: SessionsConfig.github_project_org(),
      project_number: SessionsConfig.github_project_number(),
      repo: "perme8"
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
      org: SessionsConfig.github_project_org(),
      project_number: SessionsConfig.github_project_number(),
      statuses: SessionsConfig.github_ticket_statuses()
    ]

    reconcile_local_changes(state, opts)

    case state.client.fetch_tickets(opts) do
      {:ok, tickets} ->
        Enum.each(tickets, &sync_remote_ticket(state, &1))

        persisted_tickets =
          state.ticket_repo.list_by_statuses(SessionsConfig.github_ticket_statuses())

        Phoenix.PubSub.broadcast(state.pubsub, @topic, {:tickets_synced, persisted_tickets})
        %{state | tickets: tickets, ticket_index: build_ticket_index(tickets)}

      {:error, :missing_token} ->
        Logger.debug("Skipping GitHub ticket sync: missing GH token")
        state

      {:error, reason} ->
        Logger.warning("GitHub ticket sync failed: #{inspect(reason)}")
        state
    end
  end

  defp sync_remote_ticket(state, ticket) do
    case state.ticket_repo.sync_remote_ticket(ticket) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.warning("Ticket upsert failed: #{inspect(reason)}")
    end
  end

  defp reconcile_local_changes(state, opts) do
    state.ticket_repo.list_pending_push()
    |> Enum.each(fn ticket ->
      case state.client.push_ticket_update(ticket, opts) do
        :ok ->
          state.ticket_repo.mark_sync_success(ticket)

        {:error, reason} ->
          Logger.warning("Ticket push sync failed for ##{ticket.number}: #{inspect(reason)}")
          state.ticket_repo.mark_sync_error(ticket, reason)
      end
    end)
  rescue
    reason -> Logger.warning("Ticket reconciliation failed: #{inspect(reason)}")
  end

  defp do_reorder_ticket(state, ticket_number, target_status, ordered_numbers) do
    with %{item_id: item_id} = ticket <- Map.get(state.ticket_index, ticket_number),
         project_id when is_binary(project_id) <- ticket[:project_id],
         status_field_id <- ticket[:status_field_id],
         status_option_ids <- ticket[:status_option_ids] || %{} do
      after_item_id = resolve_after_item_id(state.ticket_index, ordered_numbers, ticket_number)
      target_option_id = resolve_target_status_option_id(status_option_ids, target_status)

      opts = [
        token: SessionsConfig.github_token(),
        project_id: project_id,
        item_id: item_id,
        after_item_id: after_item_id,
        status_field_id: status_field_id,
        target_status_option_id: target_option_id
      ]

      state.client.update_ticket_order_and_status(opts)
    else
      nil -> {:error, :ticket_not_found}
      _ -> {:error, :missing_project_metadata}
    end
  end

  defp build_ticket_index(tickets) do
    Enum.reduce(tickets, %{}, fn ticket, acc ->
      case ticket[:number] do
        number when is_integer(number) -> Map.put(acc, number, ticket)
        _ -> acc
      end
    end)
  end

  defp resolve_after_item_id(index, ordered_numbers, ticket_number) do
    preceding =
      ordered_numbers
      |> Enum.take_while(&(&1 != ticket_number))
      |> List.last()

    case Map.get(index, preceding) do
      %{item_id: item_id} when is_binary(item_id) -> item_id
      _ -> nil
    end
  end

  defp resolve_target_status_option_id(_status_option_ids, nil), do: nil

  defp resolve_target_status_option_id(status_option_ids, target_status)
       when is_binary(target_status) do
    Map.get(status_option_ids, target_status)
  end
end

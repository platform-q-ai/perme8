defmodule Agents.Sessions.Infrastructure.TicketSyncServer do
  @moduledoc """
  Polls GitHub issues from the configured repository and broadcasts updates.

  Keeps the local `sessions_project_tickets` table in sync with the repo's
  issues (both open and closed) so LiveViews can render quickly without
  calling GitHub directly. Issues deleted from GitHub entirely are pruned
  from the local table on each sync.
  """

  use GenServer

  require Logger

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Domain.Entities.Ticket
  alias Agents.Sessions.Domain.Policies.TicketHierarchyPolicy
  alias Agents.Sessions.Infrastructure.Clients.GithubProjectClient
  alias Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository

  @topic "sessions:tickets"

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
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
      poll_interval_ms:
        Keyword.get(opts, :poll_interval_ms, SessionsConfig.github_poll_interval_ms()),
      pubsub: Keyword.get(opts, :pubsub, SessionsConfig.pubsub())
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

        link_hierarchy_relationships(state, tickets)

        # Remove local tickets that are no longer in the remote issues list
        # (i.e. deleted from GitHub entirely — closed issues are kept and
        # marked with state="closed" via the upsert above).
        # Guard: skip pruning when the API returns an empty list but we have
        # local tickets — this protects against transient GitHub API issues
        # (e.g. rate-limiting returning 200 with empty body) wiping the table.
        local_count = length(state.ticket_repo.list_all())

        if tickets == [] and local_count > 0 do
          Logger.warning(
            "GitHub sync returned 0 tickets but #{local_count} local tickets exist — skipping prune"
          )
        else
          remote_numbers = MapSet.new(tickets, & &1.number)
          state.ticket_repo.delete_not_in(remote_numbers)
        end

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

  defp link_hierarchy_relationships(state, remote_tickets) do
    local_tickets = state.ticket_repo.list_all_flat()
    tickets_by_number = Map.new(local_tickets, &{&1.number, &1})

    raw_parent_child_map =
      Enum.reduce(remote_tickets, %{}, fn ticket, acc ->
        Enum.reduce(Map.get(ticket, :sub_issue_numbers, []), acc, fn child_number, acc2 ->
          Map.put(acc2, child_number, ticket.number)
        end)
      end)

    referenced_children = MapSet.new(Map.keys(raw_parent_child_map))

    promoted_map =
      local_tickets
      |> Enum.map(& &1.number)
      |> Enum.reject(&MapSet.member?(referenced_children, &1))
      |> Map.new(fn number -> {number, nil} end)

    initial_entities =
      Enum.map(local_tickets, fn schema ->
        Ticket.new(%{
          id: schema.id,
          number: schema.number,
          parent_ticket_id: schema.parent_ticket_id
        })
      end)

    {safe_parent_child_map, _entities} =
      Enum.reduce(raw_parent_child_map, {%{}, initial_entities}, fn {child_number, parent_number},
                                                                    {acc, entities} ->
        resolve_parent_child(tickets_by_number, child_number, parent_number, acc, entities)
      end)

    state.ticket_repo.link_sub_tickets(Map.merge(promoted_map, safe_parent_child_map))
  end

  defp resolve_parent_child(tickets_by_number, child_number, parent_number, acc, entities) do
    case {Map.get(tickets_by_number, child_number), Map.get(tickets_by_number, parent_number)} do
      {%{id: child_id}, %{id: parent_id}} ->
        apply_parent_link(child_id, parent_id, child_number, parent_number, acc, entities)

      _ ->
        {acc, entities}
    end
  end

  defp apply_parent_link(child_id, parent_id, child_number, parent_number, acc, entities) do
    if TicketHierarchyPolicy.circular_reference?(entities, {child_id, parent_id}) do
      {acc, entities}
    else
      updated_entities =
        Enum.map(entities, fn
          %Ticket{id: ^child_id} = ticket -> %{ticket | parent_ticket_id: parent_id}
          ticket -> ticket
        end)

      {Map.put(acc, child_number, parent_number), updated_entities}
    end
  end
end

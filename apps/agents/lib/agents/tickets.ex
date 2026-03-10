defmodule Agents.Tickets do
  @moduledoc """
  Public API facade for the Tickets bounded context.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Agents.Tickets.Domain,
      Agents.Tickets.Application,
      Agents.Tickets.Infrastructure,
      Agents.Sessions,
      Agents.Sessions.Domain,
      Agents.Repo
    ],
    exports: [
      {Domain.Entities.Ticket, []}
    ]

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.TicketSyncServer

  @doc """
  Lists persisted project tickets enriched with per-user session state.

  Tickets are loaded from the agents DB (synced from GitHub open issues),
  then each ticket is matched against the user's recent tasks by issue number
  reference in instruction text (for example: "#306" or "ticket 306").
  """
  @spec list_project_tickets(String.t(), keyword()) :: [Ticket.t()]
  def list_project_tickets(user_id, opts \\ []) do
    tasks =
      Keyword.get_lazy(opts, :tasks, fn ->
        Sessions.list_tasks(user_id, opts)
      end)

    tickets =
      Keyword.get_lazy(opts, :tickets, fn ->
        ProjectTicketRepository.list_all()
      end)

    tickets
    |> Enum.map(&Ticket.from_schema/1)
    |> TicketEnrichmentPolicy.enrich_all(tasks, &SessionLifecyclePolicy.derive/1)
  end

  @doc "Persists triage ticket ordering to the database."
  @spec reorder_triage_tickets([integer()]) :: :ok
  def reorder_triage_tickets(ordered_ticket_numbers) do
    ProjectTicketRepository.reorder_positions(ordered_ticket_numbers)
  end

  @doc "Moves a ticket to the top of the triage column."
  @spec send_ticket_to_top(integer()) :: :ok
  def send_ticket_to_top(number), do: ProjectTicketRepository.send_to_top(number)

  @doc "Moves a ticket to the bottom of the triage column."
  @spec send_ticket_to_bottom(integer()) :: :ok
  def send_ticket_to_bottom(number), do: ProjectTicketRepository.send_to_bottom(number)

  @doc """
  Triggers an immediate sync of tickets from GitHub.

  Runs synchronously - the caller blocks until the sync completes
  (up to 30 seconds). The sync fetches all issues from GitHub,
  upserts them locally, links parent/child hierarchy, and prunes
  deleted issues.

  After completion the `:tickets_synced` PubSub broadcast fires
  so any subscribed LiveViews update automatically.
  """
  @spec sync_tickets() :: :ok | {:error, term()}
  def sync_tickets do
    TicketSyncServer.sync_now()
  end

  @doc """
  Closes a project ticket: marks it as closed in the local database and closes
  the issue on GitHub.

  The GitHub close runs asynchronously via the TicketSyncServer so the UI
  is not blocked.
  """
  @spec close_project_ticket(integer()) :: :ok | {:error, :not_found}
  def close_project_ticket(number) when is_integer(number) do
    case ProjectTicketRepository.close_by_number(number) do
      {:ok, _ticket} ->
        TicketSyncServer.close_ticket(number)
        :ok

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Links a task to a ticket by persisting the task ID on the ticket record.

  This creates a durable association that survives page reloads, ticket
  syncs, and re-enrichment cycles.
  """
  @spec link_ticket_to_task(integer(), String.t()) :: {:ok, struct()} | {:error, term()}
  def link_ticket_to_task(ticket_number, task_id) do
    ProjectTicketRepository.link_task(ticket_number, task_id)
  end

  @doc """
  Removes the task association from a ticket.
  """
  @spec unlink_ticket_from_task(integer()) :: {:ok, struct()} | {:error, term()}
  def unlink_ticket_from_task(ticket_number) do
    ProjectTicketRepository.unlink_task(ticket_number)
  end

  @doc false
  @spec extract_ticket_number(term()) :: integer() | nil
  def extract_ticket_number(instruction) when is_binary(instruction) do
    TicketEnrichmentPolicy.extract_ticket_number(instruction)
  end

  @doc "Builds a structured context block for a ticket, suitable for agent instructions."
  @spec build_ticket_context(Ticket.t()) :: String.t()
  defdelegate build_ticket_context(ticket), to: Ticket, as: :build_context_block

  def extract_ticket_number(_), do: nil
end

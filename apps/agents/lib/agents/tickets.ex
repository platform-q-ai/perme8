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
      Agents.Repo,
      Perme8.Events
    ],
    exports: [
      {Domain.Entities.Ticket, []}
    ]

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets.Application.TicketsConfig
  alias Agents.Tickets.Application.UseCases.AddTicketDependency
  alias Agents.Tickets.Application.UseCases.CreateTicket
  alias Agents.Tickets.Application.UseCases.RecordStageTransition
  alias Agents.Tickets.Application.UseCases.RemoveTicketDependency
  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy
  alias Agents.Tickets.Infrastructure.Clients.GithubProjectClient
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Repositories.TicketDependencyRepository
  alias Agents.Tickets.Infrastructure.TicketSyncServer

  @doc """
  Lists persisted project tickets enriched with per-user session state.

  Tickets are loaded from the agents DB (synced from GitHub open issues),
  then each ticket is matched against the user's recent tasks by issue number
  reference in instruction text (for example: "#306" or "ticket 306").

  If a ticket has a persisted `task_id` FK but that task isn't in the
  snapshot (e.g., it fell outside the 50-task window), the task is fetched
  from the DB and merged into the snapshot so enrichment can find it.
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

    tasks = backfill_missing_tasks(tickets, tasks, user_id)

    tickets
    |> Enum.map(&Ticket.from_schema/1)
    |> TicketEnrichmentPolicy.enrich_all(tasks, &SessionLifecyclePolicy.derive/1)
  end

  # Tickets with a persisted task_id FK may reference tasks outside the
  # 50-task snapshot window. Fetch any missing ones from the DB so the
  # enrichment policy can resolve them.
  defp backfill_missing_tasks(ticket_schemas, tasks, user_id) do
    snapshot_ids = MapSet.new(tasks, &Map.get(&1, :id))

    missing_ids =
      ticket_schemas
      |> Enum.map(&Map.get(&1, :task_id))
      |> Enum.reject(&(is_nil(&1) or MapSet.member?(snapshot_ids, &1)))
      |> Enum.uniq()

    if missing_ids == [] do
      tasks
    else
      fetched = Sessions.get_tasks_by_ids(missing_ids, user_id)
      tasks ++ fetched
    end
  end

  @doc """
  Records a lifecycle stage transition for a ticket.
  """
  @spec record_ticket_stage_transition(integer(), String.t(), keyword()) ::
          {:ok, %{ticket: map(), lifecycle_event: map()}} | {:error, term()}
  def record_ticket_stage_transition(ticket_id, to_stage, opts \\ []) do
    RecordStageTransition.execute(ticket_id, to_stage, opts)
  end

  @doc """
  Loads a ticket by id with lifecycle events.
  """
  @spec get_ticket_lifecycle(integer()) :: {:ok, Ticket.t()} | {:error, :ticket_not_found}
  def get_ticket_lifecycle(ticket_id) when is_integer(ticket_id) do
    case ProjectTicketRepository.get_by_id(ticket_id) do
      {:ok, schema} -> {:ok, Ticket.from_schema(schema)}
      nil -> {:error, :ticket_not_found}
    end
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
  Closes a project ticket on GitHub first, then marks it as closed locally.

  If the GitHub close fails, the local record is left unchanged and an error
  is returned so the caller can surface it to the user. This prevents the
  local state from drifting out of sync with GitHub.

  ## Options

    * `:github_client` - module implementing `GithubTicketClientBehaviour`
      (defaults to application config `:github_ticket_client` or
      `GithubProjectClient`)
  """
  @spec close_project_ticket(integer(), keyword()) :: :ok | {:error, term()}
  def close_project_ticket(number, opts \\ []) when is_integer(number) do
    client = Keyword.get_lazy(opts, :github_client, &github_client/0)

    github_opts = [
      token: TicketsConfig.github_token(),
      org: TicketsConfig.github_org(),
      repo: TicketsConfig.github_repo()
    ]

    case client.update_issue(number, %{state: "closed"}, github_opts) do
      {:ok, _issue} ->
        case ProjectTicketRepository.close_by_number(number) do
          {:ok, _ticket} -> :ok
          {:error, :not_found} -> :ok
        end

      # Issue doesn't exist on GitHub -- treat as already closed
      {:error, :not_found} ->
        case ProjectTicketRepository.close_by_number(number) do
          {:ok, _ticket} -> :ok
          {:error, :not_found} -> :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp github_client do
    Application.get_env(
      :agents,
      :github_ticket_client,
      GithubProjectClient
    )
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

  @doc """
  Creates a new ticket locally and asynchronously pushes it to GitHub.

  The first line of `body` is used as the ticket title; the rest becomes the
  body. The ticket is inserted into the local database immediately (with
  `sync_state: "pending_push"`) and a `TicketCreated` domain event is emitted.
  The `GithubTicketPushHandler` subscriber reacts to this event to create the
  corresponding GitHub issue and update the local record with the real issue
  number.
  """
  @spec create_ticket(String.t(), keyword()) :: {:ok, struct()} | {:error, term()}
  def create_ticket(body, opts \\ []) when is_binary(body) do
    CreateTicket.execute(body, opts)
  end

  @doc """
  Adds a dependency: blocker_ticket_id blocks blocked_ticket_id.

  ## Options
  - `:actor_id` - (required)
  - `:event_bus` - Event bus module
  - `:dependency_repo` - Repository module
  """
  @spec add_dependency(integer(), integer(), keyword()) :: {:ok, struct()} | {:error, term()}
  def add_dependency(blocker_ticket_id, blocked_ticket_id, opts \\ []) do
    AddTicketDependency.execute(blocker_ticket_id, blocked_ticket_id, opts)
  end

  @doc """
  Removes a dependency: blocker_ticket_id no longer blocks blocked_ticket_id.

  ## Options
  - `:actor_id` - (required)
  - `:event_bus` - Event bus module
  - `:dependency_repo` - Repository module
  """
  @spec remove_dependency(integer(), integer(), keyword()) ::
          :ok | {:error, :dependency_not_found}
  def remove_dependency(blocker_ticket_id, blocked_ticket_id, opts \\ []) do
    RemoveTicketDependency.execute(blocker_ticket_id, blocked_ticket_id, opts)
  end

  @doc """
  Searches tickets by number or title, excluding the given ticket ID.
  Used for the dependency typeahead search.
  """
  @spec search_tickets_for_dependency(String.t(), integer()) :: [struct()]
  def search_tickets_for_dependency(query, exclude_ticket_id) do
    TicketDependencyRepository.search_tickets(query, exclude_ticket_id)
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

defmodule Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository do
  @moduledoc """
  Repository for persisted session sidebar project tickets.

  Stores open GitHub issues synced from the configured repo.
  """

  import Ecto.Query, warn: false

  alias Agents.Repo
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  defp lifecycle_events_query do
    from(event in Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema,
      order_by: [asc: event.transitioned_at, asc: event.id]
    )
  end

  @doc """
  Lists root-level tickets with one-level sub-tickets preloaded.
  """
  @spec list_all() :: [ProjectTicketSchema.t()]
  def list_all do
    lifecycle_events_query = lifecycle_events_query()

    sub_tickets_query =
      ProjectTicketSchema
      |> order_by([ticket], desc: ticket.position, desc: ticket.created_at)
      |> preload([ticket], lifecycle_events: ^lifecycle_events_query)

    ProjectTicketSchema
    |> where([ticket], is_nil(ticket.parent_ticket_id))
    |> order_by([ticket], desc: ticket.position, desc: ticket.created_at)
    |> preload([ticket],
      lifecycle_events: ^lifecycle_events_query,
      sub_tickets: ^sub_tickets_query
    )
    |> Repo.all()
  end

  @doc """
  Lists all persisted tickets without hierarchy filtering.
  """
  @spec list_all_flat() :: [ProjectTicketSchema.t()]
  def list_all_flat do
    ProjectTicketSchema
    |> order_by([ticket], desc: ticket.position, desc: ticket.created_at)
    |> Repo.all()
  end

  @doc """
  Loads a ticket by id with lifecycle events preloaded.
  """
  @spec get_by_id(integer()) :: {:ok, ProjectTicketSchema.t()} | nil
  def get_by_id(id) when is_integer(id) do
    lifecycle_events_query = lifecycle_events_query()

    case Repo.get(ProjectTicketSchema, id) do
      nil -> nil
      ticket -> {:ok, Repo.preload(ticket, lifecycle_events: lifecycle_events_query)}
    end
  end

  @doc """
  Updates a ticket's lifecycle stage and entered-at timestamp.
  """
  @spec update_lifecycle_stage(integer(), String.t(), DateTime.t()) ::
          {:ok, ProjectTicketSchema.t()}
          | {:error, :ticket_not_found}
          | {:error, Ecto.Changeset.t()}
  def update_lifecycle_stage(ticket_id, to_stage, entered_at)
      when is_integer(ticket_id) and is_binary(to_stage) do
    case Repo.get(ProjectTicketSchema, ticket_id) do
      nil ->
        {:error, :ticket_not_found}

      ticket ->
        ticket
        |> ProjectTicketSchema.changeset(%{
          lifecycle_stage: to_stage,
          lifecycle_stage_entered_at: entered_at
        })
        |> Repo.update()
    end
  end

  @doc """
  Updates the position of each ticket to match the given display-order list
  of ticket numbers (first element = shown at top = highest position).
  Tickets not in the list keep their existing position.
  """
  @spec reorder_positions([integer()]) :: :ok
  def reorder_positions(ordered_numbers) when is_list(ordered_numbers) do
    count = length(ordered_numbers)

    if count > 0 do
      # Build a single UPDATE ... FROM (VALUES ...) to avoid N+1 writes.
      # First in the display list gets the highest position value.
      pairs =
        ordered_numbers
        |> Enum.with_index()
        |> Enum.map(fn {number, index} -> {number, count - 1 - index} end)

      # Use parameterized placeholders: ($1, $2), ($3, $4), ...
      {placeholders, params} =
        pairs
        |> Enum.with_index()
        |> Enum.map_reduce([], fn {{num, pos}, idx}, acc ->
          p1 = idx * 2 + 1
          p2 = idx * 2 + 2
          {"($#{p1}::integer, $#{p2}::integer)", acc ++ [num, pos]}
        end)

      values_clause = Enum.join(placeholders, ", ")

      Repo.query!(
        """
        UPDATE sessions_project_tickets AS t
        SET position = v.pos
        FROM (VALUES #{values_clause}) AS v(num, pos)
        WHERE t.number = v.num
        """,
        params
      )
    end

    :ok
  end

  @doc """
  Sets the given ticket's position to max + 1 so it appears at the top of the
  triage column (highest position = displayed first).
  """
  @spec send_to_top(integer()) :: :ok
  def send_to_top(number) when is_integer(number) do
    Repo.transaction(fn ->
      max_pos = Repo.one(from(t in ProjectTicketSchema, select: max(t.position))) || 0

      ProjectTicketSchema
      |> where([t], t.number == ^number)
      |> Repo.update_all(set: [position: max_pos + 1])
    end)

    :ok
  end

  @doc """
  Sets the given ticket's position to min - 1 so it appears at the bottom of
  the triage column (lowest position = displayed last).
  """
  @spec send_to_bottom(integer()) :: :ok
  def send_to_bottom(number) when is_integer(number) do
    Repo.transaction(fn ->
      min_pos = Repo.one(from(t in ProjectTicketSchema, select: min(t.position))) || 0

      ProjectTicketSchema
      |> where([t], t.number == ^number)
      |> Repo.update_all(set: [position: min_pos - 1])
    end)

    :ok
  end

  @doc """
  Marks a ticket as closed by its issue number.
  Returns `{:ok, ticket}` if the ticket existed, `{:error, :not_found}` otherwise.
  """
  @spec close_by_number(integer()) :: {:ok, ProjectTicketSchema.t()} | {:error, :not_found}
  def close_by_number(number) when is_integer(number) do
    case Repo.get_by(ProjectTicketSchema, number: number) do
      nil -> {:error, :not_found}
      ticket -> ticket |> ProjectTicketSchema.changeset(%{state: "closed"}) |> Repo.update()
    end
  end

  @doc """
  Deletes a ticket by its issue number.
  Returns `{:ok, ticket}` if the ticket existed, `{:error, :not_found}` otherwise.
  """
  @spec delete_by_number(integer()) :: {:ok, ProjectTicketSchema.t()} | {:error, :not_found}
  def delete_by_number(number) when is_integer(number) do
    case Repo.get_by(ProjectTicketSchema, number: number) do
      nil -> {:error, :not_found}
      ticket -> Repo.delete(ticket)
    end
  end

  @doc """
  Deletes all tickets whose number is NOT in the given set.
  Used to prune issues that have been deleted from GitHub entirely.

  Tickets with `sync_state: "pending_push"` are excluded from pruning
  because they haven't been pushed to GitHub yet and therefore won't
  appear in the remote set.
  """
  @spec delete_not_in(MapSet.t()) :: {integer(), nil}
  def delete_not_in(%MapSet{} = keep_numbers) do
    numbers_list = MapSet.to_list(keep_numbers)

    ProjectTicketSchema
    |> where([t], t.number not in ^numbers_list)
    |> where([t], t.sync_state != "pending_push")
    |> Repo.delete_all()
  end

  @doc """
  Upserts a ticket from remote GitHub data.
  New tickets get appended to the end of the position list.
  """
  @spec sync_remote_ticket(map(), keyword()) ::
          {:ok, ProjectTicketSchema.t()} | {:error, Ecto.Changeset.t()}
  def sync_remote_ticket(attrs, opts \\ []) do
    now = Keyword.get(opts, :synced_at, DateTime.utc_now() |> DateTime.truncate(:second))

    remote_attrs = normalize_remote_attrs(attrs)
    number = remote_attrs.number
    ticket = Repo.get_by(ProjectTicketSchema, number: number)

    attrs_with_sync =
      remote_attrs
      |> Map.put(:sync_state, "synced")
      |> Map.put(:last_synced_at, now)
      |> Map.put(:last_sync_error, nil)
      |> then(fn attrs ->
        if is_nil(attrs[:created_at]), do: Map.put(attrs, :created_at, now), else: attrs
      end)

    # New tickets get appended to the end; existing tickets preserve their position
    attrs_with_sync =
      if is_nil(ticket) do
        Map.put_new(attrs_with_sync, :position, next_position())
      else
        Map.put(attrs_with_sync, :position, ticket.position)
      end

    (ticket || %ProjectTicketSchema{})
    |> ProjectTicketSchema.changeset(attrs_with_sync)
    |> Repo.insert_or_update()
  end

  @doc """
  Links child tickets to parent tickets by ticket number.

  Accepts `%{child_number => parent_number}` and skips entries where either
  side is not present locally.
  """
  @spec link_sub_tickets(map()) :: :ok
  def link_sub_tickets(parent_child_map) when parent_child_map == %{}, do: :ok

  def link_sub_tickets(parent_child_map) when is_map(parent_child_map) do
    tickets_by_number =
      ProjectTicketSchema
      |> select([ticket], {ticket.number, ticket.id})
      |> Repo.all()
      |> Map.new()

    # Build resolved list of {child_id, parent_id} pairs, skipping unresolvable entries
    resolved =
      parent_child_map
      |> Enum.map(fn {child_number, parent_number} ->
        child_id = Map.get(tickets_by_number, child_number)

        parent_id =
          if is_nil(parent_number), do: nil, else: Map.get(tickets_by_number, parent_number)

        if child_id && (is_nil(parent_number) || parent_id) do
          {child_id, parent_id}
        end
      end)
      |> Enum.reject(&is_nil/1)

    if resolved != [] do
      # Batch update using a single parameterized query with VALUES + JOIN
      {placeholders, params} =
        resolved
        |> Enum.with_index()
        |> Enum.map_reduce([], fn {{child_id, parent_id}, idx}, acc ->
          p1 = idx * 2 + 1
          p2 = idx * 2 + 2
          {"($#{p1}::integer, $#{p2}::integer)", acc ++ [child_id, parent_id]}
        end)

      values_clause = Enum.join(placeholders, ", ")

      Repo.query!(
        """
        UPDATE sessions_project_tickets AS t
        SET parent_ticket_id = v.parent_id
        FROM (VALUES #{values_clause}) AS v(child_id, parent_id)
        WHERE t.id = v.child_id
        """,
        params
      )
    end

    :ok
  end

  @doc """
  Links a task to a ticket by ticket number.

  Sets the `task_id` on the ticket record so the association persists
  across page reloads and re-enrichment cycles.
  """
  @spec link_task(integer(), String.t()) :: {:ok, ProjectTicketSchema.t()} | {:error, term()}
  def link_task(ticket_number, task_id) when is_integer(ticket_number) and is_binary(task_id) do
    case Repo.get_by(ProjectTicketSchema, number: ticket_number) do
      nil -> {:error, :ticket_not_found}
      ticket -> ticket |> ProjectTicketSchema.changeset(%{task_id: task_id}) |> Repo.update()
    end
  end

  @doc """
  Unlinks a task from a ticket by ticket number.

  Clears the persisted `task_id` so the ticket is no longer associated
  with any task.
  """
  @spec unlink_task(integer()) :: {:ok, ProjectTicketSchema.t()} | {:error, term()}
  def unlink_task(ticket_number) when is_integer(ticket_number) do
    case Repo.get_by(ProjectTicketSchema, number: ticket_number) do
      nil -> {:error, :ticket_not_found}
      ticket -> ticket |> ProjectTicketSchema.changeset(%{task_id: nil}) |> Repo.update()
    end
  end

  @doc """
  Returns the next available position value for a new ticket.
  """
  @spec next_position() :: integer()
  def next_position do
    case Repo.one(from(t in ProjectTicketSchema, select: max(t.position))) do
      nil -> 0
      max_pos -> max_pos + 1
    end
  end

  @doc """
  Inserts a locally-created ticket (not yet synced to GitHub).
  """
  @spec insert_local(map()) :: {:ok, ProjectTicketSchema.t()} | {:error, Ecto.Changeset.t()}
  def insert_local(attrs) do
    %ProjectTicketSchema{}
    |> ProjectTicketSchema.changeset(attrs)
    |> Repo.insert()
  end

  @remote_attr_keys ~w(number title body labels url state created_at parent_ticket_id)a

  defp normalize_remote_attrs(attrs) do
    normalized =
      Map.new(@remote_attr_keys, fn key ->
        {key, attrs[key] || attrs[Atom.to_string(key)]}
      end)

    normalized
    |> Map.update!(:labels, &List.wrap/1)
    |> Map.update!(:state, fn state -> state || "open" end)
  end
end

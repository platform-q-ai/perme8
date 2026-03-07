defmodule Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository do
  @moduledoc """
  Repository for persisted session sidebar project tickets.

  Stores open GitHub issues synced from the configured repo.
  """

  import Ecto.Query, warn: false

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.ProjectTicketSchema

  @doc """
  Lists all persisted tickets, ordered by position descending (highest first).
  New tickets are appended with the next highest position, so they appear at
  the bottom of the UI. "Send to top" gives a ticket the highest position;
  "send to bottom" gives it the lowest.
  """
  @spec list_all() :: [ProjectTicketSchema.t()]
  def list_all do
    ProjectTicketSchema
    |> order_by([ticket], desc: ticket.position, desc: ticket.created_at)
    |> Repo.all()
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
  """
  @spec delete_not_in(MapSet.t()) :: {integer(), nil}
  def delete_not_in(%MapSet{} = keep_numbers) do
    numbers_list = MapSet.to_list(keep_numbers)

    ProjectTicketSchema
    |> where([t], t.number not in ^numbers_list)
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

  defp next_position do
    case Repo.one(from(t in ProjectTicketSchema, select: max(t.position))) do
      nil -> 0
      max_pos -> max_pos + 1
    end
  end

  @remote_attr_keys ~w(number title body labels url state created_at)a

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

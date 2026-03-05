defmodule Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository do
  @moduledoc """
  Repository for persisted session sidebar project tickets.

  Stores open GitHub issues synced from the configured repo.
  """

  import Ecto.Query, warn: false

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.ProjectTicketSchema

  @doc """
  Lists all persisted tickets, ordered by position then inserted_at.
  """
  @spec list_all() :: [ProjectTicketSchema.t()]
  def list_all do
    ProjectTicketSchema
    |> order_by([ticket], asc: ticket.position, desc: ticket.inserted_at)
    |> Repo.all()
  end

  @doc """
  Updates the position of each ticket to match the given ordered list of ticket numbers.
  Tickets not in the list keep their existing position.
  """
  @spec reorder_positions([integer()]) :: :ok
  def reorder_positions(ordered_numbers) when is_list(ordered_numbers) do
    Repo.transaction(fn ->
      ordered_numbers
      |> Enum.with_index()
      |> Enum.each(fn {number, index} ->
        ProjectTicketSchema
        |> where([t], t.number == ^number)
        |> Repo.update_all(set: [position: index])
      end)
    end)

    :ok
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
  Used to prune issues that have been closed on GitHub.
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

  @remote_attr_keys ~w(number title body labels url)a

  defp normalize_remote_attrs(attrs) do
    normalized =
      Map.new(@remote_attr_keys, fn key ->
        {key, attrs[key] || attrs[Atom.to_string(key)]}
      end)

    Map.update!(normalized, :labels, &List.wrap/1)
  end
end

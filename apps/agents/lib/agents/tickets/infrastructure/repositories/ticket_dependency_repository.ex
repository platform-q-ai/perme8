defmodule Agents.Tickets.Infrastructure.Repositories.TicketDependencyRepository do
  @moduledoc """
  Repository for ticket dependency (blocks/blocked-by) relationships.
  """

  import Ecto.Query, warn: false

  alias Agents.Repo
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Tickets.Infrastructure.Schemas.TicketDependencySchema

  @doc """
  Adds a dependency: blocker_ticket_id blocks blocked_ticket_id.
  """
  @spec add_dependency(integer(), integer()) ::
          {:ok, TicketDependencySchema.t()} | {:error, Ecto.Changeset.t()}
  def add_dependency(blocker_ticket_id, blocked_ticket_id) do
    %{blocker_ticket_id: blocker_ticket_id, blocked_ticket_id: blocked_ticket_id}
    |> TicketDependencySchema.changeset()
    |> Repo.insert()
  end

  @doc """
  Removes a dependency between the given ticket IDs.
  """
  @spec remove_dependency(integer(), integer()) :: :ok | {:error, :not_found}
  def remove_dependency(blocker_ticket_id, blocked_ticket_id) do
    query =
      from(d in TicketDependencySchema,
        where:
          d.blocker_ticket_id == ^blocker_ticket_id and d.blocked_ticket_id == ^blocked_ticket_id
      )

    case Repo.delete_all(query) do
      {0, _} -> {:error, :not_found}
      {_count, _} -> :ok
    end
  end

  @doc """
  Returns all dependency edges as `{blocker_id, blocked_id}` tuples.
  """
  @spec list_edges() :: [{integer(), integer()}]
  def list_edges do
    from(d in TicketDependencySchema,
      select: {d.blocker_ticket_id, d.blocked_ticket_id}
    )
    |> Repo.all()
  end

  @doc """
  Returns true if a ticket with the given ID exists.
  """
  @spec ticket_exists?(integer()) :: boolean()
  def ticket_exists?(ticket_id) do
    Repo.exists?(from(t in ProjectTicketSchema, where: t.id == ^ticket_id))
  end

  @doc """
  Searches tickets by number (exact match) or title (ilike),
  excluding the given ticket ID.
  """
  @spec search_tickets(String.t(), integer()) :: [ProjectTicketSchema.t()]
  def search_tickets(query_string, exclude_ticket_id) do
    query_string = String.trim(query_string)

    base_query =
      from(t in ProjectTicketSchema,
        where: t.id != ^exclude_ticket_id,
        order_by: [desc: t.position, desc: t.created_at],
        limit: 10
      )

    case Integer.parse(query_string) do
      {number, ""} ->
        from(t in base_query,
          where: t.number == ^number or ilike(t.title, ^"%#{query_string}%")
        )
        |> Repo.all()

      _ ->
        from(t in base_query,
          where: ilike(t.title, ^"%#{query_string}%")
        )
        |> Repo.all()
    end
  end
end

defmodule Agents.Tickets.Infrastructure.Repositories.TicketLifecycleEventRepository do
  @moduledoc """
  Data access for ticket lifecycle events.
  """

  import Ecto.Query, warn: false

  alias Agents.Repo
  alias Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema

  @spec create(map()) :: {:ok, TicketLifecycleEventSchema.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %TicketLifecycleEventSchema{}
    |> TicketLifecycleEventSchema.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_for_ticket(integer()) :: [TicketLifecycleEventSchema.t()]
  def list_for_ticket(ticket_id) when is_integer(ticket_id) do
    TicketLifecycleEventSchema
    |> where([event], event.ticket_id == ^ticket_id)
    |> order_by([event], asc: event.transitioned_at, asc: event.id)
    |> Repo.all()
  end

  @spec latest_for_ticket(integer()) :: TicketLifecycleEventSchema.t() | nil
  def latest_for_ticket(ticket_id) when is_integer(ticket_id) do
    TicketLifecycleEventSchema
    |> where([event], event.ticket_id == ^ticket_id)
    |> order_by([event], desc: event.transitioned_at, desc: event.id)
    |> limit(1)
    |> Repo.one()
  end
end

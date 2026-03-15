defmodule Agents.Tickets.Infrastructure.Schemas.TicketDependencySchema do
  @moduledoc """
  Ecto schema for the ticket_dependencies join table.

  Represents a directional dependency: the blocker ticket blocks the blocked ticket.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  schema "ticket_dependencies" do
    belongs_to(:blocker_ticket, ProjectTicketSchema)
    belongs_to(:blocked_ticket, ProjectTicketSchema)

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @doc false
  def changeset(dependency \\ %__MODULE__{}, attrs) do
    dependency
    |> cast(attrs, [:blocker_ticket_id, :blocked_ticket_id])
    |> validate_required([:blocker_ticket_id, :blocked_ticket_id])
    |> validate_not_self_referencing()
    |> foreign_key_constraint(:blocker_ticket_id)
    |> foreign_key_constraint(:blocked_ticket_id)
    |> unique_constraint([:blocker_ticket_id, :blocked_ticket_id])
  end

  defp validate_not_self_referencing(changeset) do
    blocker = get_field(changeset, :blocker_ticket_id)
    blocked = get_field(changeset, :blocked_ticket_id)

    if blocker && blocked && blocker == blocked do
      add_error(changeset, :blocked_ticket_id, "cannot be the same as blocker ticket")
    else
      changeset
    end
  end
end

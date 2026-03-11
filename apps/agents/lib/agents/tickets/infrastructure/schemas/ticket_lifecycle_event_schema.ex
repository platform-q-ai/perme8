defmodule Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema do
  @moduledoc """
  Ecto schema for persisted ticket lifecycle transitions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  @valid_triggers ["system", "sync", "manual"]

  @type t :: %__MODULE__{
          id: integer(),
          ticket_id: integer(),
          from_stage: String.t() | nil,
          to_stage: String.t(),
          transitioned_at: DateTime.t(),
          trigger: String.t(),
          inserted_at: DateTime.t(),
          ticket: ProjectTicketSchema.t() | Ecto.Association.NotLoaded.t()
        }

  schema "sessions_ticket_lifecycle_events" do
    field(:from_stage, :string)
    field(:to_stage, :string)
    field(:transitioned_at, :utc_datetime)
    field(:trigger, :string, default: "system")

    belongs_to(:ticket, ProjectTicketSchema)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:ticket_id, :from_stage, :to_stage, :transitioned_at, :trigger])
    |> validate_required([:ticket_id, :to_stage, :transitioned_at])
    |> validate_inclusion(:trigger, @valid_triggers)
    |> foreign_key_constraint(:ticket_id)
  end
end

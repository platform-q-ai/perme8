defmodule Agents.Sessions.Infrastructure.Schemas.InteractionSchema do
  @moduledoc """
  Ecto schema for the session_interactions table.

  Captures all human-AI communication within a session: questions,
  answers, instructions, and queued responses.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Agents.Sessions.Infrastructure.Schemas.{SessionSchema, TaskSchema}

  @valid_types ["question", "answer", "instruction", "queued_response"]
  @valid_directions ["inbound", "outbound"]
  @valid_statuses ["pending", "delivered", "expired", "cancelled", "rolled_back", "timed_out"]

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "session_interactions" do
    field(:type, :string)
    field(:direction, :string)
    field(:payload, :map, default: %{})
    field(:correlation_id, :string)
    field(:status, :string, default: "pending")

    belongs_to(:session, SessionSchema)
    belongs_to(:task, TaskSchema)

    timestamps(type: :utc_datetime)
  end

  @doc "Creates a changeset for a new interaction."
  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:session_id, :task_id, :type, :direction, :payload, :correlation_id, :status])
    |> validate_required([:session_id, :type, :direction])
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:direction, @valid_directions)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:task_id)
  end

  @doc "Creates a changeset for updating interaction status."
  def status_changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, @valid_statuses)
  end

  def valid_types, do: @valid_types
  def valid_directions, do: @valid_directions
  def valid_statuses, do: @valid_statuses
end

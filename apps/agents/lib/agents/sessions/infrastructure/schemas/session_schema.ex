defmodule Agents.Sessions.Infrastructure.Schemas.SessionSchema do
  @moduledoc """
  Ecto schema for the sessions table.

  Sessions are the aggregate root for coding sessions. Each session owns:
  - Container metadata (container_id, port, image, container_status)
  - Lifecycle state (status, paused_at, resumed_at)
  - SDK session tracking (sdk_session_id)
  - A collection of tasks (via has_many)
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  @valid_statuses ["active", "paused", "completed", "failed"]
  @valid_container_statuses ["pending", "starting", "running", "stopped", "removed"]

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "sessions" do
    field(:user_id, Ecto.UUID)
    field(:title, :string)
    field(:status, :string, default: "active")
    field(:container_id, :string)
    field(:container_port, :integer)
    field(:container_status, :string, default: "pending")
    field(:image, :string, default: "perme8-opencode")
    field(:sdk_session_id, :string)
    field(:paused_at, :utc_datetime)
    field(:resumed_at, :utc_datetime)

    has_many(:tasks, TaskSchema, foreign_key: :session_ref_id)

    timestamps(type: :utc_datetime)
  end

  @doc "Creates a changeset for a new session."
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :user_id,
      :title,
      :status,
      :container_id,
      :container_port,
      :container_status,
      :image,
      :sdk_session_id,
      :paused_at,
      :resumed_at
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:container_status, @valid_container_statuses)
    |> foreign_key_constraint(:user_id)
  end

  @doc "Creates a changeset for updating session mutable fields."
  def status_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :title,
      :status,
      :container_id,
      :container_port,
      :container_status,
      :sdk_session_id,
      :paused_at,
      :resumed_at
    ])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:container_status, @valid_container_statuses)
  end

  def valid_statuses, do: @valid_statuses
  def valid_container_statuses, do: @valid_container_statuses
end

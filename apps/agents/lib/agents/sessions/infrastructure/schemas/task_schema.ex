defmodule Agents.Sessions.Infrastructure.Schemas.TaskSchema do
  @moduledoc """
  Ecto schema for coding tasks.

  Tasks represent agentic coding sessions running in ephemeral Docker containers.
  Each task belongs to a user and tracks the lifecycle from creation to completion.

  Located in infrastructure layer as it's an Ecto-specific implementation detail.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Agents.Sessions.Domain.Entities.Task

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          instruction: String.t(),
          status: String.t(),
          container_id: String.t() | nil,
          container_port: integer() | nil,
          session_id: String.t() | nil,
          user_id: Ecto.UUID.t(),
          error: String.t() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @valid_statuses Task.valid_statuses()

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "sessions_tasks" do
    field(:instruction, :string)
    field(:status, :string, default: "pending")
    field(:container_id, :string)
    field(:container_port, :integer)
    field(:session_id, :string)
    field(:user_id, Ecto.UUID)
    field(:error, :string)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a new task.

  ## Required Fields
  - instruction
  - user_id

  ## Optional Fields
  - status (default: "pending")
  - container_id, container_port, session_id, error, started_at, completed_at
  """
  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :instruction,
      :user_id,
      :status,
      :container_id,
      :container_port,
      :session_id,
      :error,
      :started_at,
      :completed_at
    ])
    |> validate_required([:instruction, :user_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a changeset for updating task status and related mutable fields.

  Does NOT allow changing instruction or user_id.
  """
  def status_changeset(task, attrs) do
    task
    |> cast(attrs, [
      :status,
      :container_id,
      :container_port,
      :session_id,
      :error,
      :started_at,
      :completed_at
    ])
    |> validate_inclusion(:status, @valid_statuses)
  end
end

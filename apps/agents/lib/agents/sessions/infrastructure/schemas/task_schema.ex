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
  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          instruction: String.t(),
          status: String.t(),
          lifecycle_state: String.t(),
          image: String.t(),
          container_id: String.t() | nil,
          container_port: integer() | nil,
          session_id: String.t() | nil,
          user_id: Ecto.UUID.t(),
          error: String.t() | nil,
          output: String.t() | nil,
          todo_items: map() | nil,
          session_summary: map() | nil,
          parent_task_id: Ecto.UUID.t() | nil,
          pending_question: map() | nil,
          queue_position: integer() | nil,
          retry_count: integer(),
          last_retry_at: DateTime.t() | nil,
          next_retry_at: DateTime.t() | nil,
          queued_at: DateTime.t() | nil,
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @valid_statuses Task.valid_statuses()
  @valid_lifecycle_states [
    "idle",
    "queued_cold",
    "queued_warm",
    "warming",
    "pending",
    "starting",
    "running",
    "awaiting_feedback",
    "completed",
    "failed",
    "cancelled"
  ]

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "sessions_tasks" do
    field(:instruction, :string)
    field(:status, :string, default: "pending")
    field(:lifecycle_state, :string, default: "idle")
    field(:image, :string, default: "perme8-opencode")
    field(:container_id, :string)
    field(:container_port, :integer)
    field(:session_id, :string)
    field(:user_id, Ecto.UUID)
    field(:error, :string)
    field(:output, :string)
    field(:todo_items, :map)
    field(:session_summary, :map)
    field(:parent_task_id, Ecto.UUID)
    field(:pending_question, :map)
    field(:queue_position, :integer)
    field(:retry_count, :integer, default: 0)
    field(:last_retry_at, :utc_datetime)
    field(:next_retry_at, :utc_datetime)
    field(:queued_at, :utc_datetime)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)
    field(:session_ref_id, Ecto.UUID)

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
      :lifecycle_state,
      :image,
      :container_id,
      :container_port,
      :session_id,
      :error,
      :output,
      :parent_task_id,
      :queue_position,
      :retry_count,
      :last_retry_at,
      :next_retry_at,
      :queued_at,
      :started_at,
      :completed_at,
      :session_ref_id
    ])
    |> validate_required([:instruction, :user_id])
    |> maybe_derive_lifecycle_state()
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:lifecycle_state, @valid_lifecycle_states)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parent_task_id)
    |> foreign_key_constraint(:session_ref_id)
  end

  @doc """
  Creates a changeset for updating task status and related mutable fields.

  Allows updating instruction (used by session resume) but does NOT
  allow changing user_id.
  """
  def status_changeset(task, attrs) do
    task
    |> cast(attrs, [
      :status,
      :lifecycle_state,
      :instruction,
      :container_id,
      :container_port,
      :session_id,
      :error,
      :output,
      :todo_items,
      :session_summary,
      :pending_question,
      :queue_position,
      :retry_count,
      :last_retry_at,
      :next_retry_at,
      :queued_at,
      :started_at,
      :completed_at,
      :session_ref_id
    ])
    |> maybe_derive_lifecycle_state()
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:lifecycle_state, @valid_lifecycle_states)
    |> foreign_key_constraint(:session_ref_id)
  end

  defp maybe_derive_lifecycle_state(changeset) do
    if Map.has_key?(changeset.changes, :lifecycle_state) do
      changeset
    else
      lifecycle_state =
        SessionLifecyclePolicy.derive(%{
          status: get_field(changeset, :status),
          container_id: get_field(changeset, :container_id),
          container_port: get_field(changeset, :container_port)
        })

      put_change(changeset, :lifecycle_state, Atom.to_string(lifecycle_state))
    end
  end
end

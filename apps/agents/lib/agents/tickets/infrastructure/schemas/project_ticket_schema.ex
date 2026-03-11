defmodule Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema do
  @moduledoc """
  Ecto schema for persisted session sidebar project tickets.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @sync_states ["synced", "pending_push", "sync_error"]
  @valid_states ["open", "closed"]
  @lifecycle_stages [
    "open",
    "ready",
    "in_progress",
    "in_review",
    "ci_testing",
    "deployed",
    "closed"
  ]

  @type t :: %__MODULE__{
          id: integer(),
          number: integer(),
          external_id: String.t() | nil,
          title: String.t(),
          body: String.t() | nil,
          status: String.t() | nil,
          state: String.t(),
          priority: String.t() | nil,
          size: String.t() | nil,
          labels: [String.t()],
          url: String.t() | nil,
          position: integer(),
          created_at: DateTime.t(),
          sync_state: String.t(),
          last_synced_at: DateTime.t() | nil,
          last_sync_error: String.t() | nil,
          remote_updated_at: DateTime.t() | nil,
          lifecycle_stage: String.t(),
          lifecycle_stage_entered_at: DateTime.t() | nil,
          parent_ticket_id: integer() | nil,
          task_id: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "sessions_project_tickets" do
    field(:number, :integer)
    field(:external_id, :string)
    field(:title, :string)
    field(:body, :string)
    field(:status, :string)
    field(:state, :string, default: "open")
    field(:priority, :string)
    field(:size, :string)
    field(:labels, {:array, :string}, default: [])
    field(:url, :string)
    field(:position, :integer, default: 0)
    field(:created_at, :utc_datetime)
    field(:sync_state, :string, default: "synced")
    field(:last_synced_at, :utc_datetime)
    field(:last_sync_error, :string)
    field(:remote_updated_at, :utc_datetime)
    field(:lifecycle_stage, :string, default: "open")
    field(:lifecycle_stage_entered_at, :utc_datetime)
    field(:task_id, Ecto.UUID)
    belongs_to(:parent_ticket, __MODULE__)
    has_many(:sub_tickets, __MODULE__, foreign_key: :parent_ticket_id)

    has_many(:lifecycle_events, Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema,
      foreign_key: :ticket_id
    )

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [
      :number,
      :external_id,
      :title,
      :body,
      :status,
      :state,
      :priority,
      :size,
      :labels,
      :url,
      :position,
      :created_at,
      :sync_state,
      :last_synced_at,
      :last_sync_error,
      :remote_updated_at,
      :lifecycle_stage,
      :lifecycle_stage_entered_at,
      :parent_ticket_id,
      :task_id
    ])
    |> validate_required([:number, :title])
    |> validate_inclusion(:sync_state, @sync_states)
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:lifecycle_stage, @lifecycle_stages)
    |> unique_constraint(:number)
    |> foreign_key_constraint(:task_id)
  end
end

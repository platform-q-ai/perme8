defmodule Agents.Sessions.Infrastructure.Schemas.ProjectTicketSchema do
  @moduledoc """
  Ecto schema for persisted session sidebar project tickets.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @sync_states ["synced", "pending_push", "sync_error"]
  @valid_states ["open", "closed"]

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
      :remote_updated_at
    ])
    |> validate_required([:number, :title])
    |> validate_inclusion(:sync_state, @sync_states)
    |> validate_inclusion(:state, @valid_states)
    |> unique_constraint(:number)
  end
end

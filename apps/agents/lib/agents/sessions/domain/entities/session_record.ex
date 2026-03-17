defmodule Agents.Sessions.Domain.Entities.SessionRecord do
  @moduledoc """
  Pure domain entity representing a persisted session record.

  This struct is the return type for `SessionRepositoryBehaviour` callbacks,
  decoupling the Application layer from Infrastructure schemas. It mirrors the
  persistence fields of the sessions table without depending on Ecto.

  Not to be confused with `Session`, which is a rich runtime/lifecycle view
  built from task data for SDK event tracking and UI state.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          user_id: String.t() | nil,
          title: String.t() | nil,
          status: String.t() | nil,
          container_id: String.t() | nil,
          container_port: integer() | nil,
          container_status: String.t() | nil,
          image: String.t() | nil,
          sdk_session_id: String.t() | nil,
          paused_at: DateTime.t() | nil,
          resumed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          task_count: non_neg_integer() | nil
        }

  defstruct [
    :id,
    :user_id,
    :title,
    :status,
    :container_id,
    :container_port,
    :container_status,
    :image,
    :sdk_session_id,
    :paused_at,
    :resumed_at,
    :inserted_at,
    :updated_at,
    :task_count
  ]

  @doc "Creates a new SessionRecord from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs), do: struct(__MODULE__, attrs)
end

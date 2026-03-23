defmodule Agents.Sessions.Domain.Entities.TicketSession do
  @moduledoc """
  Ticket-scoped session aggregate for long-lived container lifecycle.
  """

  @valid_states [:active, :idle, :suspended, :terminated]

  @type state :: :active | :idle | :suspended | :terminated

  @type t :: %__MODULE__{
          ticket_number: integer() | nil,
          session_id: String.t() | nil,
          state: state(),
          container_id: String.t() | nil,
          container_port: integer() | nil,
          last_activity_at: DateTime.t() | nil,
          suspended_at: DateTime.t() | nil,
          terminated_at: DateTime.t() | nil
        }

  defstruct [
    :ticket_number,
    :session_id,
    :container_id,
    :container_port,
    :last_activity_at,
    :suspended_at,
    :terminated_at,
    state: :idle
  ]

  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs), do: struct(__MODULE__, attrs)

  @spec valid_states() :: [state()]
  def valid_states, do: @valid_states

  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{state: :active}), do: true
  def active?(_), do: false

  @spec idle?(t()) :: boolean()
  def idle?(%__MODULE__{state: :idle}), do: true
  def idle?(_), do: false

  @spec suspended?(t()) :: boolean()
  def suspended?(%__MODULE__{state: :suspended}), do: true
  def suspended?(_), do: false

  @spec terminated?(t()) :: boolean()
  def terminated?(%__MODULE__{state: :terminated}), do: true
  def terminated?(_), do: false
end

defmodule Agents.Tickets.Domain.Entities.TicketLifecycleEvent do
  @moduledoc """
  Pure domain entity for ticket lifecycle transitions.
  """

  @type t :: %__MODULE__{
          id: integer() | nil,
          ticket_id: integer() | nil,
          from_stage: String.t() | nil,
          to_stage: String.t() | nil,
          transitioned_at: DateTime.t() | nil,
          trigger: String.t(),
          inserted_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :ticket_id,
    :from_stage,
    :to_stage,
    :transitioned_at,
    :inserted_at,
    trigger: "system"
  ]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @spec from_schema(struct()) :: t()
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      ticket_id: schema.ticket_id,
      from_stage: schema.from_stage,
      to_stage: schema.to_stage,
      transitioned_at: schema.transitioned_at,
      trigger: schema.trigger || "system",
      inserted_at: schema.inserted_at
    }
  end
end

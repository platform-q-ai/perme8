defmodule Agents.Pipeline.Domain.Entities.Transition do
  @moduledoc "Value object describing outcome-based routing from a stage."

  @type t :: %__MODULE__{
          on: String.t(),
          to_stage: String.t() | nil,
          reason: String.t() | nil,
          ticket_stage_override: String.t() | nil,
          ticket_reason: String.t() | nil,
          params: map()
        }

  defstruct [:on, :to_stage, :reason, :ticket_stage_override, :ticket_reason, params: %{}]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)
end

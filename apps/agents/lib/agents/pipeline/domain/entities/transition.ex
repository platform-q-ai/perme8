defmodule Agents.Pipeline.Domain.Entities.Transition do
  @moduledoc "Value object describing outcome-based routing from a stage."

  @type t :: %__MODULE__{
          on: String.t(),
          to_stage: String.t() | nil,
          reason: String.t() | nil,
          params: map()
        }

  defstruct [:on, :to_stage, :reason, params: %{}]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)
end

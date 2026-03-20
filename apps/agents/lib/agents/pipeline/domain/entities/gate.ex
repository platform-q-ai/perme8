defmodule Agents.Pipeline.Domain.Entities.Gate do
  @moduledoc """
  Value object representing a stage gate.
  """

  @type t :: %__MODULE__{
          type: String.t(),
          required: boolean(),
          params: map()
        }

  defstruct [:type, required: true, params: %{}]

  @doc "Builds a gate value object from attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)
end

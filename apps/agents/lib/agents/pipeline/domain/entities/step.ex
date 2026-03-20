defmodule Agents.Pipeline.Domain.Entities.Step do
  @moduledoc """
  Value object representing a single pipeline step.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          run: String.t(),
          timeout_seconds: pos_integer() | nil,
          retries: non_neg_integer(),
          env: map()
        }

  defstruct [:name, :run, :timeout_seconds, retries: 0, env: %{}]

  @doc "Builds a step value object from attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)
end

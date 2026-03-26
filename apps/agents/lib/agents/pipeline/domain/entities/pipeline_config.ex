defmodule Agents.Pipeline.Domain.Entities.PipelineConfig do
  @moduledoc """
  Aggregate root for parsed pipeline configuration.
  """

  alias Agents.Pipeline.Domain.Entities.Stage

  @type t :: %__MODULE__{
          version: integer(),
          name: String.t(),
          description: String.t() | nil,
          stages: [Stage.t()],
          merge_queue: map()
        }

  defstruct [:version, :name, :description, stages: [], merge_queue: %{}]

  @doc "Builds a pipeline config value object from attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)
end

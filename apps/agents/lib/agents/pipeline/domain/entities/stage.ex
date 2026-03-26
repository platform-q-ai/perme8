defmodule Agents.Pipeline.Domain.Entities.Stage do
  @moduledoc """
  Value object representing a pipeline stage.
  """

  alias Agents.Pipeline.Domain.Entities.{Gate, Step}

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          schedule: map() | nil,
          triggers: [String.t()],
          depends_on: [String.t()],
          ticket_concurrency: non_neg_integer() | nil,
          config: map(),
          steps: [Step.t()],
          gates: [Gate.t()]
        }

  defstruct [
    :id,
    :type,
    :schedule,
    :ticket_concurrency,
    triggers: [],
    depends_on: [],
    config: %{},
    steps: [],
    gates: []
  ]

  @doc "Builds a stage value object from attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)
end

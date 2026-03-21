defmodule Agents.Pipeline.Domain.Entities.Stage do
  @moduledoc """
  Value object representing a pipeline stage.
  """

  alias Agents.Pipeline.Domain.Entities.{Gate, Step}

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          deploy_target: String.t() | nil,
          schedule: map() | nil,
          config: map(),
          steps: [Step.t()],
          gates: [Gate.t()]
        }

  defstruct [:id, :type, :deploy_target, :schedule, config: %{}, steps: [], gates: []]

  @doc "Builds a stage value object from attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)
end

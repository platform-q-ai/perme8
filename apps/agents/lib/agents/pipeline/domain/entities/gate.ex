defmodule Agents.Pipeline.Domain.Entities.Gate do
  @moduledoc """
  Pure domain entity representing entry conditions (gate) for a pipeline stage.

  A gate specifies what must pass before a stage can run — required dependency
  stages and optional change path filters. No infrastructure dependencies.
  """

  @type t :: %__MODULE__{
          requires: [String.t()],
          evaluation: String.t(),
          changes_in: [String.t()]
        }

  defstruct requires: [],
            evaluation: "all_of",
            changes_in: []

  @doc "Creates a new Gate from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @doc "Returns true when the gate has no requirements or change filters."
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{requires: [], changes_in: []}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc "Returns the list of required dependency stage names."
  @spec dependency_names(t()) :: [String.t()]
  def dependency_names(%__MODULE__{requires: requires}), do: requires
end

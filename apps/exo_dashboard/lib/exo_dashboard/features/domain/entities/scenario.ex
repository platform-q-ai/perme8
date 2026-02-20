defmodule ExoDashboard.Features.Domain.Entities.Scenario do
  @moduledoc """
  Pure domain entity representing a Gherkin scenario.

  Supports both Scenario and Scenario Outline keywords,
  with optional examples for outline expansion.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          keyword: String.t() | nil,
          description: String.t() | nil,
          tags: [String.t()],
          steps: list(),
          examples: list() | nil,
          location: map() | nil
        }

  defstruct [
    :id,
    :name,
    :keyword,
    :description,
    :examples,
    :location,
    tags: [],
    steps: []
  ]

  @doc "Creates a new Scenario from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs), do: struct(__MODULE__, attrs)
  def new(attrs) when is_map(attrs), do: struct(__MODULE__, attrs)
end

defmodule ExoDashboard.Features.Domain.Entities.Rule do
  @moduledoc """
  Pure domain entity representing a Gherkin Rule.

  A Rule groups related scenarios under a business rule description.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          tags: [String.t()],
          children: list()
        }

  defstruct [
    :id,
    :name,
    :description,
    tags: [],
    children: []
  ]

  @doc "Creates a new Rule from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs), do: struct(__MODULE__, attrs)
  def new(attrs) when is_map(attrs), do: struct(__MODULE__, attrs)
end

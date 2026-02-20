defmodule ExoDashboard.Features.Domain.Entities.Step do
  @moduledoc """
  Pure domain entity representing a Gherkin step.

  Each step has a keyword (Given/When/Then/And/But),
  text description, and optional data table or doc string.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          keyword: String.t() | nil,
          keyword_type: String.t() | nil,
          text: String.t() | nil,
          location: map() | nil,
          data_table: list() | nil,
          doc_string: map() | nil
        }

  defstruct [
    :id,
    :keyword,
    :keyword_type,
    :text,
    :location,
    :data_table,
    :doc_string
  ]

  @doc "Creates a new Step from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs), do: struct(__MODULE__, attrs)
  def new(attrs) when is_map(attrs), do: struct(__MODULE__, attrs)
end

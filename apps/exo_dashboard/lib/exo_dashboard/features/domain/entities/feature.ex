defmodule ExoDashboard.Features.Domain.Entities.Feature do
  @moduledoc """
  Pure domain entity representing a Gherkin feature file.

  Contains the parsed structure of a .feature file including
  its scenarios, rules, tags, and metadata.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          uri: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          tags: [String.t()],
          app: String.t() | nil,
          adapter: atom() | nil,
          language: String.t() | nil,
          children: list()
        }

  defstruct [
    :id,
    :uri,
    :name,
    :description,
    :app,
    :adapter,
    :language,
    tags: [],
    children: []
  ]

  @doc "Creates a new Feature from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) do
    struct(__MODULE__, attrs)
  end

  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end
end

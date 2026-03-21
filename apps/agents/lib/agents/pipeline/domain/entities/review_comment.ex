defmodule Agents.Pipeline.Domain.Entities.ReviewComment do
  @moduledoc "Pure domain entity for internal PR review comments."

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          pull_request_id: Ecto.UUID.t() | nil,
          author_id: String.t() | nil,
          body: String.t() | nil,
          path: String.t() | nil,
          line: integer() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :pull_request_id,
    :author_id,
    :body,
    :path,
    :line,
    :inserted_at,
    :updated_at
  ]

  @spec new(map()) :: t()
  def new(attrs), do: struct(__MODULE__, attrs)

  @spec from_schema(struct()) :: t()
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      pull_request_id: schema.pull_request_id,
      author_id: schema.author_id,
      body: schema.body,
      path: schema.path,
      line: schema.line,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end

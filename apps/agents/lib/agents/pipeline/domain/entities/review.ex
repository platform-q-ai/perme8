defmodule Agents.Pipeline.Domain.Entities.Review do
  @moduledoc "Pure domain entity for internal PR reviews."

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          pull_request_id: Ecto.UUID.t() | nil,
          author_id: String.t() | nil,
          event: String.t() | nil,
          body: String.t() | nil,
          submitted_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :pull_request_id,
    :author_id,
    :event,
    :body,
    :submitted_at,
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
      event: schema.event,
      body: schema.body,
      submitted_at: schema.submitted_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end

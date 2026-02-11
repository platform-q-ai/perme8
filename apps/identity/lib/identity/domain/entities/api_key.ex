defmodule Identity.Domain.Entities.ApiKey do
  @moduledoc """
  Pure domain entity for API keys.

  This is a value object representing an API key in the business domain.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Identity.Infrastructure.Schemas.ApiKeySchema.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          description: String.t() | nil,
          hashed_token: String.t(),
          user_id: String.t(),
          workspace_access: [String.t()],
          is_active: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :name,
    :description,
    :hashed_token,
    :user_id,
    :workspace_access,
    :is_active,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates a new ApiKey domain entity from attributes.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      name: schema.name,
      description: schema.description,
      hashed_token: schema.hashed_token,
      user_id: schema.user_id,
      workspace_access: schema.workspace_access || [],
      is_active: schema.is_active,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end
end

# Implement Inspect protocol to redact sensitive fields
defimpl Inspect, for: Identity.Domain.Entities.ApiKey do
  import Inspect.Algebra

  def inspect(api_key, opts) do
    # Redact hashed_token field
    api_key_map =
      api_key
      |> Map.from_struct()
      |> Map.update(:hashed_token, nil, fn
        nil -> nil
        _hashed -> "**redacted**"
      end)

    concat(["#Identity.Domain.Entities.ApiKey<", to_doc(api_key_map, opts), ">"])
  end
end

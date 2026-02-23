defmodule Webhooks.Domain.Entities.Subscription do
  @moduledoc """
  Domain entity representing an outbound webhook subscription.

  Pure data structure with no external dependencies.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          url: String.t() | nil,
          secret: String.t() | nil,
          event_types: [String.t()],
          is_active: boolean(),
          workspace_id: String.t() | nil,
          created_by_id: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :url,
    :secret,
    :workspace_id,
    :created_by_id,
    :inserted_at,
    :updated_at,
    event_types: [],
    is_active: true
  ]

  @doc "Creates a new Subscription from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.get(attrs, :id),
      url: Map.get(attrs, :url),
      secret: Map.get(attrs, :secret),
      event_types: Map.get(attrs, :event_types, []),
      is_active: Map.get(attrs, :is_active, true),
      workspace_id: Map.get(attrs, :workspace_id),
      created_by_id: Map.get(attrs, :created_by_id),
      inserted_at: Map.get(attrs, :inserted_at),
      updated_at: Map.get(attrs, :updated_at)
    }
  end

  @doc "Converts an infrastructure schema map/struct to a domain entity."
  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    new(%{
      id: Map.get(schema, :id),
      url: Map.get(schema, :url),
      secret: Map.get(schema, :secret),
      event_types: Map.get(schema, :event_types, []),
      is_active: Map.get(schema, :is_active, true),
      workspace_id: Map.get(schema, :workspace_id),
      created_by_id: Map.get(schema, :created_by_id),
      inserted_at: Map.get(schema, :inserted_at),
      updated_at: Map.get(schema, :updated_at)
    })
  end

  @doc "Returns whether the subscription is active."
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{is_active: is_active}), do: is_active == true
end

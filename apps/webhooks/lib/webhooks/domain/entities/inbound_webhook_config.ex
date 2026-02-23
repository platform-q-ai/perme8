defmodule Webhooks.Domain.Entities.InboundWebhookConfig do
  @moduledoc """
  Domain entity representing an inbound webhook configuration for a workspace.

  Stores the shared secret used to verify HMAC signatures on incoming
  webhook requests.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t() | nil,
          secret: String.t() | nil,
          is_active: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :workspace_id,
    :secret,
    :inserted_at,
    :updated_at,
    is_active: true
  ]

  @doc "Creates a new InboundWebhookConfig from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.get(attrs, :id),
      workspace_id: Map.get(attrs, :workspace_id),
      secret: Map.get(attrs, :secret),
      is_active: Map.get(attrs, :is_active, true),
      inserted_at: Map.get(attrs, :inserted_at),
      updated_at: Map.get(attrs, :updated_at)
    }
  end

  @doc "Converts an infrastructure schema map/struct to a domain entity."
  @spec from_schema(map()) :: t()
  def from_schema(schema) when is_map(schema) do
    new(%{
      id: Map.get(schema, :id),
      workspace_id: Map.get(schema, :workspace_id),
      secret: Map.get(schema, :secret),
      is_active: Map.get(schema, :is_active, true),
      inserted_at: Map.get(schema, :inserted_at),
      updated_at: Map.get(schema, :updated_at)
    })
  end
end

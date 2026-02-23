defmodule Webhooks.Domain.Entities.InboundLog do
  @moduledoc """
  Domain entity representing an inbound webhook log entry.

  Records details of received webhook requests including
  signature validation status and handler results.
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          workspace_id: String.t() | nil,
          event_type: String.t() | nil,
          payload: map() | nil,
          source_ip: String.t() | nil,
          signature_valid: boolean(),
          handler_result: String.t() | nil,
          received_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :workspace_id,
    :event_type,
    :payload,
    :source_ip,
    :handler_result,
    :received_at,
    :inserted_at,
    :updated_at,
    signature_valid: false
  ]

  @doc "Creates a new InboundLog from a map of attributes."
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      id: Map.get(attrs, :id),
      workspace_id: Map.get(attrs, :workspace_id),
      event_type: Map.get(attrs, :event_type),
      payload: Map.get(attrs, :payload),
      source_ip: Map.get(attrs, :source_ip),
      signature_valid: Map.get(attrs, :signature_valid, false),
      handler_result: Map.get(attrs, :handler_result),
      received_at: Map.get(attrs, :received_at),
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
      event_type: Map.get(schema, :event_type),
      payload: Map.get(schema, :payload),
      source_ip: Map.get(schema, :source_ip),
      signature_valid: Map.get(schema, :signature_valid, false),
      handler_result: Map.get(schema, :handler_result),
      received_at: Map.get(schema, :received_at),
      inserted_at: Map.get(schema, :inserted_at),
      updated_at: Map.get(schema, :updated_at)
    })
  end
end

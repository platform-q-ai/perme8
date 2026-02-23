defmodule Webhooks.Infrastructure.Schemas.InboundLogSchema do
  @moduledoc """
  Ecto schema for inbound webhook log entries.

  Maps to the `inbound_webhook_logs` database table.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Webhooks.Domain.Entities.InboundLog

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inbound_webhook_logs" do
    field(:workspace_id, :binary_id)
    field(:event_type, :string)
    field(:payload, :map, default: %{})
    field(:source_ip, :string)
    field(:signature_valid, :boolean, default: false)
    field(:handler_result, :string)
    field(:received_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating an inbound webhook log entry."
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :workspace_id,
      :event_type,
      :payload,
      :source_ip,
      :signature_valid,
      :handler_result,
      :received_at
    ])
    |> validate_required([:workspace_id, :received_at])
  end

  @doc "Converts a schema struct to a domain InboundLog entity."
  def to_entity(%__MODULE__{} = schema) do
    InboundLog.from_schema(%{
      id: schema.id,
      workspace_id: schema.workspace_id,
      event_type: schema.event_type,
      payload: schema.payload,
      source_ip: schema.source_ip,
      signature_valid: schema.signature_valid,
      handler_result: schema.handler_result,
      received_at: schema.received_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end
end

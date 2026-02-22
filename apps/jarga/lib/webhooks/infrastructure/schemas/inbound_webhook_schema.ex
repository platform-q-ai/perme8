defmodule Jarga.Webhooks.Infrastructure.Schemas.InboundWebhookSchema do
  @moduledoc """
  Ecto schema for inbound webhooks database persistence.

  Domain entity: Jarga.Webhooks.Domain.Entities.InboundWebhook
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inbound_webhooks" do
    field(:workspace_id, :binary_id)
    field(:event_type, :string)
    field(:payload, :map)
    field(:source_ip, :string)
    field(:signature_valid, :boolean, default: false)
    field(:handler_result, :string)
    field(:received_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating an inbound webhook record.
  """
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
end

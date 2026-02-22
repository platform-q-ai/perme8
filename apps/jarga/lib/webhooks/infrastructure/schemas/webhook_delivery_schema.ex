defmodule Jarga.Webhooks.Infrastructure.Schemas.WebhookDeliverySchema do
  @moduledoc """
  Ecto schema for webhook deliveries database persistence.

  Domain entity: Jarga.Webhooks.Domain.Entities.WebhookDelivery
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ["pending", "success", "failed"]

  schema "webhook_deliveries" do
    field(:event_type, :string)
    field(:payload, :map)
    field(:status, :string, default: "pending")
    field(:response_code, :integer)
    field(:response_body, :string)
    field(:attempts, :integer, default: 0)
    field(:max_attempts, :integer, default: 5)
    field(:next_retry_at, :utc_datetime)
    field(:webhook_subscription_id, :binary_id)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a webhook delivery.
  """
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :webhook_subscription_id,
      :event_type,
      :payload,
      :status,
      :response_code,
      :response_body,
      :attempts,
      :max_attempts,
      :next_retry_at
    ])
    |> validate_required([:webhook_subscription_id, :event_type, :payload])
    |> validate_inclusion(:status, @valid_statuses)
  end
end

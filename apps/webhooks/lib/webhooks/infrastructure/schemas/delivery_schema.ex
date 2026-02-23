defmodule Webhooks.Infrastructure.Schemas.DeliverySchema do
  @moduledoc """
  Ecto schema for webhook delivery records.

  Maps to the `webhook_deliveries` database table.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Webhooks.Domain.Entities.Delivery
  alias Webhooks.Infrastructure.Schemas.SubscriptionSchema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_deliveries" do
    field(:event_type, :string)
    field(:payload, :map, default: %{})
    field(:status, :string, default: "pending")
    field(:response_code, :integer)
    field(:response_body, :string)
    field(:attempts, :integer, default: 0)
    field(:max_attempts, :integer, default: 5)
    field(:next_retry_at, :utc_datetime)

    belongs_to(:subscription, SubscriptionSchema)

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(pending success failed)

  @doc "Changeset for creating or updating a webhook delivery."
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :subscription_id,
      :event_type,
      :payload,
      :status,
      :response_code,
      :response_body,
      :attempts,
      :max_attempts,
      :next_retry_at
    ])
    |> validate_required([:subscription_id, :event_type])
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:subscription_id)
  end

  @doc "Converts a schema struct to a domain Delivery entity."
  def to_entity(%__MODULE__{} = schema) do
    Delivery.from_schema(%{
      id: schema.id,
      subscription_id: schema.subscription_id,
      event_type: schema.event_type,
      payload: schema.payload,
      status: schema.status,
      response_code: schema.response_code,
      response_body: schema.response_body,
      attempts: schema.attempts,
      max_attempts: schema.max_attempts,
      next_retry_at: schema.next_retry_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end
end

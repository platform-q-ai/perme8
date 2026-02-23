defmodule Webhooks.Infrastructure.Schemas.SubscriptionSchema do
  @moduledoc """
  Ecto schema for outbound webhook subscriptions.

  Maps to the `webhook_subscriptions` database table.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Webhooks.Domain.Entities.Subscription

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_subscriptions" do
    field(:url, :string)
    field(:secret, :string)
    field(:event_types, {:array, :string}, default: [])
    field(:is_active, :boolean, default: true)
    field(:workspace_id, :binary_id)
    field(:created_by_id, :binary_id)

    timestamps(type: :utc_datetime)
  end

  @doc "Changeset for creating or updating a webhook subscription."
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:url, :secret, :event_types, :is_active, :workspace_id, :created_by_id])
    |> validate_required([:url, :secret, :workspace_id])
    |> validate_format(:url, ~r/^https?:\/\/.+/,
      message: "must be a valid URL starting with http:// or https://"
    )
  end

  @doc "Converts a schema struct to a domain Subscription entity."
  def to_entity(%__MODULE__{} = schema) do
    Subscription.from_schema(%{
      id: schema.id,
      url: schema.url,
      secret: schema.secret,
      event_types: schema.event_types,
      is_active: schema.is_active,
      workspace_id: schema.workspace_id,
      created_by_id: schema.created_by_id,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    })
  end
end

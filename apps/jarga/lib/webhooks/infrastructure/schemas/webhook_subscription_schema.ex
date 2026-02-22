defmodule Jarga.Webhooks.Infrastructure.Schemas.WebhookSubscriptionSchema do
  @moduledoc """
  Ecto schema for webhook subscriptions database persistence.

  Domain entity: Jarga.Webhooks.Domain.Entities.WebhookSubscription
  """

  use Ecto.Schema
  import Ecto.Changeset

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

  @doc """
  Changeset for creating or updating a webhook subscription.
  """
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:url, :secret, :event_types, :is_active, :workspace_id, :created_by_id])
    |> validate_required([:url, :secret, :workspace_id])
    |> validate_format(:url, ~r/^https?:\/\/.+/,
      message: "must be a valid URL starting with http:// or https://"
    )
  end
end

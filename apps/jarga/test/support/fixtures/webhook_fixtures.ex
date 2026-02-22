defmodule Jarga.WebhookFixtures do
  @moduledoc """
  Test helpers for creating webhook entities.

  Uses infrastructure schemas + Repo for database-backed fixtures.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Webhooks.Infrastructure,
      Identity.Repo
    ],
    exports: []

  alias Identity.Repo
  alias Jarga.Webhooks.Infrastructure.Schemas.WebhookSubscriptionSchema
  alias Jarga.Webhooks.Infrastructure.Schemas.WebhookDeliverySchema
  alias Jarga.Webhooks.Infrastructure.Schemas.InboundWebhookSchema

  @doc """
  Creates a webhook subscription in the database.

  ## Options

  Accepts any field from the schema. Defaults are provided for all required fields.
  `workspace_id` is required (no default workspace).
  """
  def webhook_subscription_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        url: "https://example.com/webhook/#{System.unique_integer([:positive])}",
        secret: :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false),
        event_types: ["projects.project_created"],
        is_active: true
      })

    %WebhookSubscriptionSchema{}
    |> WebhookSubscriptionSchema.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Creates a webhook delivery in the database.

  Requires `webhook_subscription_id` in attrs.
  """
  def webhook_delivery_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        event_type: "projects.project_created",
        payload: %{"project_id" => Ecto.UUID.generate()},
        status: "pending",
        attempts: 0,
        max_attempts: 5
      })

    %WebhookDeliverySchema{}
    |> WebhookDeliverySchema.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Creates an inbound webhook in the database.

  Requires `workspace_id` in attrs.
  """
  def inbound_webhook_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        event_type: "external.payment_received",
        payload: %{"amount" => 100},
        source_ip: "192.168.1.1",
        signature_valid: true,
        handler_result: "processed",
        received_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    %InboundWebhookSchema{}
    |> InboundWebhookSchema.changeset(attrs)
    |> Repo.insert!()
  end
end

defmodule Jarga.Webhooks.Infrastructure.Queries.DeliveryQueries do
  @moduledoc """
  Query objects for webhook deliveries.

  All functions return Ecto queryables (not results).
  """

  import Ecto.Query, warn: false

  alias Jarga.Webhooks.Infrastructure.Schemas.WebhookDeliverySchema

  @doc "Base query for webhook deliveries."
  def base do
    WebhookDeliverySchema
  end

  @doc "Filters deliveries by webhook_subscription_id."
  def for_subscription(query \\ base(), subscription_id) do
    from(d in query, where: d.webhook_subscription_id == ^subscription_id)
  end

  @doc "Filters by delivery id."
  def by_id(query \\ base(), id) do
    from(d in query, where: d.id == ^id)
  end

  @doc """
  Filters deliveries that are pending and ready for retry.

  Returns deliveries where status is "pending" and next_retry_at <= now.
  """
  def pending_retries(query \\ base()) do
    now = DateTime.utc_now()

    from(d in query,
      where:
        d.status == "pending" and
          not is_nil(d.next_retry_at) and
          d.next_retry_at <= ^now
    )
  end

  @doc "Orders deliveries by inserted_at desc."
  def ordered(query \\ base()) do
    from(d in query, order_by: [desc: d.inserted_at])
  end
end

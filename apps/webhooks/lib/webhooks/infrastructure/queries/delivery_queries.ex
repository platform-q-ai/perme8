defmodule Webhooks.Infrastructure.Queries.DeliveryQueries do
  @moduledoc """
  Query objects for webhook delivery queries.

  Provides composable, pipeline-friendly query functions.
  """

  import Ecto.Query, warn: false

  @doc "Filters deliveries by subscription_id."
  def for_subscription(query, subscription_id) do
    from(d in query, where: d.subscription_id == ^subscription_id)
  end

  @doc "Filters by delivery ID."
  def by_id(query, id) do
    from(d in query, where: d.id == ^id)
  end

  @doc "Filters deliveries by workspace_id via join through webhook_subscriptions."
  def for_workspace(query, workspace_id) do
    from(d in query,
      join: s in Webhooks.Infrastructure.Schemas.SubscriptionSchema,
      on: d.subscription_id == s.id,
      where: s.workspace_id == ^workspace_id
    )
  end

  @doc """
  Filters deliveries that are pending and due for retry.

  Finds deliveries where status is "pending" and next_retry_at <= now.
  """
  def pending_retries(query) do
    now = DateTime.utc_now()

    from(d in query,
      where: d.status == "pending" and not is_nil(d.next_retry_at) and d.next_retry_at <= ^now
    )
  end

  @doc "Orders deliveries by inserted_at descending (newest first)."
  def ordered(query) do
    from(d in query, order_by: [desc: d.inserted_at])
  end

  @doc "Limits the number of results returned."
  def limit(query, max) do
    from(d in query, limit: ^max)
  end
end

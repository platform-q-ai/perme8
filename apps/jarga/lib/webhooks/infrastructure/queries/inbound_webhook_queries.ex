defmodule Jarga.Webhooks.Infrastructure.Queries.InboundWebhookQueries do
  @moduledoc """
  Query objects for inbound webhooks.

  All functions return Ecto queryables (not results).
  """

  import Ecto.Query, warn: false

  alias Jarga.Webhooks.Infrastructure.Schemas.InboundWebhookSchema

  @doc "Base query for inbound webhooks."
  def base do
    InboundWebhookSchema
  end

  @doc "Filters inbound webhooks by workspace_id."
  def for_workspace(query \\ base(), workspace_id) do
    from(iw in query, where: iw.workspace_id == ^workspace_id)
  end

  @doc "Orders by received_at desc."
  def ordered(query \\ base()) do
    from(iw in query, order_by: [desc: iw.received_at])
  end
end

defmodule Jarga.Webhooks.Infrastructure.Queries.InboundWebhookConfigQueries do
  @moduledoc """
  Query objects for inbound webhook configurations.

  All functions return Ecto queryables (not results).
  """

  import Ecto.Query, warn: false

  alias Jarga.Webhooks.Infrastructure.Schemas.InboundWebhookConfigSchema

  @doc "Base query for inbound webhook configs."
  def base do
    InboundWebhookConfigSchema
  end

  @doc "Filters configs by workspace_id."
  def for_workspace(query \\ base(), workspace_id) do
    from(c in query, where: c.workspace_id == ^workspace_id)
  end
end

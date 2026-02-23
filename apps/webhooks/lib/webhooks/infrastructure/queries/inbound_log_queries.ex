defmodule Webhooks.Infrastructure.Queries.InboundLogQueries do
  @moduledoc """
  Query objects for inbound webhook log queries.

  Provides composable, pipeline-friendly query functions.
  """

  import Ecto.Query, warn: false

  @doc "Filters logs by workspace_id."
  def for_workspace(query, workspace_id) do
    from(l in query, where: l.workspace_id == ^workspace_id)
  end

  @doc "Orders logs by received_at descending (most recent first)."
  def ordered(query) do
    from(l in query, order_by: [desc: l.received_at])
  end
end

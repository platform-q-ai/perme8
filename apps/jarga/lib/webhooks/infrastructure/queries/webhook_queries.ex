defmodule Jarga.Webhooks.Infrastructure.Queries.WebhookQueries do
  @moduledoc """
  Query objects for webhook subscriptions.

  All functions return Ecto queryables (not results).
  """

  import Ecto.Query, warn: false

  alias Jarga.Webhooks.Infrastructure.Schemas.WebhookSubscriptionSchema

  @doc "Base query for webhook subscriptions."
  def base do
    WebhookSubscriptionSchema
  end

  @doc "Filters subscriptions by workspace_id."
  def for_workspace(query \\ base(), workspace_id) do
    from(s in query, where: s.workspace_id == ^workspace_id)
  end

  @doc "Filters to only active subscriptions."
  def active(query \\ base()) do
    from(s in query, where: s.is_active == true)
  end

  @doc """
  Filters active subscriptions for a workspace that match the given event_type.

  A subscription matches if:
  - It is active
  - It belongs to the workspace
  - The event_type is contained in its event_types array OR event_types is empty (wildcard)
  """
  def active_for_event(workspace_id, event_type) do
    from(s in base(),
      where:
        s.workspace_id == ^workspace_id and
          s.is_active == true and
          (^event_type in s.event_types or s.event_types == ^[])
    )
  end

  @doc "Filters by subscription id."
  def by_id(query \\ base(), id) do
    from(s in query, where: s.id == ^id)
  end
end

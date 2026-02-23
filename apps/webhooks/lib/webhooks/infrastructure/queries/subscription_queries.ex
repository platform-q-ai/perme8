defmodule Webhooks.Infrastructure.Queries.SubscriptionQueries do
  @moduledoc """
  Query objects for webhook subscription queries.

  Provides composable, pipeline-friendly query functions.
  """

  import Ecto.Query, warn: false

  @doc "Filters subscriptions by workspace_id."
  def for_workspace(query, workspace_id) do
    from(s in query, where: s.workspace_id == ^workspace_id)
  end

  @doc "Filters only active subscriptions."
  def active(query) do
    from(s in query, where: s.is_active == true)
  end

  @doc "Filters by subscription ID."
  def by_id(query, id) do
    from(s in query, where: s.id == ^id)
  end

  @doc "Filters by ID and workspace_id."
  def by_id_and_workspace(query, id, workspace_id) do
    from(s in query, where: s.id == ^id and s.workspace_id == ^workspace_id)
  end

  @doc """
  Filters subscriptions whose event_types array contains the given event_type.

  Uses PostgreSQL's ANY() array operator.
  """
  def matching_event_type(query, event_type) do
    from(s in query, where: fragment("? = ANY(?)", ^event_type, s.event_types))
  end
end

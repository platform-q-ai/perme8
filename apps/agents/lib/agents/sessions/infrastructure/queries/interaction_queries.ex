defmodule Agents.Sessions.Infrastructure.Queries.InteractionQueries do
  @moduledoc """
  Composable Ecto query functions for session interactions.
  """

  import Ecto.Query, warn: false

  alias Agents.Sessions.Infrastructure.Schemas.InteractionSchema

  def base do
    from(i in InteractionSchema, as: :interaction)
  end

  def for_session(query, session_id) do
    from([interaction: i] in query, where: i.session_id == ^session_id)
  end

  def by_type(query, type) do
    from([interaction: i] in query, where: i.type == ^type)
  end

  def by_correlation_id(query, correlation_id) do
    from([interaction: i] in query, where: i.correlation_id == ^correlation_id)
  end

  def pending(query) do
    from([interaction: i] in query, where: i.status == "pending")
  end

  def chronological(query) do
    from([interaction: i] in query, order_by: [asc: i.inserted_at])
  end

  @doc "Returns the latest pending question for a session."
  def latest_pending_question(session_id) do
    base()
    |> for_session(session_id)
    |> by_type("question")
    |> pending()
    |> from(order_by: [desc: :inserted_at], limit: 1)
  end
end

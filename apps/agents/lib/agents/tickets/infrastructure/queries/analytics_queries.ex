defmodule Agents.Tickets.Infrastructure.Queries.AnalyticsQueries do
  @moduledoc """
  Composable Ecto query objects for ticket lifecycle analytics aggregation.
  """

  import Ecto.Query

  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema

  @doc "Returns all tickets as maps with :id and :lifecycle_stage."
  @spec all_tickets() :: Ecto.Query.t()
  def all_tickets do
    from(t in ProjectTicketSchema,
      select: %{id: t.id, lifecycle_stage: t.lifecycle_stage}
    )
  end

  @doc "Returns lifecycle events within a date range, ordered by transitioned_at."
  @spec lifecycle_events_in_range(Date.t(), Date.t()) :: Ecto.Query.t()
  def lifecycle_events_in_range(date_from, date_to) do
    from_dt = date_to_datetime(date_from)
    to_dt = date_to_end_of_day(date_to)

    from(e in TicketLifecycleEventSchema,
      where: e.transitioned_at >= ^from_dt and e.transitioned_at <= ^to_dt,
      order_by: [asc: e.transitioned_at],
      select: %{
        id: e.id,
        ticket_id: e.ticket_id,
        from_stage: e.from_stage,
        to_stage: e.to_stage,
        transitioned_at: e.transitioned_at,
        trigger: e.trigger
      }
    )
  end

  defp date_to_datetime(%Date{} = date) do
    DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  end

  defp date_to_end_of_day(%Date{} = date) do
    DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
  end
end

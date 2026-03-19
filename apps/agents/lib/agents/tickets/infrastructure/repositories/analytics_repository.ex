defmodule Agents.Tickets.Infrastructure.Repositories.AnalyticsRepository do
  @moduledoc """
  Data access layer for analytics queries. Executes query objects via Agents.Repo.
  """

  alias Agents.Tickets.Infrastructure.Queries.AnalyticsQueries

  @default_repo Agents.Repo

  @doc """
  Fetches raw analytics data: all tickets and lifecycle events within a date range.

  ## Options

    * `:date_from` - Start date (required)
    * `:date_to` - End date (required)
    * `:repo` - Ecto Repo module (default: Agents.Repo)

  Returns `%{tickets: [map], events: [map]}`.
  """
  @spec get_analytics_data(keyword()) :: %{tickets: [map()], events: [map()]}
  def get_analytics_data(opts) do
    repo = Keyword.get(opts, :repo, @default_repo)
    date_from = Keyword.fetch!(opts, :date_from)
    date_to = Keyword.fetch!(opts, :date_to)

    tickets = repo.all(AnalyticsQueries.all_tickets())
    events = repo.all(AnalyticsQueries.lifecycle_events_in_range(date_from, date_to))

    %{tickets: tickets, events: events}
  end
end

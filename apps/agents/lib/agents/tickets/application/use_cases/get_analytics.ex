defmodule Agents.Tickets.Application.UseCases.GetAnalytics do
  @moduledoc """
  Orchestrates analytics retrieval by coordinating infrastructure queries
  and domain policies.

  This is a read-only use case — it does not emit domain events.
  """

  alias Agents.Tickets.Domain.Policies.AnalyticsPolicy

  @default_analytics_repo Agents.Tickets.Infrastructure.Repositories.AnalyticsRepository

  @doc """
  Fetches and computes analytics for ticket lifecycle events.

  ## Options

    * `:date_from` - Start date (default: 30 days ago)
    * `:date_to` - End date (default: today)
    * `:granularity` - Time bucketing: `:daily` | `:weekly` | `:monthly` (default: `:daily`)
    * `:analytics_repo` - Repository module for analytics data (default: AnalyticsRepository)

  ## Returns

    `{:ok, analytics}` where analytics contains:
    - `summary` — `%{total, open, avg_cycle_time_seconds, completed}`
    - `distribution` — `%{stage => count}` for bar chart
    - `throughput` — `[%{bucket, stage, count}]` for trend line chart
    - `cycle_times` — `[%{bucket, stage, avg_seconds}]` for cycle time chart
    - `buckets` — `[Date.t()]` time bucket dates
    - `granularity` — the applied granularity atom
    - `date_from` — the applied start date
    - `date_to` — the applied end date
  """
  @spec execute(keyword()) :: {:ok, map()}
  def execute(opts \\ []) do
    analytics_repo = Keyword.get(opts, :analytics_repo, @default_analytics_repo)
    granularity = Keyword.get(opts, :granularity, :daily)
    date_to = Keyword.get(opts, :date_to, Date.utc_today())
    date_from = Keyword.get(opts, :date_from, Date.add(date_to, -30))
    date_range = {date_from, date_to}

    raw_data = analytics_repo.get_analytics_data(date_from: date_from, date_to: date_to)

    tickets = raw_data.tickets
    events = raw_data.events

    distribution = AnalyticsPolicy.count_by_stage(tickets)
    summary = AnalyticsPolicy.summarize(tickets, events, date_range)
    throughput = AnalyticsPolicy.bucket_transitions(events, granularity, date_range)
    cycle_times = AnalyticsPolicy.bucket_cycle_times(events, granularity, date_range)
    buckets = AnalyticsPolicy.time_buckets(date_from, date_to, granularity)

    {:ok,
     %{
       summary: summary,
       distribution: distribution,
       throughput: throughput,
       cycle_times: cycle_times,
       buckets: buckets,
       granularity: granularity,
       date_from: date_from,
       date_to: date_to
     }}
  end
end

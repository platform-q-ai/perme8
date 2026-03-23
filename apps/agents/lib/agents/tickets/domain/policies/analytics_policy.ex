defmodule Agents.Tickets.Domain.Policies.AnalyticsPolicy do
  @moduledoc """
  Pure aggregation logic for ticket lifecycle analytics.

  All functions operate on domain entity structs or plain data —
  no I/O, no Repo.
  """

  @valid_stages [
    "open",
    "ready",
    "in_progress",
    "in_review",
    "ci_testing",
    "merge_queue",
    "deployed",
    "closed"
  ]

  @doc """
  Counts tickets grouped by their current lifecycle_stage.

  Returns a map with all valid stages, defaulting to 0 for stages with no tickets.
  """
  @spec count_by_stage([map()]) :: %{String.t() => non_neg_integer()}
  def count_by_stage(tickets) when is_list(tickets) do
    base = Map.new(@valid_stages, &{&1, 0})

    tickets
    |> Enum.reduce(base, fn ticket, acc ->
      stage = Map.get(ticket, :lifecycle_stage, "open")

      if Map.has_key?(acc, stage) do
        Map.update!(acc, stage, &(&1 + 1))
      else
        acc
      end
    end)
  end

  @doc """
  Computes summary metrics from tickets and lifecycle events within a date range.

  Returns `%{total: int, open: int, avg_cycle_time_seconds: int | nil, completed: int}`.
  """
  @spec summarize([map()], [map()], {Date.t(), Date.t()}) :: map()
  def summarize(tickets, events, {date_from, date_to}) do
    total = length(tickets)
    open = Enum.count(tickets, &(&1.lifecycle_stage != "closed"))
    completed = completed_in_range(events, {date_from, date_to})
    avg_cycle = avg_cycle_time_seconds(events, tickets)

    %{
      total: total,
      open: open,
      avg_cycle_time_seconds: avg_cycle,
      completed: completed
    }
  end

  @doc """
  Computes average cycle time (open → closed) across tickets that have been closed.

  Returns nil when no tickets have been closed.
  """
  @spec avg_cycle_time_seconds([map()], [map()]) :: non_neg_integer() | nil
  def avg_cycle_time_seconds(events, tickets) when is_list(events) and is_list(tickets) do
    closed_ticket_ids =
      tickets
      |> Enum.filter(&(&1.lifecycle_stage == "closed"))
      |> Enum.map(& &1.id)
      |> MapSet.new()

    if MapSet.size(closed_ticket_ids) == 0 do
      nil
    else
      events_by_ticket =
        events
        |> Enum.filter(&MapSet.member?(closed_ticket_ids, &1.ticket_id))
        |> Enum.group_by(& &1.ticket_id)

      cycle_times =
        Enum.flat_map(events_by_ticket, fn {_ticket_id, ticket_events} ->
          compute_ticket_cycle_time(ticket_events)
        end)

      if cycle_times == [] do
        nil
      else
        div(Enum.sum(cycle_times), length(cycle_times))
      end
    end
  end

  @doc """
  Counts tickets that entered the "closed" stage within the given date range.
  """
  @spec completed_in_range([map()], {Date.t(), Date.t()}) :: non_neg_integer()
  def completed_in_range(events, {date_from, date_to}) do
    events
    |> Enum.filter(fn event ->
      event.to_stage == "closed" &&
        in_date_range?(event.transitioned_at, date_from, date_to)
    end)
    |> Enum.map(& &1.ticket_id)
    |> Enum.uniq()
    |> length()
  end

  @doc """
  Groups lifecycle events into time buckets for the throughput chart.

  Returns `[%{bucket: Date.t(), stage: String.t(), count: integer()}]`.
  """
  @spec bucket_transitions([map()], atom(), {Date.t(), Date.t()}) :: [map()]
  def bucket_transitions(events, granularity, {date_from, date_to}) do
    buckets = time_buckets(date_from, date_to, granularity)

    events
    |> Enum.filter(&in_date_range?(&1.transitioned_at, date_from, date_to))
    |> Enum.group_by(fn event ->
      {bucket_key(event.transitioned_at, granularity), event.to_stage}
    end)
    |> Enum.flat_map(fn {{bucket, stage}, group} ->
      if bucket in buckets do
        [%{bucket: bucket, stage: stage, count: length(group)}]
      else
        []
      end
    end)
    |> Enum.sort_by(&{&1.bucket, &1.stage})
  end

  @doc """
  Groups lifecycle events into time buckets for the cycle time chart.

  Returns `[%{bucket: Date.t(), stage: String.t(), avg_seconds: float()}]`.
  """
  @spec bucket_cycle_times([map()], atom(), {Date.t(), Date.t()}) :: [map()]
  def bucket_cycle_times(events, granularity, {date_from, date_to}) do
    # Group events by ticket_id, then compute duration for each stage per event pair
    events_by_ticket =
      events
      |> Enum.filter(&in_date_range?(&1.transitioned_at, date_from, date_to))
      |> Enum.group_by(& &1.ticket_id)

    # For each ticket, compute stage durations from consecutive events
    stage_durations =
      Enum.flat_map(events_by_ticket, fn {_ticket_id, ticket_events} ->
        compute_stage_durations(ticket_events, granularity)
      end)

    # Group by bucket + stage, compute averages
    stage_durations
    |> Enum.group_by(&{&1.bucket, &1.stage})
    |> Enum.map(fn {{bucket, stage}, durations} ->
      total = Enum.sum(Enum.map(durations, & &1.duration))
      avg = total / length(durations)
      %{bucket: bucket, stage: stage, avg_seconds: Float.round(avg, 1)}
    end)
    |> Enum.sort_by(&{&1.bucket, &1.stage})
  end

  @doc """
  Generates a list of bucket start dates between `date_from` and `date_to`
  at the given granularity.
  """
  @spec time_buckets(Date.t(), Date.t(), atom()) :: [Date.t()]
  def time_buckets(date_from, date_to, granularity) do
    first_bucket = bucket_key_date(date_from, granularity)
    generate_buckets(first_bucket, date_to, granularity, [])
  end

  @doc """
  Returns the bucket start date for a given datetime at the given granularity.

  - `:daily` → the date itself
  - `:weekly` → the Monday of that week
  - `:monthly` → the first of that month
  """
  @spec bucket_key(DateTime.t(), atom()) :: Date.t()
  def bucket_key(%DateTime{} = datetime, granularity) do
    datetime |> DateTime.to_date() |> bucket_key_date(granularity)
  end

  @doc "Returns valid lifecycle stages."
  @spec valid_stages() :: [String.t()]
  def valid_stages, do: @valid_stages

  # Private helpers

  defp bucket_key_date(%Date{} = date, :daily), do: date

  defp bucket_key_date(%Date{} = date, :weekly) do
    # ISO week starts on Monday (1)
    day_of_week = Date.day_of_week(date)
    Date.add(date, -(day_of_week - 1))
  end

  defp bucket_key_date(%Date{year: year, month: month}, :monthly) do
    Date.new!(year, month, 1)
  end

  defp generate_buckets(current, date_to, granularity, acc) do
    if Date.after?(current, date_to) do
      Enum.reverse(acc)
    else
      next = advance_bucket(current, granularity)
      generate_buckets(next, date_to, granularity, [current | acc])
    end
  end

  defp advance_bucket(date, :daily), do: Date.add(date, 1)
  defp advance_bucket(date, :weekly), do: Date.add(date, 7)

  defp advance_bucket(%Date{year: year, month: month}, :monthly) do
    if month == 12 do
      Date.new!(year + 1, 1, 1)
    else
      Date.new!(year, month + 1, 1)
    end
  end

  defp compute_stage_durations(ticket_events, granularity) do
    sorted = Enum.sort_by(ticket_events, & &1.transitioned_at, DateTime)

    sorted
    |> Enum.with_index()
    |> Enum.flat_map(fn {event, index} ->
      next = Enum.at(sorted, index + 1)

      if next do
        duration =
          DateTime.diff(next.transitioned_at, event.transitioned_at, :second) |> max(0)

        bucket = bucket_key(event.transitioned_at, granularity)
        [%{bucket: bucket, stage: event.to_stage, duration: duration}]
      else
        []
      end
    end)
  end

  defp compute_ticket_cycle_time(ticket_events) do
    sorted = Enum.sort_by(ticket_events, & &1.transitioned_at, DateTime)
    first_event = List.first(sorted)
    last_close = sorted |> Enum.filter(&(&1.to_stage == "closed")) |> List.last()

    if first_event && last_close do
      [DateTime.diff(last_close.transitioned_at, first_event.transitioned_at, :second) |> max(0)]
    else
      []
    end
  end

  defp in_date_range?(%DateTime{} = datetime, date_from, date_to) do
    date = DateTime.to_date(datetime)
    Date.compare(date, date_from) != :lt && Date.compare(date, date_to) != :gt
  end
end

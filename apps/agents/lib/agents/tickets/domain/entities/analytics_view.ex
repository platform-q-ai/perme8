defmodule Agents.Tickets.Domain.Entities.AnalyticsView do
  @moduledoc """
  Pure display helpers for computing SVG chart coordinates from aggregated analytics data.

  All functions are pure — no I/O, no Repo.
  """

  alias Agents.Tickets.Domain.Entities.Ticket.View, as: TicketView
  alias Agents.Tickets.Domain.Policies.TicketLifecyclePolicy

  @doc """
  Transforms stage count data into SVG bar chart rendering data.

  Given a map of `%{stage => count}` and a `max_height` (SVG viewport height),
  returns a list of bar maps ready for SVG rendering.
  """
  @spec distribution_bars(%{String.t() => non_neg_integer()}, number()) :: [map()]
  def distribution_bars(stage_counts, max_height) when is_map(stage_counts) do
    max_count = stage_counts |> Map.values() |> Enum.max(fn -> 0 end)

    stages = [
      "open",
      "ready",
      "in_progress",
      "in_review",
      "ci_testing",
      "merge_queue",
      "deployed",
      "closed"
    ]

    stages
    |> Enum.with_index()
    |> Enum.map(fn {stage, index} ->
      count = Map.get(stage_counts, stage, 0)

      bar_height =
        if max_count > 0,
          do: Float.round(count / max_count * max_height, 1),
          else: 0.0

      %{
        stage: stage,
        count: count,
        label: TicketLifecyclePolicy.stage_label(stage),
        color: TicketLifecyclePolicy.stage_color(stage),
        bar_height: bar_height,
        y_offset: Float.round(max_height - bar_height, 1),
        x_position: index
      }
    end)
  end

  @doc """
  Transforms bucketed trend data into SVG polyline point strings for each stage.

  Given bucketed data (list of `%{bucket, stage, count_or_value}`), chart dimensions
  `{width, height}`, and a list of buckets (x-axis), returns a map of
  `%{stage => "x1,y1 x2,y2 ..."}` polyline point strings.
  """
  @spec trend_line_points([map()], {number(), number()}, [Date.t()], atom()) :: %{
          String.t() => String.t()
        }
  def trend_line_points(bucketed_data, {width, height}, buckets, value_key \\ :count) do
    if buckets == [] do
      %{}
    else
      # Group data by stage
      by_stage = Enum.group_by(bucketed_data, & &1.stage)

      # Find max value for Y scaling
      max_val =
        bucketed_data
        |> Enum.map(&Map.get(&1, value_key, 0))
        |> Enum.max(fn -> 0 end)

      bucket_count = length(buckets)
      x_step = if bucket_count > 1, do: width / (bucket_count - 1), else: width / 2

      Map.new(by_stage, fn {stage, data} ->
        data_by_bucket = Map.new(data, &{&1.bucket, Map.get(&1, value_key, 0)})
        points = build_polyline_points(buckets, data_by_bucket, x_step, max_val, height)
        {stage, points}
      end)
    end
  end

  @doc """
  Formats bucket dates as x-axis labels based on granularity.
  """
  @spec chart_x_labels([Date.t()], atom()) :: [String.t()]
  def chart_x_labels(buckets, granularity) do
    Enum.map(buckets, &format_bucket_label(&1, granularity))
  end

  @doc """
  Formats summary metrics for display in cards.

  Returns a map with display-ready string values.
  """
  @spec summary_display(map()) :: map()
  def summary_display(summary) do
    %{
      total: to_string(summary.total),
      open: to_string(summary.open),
      avg_cycle_time: format_cycle_time(summary.avg_cycle_time_seconds),
      completed: to_string(summary.completed)
    }
  end

  # Private helpers

  defp build_polyline_points(buckets, data_by_bucket, x_step, max_val, height) do
    buckets
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {bucket, i} ->
      value = Map.get(data_by_bucket, bucket, 0)
      x = Float.round(i * x_step, 1)

      y =
        if max_val > 0,
          do: Float.round(height - value / max_val * height, 1),
          else: height

      "#{x},#{y}"
    end)
  end

  defp format_bucket_label(date, :daily) do
    "#{date.month}/#{date.day}"
  end

  defp format_bucket_label(date, :weekly) do
    "W#{date.month}/#{date.day}"
  end

  defp format_bucket_label(date, :monthly) do
    months = ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
    Enum.at(months, date.month - 1)
  end

  defp format_cycle_time(nil), do: "N/A"
  defp format_cycle_time(0), do: "0m"
  defp format_cycle_time(seconds), do: TicketView.format_duration(seconds)
end

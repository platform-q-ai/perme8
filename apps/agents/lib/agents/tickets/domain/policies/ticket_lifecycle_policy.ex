defmodule Agents.Tickets.Domain.Policies.TicketLifecyclePolicy do
  @moduledoc """
  Pure lifecycle stage validation and duration calculations.
  """

  @valid_stages ["open", "ready", "in_progress", "in_review", "ci_testing", "deployed", "closed"]

  @spec valid_stage?(term()) :: boolean()
  def valid_stage?(stage), do: stage in @valid_stages

  @spec valid_transition?(term(), term()) :: :ok | {:error, atom()}
  def valid_transition?(from_stage, to_stage) do
    cond do
      not valid_stage?(from_stage) -> {:error, :invalid_from_stage}
      not valid_stage?(to_stage) -> {:error, :invalid_to_stage}
      from_stage == to_stage -> {:error, :same_stage}
      true -> :ok
    end
  end

  @spec calculate_stage_durations([map()], DateTime.t()) :: [{String.t(), non_neg_integer()}]
  def calculate_stage_durations([], _now), do: []

  def calculate_stage_durations(events, %DateTime{} = now) when is_list(events) do
    events
    |> Enum.with_index()
    |> Enum.map(fn {event, index} ->
      next_event = Enum.at(events, index + 1)
      stage_end = if next_event, do: next_event.transitioned_at, else: now
      {event.to_stage, duration_seconds(event.transitioned_at, stage_end)}
    end)
  end

  @spec calculate_relative_durations([{String.t(), number()}]) :: [{String.t(), float()}]
  def calculate_relative_durations([]), do: []

  def calculate_relative_durations(durations) do
    total = Enum.reduce(durations, 0, fn {_stage, seconds}, acc -> acc + max(seconds, 0) end)

    if total <= 0 do
      Enum.map(durations, fn {stage, _seconds} -> {stage, 0.0} end)
    else
      Enum.map(durations, fn {stage, seconds} ->
        {stage, Float.round(max(seconds, 0) * 100 / total, 1)}
      end)
    end
  end

  @spec stage_label(String.t()) :: String.t()
  def stage_label("open"), do: "Open"
  def stage_label("ready"), do: "Ready"
  def stage_label("in_progress"), do: "In Progress"
  def stage_label("in_review"), do: "In Review"
  def stage_label("ci_testing"), do: "CI Testing"
  def stage_label("deployed"), do: "Deployed"
  def stage_label("closed"), do: "Closed"
  def stage_label(_), do: "Unknown"

  @spec stage_color(String.t()) :: String.t()
  def stage_color("open"), do: "neutral"
  def stage_color("ready"), do: "info"
  def stage_color("in_progress"), do: "warning"
  def stage_color("in_review"), do: "primary"
  def stage_color("ci_testing"), do: "accent"
  def stage_color("deployed"), do: "success"
  def stage_color("closed"), do: "base"
  def stage_color(_), do: "neutral"

  defp duration_seconds(started_at, ended_at) do
    DateTime.diff(ended_at, started_at, :second)
    |> max(0)
  end
end

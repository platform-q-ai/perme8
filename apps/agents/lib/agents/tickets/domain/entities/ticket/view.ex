defmodule Agents.Tickets.Domain.Entities.Ticket.View do
  @moduledoc """
  Pure display helpers for ticket lifecycle rendering.
  """

  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Policies.TicketLifecyclePolicy

  @spec lifecycle_stage_label(Ticket.t()) :: String.t()
  def lifecycle_stage_label(%Ticket{} = ticket) do
    TicketLifecyclePolicy.stage_label(ticket.lifecycle_stage)
  end

  @spec lifecycle_stage_color(Ticket.t()) :: String.t()
  def lifecycle_stage_color(%Ticket{} = ticket) do
    TicketLifecyclePolicy.stage_color(ticket.lifecycle_stage)
  end

  @spec current_stage_duration(Ticket.t(), DateTime.t()) :: String.t()
  def current_stage_duration(%Ticket{lifecycle_stage_entered_at: nil}, _now), do: "0m"

  def current_stage_duration(%Ticket{} = ticket, %DateTime{} = now) do
    now
    |> DateTime.diff(ticket.lifecycle_stage_entered_at, :second)
    |> max(0)
    |> format_duration()
  end

  @spec lifecycle_summary(Ticket.t()) :: [map()]
  def lifecycle_summary(%Ticket{} = ticket) do
    ticket.lifecycle_events
    |> TicketLifecyclePolicy.calculate_stage_durations()
    |> Enum.map(fn {stage, duration_seconds} ->
      %{
        stage: stage,
        duration_seconds: duration_seconds,
        label: TicketLifecyclePolicy.stage_label(stage)
      }
    end)
  end

  @spec lifecycle_timeline_data(Ticket.t()) :: [map()]
  def lifecycle_timeline_data(%Ticket{} = ticket) do
    durations = TicketLifecyclePolicy.calculate_stage_durations(ticket.lifecycle_events)
    relative = TicketLifecyclePolicy.calculate_relative_durations(durations) |> Map.new()

    Enum.map(durations, fn {stage, duration_seconds} ->
      %{
        stage: stage,
        label: TicketLifecyclePolicy.stage_label(stage),
        color: TicketLifecyclePolicy.stage_color(stage),
        duration_seconds: duration_seconds,
        duration: format_duration(duration_seconds),
        relative_width: Map.get(relative, stage, 0.0)
      }
    end)
  end

  @spec format_duration(non_neg_integer()) :: String.t()
  def format_duration(seconds) when is_integer(seconds) and seconds >= 0 do
    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3_600)
    minutes = div(rem(seconds, 3_600), 60)

    cond do
      days > 0 and hours > 0 -> "#{days}d #{hours}h"
      days > 0 -> "#{days}d"
      hours > 0 and minutes > 0 -> "#{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h"
      true -> "#{minutes}m"
    end
  end
end

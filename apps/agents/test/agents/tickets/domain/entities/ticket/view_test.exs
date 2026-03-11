defmodule Agents.Tickets.Domain.Entities.Ticket.ViewTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Entities.Ticket.View
  alias Agents.Tickets.Domain.Entities.TicketLifecycleEvent

  describe "lifecycle_stage_label/1" do
    test "returns formatted stage label" do
      ticket = Ticket.new(%{lifecycle_stage: "in_progress"})
      assert View.lifecycle_stage_label(ticket) == "In Progress"
    end
  end

  describe "lifecycle_stage_color/1" do
    test "returns stage color identifier" do
      ticket = Ticket.new(%{lifecycle_stage: "in_review"})
      assert View.lifecycle_stage_color(ticket) == "primary"
    end
  end

  describe "current_stage_duration/2" do
    test "returns formatted duration for current stage" do
      ticket = Ticket.new(%{lifecycle_stage_entered_at: ~U[2026-03-10 10:00:00Z]})
      now = ~U[2026-03-10 12:15:00Z]

      assert View.current_stage_duration(ticket, now) == "2h 15m"
    end

    test "returns 0m when lifecycle_stage_entered_at is nil" do
      ticket = Ticket.new(%{lifecycle_stage_entered_at: nil})
      assert View.current_stage_duration(ticket, ~U[2026-03-10 12:00:00Z]) == "0m"
    end
  end

  describe "lifecycle_summary/1" do
    test "returns ordered stage summary with labels" do
      ticket =
        Ticket.new(%{
          lifecycle_events: [
            TicketLifecycleEvent.new(%{
              to_stage: "open",
              transitioned_at: ~U[2026-03-10 09:00:00Z]
            }),
            TicketLifecycleEvent.new(%{
              to_stage: "ready",
              transitioned_at: ~U[2026-03-10 10:00:00Z]
            }),
            TicketLifecycleEvent.new(%{
              to_stage: "in_progress",
              transitioned_at: ~U[2026-03-10 11:00:00Z]
            })
          ]
        })

      summary = View.lifecycle_summary(ticket)

      assert [%{stage: "open", label: "Open"} | _] = summary
      assert Enum.all?(summary, &is_integer(&1.duration_seconds))
    end
  end

  describe "lifecycle_timeline_data/1" do
    test "returns timeline bars with relative widths" do
      ticket =
        Ticket.new(%{
          lifecycle_events: [
            TicketLifecycleEvent.new(%{
              to_stage: "open",
              transitioned_at: ~U[2026-03-10 09:00:00Z]
            }),
            TicketLifecycleEvent.new(%{
              to_stage: "ready",
              transitioned_at: ~U[2026-03-10 10:00:00Z]
            }),
            TicketLifecycleEvent.new(%{
              to_stage: "in_progress",
              transitioned_at: ~U[2026-03-10 13:00:00Z]
            })
          ]
        })

      timeline = View.lifecycle_timeline_data(ticket)

      assert Enum.all?(timeline, fn item ->
               Map.has_key?(item, :stage) and Map.has_key?(item, :relative_width)
             end)
    end
  end

  describe "format_duration/1" do
    test "formats seconds to human-readable text" do
      assert View.format_duration(8100) == "2h 15m"
      assert View.format_duration(3 * 24 * 3600) == "3d"
      assert View.format_duration(3 * 24 * 3600 + 4 * 3600) == "3d 4h"
      assert View.format_duration(45 * 60) == "45m"
      assert View.format_duration(0) == "0m"
    end
  end
end

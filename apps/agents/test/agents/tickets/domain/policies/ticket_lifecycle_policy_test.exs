defmodule Agents.Tickets.Domain.Policies.TicketLifecyclePolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Tickets.Domain.Entities.TicketLifecycleEvent
  alias Agents.Tickets.Domain.Policies.TicketLifecyclePolicy

  @stages ["open", "ready", "in_progress", "in_review", "ci_testing", "deployed", "closed"]

  describe "valid_stage?/1" do
    test "returns true for all valid stages" do
      Enum.each(@stages, fn stage ->
        assert TicketLifecyclePolicy.valid_stage?(stage)
      end)
    end

    test "returns false for invalid stages" do
      refute TicketLifecyclePolicy.valid_stage?("unknown")
      refute TicketLifecyclePolicy.valid_stage?("")
      refute TicketLifecyclePolicy.valid_stage?(nil)
    end
  end

  describe "valid_transition?/2" do
    test "rejects same-stage transitions" do
      assert {:error, :same_stage} = TicketLifecyclePolicy.valid_transition?("open", "open")
    end

    test "accepts transitions between distinct valid stages" do
      assert :ok = TicketLifecyclePolicy.valid_transition?("open", "in_progress")
      assert :ok = TicketLifecyclePolicy.valid_transition?("deployed", "in_review")
    end

    test "rejects transitions with invalid stages" do
      assert {:error, :invalid_from_stage} =
               TicketLifecyclePolicy.valid_transition?("invalid", "open")

      assert {:error, :invalid_to_stage} =
               TicketLifecyclePolicy.valid_transition?("open", "invalid")
    end
  end

  describe "calculate_stage_durations/1 and /2" do
    test "returns [] for empty event list" do
      assert TicketLifecyclePolicy.calculate_stage_durations([], DateTime.utc_now()) == []
    end

    test "handles single event by measuring from transitioned_at to now" do
      now = ~U[2026-03-10 12:00:00Z]

      events = [
        TicketLifecycleEvent.new(%{
          to_stage: "in_progress",
          transitioned_at: ~U[2026-03-10 10:00:00Z]
        })
      ]

      assert [{"in_progress", 7200}] =
               TicketLifecyclePolicy.calculate_stage_durations(events, now)
    end

    test "computes ordered stage durations from lifecycle events" do
      now = ~U[2026-03-10 13:00:00Z]

      events = [
        TicketLifecycleEvent.new(%{to_stage: "open", transitioned_at: ~U[2026-03-10 09:00:00Z]}),
        TicketLifecycleEvent.new(%{to_stage: "ready", transitioned_at: ~U[2026-03-10 10:00:00Z]}),
        TicketLifecycleEvent.new(%{
          to_stage: "in_progress",
          transitioned_at: ~U[2026-03-10 11:30:00Z]
        })
      ]

      assert [
               {"open", 3600},
               {"ready", 5400},
               {"in_progress", 5400}
             ] = TicketLifecyclePolicy.calculate_stage_durations(events, now)
    end
  end

  describe "calculate_relative_durations/1" do
    test "returns percentage-based relative widths" do
      durations = [{"open", 10}, {"ready", 30}, {"in_progress", 60}]

      assert [
               {"open", 10.0},
               {"ready", 30.0},
               {"in_progress", 60.0}
             ] = TicketLifecyclePolicy.calculate_relative_durations(durations)
    end

    test "returns [] for empty input" do
      assert TicketLifecyclePolicy.calculate_relative_durations([]) == []
    end
  end

  describe "stage_label/1" do
    test "returns human-readable labels" do
      assert TicketLifecyclePolicy.stage_label("open") == "Open"
      assert TicketLifecyclePolicy.stage_label("ready") == "Ready"
      assert TicketLifecyclePolicy.stage_label("in_progress") == "In Progress"
      assert TicketLifecyclePolicy.stage_label("in_review") == "In Review"
      assert TicketLifecyclePolicy.stage_label("ci_testing") == "CI Testing"
      assert TicketLifecyclePolicy.stage_label("deployed") == "Deployed"
      assert TicketLifecyclePolicy.stage_label("closed") == "Closed"
    end
  end

  describe "stage_color/1" do
    test "returns a color identifier for each stage" do
      assert TicketLifecyclePolicy.stage_color("open") == "neutral"
      assert TicketLifecyclePolicy.stage_color("ready") == "info"
      assert TicketLifecyclePolicy.stage_color("in_progress") == "warning"
      assert TicketLifecyclePolicy.stage_color("in_review") == "primary"
      assert TicketLifecyclePolicy.stage_color("ci_testing") == "accent"
      assert TicketLifecyclePolicy.stage_color("deployed") == "success"
      assert TicketLifecyclePolicy.stage_color("closed") == "base"
    end
  end
end

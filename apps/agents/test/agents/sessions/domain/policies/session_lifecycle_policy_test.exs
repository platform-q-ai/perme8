defmodule Agents.Sessions.Domain.Policies.SessionLifecyclePolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy

  describe "derive/1" do
    test "returns idle for nil map" do
      assert SessionLifecyclePolicy.derive(nil) == :idle
    end

    test "returns idle for nil status" do
      assert SessionLifecyclePolicy.derive(task(status: nil)) == :idle
    end

    test "returns queued_cold for queued tasks without real container" do
      assert SessionLifecyclePolicy.derive(task(status: "queued", container_id: nil)) ==
               :queued_cold

      assert SessionLifecyclePolicy.derive(task(status: "queued", container_id: "")) ==
               :queued_cold

      assert SessionLifecyclePolicy.derive(
               task(status: "queued", container_id: "task:placeholder")
             ) ==
               :queued_cold
    end

    test "returns queued_warm for queued tasks with real container" do
      assert SessionLifecyclePolicy.derive(task(status: "queued", container_id: "container-123")) ==
               :queued_warm
    end

    test "returns warming for pending tasks with real container and no port" do
      assert SessionLifecyclePolicy.derive(
               task(status: "pending", container_id: "container-123", container_port: nil)
             ) == :warming
    end

    test "returns pending for pending tasks without container" do
      assert SessionLifecyclePolicy.derive(task(status: "pending", container_id: nil)) == :pending
    end

    test "returns pending for pending tasks with container and port" do
      assert SessionLifecyclePolicy.derive(
               task(status: "pending", container_id: "container-123", container_port: 4100)
             ) == :pending
    end

    test "maps known status values directly" do
      assert SessionLifecyclePolicy.derive(task(status: "starting")) == :starting
      assert SessionLifecyclePolicy.derive(task(status: "running")) == :running

      assert SessionLifecyclePolicy.derive(task(status: "awaiting_feedback")) ==
               :awaiting_feedback

      assert SessionLifecyclePolicy.derive(task(status: "completed")) == :completed
      assert SessionLifecyclePolicy.derive(task(status: "failed")) == :failed
      assert SessionLifecyclePolicy.derive(task(status: "cancelled")) == :cancelled
    end

    test "returns idle for unknown status" do
      assert SessionLifecyclePolicy.derive(task(status: "mystery")) == :idle
    end
  end

  describe "can_transition?/2" do
    test "returns true for valid transitions" do
      valid = [
        {:idle, :queued_cold},
        {:idle, :queued_warm},
        {:idle, :running},
        {:idle, :completed},
        {:idle, :failed},
        {:idle, :cancelled},
        {:queued_cold, :warming},
        {:queued_cold, :pending},
        {:queued_cold, :cancelled},
        {:queued_warm, :pending},
        {:queued_warm, :starting},
        {:queued_warm, :cancelled},
        {:warming, :pending},
        {:warming, :failed},
        {:warming, :cancelled},
        {:pending, :starting},
        {:pending, :cancelled},
        {:starting, :running},
        {:starting, :cancelled},
        {:running, :completed},
        {:running, :failed},
        {:running, :cancelled},
        {:running, :idle},
        {:running, :awaiting_feedback},
        {:awaiting_feedback, :running},
        {:awaiting_feedback, :failed},
        {:awaiting_feedback, :cancelled},
        {:awaiting_feedback, :queued_cold},
        {:awaiting_feedback, :queued_warm}
      ]

      Enum.each(valid, fn {from_state, to_state} ->
        assert SessionLifecyclePolicy.can_transition?(from_state, to_state)
      end)
    end

    test "returns false for invalid transitions" do
      refute SessionLifecyclePolicy.can_transition?(:completed, :running)
      refute SessionLifecyclePolicy.can_transition?(:idle, :warming)
      refute SessionLifecyclePolicy.can_transition?(:failed, :queued_cold)
      refute SessionLifecyclePolicy.can_transition?(:cancelled, :pending)
    end

    test "returns false for self transitions" do
      refute SessionLifecyclePolicy.can_transition?(:running, :running)
      refute SessionLifecyclePolicy.can_transition?(:idle, :idle)
    end

    test "returns true for SDK-event-driven transitions" do
      sdk_transitions = [
        {:awaiting_feedback, :running},
        {:awaiting_feedback, :failed},
        {:awaiting_feedback, :cancelled},
        {:running, :idle},
        {:idle, :running},
        {:idle, :completed},
        {:idle, :failed},
        {:idle, :cancelled}
      ]

      Enum.each(sdk_transitions, fn {from_state, to_state} ->
        assert SessionLifecyclePolicy.can_transition?(from_state, to_state),
               "expected #{from_state} -> #{to_state} to be valid"
      end)
    end
  end

  describe "predicates" do
    @states [
      :idle,
      :queued_cold,
      :queued_warm,
      :warming,
      :pending,
      :starting,
      :running,
      :awaiting_feedback,
      :completed,
      :failed,
      :cancelled
    ]

    test "active?/1" do
      for state <- @states do
        expected =
          state in [
            :queued_cold,
            :queued_warm,
            :warming,
            :pending,
            :starting,
            :running,
            :awaiting_feedback
          ]

        assert SessionLifecyclePolicy.active?(state) == expected
      end
    end

    test "terminal?/1" do
      for state <- @states do
        expected = state in [:completed, :failed, :cancelled]
        assert SessionLifecyclePolicy.terminal?(state) == expected
      end
    end

    test "warm?/1" do
      for state <- @states do
        expected = state in [:queued_warm, :warming, :running, :starting]
        assert SessionLifecyclePolicy.warm?(state) == expected
      end
    end

    test "cold?/1" do
      for state <- @states do
        expected = state in [:queued_cold, :idle]
        assert SessionLifecyclePolicy.cold?(state) == expected
      end
    end

    test "can_submit_message?/1" do
      for state <- @states do
        expected =
          state in [
            :queued_cold,
            :queued_warm,
            :warming,
            :pending,
            :starting,
            :running,
            :awaiting_feedback
          ]

        assert SessionLifecyclePolicy.can_submit_message?(state) == expected
      end
    end
  end

  defp task(overrides) do
    Map.merge(
      %{
        status: "queued",
        container_id: nil,
        container_port: nil
      },
      Map.new(overrides)
    )
  end
end

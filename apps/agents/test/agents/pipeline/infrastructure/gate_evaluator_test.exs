defmodule Agents.Pipeline.Infrastructure.GateEvaluatorTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{Gate, Stage}
  alias Agents.Pipeline.Infrastructure.GateEvaluator

  test "passes quality gates when required checks are present" do
    stage = Stage.new(%{id: "test", type: "verification"})
    gate = Gate.new(%{type: "quality", params: %{"checks" => ["unit-tests"]}})

    assert {:ok, %{status: :passed, gate_results: [result]}} =
             GateEvaluator.evaluate(stage, [gate], %{
               "stage_execution" => %{
                 "steps" => [%{"name" => "unit-tests", "status" => "passed"}]
               }
             })

    assert result.status == :passed
  end

  test "blocks manual approval gates until approval exists" do
    stage = Stage.new(%{id: "merge-queue", type: "automation"})
    gate = Gate.new(%{type: "manual_approval", params: %{"key" => "merge-window"}})

    assert {:ok, %{status: :blocked, gate_results: [result]}} =
             GateEvaluator.evaluate(stage, [gate], %{})

    assert result.reason == "approval_required"
  end

  test "blocks time window gates outside configured hours" do
    stage = Stage.new(%{id: "deploy", type: "automation"})
    gate = Gate.new(%{type: "time_window", params: %{"after" => "09:00", "before" => "17:00"}})

    assert {:ok, %{status: :blocked}} =
             GateEvaluator.evaluate(stage, [gate], %{"current_time" => ~U[2026-03-27 08:00:00Z]})
  end

  test "passes environment ready gates when environment key is present" do
    stage = Stage.new(%{id: "deploy", type: "automation"})
    gate = Gate.new(%{type: "environment_ready", params: %{"key" => "render-prod"}})

    assert {:ok, %{status: :passed}} =
             GateEvaluator.evaluate(stage, [gate], %{"ready_environments" => ["render-prod"]})
  end
end

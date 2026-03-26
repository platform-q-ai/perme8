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
end

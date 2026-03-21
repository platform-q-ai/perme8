defmodule Agents.Pipeline.Domain.Entities.PipelineRunTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{PipelineRun, StageResult}

  test "records stage results and serializes them" do
    run =
      PipelineRun.new(%{
        trigger_type: "on_session_complete",
        trigger_reference: "task-1",
        remaining_stage_ids: ["test"]
      })

    result =
      StageResult.new(%{
        stage_id: "test",
        status: :passed,
        output: "ok",
        exit_code: 0
      })

    run = PipelineRun.record_stage_result(run, result)

    assert run.stage_results["test"].status == :passed
    assert PipelineRun.stage_results_to_map(run)["test"]["status"] == "passed"
  end

  test "pop_next_stage promotes the next pending stage" do
    run =
      PipelineRun.new(%{
        trigger_type: "on_merge",
        trigger_reference: "7",
        remaining_stage_ids: ["deploy"]
      })

    assert {"deploy", updated} = PipelineRun.pop_next_stage(run)
    assert updated.current_stage_id == "deploy"
    assert updated.remaining_stage_ids == []
  end
end

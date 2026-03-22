defmodule Agents.Pipeline.Domain.Events.PipelineStageChangedTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Events.PipelineStageChanged

  @valid_attrs %{
    aggregate_id: "run-123",
    actor_id: "system",
    pipeline_run_id: "run-123",
    stage_id: "test",
    from_status: "pending",
    to_status: "running",
    trigger_type: "pull_request",
    task_id: "task-1",
    session_id: "session-1",
    pull_request_number: 42
  }

  test "returns event and aggregate types" do
    assert PipelineStageChanged.event_type() == "pipeline.pipeline_stage_changed"
    assert PipelineStageChanged.aggregate_type() == "pipeline_run"
  end

  test "new/1 builds event with stage transition details" do
    event = PipelineStageChanged.new(@valid_attrs)

    assert event.pipeline_run_id == "run-123"
    assert event.stage_id == "test"
    assert event.from_status == "pending"
    assert event.to_status == "running"
    assert event.pull_request_number == 42
  end

  test "new/1 raises when required fields are missing" do
    assert_raise ArgumentError, fn ->
      PipelineStageChanged.new(%{aggregate_id: "run-123", actor_id: "system"})
    end
  end
end

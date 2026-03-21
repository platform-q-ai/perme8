defmodule Agents.Pipeline.Domain.Policies.PipelineLifecyclePolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Policies.PipelineLifecyclePolicy

  test "allows documented transitions" do
    assert :ok = PipelineLifecyclePolicy.valid_transition?("idle", "running_stage")
    assert :ok = PipelineLifecyclePolicy.valid_transition?("running_stage", "awaiting_result")
    assert :ok = PipelineLifecyclePolicy.valid_transition?("awaiting_result", "passed")
    assert :ok = PipelineLifecyclePolicy.valid_transition?("awaiting_result", "failed")
    assert :ok = PipelineLifecyclePolicy.valid_transition?("passed", "running_stage")
    assert :ok = PipelineLifecyclePolicy.valid_transition?("passed", "deploy")
    assert :ok = PipelineLifecyclePolicy.valid_transition?("failed", "reopen_session")
  end

  test "rejects invalid transitions" do
    assert {:error, :invalid_transition} =
             PipelineLifecyclePolicy.valid_transition?("idle", "passed")

    assert {:error, :invalid_transition} =
             PipelineLifecyclePolicy.valid_transition?("failed", "running_stage")
  end
end

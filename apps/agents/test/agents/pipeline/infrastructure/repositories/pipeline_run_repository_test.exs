defmodule Agents.Pipeline.Infrastructure.Repositories.PipelineRunRepositoryTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Infrastructure.Repositories.PipelineRunRepository

  test "creates, reads, and updates pipeline runs" do
    assert {:ok, run} =
             PipelineRunRepository.create_run(%{
               trigger_type: "on_session_complete",
               trigger_reference: "task-123",
               remaining_stage_ids: ["test"],
               stage_results: %{}
             })

    assert {:ok, loaded} = PipelineRunRepository.get_run(run.id)
    assert loaded.trigger_reference == "task-123"

    assert {:ok, updated} =
             PipelineRunRepository.update_run(run.id, %{
               status: "running_stage",
               current_stage_id: "test"
             })

    assert updated.status == "running_stage"
    assert updated.current_stage_id == "test"
  end
end

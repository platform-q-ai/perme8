defmodule Agents.Pipeline.Infrastructure.Schemas.PipelineRunSchemaTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Infrastructure.Schemas.PipelineRunSchema

  test "requires trigger metadata and validates status" do
    changeset = PipelineRunSchema.changeset(%PipelineRunSchema{}, %{})

    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).trigger_type
    assert "can't be blank" in errors_on(changeset).trigger_reference

    changeset =
      PipelineRunSchema.changeset(%PipelineRunSchema{}, %{
        trigger_type: "on_session_complete",
        trigger_reference: "task-1",
        remaining_stage_ids: [],
        stage_results: %{},
        status: "bogus"
      })

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).status
  end
end

defmodule Agents.Pipeline.Domain.Events.PipelineRunRequested do
  @moduledoc "Emitted when a pipeline run should attempt stage admission/execution."

  use Perme8.Events.DomainEvent,
    aggregate_type: "pipeline_run",
    fields: [pipeline_run_id: nil],
    required: [:pipeline_run_id]
end

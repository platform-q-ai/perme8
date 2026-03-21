defmodule Agents.Pipeline.Domain.Events.PipelineStageChanged do
  @moduledoc "Emitted when a pipeline run changes stage status."

  use Perme8.Events.DomainEvent,
    aggregate_type: "pipeline_run",
    fields: [
      pipeline_run_id: nil,
      stage_id: nil,
      from_status: nil,
      to_status: nil,
      trigger_type: nil,
      task_id: nil,
      session_id: nil,
      pull_request_number: nil
    ],
    required: [:pipeline_run_id, :from_status, :to_status]
end

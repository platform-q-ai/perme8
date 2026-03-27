defmodule Agents.Pipeline.Infrastructure.PipelineEventHandler do
  @moduledoc "Subscribes to session and pull-request domain events and triggers pipeline runs."

  use Perme8.Events.EventHandler

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PipelineRun
  alias Agents.Pipeline.Application.UseCases.ProjectTicketLifecycleFromRun
  alias Agents.Pipeline.Application.UseCases.RunStage
  alias Agents.Pipeline.Application.UseCases.TriggerPipelineRun

  @impl Perme8.Events.EventHandler
  def subscriptions,
    do: [
      "events:sessions:task",
      "events:sessions:session",
      "events:pipeline:pull_request",
      "events:pipeline:pipeline_run",
      "events:pipeline:pipeline_run_stage_changed"
    ]

  @impl Perme8.Events.EventHandler
  def handle_event(%{event_type: "sessions.task_completed"} = event) do
    TriggerPipelineRun.execute(%{
      event: event,
      trigger_type: "on_session_complete",
      trigger_reference: event.task_id,
      task_id: event.task_id
    })

    :ok
  end

  def handle_event(%{event_type: "sessions.session_diff_produced"} = event) do
    TriggerPipelineRun.execute(%{
      event: event,
      trigger_type: "on_session_complete",
      trigger_reference: event.task_id,
      task_id: event.task_id
    })

    :ok
  end

  def handle_event(%{event_type: "pipeline.pull_request_created"} = event) do
    trigger_pr_event("on_pull_request", event)
  end

  def handle_event(%{event_type: "pipeline.pull_request_updated"} = event) do
    trigger_pr_event("on_pull_request", event)
  end

  def handle_event(%{event_type: "pipeline.pull_request_merged"} = event) do
    trigger_pr_event("on_merge", event)
  end

  def handle_event(%{event_type: "pipeline.pipeline_run_requested", pipeline_run_id: run_id}) do
    RunStage.execute(run_id)
    :ok
  end

  def handle_event(%{event_type: "pipeline.pipeline_stage_changed", to_status: to_status} = event)
      when to_status in ["passed", "failed", "blocked"] do
    project_ticket_lifecycle(event)
    maybe_resume_queued_for_stage(event.stage_id)
    :ok
  end

  def handle_event(%{event_type: "pipeline.pipeline_stage_changed", to_status: "queued"} = event) do
    project_ticket_lifecycle(event)
    :ok
  end

  def handle_event(_event), do: :ok

  defp trigger_pr_event(trigger_type, event) do
    TriggerPipelineRun.execute(%{
      event: event,
      trigger_type: trigger_type,
      trigger_reference: to_string(event.number),
      pull_request_number: event.number
    })

    :ok
  rescue
    error -> {:error, error}
  end

  defp maybe_resume_queued_for_stage(nil), do: :ok

  defp maybe_resume_queued_for_stage(stage_id) do
    repo = PipelineRuntimeConfig.pipeline_run_repository()

    case repo.list_queued_for_stage(stage_id) do
      [run | _] -> RunStage.execute(run.id)
      _ -> :ok
    end
  end

  defp project_ticket_lifecycle(%{pipeline_run_id: run_id} = event) do
    repo = PipelineRuntimeConfig.pipeline_run_repository()
    stage_id = event.stage_id || event.queued_stage_id

    with {:ok, run} <- repo.get_run(run_id) do
      ProjectTicketLifecycleFromRun.execute(PipelineRun.from_schema(run), stage_id)
    end

    :ok
  end
end

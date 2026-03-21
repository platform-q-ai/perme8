defmodule Agents.Pipeline.Infrastructure.PipelineEventHandler do
  @moduledoc "Subscribes to session and pull-request domain events and triggers pipeline runs."

  use Perme8.Events.EventHandler

  alias Agents.Pipeline.Application.UseCases.TriggerPipelineRun

  @impl Perme8.Events.EventHandler
  def subscriptions,
    do: ["events:sessions:task", "events:sessions:session", "events:pipeline:pull_request"]

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
end

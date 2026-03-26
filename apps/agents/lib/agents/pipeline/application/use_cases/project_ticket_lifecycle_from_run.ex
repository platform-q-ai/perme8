defmodule Agents.Pipeline.Application.UseCases.ProjectTicketLifecycleFromRun do
  @moduledoc false

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PipelineRun
  alias Agents.Tickets.Application.UseCases.RecordStageTransition
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository

  @spec execute(PipelineRun.t(), String.t() | nil, keyword()) :: :ok | {:error, term()}
  def execute(%PipelineRun{} = run, stage_id, opts \\ []) do
    ticket_repo = Keyword.get(opts, :ticket_repo, ProjectTicketRepository)
    record_stage_transition = Keyword.get(opts, :record_stage_transition, RecordStageTransition)

    pipeline_config_repo =
      Keyword.get(opts, :pipeline_config_repo, PipelineRuntimeConfig.pipeline_config_repository())

    with pull_request_number when is_integer(pull_request_number) <- run.pull_request_number,
         {:ok, ticket} <- ticket_repo.get_by_number(pull_request_number),
         {:ok, config} <- pipeline_config_repo.get_current(),
         projection when is_map(projection) <- projection_for(run, stage_id, config.stages),
         :ok <-
           maybe_record_transition(
             ticket.number,
             ticket.lifecycle_stage,
             projection,
             record_stage_transition,
             opts
           ),
         {:ok, _ticket} <-
           ticket_repo.set_lifecycle_projection(ticket.number, %{
             lifecycle_owner_run_id: run.id,
             lifecycle_reason: projection.reason
           }) do
      :ok
    else
      nil -> :ok
      {:error, :not_found} -> :ok
      {:error, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp projection_for(run, stage_id, stages) do
    stage = Enum.find(stages, &(&1.id == stage_id))
    transition = stage && Enum.find(stage.transitions || [], &(&1.on == run.status))

    ticket_stage =
      cond do
        transition && is_binary(transition.ticket_stage_override) ->
          transition.ticket_stage_override

        run.status == "blocked" ->
          "in_progress"

        stage && is_binary(stage.ticket_stage) ->
          stage.ticket_stage

        true ->
          nil
      end

    %{
      stage: ticket_stage,
      reason:
        cond do
          transition && is_binary(transition.ticket_reason) -> transition.ticket_reason
          transition && is_binary(transition.reason) -> transition.reason
          run.status == "queued" -> "queued_for_capacity"
          run.status == "blocked" -> run.failure_reason || "stage_blocked"
          run.status == "failed" -> run.failure_reason || "stage_failed"
          true -> nil
        end
    }
  end

  defp maybe_record_transition(
         _ticket_number,
         _from_stage,
         %{stage: nil},
         _record_stage_transition,
         _opts
       ),
       do: :ok

  defp maybe_record_transition(
         _ticket_number,
         to_stage,
         %{stage: to_stage},
         _record_stage_transition,
         _opts
       ),
       do: :ok

  defp maybe_record_transition(
         ticket_number,
         _from_stage,
         %{stage: to_stage, reason: reason},
         record_stage_transition,
         opts
       ) do
    trigger = if(reason, do: "pipeline:#{reason}", else: "pipeline")

    case record_stage_transition.execute(
           ticket_number,
           to_stage,
           Keyword.put(opts, :trigger, trigger)
         ) do
      {:ok, _} -> :ok
      {:error, :same_stage} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end

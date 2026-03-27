defmodule Agents.Pipeline.Application.UseCases.ProjectTicketLifecycleFromRun do
  @moduledoc false

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PipelineRun
  alias Agents.Tickets.Application.UseCases.RecordStageTransition

  @spec execute(PipelineRun.t(), String.t() | nil, keyword()) :: :ok | {:error, term()}
  def execute(%PipelineRun{} = run, stage_id, opts \\ []) do
    ticket_repo = Keyword.get(opts, :ticket_repo, PipelineRuntimeConfig.ticket_repository())
    record_stage_transition = Keyword.get(opts, :record_stage_transition, RecordStageTransition)

    pipeline_run_repo =
      Keyword.get(opts, :pipeline_run_repo, PipelineRuntimeConfig.pipeline_run_repository())

    pipeline_config_repo =
      Keyword.get(opts, :pipeline_config_repo, PipelineRuntimeConfig.pipeline_config_repository())

    with {:ok, ticket} <- fetch_ticket(run.pull_request_number, ticket_repo),
         :ok <- maybe_claim_lifecycle_ownership(ticket, run, pipeline_run_repo),
         {:ok, config} <- pipeline_config_repo.get_current(),
         projection <- projection_for(run, stage_id, config.stages),
         :ok <-
           maybe_record_transition(
             ticket.number,
             ticket.lifecycle_stage,
             projection,
             record_stage_transition,
             opts
           ),
         {:ok, _ticket} <- persist_projection(ticket_repo, ticket.number, run, projection) do
      :ok
    else
      {:skip, _reason} -> :ok
      {:error, :not_found} -> :ok
      {:error, :not_lifecycle_owner} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_ticket(integer() | nil, module()) :: {:ok, map()} | {:skip, atom()}
  defp fetch_ticket(pull_request_number, _ticket_repo) when not is_integer(pull_request_number),
    do: {:skip, :no_ticket}

  defp fetch_ticket(pull_request_number, ticket_repo) do
    case ticket_repo.get_by_number(pull_request_number) do
      {:ok, ticket} -> {:ok, ticket}
      nil -> {:skip, :ticket_missing}
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_claim_lifecycle_ownership(ticket, run, pipeline_run_repo) do
    owner_id = Map.get(ticket, :lifecycle_owner_run_id)

    if is_nil(owner_id) or owner_id == run.id do
      :ok
    else
      check_existing_owner(owner_id, run, pipeline_run_repo)
    end
  end

  defp check_existing_owner(owner_id, run, pipeline_run_repo) do
    case pipeline_run_repo.get_run(owner_id) do
      {:ok, owner_schema} ->
        owner_run = PipelineRun.from_schema(owner_schema)
        if lifecycle_owner?(owner_run, run), do: {:error, :not_lifecycle_owner}, else: :ok

      _ ->
        :ok
    end
  end

  defp lifecycle_owner?(owner_run, current_run) do
    owner_active? = active_run?(owner_run)
    current_active? = active_run?(current_run)

    cond do
      owner_active? and not current_active? -> true
      not owner_active? and current_active? -> false
      true -> not newer_run?(current_run, owner_run)
    end
  end

  defp active_run?(run),
    do: run.status in ["queued", "running_stage", "awaiting_result", "blocked"]

  defp newer_run?(left, right) do
    case {left.inserted_at, right.inserted_at} do
      {%DateTime{} = left_at, %DateTime{} = right_at} ->
        DateTime.compare(left_at, right_at) == :gt

      _ ->
        false
    end
  end

  defp projection_for(run, stage_id, stages) do
    stage = Enum.find(stages, &(&1.id == stage_id))
    transition = stage && Enum.find(stage.transitions || [], &(&1.on == run.status))

    %{
      stage: projected_ticket_stage(run, stage, transition),
      reason: projected_reason(run, transition)
    }
  end

  defp projected_ticket_stage(_run, _stage, %{ticket_stage_override: override})
       when is_binary(override), do: override

  defp projected_ticket_stage(%{status: "blocked"}, _stage, _transition), do: "in_progress"

  defp projected_ticket_stage(_run, %{ticket_stage: ticket_stage}, _transition)
       when is_binary(ticket_stage), do: ticket_stage

  defp projected_ticket_stage(_run, _stage, _transition), do: nil

  defp projected_reason(_run, %{ticket_reason: ticket_reason}) when is_binary(ticket_reason),
    do: ticket_reason

  defp projected_reason(_run, %{reason: reason}) when is_binary(reason), do: reason
  defp projected_reason(%{status: "queued"}, _transition), do: "queued_for_capacity"

  defp projected_reason(%{status: "blocked", failure_reason: reason}, _transition),
    do: reason || "stage_blocked"

  defp projected_reason(%{status: "failed", failure_reason: reason}, _transition),
    do: reason || "stage_failed"

  defp projected_reason(_run, _transition), do: nil

  defp persist_projection(ticket_repo, ticket_number, run, projection) do
    ticket_repo.set_lifecycle_projection(ticket_number, %{
      lifecycle_owner_run_id: run.id,
      lifecycle_reason: projection.reason
    })
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

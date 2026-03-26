defmodule Agents.Pipeline.Application.UseCases.RunStage do
  @moduledoc "Executes queued stages for a pipeline run."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.Domain.Entities.{PipelineRun, StageResult}
  alias Agents.Pipeline.Domain.Events.PipelineStageChanged
  alias Agents.Pipeline.Domain.Policies.PipelineLifecyclePolicy
  @spec execute(Ecto.UUID.t(), keyword()) :: {:ok, PipelineRun.t()} | {:error, term()}
  def execute(run_id, opts \\ []) do
    repo_module =
      Keyword.get(opts, :pipeline_run_repo, PipelineRuntimeConfig.pipeline_run_repository())

    stage_executor = Keyword.get(opts, :stage_executor, PipelineRuntimeConfig.stage_executor())
    gate_evaluator = Keyword.get(opts, :gate_evaluator, PipelineRuntimeConfig.gate_evaluator())
    event_bus = Keyword.get(opts, :event_bus, PipelineRuntimeConfig.event_bus())

    session_reopener =
      Keyword.get(opts, :session_reopener, PipelineRuntimeConfig.session_reopener())

    task_context_provider =
      Keyword.get(opts, :task_context_provider, PipelineRuntimeConfig.task_context_provider())

    with {:ok, config} <- load_pipeline(opts),
         {:ok, schema} <- repo_module.get_run(run_id) do
      run = PipelineRun.from_schema(schema)

      deps = %{
        stages: config.stages,
        repo_module: repo_module,
        stage_executor: stage_executor,
        gate_evaluator: gate_evaluator,
        session_reopener: session_reopener,
        event_bus: event_bus,
        task_context_provider: task_context_provider,
        opts: opts
      }

      do_execute(run, deps)
    end
  end

  defp do_execute(run, deps) do
    {stage_id, run} = PipelineRun.pop_next_stage(run)

    with true <- is_binary(stage_id),
         {:ok, stage} <- fetch_stage(deps.stages, stage_id),
         {:ok, running} <- transition_and_store(run, deps, "running_stage", stage_id),
         {:ok, awaiting} <- transition_and_store(running, deps, "awaiting_result", stage_id) do
      context = execution_context(awaiting, stage, deps)

      case deps.stage_executor.execute(stage, context) do
        {:ok, result} -> handle_success(awaiting, stage, result, context, deps)
        {:error, result} -> handle_failure(awaiting, stage, result, deps)
      end
    else
      false -> {:ok, run}
      error -> error
    end
  end

  defp handle_success(run, stage, result, context, deps) do
    gate_context = Map.put(context, "stage_execution", result.metadata || %{})

    with {:ok, gate_outcome} <- deps.gate_evaluator.evaluate(stage, stage.gates, gate_context) do
      case gate_outcome.status do
        :passed ->
          persist_gate_outcome(run, stage, result, gate_outcome, deps, "passed", nil)

        :blocked ->
          persist_gate_outcome(
            run,
            stage,
            result,
            gate_outcome,
            deps,
            "blocked",
            gate_outcome.reason
          )

        :failed ->
          persist_gate_outcome(
            run,
            stage,
            result,
            gate_outcome,
            deps,
            "failed",
            gate_outcome.reason
          )
      end
    end
  end

  defp persist_gate_outcome(run, stage, result, gate_outcome, deps, run_status, failure_reason) do
    stage_status = if(run_status == "passed", do: :passed, else: String.to_atom(run_status))

    stage_result =
      StageResult.new(%{
        stage_id: stage.id,
        status: stage_status,
        output: result.output,
        exit_code: result.exit_code,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second),
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        failure_reason: if(is_nil(failure_reason), do: nil, else: to_string(failure_reason)),
        metadata: Map.merge(result.metadata || %{}, gate_outcome.metadata || %{})
      })

    attrs = %{
      status: run_status,
      current_stage_id: if(run_status == "passed", do: nil, else: stage.id),
      remaining_stage_ids: run.remaining_stage_ids,
      stage_results:
        run |> PipelineRun.record_stage_result(stage_result) |> PipelineRun.stage_results_to_map(),
      failure_reason: if(is_nil(failure_reason), do: nil, else: to_string(failure_reason))
    }

    with {:ok, schema} <- deps.repo_module.update_run(run.id, attrs),
         :ok <- emit_stage_changed(deps.event_bus, run, "awaiting_result", run_status, stage.id),
         {:ok, updated_run} <- {:ok, PipelineRun.from_schema(schema)} do
      case {run_status, updated_run.remaining_stage_ids} do
        {"passed", []} -> {:ok, updated_run}
        {"passed", [_ | _]} -> do_execute(updated_run, deps)
        _ -> {:ok, updated_run}
      end
    end
  end

  defp handle_failure(run, stage, result, deps) do
    stage_result =
      StageResult.new(%{
        stage_id: stage.id,
        status: :failed,
        output: result.output,
        exit_code: result.exit_code,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second),
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        failure_reason: inspect(result.reason),
        metadata: result.metadata || %{}
      })

    attrs = %{
      status: "failed",
      current_stage_id: stage.id,
      remaining_stage_ids: run.remaining_stage_ids,
      stage_results:
        run |> PipelineRun.record_stage_result(stage_result) |> PipelineRun.stage_results_to_map(),
      failure_reason: inspect(result.reason)
    }

    with {:ok, failed_schema} <- deps.repo_module.update_run(run.id, attrs),
         :ok <- emit_stage_changed(deps.event_bus, run, "awaiting_result", "failed", stage.id) do
      failed_run = PipelineRun.from_schema(failed_schema)

      if failed_run.trigger_type == "on_session_complete" do
        reopen_failed_session(failed_run, deps)
      else
        {:ok, failed_run}
      end
    end
  end

  defp reopen_failed_session(run, deps) do
    with %{user_id: user_id} when is_binary(user_id) <- task_context(run.task_id, deps),
         :ok <- PipelineLifecyclePolicy.valid_transition?("failed", "reopen_session"),
         :ok <-
           deps.session_reopener.reopen(%{
             task_id: run.task_id,
             user_id: user_id,
             instruction: "Pipeline stage failed. Please fix the failing checks and continue."
           }),
         {:ok, reopened_schema} <-
           deps.repo_module.update_run(run.id, %{
             status: "reopen_session",
             remaining_stage_ids: run.remaining_stage_ids,
             reopened_at: DateTime.utc_now() |> DateTime.truncate(:second)
           }),
         :ok <-
           emit_stage_changed(
             deps.event_bus,
             run,
             "failed",
             "reopen_session",
             run.current_stage_id
           ) do
      {:ok, PipelineRun.from_schema(reopened_schema)}
    else
      %{} -> {:error, :missing_task_user}
      {:error, reason} -> {:error, {:reopen_session_failed, reason}}
      other -> {:error, {:reopen_session_failed, other}}
    end
  end

  defp execution_context(run, stage, deps) do
    task = task_context(run.task_id, deps)

    %{
      "task_id" => run.task_id,
      "session_id" => run.session_id,
      "pull_request_number" => run.pull_request_number,
      "source_branch" => run.source_branch,
      "target_branch" => run.target_branch,
      "trigger_type" => run.trigger_type,
      "stage_id" => stage.id,
      "stage_type" => stage.type,
      "stage_ticket_concurrency" => stage.ticket_concurrency,
      "container_id" => task[:container_id],
      "instruction" => task[:instruction]
    }
  end

  defp task_context(nil, _opts), do: %{}

  defp task_context(task_id, deps) do
    case deps.task_context_provider.get_task_context(task_id) do
      {:ok, task_context} -> task_context
      {:error, _reason} -> %{}
    end
  end

  defp transition_and_store(run, deps, next_status, stage_id) do
    with :ok <- PipelineLifecyclePolicy.valid_transition?(run.status, next_status),
         {:ok, schema} <-
           deps.repo_module.update_run(run.id, %{
             status: next_status,
             current_stage_id: stage_id,
             remaining_stage_ids: run.remaining_stage_ids
           }),
         :ok <- emit_stage_changed(deps.event_bus, run, run.status, next_status, stage_id) do
      {:ok, PipelineRun.from_schema(schema)}
    end
  end

  defp emit_stage_changed(event_bus, run, from_status, to_status, stage_id) do
    event_bus.emit(
      PipelineStageChanged.new(%{
        aggregate_id: to_string(run.id),
        actor_id: run.trigger_type,
        pipeline_run_id: run.id,
        stage_id: stage_id,
        from_status: from_status,
        to_status: to_status,
        trigger_type: run.trigger_type,
        task_id: run.task_id,
        session_id: run.session_id,
        pull_request_number: run.pull_request_number
      })
    )
  end

  defp fetch_stage(stages, stage_id) do
    case Enum.find(stages, &(&1.id == stage_id)) do
      nil -> {:error, :stage_not_found}
      stage -> {:ok, stage}
    end
  end

  defp load_pipeline(opts),
    do: LoadPipeline.execute(maybe_put([], :pipeline_config_repo, opts[:pipeline_config_repo]))

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end

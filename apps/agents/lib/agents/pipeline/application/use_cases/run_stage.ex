defmodule Agents.Pipeline.Application.UseCases.RunStage do
  @moduledoc "Executes queued stages for a pipeline run."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.{PipelineRun, StageResult}
  alias Agents.Pipeline.Domain.Events.PipelineStageChanged
  alias Agents.Pipeline.Domain.Policies.PipelineLifecyclePolicy
  alias Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @spec execute(Ecto.UUID.t(), keyword()) :: {:ok, PipelineRun.t()} | {:error, term()}
  def execute(run_id, opts \\ []) do
    repo_module =
      Keyword.get(opts, :pipeline_run_repo, PipelineRuntimeConfig.pipeline_run_repository())

    stage_executor = Keyword.get(opts, :stage_executor, PipelineRuntimeConfig.stage_executor())
    event_bus = Keyword.get(opts, :event_bus, PipelineRuntimeConfig.event_bus())

    session_reopener =
      Keyword.get(opts, :session_reopener, PipelineRuntimeConfig.session_reopener())

    pipeline_path = Keyword.get(opts, :pipeline_path, default_pipeline_path())

    with {:ok, config} <- load_pipeline(pipeline_path, opts),
         {:ok, schema} <- repo_module.get_run(run_id) do
      run = PipelineRun.from_schema(schema)

      do_execute(
        run,
        config.stages,
        repo_module,
        stage_executor,
        session_reopener,
        event_bus,
        opts
      )
    end
  end

  defp do_execute(run, stages, repo_module, stage_executor, session_reopener, event_bus, opts) do
    {stage_id, run} = PipelineRun.pop_next_stage(run)

    with true <- is_binary(stage_id),
         {:ok, stage} <- fetch_stage(stages, stage_id),
         {:ok, running} <-
           transition_and_store(run, repo_module, event_bus, "running_stage", stage_id),
         {:ok, awaiting} <-
           transition_and_store(running, repo_module, event_bus, "awaiting_result", stage_id) do
      context = execution_context(awaiting, opts)

      case stage_executor.execute(stage, context) do
        {:ok, result} ->
          handle_success(
            awaiting,
            stage,
            result,
            stages,
            repo_module,
            event_bus,
            stage_executor,
            session_reopener,
            opts
          )

        {:error, result} ->
          handle_failure(awaiting, stage, result, repo_module, event_bus, session_reopener, opts)
      end
    else
      false -> {:ok, run}
      error -> error
    end
  end

  defp handle_success(
         run,
         stage,
         result,
         stages,
         repo_module,
         event_bus,
         stage_executor,
         session_reopener,
         opts
       ) do
    stage_result =
      StageResult.new(%{
        stage_id: stage.id,
        status: :passed,
        output: result.output,
        exit_code: result.exit_code,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second),
        completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        metadata: result.metadata || %{}
      })

    attrs = %{
      status: "passed",
      current_stage_id: nil,
      remaining_stage_ids: run.remaining_stage_ids,
      stage_results:
        run |> PipelineRun.record_stage_result(stage_result) |> PipelineRun.stage_results_to_map(),
      failure_reason: nil
    }

    with {:ok, passed_schema} <- repo_module.update_run(run.id, attrs),
         :ok <- emit_stage_changed(event_bus, run, "awaiting_result", "passed", stage.id),
         {:ok, passed_run} <- {:ok, PipelineRun.from_schema(passed_schema)} do
      case passed_run.remaining_stage_ids do
        [] ->
          {:ok, passed_run}

        [next_stage_id | _] ->
          passed_run =
            maybe_mark_deploy(passed_run, stages, next_stage_id, repo_module, event_bus)

          do_execute(
            passed_run,
            stages,
            repo_module,
            stage_executor,
            session_reopener,
            event_bus,
            opts
          )
      end
    end
  end

  defp handle_failure(run, stage, result, repo_module, event_bus, session_reopener, opts) do
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

    with {:ok, failed_schema} <- repo_module.update_run(run.id, attrs),
         :ok <- emit_stage_changed(event_bus, run, "awaiting_result", "failed", stage.id) do
      failed_run = PipelineRun.from_schema(failed_schema)

      if failed_run.trigger_type == "on_session_complete" do
        reopen_failed_session(failed_run, repo_module, event_bus, session_reopener, opts)
      else
        {:ok, failed_run}
      end
    end
  end

  defp reopen_failed_session(run, repo_module, event_bus, session_reopener, opts) do
    with %{user_id: user_id} when is_binary(user_id) <- task_context(run.task_id, opts),
         :ok <- PipelineLifecyclePolicy.valid_transition?("failed", "reopen_session"),
         :ok <-
           session_reopener.reopen(%{
             task_id: run.task_id,
             user_id: user_id,
             instruction: "Pipeline stage failed. Please fix the failing checks and continue."
           }),
         {:ok, reopened_schema} <-
           repo_module.update_run(run.id, %{
             status: "reopen_session",
             remaining_stage_ids: run.remaining_stage_ids,
             reopened_at: DateTime.utc_now() |> DateTime.truncate(:second)
           }),
         :ok <-
           emit_stage_changed(event_bus, run, "failed", "reopen_session", run.current_stage_id) do
      {:ok, PipelineRun.from_schema(reopened_schema)}
    else
      %{} -> {:error, :missing_task_user}
      {:error, reason} -> {:error, {:reopen_session_failed, reason}}
      other -> {:error, {:reopen_session_failed, other}}
    end
  end

  defp maybe_mark_deploy(run, stages, next_stage_id, repo_module, event_bus) do
    case Enum.find(stages, &(&1.id == next_stage_id)) do
      %{type: "deploy"} ->
        with :ok <- PipelineLifecyclePolicy.valid_transition?(run.status, "deploy"),
             {:ok, schema} <-
               repo_module.update_run(run.id, %{
                 status: "deploy",
                 remaining_stage_ids: run.remaining_stage_ids
               }),
             :ok <- emit_stage_changed(event_bus, run, run.status, "deploy", next_stage_id) do
          PipelineRun.from_schema(schema)
        else
          _ -> run
        end

      _ ->
        run
    end
  end

  defp execution_context(run, opts) do
    task = task_context(run.task_id, opts)

    %{
      "task_id" => run.task_id,
      "session_id" => run.session_id,
      "pull_request_number" => run.pull_request_number,
      "source_branch" => run.source_branch,
      "target_branch" => run.target_branch,
      "trigger_type" => run.trigger_type,
      "container_id" => task[:container_id],
      "instruction" => task[:instruction]
    }
  end

  defp task_context(nil, _opts), do: %{}

  defp task_context(task_id, opts) do
    task_repo =
      Keyword.get(
        opts,
        :task_repo,
        Application.get_env(:agents, :pipeline_task_repo, TaskRepository)
      )

    case task_repo.get_task(task_id) do
      nil ->
        %{}

      task ->
        %{user_id: task.user_id, container_id: task.container_id, instruction: task.instruction}
    end
  end

  defp transition_and_store(run, repo_module, event_bus, next_status, stage_id) do
    with :ok <- PipelineLifecyclePolicy.valid_transition?(run.status, next_status),
         {:ok, schema} <-
           repo_module.update_run(run.id, %{
             status: next_status,
             current_stage_id: stage_id,
             remaining_stage_ids: run.remaining_stage_ids
           }),
         :ok <- emit_stage_changed(event_bus, run, run.status, next_status, stage_id) do
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

  defp load_pipeline(path, opts) do
    parser = Keyword.get(opts, :pipeline_parser, PipelineRuntimeConfig.pipeline_parser())
    parser.parse_file(path)
  end

  defp default_pipeline_path do
    Path.expand("../../../../../../../perme8-pipeline.yml", __DIR__)
  end
end

defmodule Agents.Pipeline.Application.UseCases.ManageMergeQueue do
  @moduledoc "Evaluates merge readiness, runs pre-merge validation, and merges eligible pull requests."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Application.UseCases.MergePullRequest
  alias Agents.Pipeline.Domain.Entities.{PipelineRun, PullRequest, Stage, Step}
  alias Agents.Pipeline.Domain.Policies.MergeQueuePolicy
  alias Agents.Pipeline.Infrastructure.MergeQueueWorker

  @spec execute(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(number, opts \\ []) when is_integer(number) do
    pull_request_repo =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    pipeline_run_repo =
      Keyword.get(opts, :pipeline_run_repo, PipelineRuntimeConfig.pipeline_run_repository())

    parser = Keyword.get(opts, :pipeline_parser, PipelineRuntimeConfig.pipeline_parser())
    stage_executor = Keyword.get(opts, :stage_executor, PipelineRuntimeConfig.stage_executor())
    merge_queue_worker = Keyword.get(opts, :merge_queue_worker, MergeQueueWorker)
    merge_pull_request = Keyword.get(opts, :merge_pull_request, MergePullRequest)
    pipeline_path = Keyword.get(opts, :pipeline_path, default_pipeline_path())
    worker_opts = merge_queue_worker_opts(opts)

    with {:ok, config} <- parser.parse_file(pipeline_path),
         {:ok, pr_schema} <- pull_request_repo.get_by_number(number),
         {:ok, run_schemas} <- list_runs(pipeline_run_repo, number),
         pull_request = PullRequest.from_schema(pr_schema),
         decision =
           MergeQueuePolicy.evaluate(
             pull_request,
             Enum.map(run_schemas, &PipelineRun.from_schema/1),
             config.merge_queue
           ),
         :ok <- ensure_ready(decision),
         {:ok, _} <- maybe_enqueue(merge_queue_worker, number, worker_opts, opts),
         {:ok, claim_status} <- merge_queue_worker.claim_next(number, worker_opts) do
      case claim_status do
        :queued ->
          {:ok, %{status: :queued, decision: decision, pull_request: pull_request}}

        :claimed ->
          case run_pre_merge_validation(config, pull_request, decision, stage_executor, opts) do
            {:ok, validation} ->
              with {:ok, merged} <- merge_pull_request.execute(number, opts) do
                :ok = merge_queue_worker.complete(number, worker_opts)

                {:ok,
                 %{
                   status: :merged,
                   decision: decision,
                   validation: validation,
                   pull_request: merged
                 }}
              else
                error ->
                  :ok = merge_queue_worker.fail(number, error, worker_opts)
                  error
              end

            {:error, reason} ->
              :ok = merge_queue_worker.fail(number, reason, worker_opts)
              {:error, {:pre_merge_validation_failed, reason, decision}}
          end
      end
    end
  end

  defp maybe_enqueue(worker, number, worker_opts, opts) do
    if Keyword.get(opts, :skip_enqueue?, false) do
      {:ok, :already_enqueued}
    else
      worker.enqueue(number, worker_opts)
    end
  end

  defp list_runs(repo_module, number) do
    case repo_module.list_runs_for_pull_request(number) do
      runs when is_list(runs) -> {:ok, runs}
      {:ok, runs} when is_list(runs) -> {:ok, runs}
      other -> {:error, {:invalid_pipeline_runs_response, other}}
    end
  end

  defp ensure_ready(%{eligible?: true}), do: :ok
  defp ensure_ready(%{reasons: reasons}), do: {:error, {:not_ready, reasons}}

  defp run_pre_merge_validation(config, pull_request, decision, stage_executor, opts) do
    validation_stage = build_validation_stage(config, pull_request, decision)

    context = %{
      "trigger_type" => "on_merge",
      "pull_request_number" => pull_request.number,
      "source_branch" => pull_request.source_branch,
      "target_branch" => pull_request.target_branch,
      "container_id" => Keyword.get(opts, :container_id)
    }

    case stage_executor.execute(validation_stage, context) do
      {:ok, result} ->
        {:ok,
         %{
           result: result,
           stage_id: validation_stage.id,
           required_stages: decision.required_stages
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_validation_stage(config, pull_request, decision) do
    stages = validation_stages(config, decision.required_stages)

    timeout_seconds =
      stages
      |> Enum.flat_map(& &1.steps)
      |> Enum.map(&(&1.timeout_seconds || 0))
      |> Enum.max(fn -> 30 end)

    command_chain =
      stages
      |> Enum.flat_map(& &1.steps)
      |> Enum.map(& &1.run)
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" && ")

    merge_command =
      "(git merge --no-ff --no-commit #{shell_escape(pull_request.source_branch)} && #{command_chain}); STATUS=$?; git merge --abort >/dev/null 2>&1 || true; exit $STATUS"

    Stage.new(%{
      id: "merge-queue-validation",
      type: "verification",
      config: %{"pre_merge_validation" => true},
      steps: [
        Step.new(%{
          name: "validate-merge-result",
          run: merge_command,
          timeout_seconds: timeout_seconds,
          retries: 0,
          env: %{}
        })
      ],
      gates: []
    })
  end

  defp validation_stages(config, []), do: Enum.filter(config.stages, &(&1.type == "verification"))

  defp validation_stages(config, required_stage_ids) do
    case Enum.filter(config.stages, &(&1.id in required_stage_ids)) do
      [] -> Enum.filter(config.stages, &(&1.type == "verification"))
      stages -> stages
    end
  end

  defp shell_escape(value) do
    escaped = String.replace(value || "", "'", "'\"'\"'")
    "'#{escaped}'"
  end

  defp merge_queue_worker_opts(opts) do
    case Keyword.get(opts, :merge_queue_worker_name) do
      nil -> []
      name -> [name: name]
    end
  end

  defp default_pipeline_path do
    Path.expand("../../../../../../../perme8-pipeline.yml", __DIR__)
  end
end

defmodule Agents.Pipeline.Application.UseCases.ReplenishWarmPool do
  @moduledoc """
  Replenishes the configured warm pool by executing the YAML-defined warm-pool stage.
  """

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Policies.WarmPoolPolicy

  @type result :: %{
          status: :replenished | :skipped,
          current_count: non_neg_integer(),
          shortage: non_neg_integer(),
          target_count: non_neg_integer(),
          stage_id: String.t()
        }

  @doc "Executes a warm-pool replenishment cycle from the configured YAML stage."
  @spec execute(keyword()) :: {:ok, result()} | {:error, term()}
  def execute(opts \\ []) do
    pipeline_path = Keyword.get(opts, :pipeline_path, default_pipeline_path())
    parser = Keyword.get(opts, :pipeline_parser, PipelineRuntimeConfig.pipeline_parser())
    stage_executor = Keyword.get(opts, :stage_executor, PipelineRuntimeConfig.stage_executor())

    warm_pool_counter =
      Keyword.get(opts, :warm_pool_counter, PipelineRuntimeConfig.warm_pool_counter())

    with {:ok, config} <- parser.parse_file(pipeline_path),
         {:ok, stage} <- fetch_warm_pool_stage(config.stages),
         {:ok, policy} <- WarmPoolPolicy.from_stage(stage) do
      execute_replenishment(stage, policy, warm_pool_counter, stage_executor)
    else
      {:error, _} = error -> error
    end
  end

  defp execute_replenishment(stage, policy, warm_pool_counter, stage_executor) do
    with {:ok, current_count} <- fetch_current_count(warm_pool_counter, policy) do
      shortage = WarmPoolPolicy.shortage(policy, current_count)

      if shortage == 0 do
        {:ok, skipped_result(policy, current_count)}
      else
        run_replenishment_stage(stage, policy, current_count, shortage, stage_executor)
      end
    end
  end

  defp fetch_current_count(warm_pool_counter, policy) do
    case warm_pool_counter.current_warm_count(policy) do
      current_count when is_integer(current_count) and current_count >= 0 -> {:ok, current_count}
      {:error, _} = error -> error
      other -> {:error, {:invalid_warm_pool_count, other}}
    end
  end

  defp run_replenishment_stage(stage, policy, current_count, shortage, stage_executor) do
    case stage_executor.execute(
           stage_with_runtime_env(stage, policy, shortage),
           execution_context(policy, current_count, shortage)
         ) do
      {:ok, _result} -> {:ok, replenished_result(policy, current_count, shortage)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_warm_pool_stage(stages) do
    case Enum.find(stages, &(&1.type == "warm_pool" or &1.id == "warm-pool")) do
      nil -> {:error, :warm_pool_stage_not_found}
      stage -> {:ok, stage}
    end
  end

  defp execution_context(policy, current_count, shortage) do
    %{
      "trigger_type" => "on_warm_pool",
      "warm_pool_stage_id" => policy.stage_id,
      "warm_pool_target_count" => policy.target_count,
      "warm_pool_current_count" => current_count,
      "warm_pool_shortage" => shortage,
      "warm_pool_image" => policy.image,
      "warm_pool_readiness_strategy" => Map.get(policy.readiness_criteria, "strategy"),
      "warm_pool_readiness_required_step" => Map.get(policy.readiness_criteria, "required_step")
    }
  end

  defp stage_with_runtime_env(stage, policy, shortage) do
    env = %{
      "WARM_POOL_IMAGE" => policy.image,
      "WARM_POOL_TARGET_COUNT" => Integer.to_string(policy.target_count),
      "WARM_POOL_SHORTAGE" => Integer.to_string(shortage),
      "WARM_POOL_READINESS_STRATEGY" =>
        to_string(Map.get(policy.readiness_criteria, "strategy", "")),
      "WARM_POOL_READINESS_REQUIRED_STEP" =>
        to_string(Map.get(policy.readiness_criteria, "required_step", ""))
    }

    steps =
      Enum.map(
        stage.steps,
        &Map.update!(&1, :env, fn step_env -> Map.merge(env, step_env || %{}) end)
      )

    %{stage | steps: steps}
  end

  defp skipped_result(policy, current_count) do
    %{
      status: :skipped,
      current_count: current_count,
      shortage: 0,
      target_count: policy.target_count,
      stage_id: policy.stage_id
    }
  end

  defp replenished_result(policy, current_count, shortage) do
    %{
      status: :replenished,
      current_count: current_count,
      shortage: shortage,
      target_count: policy.target_count,
      stage_id: policy.stage_id
    }
  end

  defp default_pipeline_path do
    Path.expand("../../../../../../../perme8-pipeline.yml", __DIR__)
  end
end

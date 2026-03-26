defmodule Agents.Pipeline.Application.UseCases.ReplenishWarmPoolTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.UseCases.ReplenishWarmPool
  alias Agents.Pipeline.Domain.Entities.{Stage, Step}

  defmodule PipelineConfigRepoStub do
    def get_current, do: Process.get(:pipeline_config)
  end

  defmodule WarmPoolCounterStub do
    def current_warm_count(policy) do
      send(self(), {:current_warm_count, policy.target_count})
      Process.get(:current_warm_count, 0)
    end
  end

  defmodule StageExecutorStub do
    def execute(stage, context) do
      send(self(), {:execute, stage, context})
      Process.get(:stage_result, {:ok, %{output: "ok", exit_code: 0, metadata: %{}}})
    end
  end

  defmodule InventoryErrorCounterStub do
    def current_warm_count(_policy), do: {:error, :warm_pool_inventory_unavailable}
  end

  test "skips replenishment when current count meets target" do
    Process.put(:pipeline_config, {:ok, pipeline_config(2)})
    Process.put(:current_warm_count, 2)

    assert {:ok, result} =
             ReplenishWarmPool.execute(
               pipeline_config_repo: PipelineConfigRepoStub,
               warm_pool_counter: WarmPoolCounterStub,
               stage_executor: StageExecutorStub
             )

    assert result.status == :skipped
    refute_received {:execute, _, _}
  end

  test "executes the warm-pool stage when there is a shortage" do
    Process.put(:pipeline_config, {:ok, pipeline_config(3)})
    Process.put(:current_warm_count, 1)

    assert {:ok, result} =
             ReplenishWarmPool.execute(
               pipeline_config_repo: PipelineConfigRepoStub,
               warm_pool_counter: WarmPoolCounterStub,
               stage_executor: StageExecutorStub
             )

    assert result.status == :replenished
    assert result.shortage == 2

    assert_received {:execute, stage, context}
    [step] = stage.steps
    assert step.env["WARM_POOL_SHORTAGE"] == "2"
    assert context["warm_pool_shortage"] == 2
  end

  test "returns inventory errors without executing the stage" do
    Process.put(:pipeline_config, {:ok, pipeline_config(3)})

    assert {:error, :warm_pool_inventory_unavailable} =
             ReplenishWarmPool.execute(
               pipeline_config_repo: PipelineConfigRepoStub,
               warm_pool_counter: InventoryErrorCounterStub,
               stage_executor: StageExecutorStub
             )

    refute_received {:execute, _, _}
  end

  defp pipeline_config(target_count) do
    %{
      stages: [
        Stage.new(%{
          id: "warm-pool",
          type: "warm_pool",
          schedule: %{"cron" => "*/5 * * * *"},
          config: %{
            "warm_pool" => %{
              "target_count" => target_count,
              "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
              "readiness" => %{"strategy" => "command_success", "required_step" => "prewarm"}
            }
          },
          steps: [Step.new(%{name: "prewarm", run: "scripts/warm_pool.sh", env: %{}})]
        })
      ]
    }
  end
end

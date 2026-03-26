defmodule Agents.Pipeline.Infrastructure.PipelineSchedulerTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.PipelineScheduler
  alias Agents.Pipeline.Domain.Entities.Stage

  defmodule PipelineConfigRepoStub do
    def get_current do
      {:ok,
       %{
         stages: [
           Stage.new(%{
             id: "warm-pool",
             type: "warm_pool",
             schedule: %{"cron" => "*/1 * * * *"}
           })
         ]
       }}
    end
  end

  defmodule ReplenishWarmPoolStub do
    def execute(_opts) do
      if pid = Process.whereis(:pipeline_scheduler_test_observer) do
        send(pid, :replenish_called)
      end

      {:ok, %{status: :replenished}}
    end
  end

  test "runs warm-pool replenishment on tick without crashing" do
    Process.register(self(), :pipeline_scheduler_test_observer)
    name = String.to_atom("pipeline_scheduler_test_#{System.unique_integer([:positive])}")

    Application.put_env(:agents, :pipeline_config_repository, PipelineConfigRepoStub)

    on_exit(fn ->
      Application.delete_env(:agents, :pipeline_config_repository)

      if Process.whereis(:pipeline_scheduler_test_observer) == self() do
        Process.unregister(:pipeline_scheduler_test_observer)
      end
    end)

    {:ok, pid} =
      start_supervised(
        {PipelineScheduler, replenish_warm_pool: ReplenishWarmPoolStub, name: name}
      )

    send(pid, :tick)
    assert_receive :replenish_called
  end
end

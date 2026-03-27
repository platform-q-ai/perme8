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
             triggers: ["on_warm_pool"],
             schedule: %{"cron" => "*/1 * * * *"}
           })
         ]
       }}
    end
  end

  defmodule TriggerPipelineRunStub do
    def execute(_attrs) do
      if pid = Process.whereis(:pipeline_scheduler_test_observer) do
        send(pid, :trigger_called)
      end

      {:ok, %{status: "started"}}
    end
  end

  test "triggers scheduled pipeline flow on tick without crashing" do
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
        {PipelineScheduler, trigger_pipeline_run: TriggerPipelineRunStub, name: name}
      )

    send(pid, :tick)
    assert_receive :trigger_called
  end
end

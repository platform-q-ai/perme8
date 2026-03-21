defmodule Agents.Pipeline.Infrastructure.PipelineSchedulerTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.PipelineScheduler
  alias Agents.Pipeline.Domain.Entities.Stage

  defmodule ParserStub do
    def parse_file(_path),
      do:
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

    {:ok, pid} =
      start_supervised(
        {PipelineScheduler,
         pipeline_path: "ignored.yml",
         pipeline_parser: ParserStub,
         replenish_warm_pool: ReplenishWarmPoolStub,
         name: name}
      )

    send(pid, :tick)
    assert_receive :replenish_called
    Process.unregister(:pipeline_scheduler_test_observer)
  end
end
